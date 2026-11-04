-- LOCAL MARS: canonical M-003 value and member profile support.
-- Apply after 001_mars_world.sql in the Supabase project used by world-server.js.

insert into public.world_parcels
  (id, latitude, longitude, area_sqm, terrain, resource, base_price)
values
  ('M-003', 3, -26, 1550, 'ที่ราบสูง', 'ซิลิกา', 9999999)
on conflict (id) do update set
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  area_sqm = excluded.area_sqm,
  terrain = excluded.terrain,
  resource = excluded.resource,
  base_price = excluded.base_price;

-- The browser client writes a display profile after online sign-up/sign-in.
create table if not exists public.mars_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Explorer',
  updated_at timestamptz not null default now()
);

alter table public.mars_profiles enable row level security;
drop policy if exists mars_profiles_read_own on public.mars_profiles;
create policy mars_profiles_read_own on public.mars_profiles
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists mars_profiles_insert_own on public.mars_profiles;
create policy mars_profiles_insert_own on public.mars_profiles
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists mars_profiles_update_own on public.mars_profiles;
create policy mars_profiles_update_own on public.mars_profiles
  for update to authenticated using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update on public.mars_profiles to authenticated;
grant select on public.world_parcels to anon, authenticated;
