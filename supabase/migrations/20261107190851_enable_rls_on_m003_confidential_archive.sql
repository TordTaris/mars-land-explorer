-- LOCAL MARS: defense-in-depth for the M-003 confidential archive.
-- The archive remains private; no direct table access is granted to API roles.
alter table lmso_private.m003_confidential_archive enable row level security;
revoke all on table lmso_private.m003_confidential_archive from public, anon, authenticated;
