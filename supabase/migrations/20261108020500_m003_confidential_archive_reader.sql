-- LOCAL MARS: server-only reader for the M-003 confidential archive.
-- The Edge Function invokes this only after verifying the signed-in M-003 owner
-- and the separate M-003 security password.
create or replace function public.get_m003_confidential_archive()
returns jsonb
language sql
security definer
set search_path = pg_catalog, lmso_private
as $$
  select jsonb_build_object(
    'record_key', record_key,
    'title', title,
    'classification', classification,
    'parcel_id', parcel_id,
    'floor_no', floor_no,
    'content', content,
    'created_at', created_at,
    'updated_at', updated_at
  )
  from lmso_private.m003_confidential_archive
  where record_key = 'LMSO_CONFIDENTIALITY_POLICY_V1'
  limit 1;
$$;
revoke all on function public.get_m003_confidential_archive() from public, anon, authenticated;
grant execute on function public.get_m003_confidential_archive() to service_role;
