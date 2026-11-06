-- Disable the LOCAL MARS administrator satellite catalog console.
drop policy if exists "Only admins can read satellite catalog snapshots" on public.ares_satellite_catalog_snapshots;
revoke all privileges on table public.ares_satellite_catalog_snapshots from anon, authenticated;
select cron.unschedule('ares-public-satellite-sync');