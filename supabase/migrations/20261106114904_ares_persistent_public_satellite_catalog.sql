-- ARES persistent public satellite catalog.
-- Provider GP elements are stored in Supabase; refresh runs every two hours.
create table if not exists public.ares_satellite_catalog_snapshots (
  group_id text primary key check (group_id in ('GNSS','MILITARY','WEATHER','EARTH-RESOURCES','STATIONS')),
  source_url text not null,
  payload jsonb not null default '[]'::jsonb check (jsonb_typeof(payload) = 'array'),
  record_count integer not null default 0 check (record_count >= 0),
  fetched_at timestamptz not null default now(),
  source_status text not null default 'ok' check (source_status in ('ok','error'))
);
alter table public.ares_satellite_catalog_snapshots enable row level security;
drop policy if exists "Public satellite catalog snapshots are readable" on public.ares_satellite_catalog_snapshots;
create policy "Public satellite catalog snapshots are readable"
on public.ares_satellite_catalog_snapshots for select to anon, authenticated using (true);
grant select on public.ares_satellite_catalog_snapshots to anon, authenticated;
revoke insert, update, delete on public.ares_satellite_catalog_snapshots from anon, authenticated;

create table if not exists public.ares_satellite_sync_state (
  group_id text primary key check (group_id in ('GNSS','MILITARY','WEATHER','EARTH-RESOURCES','STATIONS')),
  source_group text not null,
  request_id bigint,
  requested_at timestamptz,
  last_success_at timestamptz,
  last_error text
);
alter table public.ares_satellite_sync_state enable row level security;
revoke all on public.ares_satellite_sync_state from anon, authenticated;

insert into public.ares_satellite_sync_state(group_id,source_group) values
 ('GNSS','gnss'),('MILITARY','military'),('WEATHER','weather'),('EARTH-RESOURCES','resource'),('STATIONS','stations')
on conflict (group_id) do update set source_group=excluded.source_group;

create or replace function public.ares_sync_public_satellite_catalog()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, net
as $$
declare
  s record;
  response_row record;
  new_request_id bigint;
  processed integer := 0;
  queued integer := 0;
  parsed jsonb;
  source_url text;
begin
  for s in select * from public.ares_satellite_sync_state order by group_id loop
    if s.request_id is not null then
      select status_code, content, error_msg into response_row
      from net._http_response where id = s.request_id;
      if found then
        if response_row.status_code between 200 and 299 and response_row.content is not null then
          begin
            parsed := response_row.content::jsonb;
            if jsonb_typeof(parsed) = 'array' then
              source_url := 'https://celestrak.org/NORAD/elements/gp.php?GROUP=' || s.source_group || '&FORMAT=JSON';
              insert into public.ares_satellite_catalog_snapshots(group_id,source_url,payload,record_count,fetched_at,source_status)
              values(s.group_id,source_url,parsed,jsonb_array_length(parsed),now(),'ok')
              on conflict (group_id) do update set source_url=excluded.source_url,payload=excluded.payload,
                record_count=excluded.record_count,fetched_at=excluded.fetched_at,source_status='ok';
              update public.ares_satellite_sync_state set last_success_at=now(),last_error=null where group_id=s.group_id;
              processed := processed + 1;
            else
              update public.ares_satellite_sync_state set last_error='Provider returned non-array JSON' where group_id=s.group_id;
            end if;
          exception when others then
            update public.ares_satellite_sync_state set last_error=left(sqlerrm,500) where group_id=s.group_id;
          end;
        else
          update public.ares_satellite_sync_state set last_error=coalesce(response_row.error_msg,'HTTP '||response_row.status_code::text) where group_id=s.group_id;
        end if;
      end if;
    end if;

    if s.requested_at is null or s.requested_at < now() - interval '2 hours' then
      source_url := 'https://celestrak.org/NORAD/elements/gp.php?GROUP=' || s.source_group || '&FORMAT=JSON';
      new_request_id := net.http_get(url:=source_url,headers:='{"Accept":"application/json"}'::jsonb,timeout_milliseconds:=20000);
      update public.ares_satellite_sync_state set request_id=new_request_id,requested_at=now() where group_id=s.group_id;
      queued := queued + 1;
    end if;
  end loop;
  return jsonb_build_object('processed',processed,'queued',queued,'checked_at',now());
end;
$$;
revoke all on function public.ares_sync_public_satellite_catalog() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname='ares-public-satellite-sync';
select cron.schedule('ares-public-satellite-sync','0 */2 * * *','select public.ares_sync_public_satellite_catalog();');
select public.ares_sync_public_satellite_catalog();
