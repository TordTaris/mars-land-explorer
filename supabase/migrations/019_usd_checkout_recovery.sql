-- LOCAL MARS 019: harden USD checkout recovery and Stripe event lifecycle.
-- Safe additive migration: preserves all THB history and MLC balances.
begin;

alter table public.mars_usd_parcel_orders
  add column if not exists refund_required boolean not null default false,
  add column if not exists fulfillment_note text;

create or replace function public.mars_create_usd_parcel_order(p_buyer_id uuid,p_parcel_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_parcel public.world_parcels%rowtype; v_order public.mars_usd_parcel_orders%rowtype;
begin
  if coalesce(current_setting('request.jwt.claim.role',true),'') <> 'service_role' then raise exception 'forbidden'; end if;
  if p_buyer_id is null or p_parcel_id is null then raise exception 'invalid buyer or parcel'; end if;
  select * into v_parcel from public.world_parcels where id=p_parcel_id for update;
  if not found then raise exception 'ไม่พบแปลงพื้นที่'; end if;
  if not v_parcel.is_for_sale or v_parcel.sale_price_usd is null or v_parcel.sale_price_usd<=0 then
    raise exception 'แปลงนี้ยังไม่มีราคา USD หรือยังไม่เปิดขาย';
  end if;
  if exists(select 1 from public.world_claims where parcel_id=p_parcel_id) then raise exception 'แปลงนี้มีเจ้าของแล้ว'; end if;
  update public.mars_usd_parcel_orders set status='expired',updated_at=now()
    where parcel_id=p_parcel_id and status='pending' and expires_at<=now();
  if exists(select 1 from public.mars_usd_parcel_orders where parcel_id=p_parcel_id and status='pending' and expires_at>now()) then
    raise exception 'แปลงนี้มีคำสั่งซื้อ USD ที่รอชำระอยู่';
  end if;
  -- Stripe Checkout sessions expire at 35 minutes; the DB hold has a 1-minute safety margin.
  insert into public.mars_usd_parcel_orders(buyer_id,parcel_id,amount_cents,currency,status,expires_at)
    values(p_buyer_id,p_parcel_id,round(v_parcel.sale_price_usd*100)::bigint,'usd','pending',now()+interval '36 minutes')
    returning * into v_order;
  return jsonb_build_object('order_id',v_order.id,'parcel_id',v_order.parcel_id,
    'amount_cents',v_order.amount_cents,'currency',v_order.currency,'expires_at',v_order.expires_at);
end; $$;

create or replace function public.mars_attach_usd_checkout_session(p_order_id uuid,p_session_id text,p_checkout_url text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if coalesce(current_setting('request.jwt.claim.role',true),'') <> 'service_role' then raise exception 'forbidden'; end if;
  if p_session_id is null or p_checkout_url is null then raise exception 'missing Stripe session'; end if;
  update public.mars_usd_parcel_orders
    set stripe_checkout_session_id=p_session_id,checkout_url=p_checkout_url,updated_at=now()
    where id=p_order_id and status='pending' and expires_at>now()
      and (stripe_checkout_session_id is null or stripe_checkout_session_id=p_session_id);
  if not found then raise exception 'USD order expired, already attached, or is not pending'; end if;
end; $$;

create or replace function public.mars_mark_usd_order_status(
  p_event_id text,p_event_type text,p_order_id uuid,p_session_id text,p_status text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_order public.mars_usd_parcel_orders%rowtype; v_inserted integer;
begin
  if coalesce(current_setting('request.jwt.claim.role',true),'') <> 'service_role' then raise exception 'forbidden'; end if;
  if p_event_id is null or p_order_id is null or p_session_id is null
     or p_status not in ('expired','failed') then raise exception 'invalid event payload'; end if;
  insert into public.mars_stripe_webhook_events(stripe_event_id,event_type)
    values(p_event_id,p_event_type) on conflict do nothing;
  get diagnostics v_inserted=row_count;
  if v_inserted=0 then return jsonb_build_object('ok',true,'duplicate',true); end if;
  select * into v_order from public.mars_usd_parcel_orders where id=p_order_id for update;
  if not found then raise exception 'ไม่พบคำสั่งซื้อ USD'; end if;
  if v_order.status='paid' then return jsonb_build_object('ok',true,'already_paid',true); end if;
  if v_order.stripe_checkout_session_id is not null
     and v_order.stripe_checkout_session_id is distinct from p_session_id then
    raise exception 'USD checkout session mismatch';
  end if;
  update public.mars_usd_parcel_orders
    set stripe_checkout_session_id=coalesce(stripe_checkout_session_id,p_session_id),
        status=p_status,updated_at=now()
    where id=p_order_id and status='pending';
  return jsonb_build_object('ok',true,'status',p_status);
end; $$;

create or replace function public.mars_fulfill_paid_order_usd(
  p_event_id text,p_event_type text,p_order_id uuid,p_session_id text,
  p_payment_intent_id text,p_amount_cents bigint,p_currency text,p_owner_id uuid
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_order public.mars_usd_parcel_orders%rowtype; v_inserted integer; v_claim_owner uuid;
begin
  if coalesce(current_setting('request.jwt.claim.role',true),'') <> 'service_role' then raise exception 'forbidden'; end if;
  if p_event_id is null or p_order_id is null or p_session_id is null or p_owner_id is null
     or p_amount_cents is null or p_amount_cents<=0 or lower(coalesce(p_currency,''))<>'usd' then
    raise exception 'invalid USD fulfillment payload';
  end if;
  insert into public.mars_stripe_webhook_events(stripe_event_id,event_type)
    values(p_event_id,p_event_type) on conflict do nothing;
  get diagnostics v_inserted=row_count;
  if v_inserted=0 then return jsonb_build_object('ok',true,'duplicate',true); end if;
  select * into v_order from public.mars_usd_parcel_orders where id=p_order_id for update;
  if not found then raise exception 'ไม่พบคำสั่งซื้อ USD'; end if;
  if v_order.status='paid' then return jsonb_build_object('ok',true,'already_paid',true); end if;
  if v_order.status not in ('pending','expired') then raise exception 'USD order is not payable'; end if;
  if v_order.stripe_checkout_session_id is not null
     and v_order.stripe_checkout_session_id is distinct from p_session_id then
    raise exception 'USD checkout session mismatch';
  end if;
  if v_order.amount_cents<>p_amount_cents or lower(v_order.currency)<>lower(p_currency) then
    raise exception 'USD amount or currency mismatch';
  end if;
  -- Serialize fulfillment for this parcel, including races between different orders.
  perform 1 from public.world_parcels where id=v_order.parcel_id for update;
  select owner_id into v_claim_owner from public.world_claims where parcel_id=v_order.parcel_id;
  if v_claim_owner is not null and v_claim_owner<>v_order.buyer_id then
    update public.mars_usd_parcel_orders
      set status='failed',refund_required=true,
          fulfillment_note='Payment confirmed after another buyer claimed this parcel; refund review required.',
          stripe_checkout_session_id=coalesce(stripe_checkout_session_id,p_session_id),
          stripe_payment_intent_id=p_payment_intent_id,updated_at=now()
      where id=v_order.id;
    insert into public.mars_owner_wallet_entries_usd(owner_id,order_id,entry_type,gross_amount_cents,net_amount_cents,settlement_status)
      values(p_owner_id,v_order.id,'refund',0,0,'reversed') on conflict do nothing;
    return jsonb_build_object('ok',true,'refund_required',true,'order_id',v_order.id);
  end if;
  if v_claim_owner is null then
    insert into public.world_claims(parcel_id,owner_id) values(v_order.parcel_id,v_order.buyer_id);
  end if;
  update public.mars_usd_parcel_orders
    set status='paid',stripe_checkout_session_id=coalesce(stripe_checkout_session_id,p_session_id),
        stripe_payment_intent_id=p_payment_intent_id,paid_at=now(),updated_at=now(),
        refund_required=false,fulfillment_note=null
    where id=v_order.id;
  insert into public.world_events(actor_id,event_type,parcel_id,payload)
    values(v_order.buyer_id,'parcel_paid_and_claimed_usd',v_order.parcel_id,
      jsonb_build_object('order_id',v_order.id,'amount_cents',v_order.amount_cents,'currency','usd'));
  insert into public.mars_owner_wallet_entries_usd(owner_id,order_id,entry_type,gross_amount_cents,net_amount_cents,settlement_status)
    values(p_owner_id,v_order.id,'parcel_sale',v_order.amount_cents,0,'pending') on conflict do nothing;
  return jsonb_build_object('ok',true,'order_id',v_order.id,'parcel_id',v_order.parcel_id);
end; $$;

revoke all on function public.mars_mark_usd_order_status(text,text,uuid,text,text) from public,anon,authenticated;
grant execute on function public.mars_mark_usd_order_status(text,text,uuid,text,text) to service_role;
revoke all on function public.mars_create_usd_parcel_order(uuid,text) from public,anon,authenticated;
revoke all on function public.mars_attach_usd_checkout_session(uuid,text,text) from public,anon,authenticated;
revoke all on function public.mars_fulfill_paid_order_usd(text,text,uuid,text,text,bigint,text,uuid) from public,anon,authenticated;
grant execute on function public.mars_create_usd_parcel_order(uuid,text) to service_role;
grant execute on function public.mars_attach_usd_checkout_session(uuid,text,text) to service_role;
grant execute on function public.mars_fulfill_paid_order_usd(text,text,uuid,text,text,bigint,text,uuid) to service_role;
commit;
