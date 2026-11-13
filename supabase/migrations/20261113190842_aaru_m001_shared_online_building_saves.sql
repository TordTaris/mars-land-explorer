-- A’ARU M-001 shared online construction records.
-- Mirrors each member-owned private construction row; no wallet or parcel ownership data is exposed.
create table if not exists public.aaru_m001_shared_buildings (
  id uuid primary key default gen_random_uuid(),
  parcel_id text not null default 'M-001' check (parcel_id = 'M-001'),
  owner_id uuid not null references auth.users(id) on delete cascade,
  source_building_id uuid not null references public.mars_city_buildings(id) on delete cascade,
  building_type text not null check (building_type in ('habitat','greenhouse','landing_pad','lab','solar','road','climate_control')),
  name text not null check (char_length(name) between 1 and 60),
  position jsonb not null default '{}'::jsonb check (
    jsonb_typeof(position) = 'object'
    and jsonb_typeof(position->'x') = 'number'
    and jsonb_typeof(position->'z') = 'number'
    and abs((position->>'x')::numeric) <= 50
    and abs((position->>'z')::numeric) <= 50
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, source_building_id)
);

comment on table public.aaru_m001_shared_buildings is
  'Shared A’ARU construction records for parcel M-001. Each row mirrors an authenticated member-owned mars_city_buildings record; no wallet or parcel ownership data is stored here.';

alter table public.aaru_m001_shared_buildings enable row level security;
grant select, insert, update, delete on public.aaru_m001_shared_buildings to authenticated;

drop policy if exists aaru_m001_shared_read_members on public.aaru_m001_shared_buildings;
create policy aaru_m001_shared_read_members
  on public.aaru_m001_shared_buildings for select to authenticated
  using (true);

drop policy if exists aaru_m001_shared_insert_owner on public.aaru_m001_shared_buildings;
create policy aaru_m001_shared_insert_owner
  on public.aaru_m001_shared_buildings for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.mars_city_buildings b
      where b.id = source_building_id
        and b.owner_id = (select auth.uid())
    )
  );

drop policy if exists aaru_m001_shared_update_owner on public.aaru_m001_shared_buildings;
create policy aaru_m001_shared_update_owner
  on public.aaru_m001_shared_buildings for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.mars_city_buildings b
      where b.id = source_building_id
        and b.owner_id = (select auth.uid())
    )
  );

drop policy if exists aaru_m001_shared_delete_owner on public.aaru_m001_shared_buildings;
create policy aaru_m001_shared_delete_owner
  on public.aaru_m001_shared_buildings for delete to authenticated
  using (owner_id = (select auth.uid()));

alter table public.aaru_m001_shared_buildings replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'aaru_m001_shared_buildings'
  ) then
    alter publication supabase_realtime add table public.aaru_m001_shared_buildings;
  end if;
end
$$;
