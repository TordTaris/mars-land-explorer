-- LOCAL MARS payment RPCs: all money and fulfillment writes are server-only.
-- Apply after 003_promptpay_parcel_payments.sql in Supabase SQL Editor.

alter table public.mars_parcel_orders
  add column if not exists expires_at timestamptz;

create or replace function public.mars_create_parcel_order(
  p_buyer_id uuid,
  p_parcel_id text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parcel public.world_parcels%rowtype;
  v_order public.mars_parcel_orders%rowtype;
begin
  if coalesce(current_setting('request.jwt.claim.role', true),'') <> 'service_role' then
    raise exception 'forbidden';
  end if;
  select * into v_parcel from public.world_parcels where id=p_parcel_id for update;
  if not found then raise exception 'ไม่พบแปลงพื้นที่'; end if;
  if not v_parcel.is_for_sale or v_parcel.sale_price_thb is null or v_parcel.sale_price_thb <= 0 then
    raise exception 'แปลงนี้ยังไม่เปิดขาย';
  end if;
  if exists(select 1 from public.world_claims where parcel_id=p_parcel_id) then
    raise exception 'แปลงนี้มีเจ้าของแล้ว';
  end if;
  if exists(
    select 1 from public.mars_parcel_orders
    where parcel_id=p_parcel_id and status='pending' and expires_at > now()
  ) then
    raise exception 'แปลงนี้มีคำสั่งซื้อที่กำลังรอชำระ กรุณาลองใหม่ภายหลัง';
  end if;
  update public.mars_parcel_orders set status='expired',updated_at=now()
    where parcel_id=p_parcel_id and status='pending' and (expires_at is null or expires_at <= now());
  insert into public.mars_parcel_orders(buyer_id,parcel_id,amount_satang,currency,status,expires_at)
  values(p_buyer_id,p_parcel_id,v_parcel.sale_price_thb * 100,'thb','pending',now()+interval '30 minutes')
  returning * into v_order;
  return jsonb_build_object('order_id',v_order.id,'parcel_id',v_order.parcel_id,
    'amount_satang',v_order.amount_satang,'currency',v_order.currency,'expires_at',v_order.expires_at);
end;
$$;

create or replace function public.mars_attach_checkout_session(
  p_order_id uuid,
  p_session_id text,
  p_checkout_url text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('request.jwt.claim.role', true),'') <> 'service_role' then
    raise exception 'forbidden';
  end if;
  update public.mars_parcel_orders
  set stripe_checkout_session_id=p_session_id,checkout_url=p_checkout_url,updated_at=now()
  where id=p_order_id and status='pending' and expires_at > now();
  if not found then raise exception 'คำสั่งซื้อหมดอายุหรือไม่อยู่ในสถานะรอชำระ'; end if;
end;
$$;

create or replace function public.mars_fulfill_paid_order(
  p_event_id text,
  p_event_type text,
  p_order_id uuid,
  p_session_id text,
  p_payment_intent_id text,
  p_amount_satang bigint,
  p_currency text,
  p_owner_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.mars_parcel_orders%rowtype;
  v_inserted integer;
begin
  if coalesce(current_setting('request.jwt.claim.role', true),'') <> 'service_role' then
    raise exception 'forbidden';
  end if;
  insert into public.mars_stripe_webhook_events(stripe_event_id,event_type)
  values(p_event_id,p_event_type) on conflict do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted=0 then return jsonb_build_object('ok',true,'duplicate',true); end if;

  select * into v_order from public.mars_parcel_orders where id=p_order_id for update;
  if not found then raise exception 'ไม่พบคำสั่งซื้อ'; end if;
  if v_order.status='paid' then return jsonb_build_object('ok',true,'already_paid',true); end if;
  if v_order.status <> 'pending' then raise exception 'คำสั่งซื้อไม่ได้อยู่ในสถานะรอชำระ'; end if;
  if v_order.expires_at <= now() then raise exception 'คำสั่งซื้อหมดอายุ'; end if;
  if v_order.stripe_checkout_session_id is distinct from p_session_id then raise exception 'Checkout Session ไม่ตรงกับคำสั่งซื้อ'; end if;
  if v_order.amount_satang <> p_amount_satang or lower(v_order.currency) <> lower(p_currency) or lower(p_currency) <> 'thb' then
    raise exception 'ยอดเงินหรือสกุลเงินไม่ตรงกับคำสั่งซื้อ';
  end if;
  if exists(select 1 from public.world_claims where parcel_id=v_order.parcel_id) then
    raise exception 'แปลงนี้ถูกจองแล้ว ไม่สามารถโอนสิทธิ์ซ้ำ';
  end if;

  insert into public.world_claims(parcel_id,owner_id) values(v_order.parcel_id,v_order.buyer_id);
  update public.mars_parcel_orders
    set status='paid',stripe_payment_intent_id=p_payment_intent_id,paid_at=now(),updated_at=now()
    where id=v_order.id;
  insert into public.world_events(actor_id,event_type,parcel_id,payload)
    values(v_order.buyer_id,'parcel_paid_and_claimed',v_order.parcel_id,
      jsonb_build_object('order_id',v_order.id,'amount_satang',v_order.amount_satang,'currency','thb'));
  insert into public.mars_owner_wallet_entries(owner_id,order_id,entry_type,gross_amount_satang,net_amount_satang,settlement_status)
    values(p_owner_id,v_order.id,'parcel_sale',v_order.amount_satang,0,'pending')
    on conflict do nothing;
  return jsonb_build_object('ok',true,'order_id',v_order.id,'parcel_id',v_order.parcel_id);
end;
$$;

revoke all on function public.mars_create_parcel_order(uuid,text) from public,anon,authenticated;
revoke all on function public.mars_attach_checkout_session(uuid,text,text) from public,anon,authenticated;
revoke all on function public.mars_fulfill_paid_order(text,text,uuid,text,text,bigint,text,uuid) from public,anon,authenticated;
grant execute on function public.mars_create_parcel_order(uuid,text) to service_role;
grant execute on function public.mars_attach_checkout_session(uuid,text,text) to service_role;
grant execute on function public.mars_fulfill_paid_order(text,text,uuid,text,text,bigint,text,uuid) to service_role;
