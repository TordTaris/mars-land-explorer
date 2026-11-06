drop policy if exists "Only admins can read satellite catalog snapshots" on public.ares_satellite_catalog_snapshots;
drop policy if exists "Authenticated members can read satellite catalog snapshots" on public.ares_satellite_catalog_snapshots;
create policy "Authenticated members can read satellite catalog snapshots"
on public.ares_satellite_catalog_snapshots
for select to authenticated
using ((select auth.uid()) is not null);
revoke all privileges on table public.ares_satellite_catalog_snapshots from anon;
grant select on table public.ares_satellite_catalog_snapshots to authenticated;
do $$
begin
  if exists (select 1 from cron.job where jobname='ares-public-satellite-sync') then
    perform cron.unschedule('ares-public-satellite-sync');
  end if;
  perform cron.schedule('ares-public-satellite-sync','0 */2 * * *','select public.ares_sync_public_satellite_catalog();');
end $$;