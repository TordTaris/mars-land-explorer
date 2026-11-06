create or replace function public.mars_wallet_mlc_claim_m001_allocation()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  u uuid := auth.uid();
  v_id uuid;
  v_balance bigint;
begin
  if u is null then raise exception 'Sign in is required'; end if;
  if u <> '01eb201c-0f2c-401e-bd49-2bda52afc80c'::uuid then
    raise exception 'This one-time M-001 development allocation is not assigned to this account';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:' || u::text, 0));
  insert into public.mars_wallet_ledger(user_id,idempotency_key,resource,amount,reason)
  values (u,'mlc:m001-development-allocation:v1','mlc',10000,'M-001 development sandbox allocation')
  on conflict (user_id,idempotency_key,resource) do nothing
  returning id into v_id;
  select coalesce(sum(amount),0)::bigint into v_balance
  from public.mars_wallet_ledger where user_id=u and resource='mlc';
  return jsonb_build_object('ok',true,'granted',v_id is not null,
    'allocation_amount',case when v_id is not null then 10000 else 0 end,
    'balance',v_balance,'currency','MLC','cash_value',false);
end;
$function$;
revoke all on function public.mars_wallet_mlc_claim_m001_allocation() from public;
revoke all on function public.mars_wallet_mlc_claim_m001_allocation() from anon;
grant execute on function public.mars_wallet_mlc_claim_m001_allocation() to authenticated;