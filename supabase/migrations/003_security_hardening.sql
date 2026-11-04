-- MARS LAND hardening patch. Run AFTER 002_global_cities_wallet_market.sql.
-- mars_profiles contains only public-safe fields; keep email and auth data in auth.users.
drop policy if exists mars_profiles_read_self on public.mars_profiles;
drop policy if exists mars_profiles_read_public_safe on public.mars_profiles;
create policy mars_profiles_read_public_safe
on public.mars_profiles for select to anon, authenticated
using (true);

-- A fixed server-side key prevents clients from minting repeated starter grants
-- by changing an idempotency key.
drop function if exists public.mars_wallet_grant_starter(text);
drop function if exists public.mars_wallet_grant_starter();
create function public.mars_wallet_grant_starter()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  u uuid := auth.uid();
begin
  if u is null then
    raise exception 'กรุณาเข้าสู่ระบบ';
  end if;

  insert into public.mars_wallet_ledger
    (user_id, idempotency_key, resource, amount, reason)
  values
    (u, 'starter-grant-v1', 'credits', 500, 'DEMO starter grant'),
    (u, 'starter-grant-v1', 'energy', 100, 'DEMO starter grant'),
    (u, 'starter-grant-v1', 'metal', 50, 'DEMO starter grant')
  on conflict (user_id, idempotency_key, resource) do nothing;

  return jsonb_build_object('ok', true, 'demo_only', true);
end;
$$;

revoke all on function public.mars_wallet_grant_starter() from public;
grant execute on function public.mars_wallet_grant_starter() to authenticated;
