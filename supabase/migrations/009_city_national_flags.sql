-- LOCAL MARS: shared national flags for the 3D city construction simulator.
-- Run this migration in the same Supabase project used by city.html.
create table if not exists public.mars_city_national_flags (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  country_name text not null,
  flag_emoji text not null,
  x double precision not null check (x between -10.5 and 10.5),
  z double precision not null check (z between -10.5 and 10.5),
  level integer not null default 0 check (level between 0 and 2),
  created_at timestamptz not null default now()
);
create index if not exists mars_city_national_flags_created_idx
  on public.mars_city_national_flags(created_at);
create index if not exists mars_city_national_flags_owner_idx
  on public.mars_city_national_flags(owner_id);
alter table public.mars_city_national_flags enable row level security;
drop policy if exists mars_city_national_flags_public_read on public.mars_city_national_flags;
create policy mars_city_national_flags_public_read
  on public.mars_city_national_flags for select to anon, authenticated using (true);
drop policy if exists mars_city_national_flags_owner_insert on public.mars_city_national_flags;
create policy mars_city_national_flags_owner_insert
  on public.mars_city_national_flags for insert to authenticated
  with check (auth.uid() = owner_id);
drop policy if exists mars_city_national_flags_owner_update on public.mars_city_national_flags;
create policy mars_city_national_flags_owner_update
  on public.mars_city_national_flags for update to authenticated
  using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
drop policy if exists mars_city_national_flags_owner_delete on public.mars_city_national_flags;
create policy mars_city_national_flags_owner_delete
  on public.mars_city_national_flags for delete to authenticated
  using (auth.uid() = owner_id);
grant select on public.mars_city_national_flags to anon, authenticated;
grant insert, update, delete on public.mars_city_national_flags to authenticated;
do $$
begin
  alter publication supabase_realtime add table public.mars_city_national_flags;
exception
  when duplicate_object then null;
  when undefined_object then null;
end
$$;
