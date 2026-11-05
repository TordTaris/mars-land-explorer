-- LOCAL MARS 020: global shared-world Realtime publication coverage.
-- Additive and idempotent. Preserves existing parcel, THB and MLC data.
-- Apply after the currently deployed database migrations, including 019 if present.

begin;

do $$
declare
  v_table text;
  v_tables text[] := array[
    'world_parcels',
    'world_claims',
    'world_structures',
    'world_events',
    'mars_cities',
    'mars_city_buildings',
    'mars_city_resources',
    'mars_city_national_flags',
    'mars_mlc_parcel_market'
  ];
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise exception 'supabase_realtime publication is missing; enable Realtime in Supabase before applying migration 020';
  end if;

  foreach v_table in array v_tables loop
    if to_regclass(format('public.%I', v_table)) is not null
       and not exists (
         select 1 from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = v_table
       ) then
      execute format('alter publication supabase_realtime add table public.%I', v_table);
    end if;
  end loop;
end
$$;

commit;
