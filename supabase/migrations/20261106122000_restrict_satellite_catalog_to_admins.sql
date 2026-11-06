create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create or replace function private.is_mars_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null
     and exists (
       select 1 from public.mars_store_admins a
       where a.user_id = auth.uid()
     );
$$;

revoke all on function private.is_mars_admin() from public;
grant execute on function private.is_mars_admin() to authenticated;

drop policy if exists "Public satellite catalog snapshots are readable"
  on public.ares_satellite_catalog_snapshots;
drop policy if exists "Only admins can read satellite catalog snapshots"
  on public.ares_satellite_catalog_snapshots;

revoke all on table public.ares_satellite_catalog_snapshots from anon;
grant select on table public.ares_satellite_catalog_snapshots to authenticated;

create policy "Only admins can read satellite catalog snapshots"
  on public.ares_satellite_catalog_snapshots
  for select to authenticated
  using (private.is_mars_admin());
