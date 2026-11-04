-- LOCAL MARS 012: separate closed-loop MLC game wallet.
-- MLC is a non-cashable in-app game currency. It is NOT USD, ETH, crypto,
-- a deposit, a payment method, or redeemable for real money.
alter table public.mars_wallet_ledger
  drop constraint if exists mars_wallet_ledger_resource_check;
alter table public.mars_wallet_ledger
  add constraint mars_wallet_ledger_resource_check
  check (resource in ('credits','energy','metal','mlc'));

create or replace function public.mars_wallet_mlc_grant_starter()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare u uuid:=auth.uid();
begin
  if u is null then raise exception 'กรุณาเข้าสู่ระบบ'; end if;
  insert into public.mars_wallet_ledger(user_id,idempotency_key,resource,amount,reason)
  values(u,'mlc:starter:v1','mlc',1000,'MLC starter allocation')
  on conflict(user_id,idempotency_key,resource) do nothing;
  return jsonb_build_object('ok',true,'currency','MLC','starter_amount',1000,'demo_only',true);
end $$;

create or replace function public.mars_wallet_mlc_transfer(
  p_recipient uuid,
  p_amount integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  u uuid:=auth.uid();
  sender_balance bigint;
  existing_id uuid;
  lock_key text;
begin
  if u is null then raise exception 'กรุณาเข้าสู่ระบบ'; end if;
  if p_recipient is null or p_recipient=u then raise exception 'บัญชีผู้รับไม่ถูกต้อง'; end if;
  if p_amount is null or p_amount<1 or p_amount>1000000 then raise exception 'จำนวน MLC ต้องอยู่ระหว่าง 1 ถึง 1,000,000'; end if;
  if p_idempotency_key is null or p_idempotency_key !~ '^mlc:[a-zA-Z0-9:_-]{8,100}$' then raise exception 'รหัสรายการไม่ถูกต้อง'; end if;

  select id into existing_id from public.mars_wallet_ledger
    where user_id=u and idempotency_key=p_idempotency_key and resource='mlc';
  if existing_id is not null then
    return jsonb_build_object('ok',true,'duplicate',true,'demo_only',true);
  end if;

  -- Acquire account locks in a stable order to prevent deadlocks.
  lock_key:=least(u::text,p_recipient::text)||':'||greatest(u::text,p_recipient::text);
  perform pg_advisory_xact_lock(hashtextextended(lock_key,0));

  if not exists(select 1 from auth.users where id=p_recipient) then
    raise exception 'ไม่พบบัญชีผู้รับ';
  end if;
  select coalesce(sum(amount),0) into sender_balance
    from public.mars_wallet_ledger where user_id=u and resource='mlc';
  if sender_balance<p_amount then raise exception 'ยอด MLC ไม่เพียงพอ'; end if;

  insert into public.mars_wallet_ledger(user_id,idempotency_key,resource,amount,reason)
  values
    (u,p_idempotency_key,'mlc',-p_amount,'MLC transfer sent to '||p_recipient::text),
    (p_recipient,p_idempotency_key,'mlc',p_amount,'MLC transfer received from '||u::text);
  return jsonb_build_object('ok',true,'amount',p_amount,'currency','MLC','demo_only',true);
end $$;

revoke all on function public.mars_wallet_mlc_grant_starter() from public;
revoke all on function public.mars_wallet_mlc_transfer(uuid,integer,text) from public;
grant execute on function public.mars_wallet_mlc_grant_starter() to authenticated;
grant execute on function public.mars_wallet_mlc_transfer(uuid,integer,text) to authenticated;
