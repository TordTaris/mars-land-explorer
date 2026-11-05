-- LOCAL MARS 018: USD parcel checkout and owner ledger.
-- Separate USD order/ledger tables keep historical THB satang records unchanged.
begin;

create table if not exists public.mars_usd_parcel_orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references auth.users(id) on delete restrict,
  parcel_id text not null references public.world_parcels(id) on delete restrict,
  amount_cents bigint not null check (amount_cents > 0),
  currency text not null default 'usd' check (currency = 'usd'),
  status text not null default 'pending'
    check (status in ('pending','paid','expired','cancelled','refunded','failed')),
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text unique,
  checkout_url text,
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists mars_usd_orders_buyer_idx
  on public.mars_usd_parcel_orders(buyer_id,created_at desc);
create index if not exists mars_usd_orders_parcel_status_idx
  on public.mars_usd_parcel_orders(parcel_id,status);

create table if not exists public.mars_owner_wallet_entries_usd (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  order_id uuid references public.mars_usd_parcel_orders(id) on delete restrict,
  entry_type text not null check (entry_type in ('parcel_sale','refund','payout_adjustment')),
  gross_amount_cents bigint not null default 0,
  stripe_fee_cents bigint not null default 0,
  net_amount_cents bigint not null default 0,
  settlement_status text not null default 'pending'
    check (settlement_status in ('pending','available','paid_out','reversed')),
  stripe_balance_transaction_id text unique,
  stripe_payout_id text,
  created_at timestamptz not null default now()
);
create index if not exists mars_owner_wallet_usd_owner_idx
  on public.mars_owner_wallet_entries_usd(owner_id,created_at desc);

alter table public.mars_usd_parcel_orders enable row level security;
alter table public.mars_owner_wallet_entries_usd enable row level security;
drop policy if exists mars_usd_orders_buyer_read on public.mars_usd_parcel_orders;
create policy mars_usd_orders_buyer_read on public.mars_usd_parcel_orders
  for select to authenticated using (auth.uid()=buyer_id);
drop policy if exists mars_owner_wallet_usd_admin_read on public.mars_owner_wallet_entries_usd;
create policy mars_owner_wallet_usd_admin_read on public.mars_owner_wallet_entries_usd
  for select to authenticated using (
    owner_id=auth.uid() and exists(
      select 1 from public.mars_store_admins a where a.user_id=auth.uid()
    )
  );
revoke all on public.mars_usd_parcel_orders from anon,authenticated;
grant select on public.mars_usd_parcel_orders to authenticated;
revoke all on public.mars_owner_wallet_entries_usd from anon,authenticated;
grant select on public.mars_owner_wallet_entries_usd to authenticated;

create or replace function public.mars_create_usd_parcel_order(p_buyer_id uuid,p_parcel_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_parcel public.world_parcels%rowtype; v_order public.mars_usd_parcel_orders%rowtype;
begin
  if coalesce(current_setting('request.jwt.claim.role',true),'') <> 'service_role' then raise exception 'forbidden'; end if;
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
  insert into public.mars_usd_parcel_orders(buyer_id,parcel_id,amount_cents,currency,status,expires_at)
    values(p_buyer_id,p_parcel_id,round(v_parcel.sale_price_usd*100)::bigint,'usd','pending',now()+interval '30 minutes')
    returning * into v_order;
  return jsonb_build_object('order_id',v_order.id,'parcel_id',v_order.parcel_id,
    'amount_cents',v_order.amount_cents,'currency',v_order.currency,'expires_at',v_order.expires_at);
end; $$;

create or replace function public.mars_attach_usd_checkout_session(p_order_id uuid,p_session_id text,p_checkout_url text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if coalesce(current_setting('request.jwt.claim.role',true),'') <> 'service_role' then raise exception 'forbidden'; end if;
  update public.mars_usd_parcel_orders set stripe_checkout_session_id=p_session_id,checkout_url=p_checkout_url,updated_at=now()
    where id=p_order_id and status='pending' and expires_at>now();
  if not found then raise exception 'USD order expired or is not pending'; end if;
end; $$;

create or replace function public.mars_fulfill_paid_order_usd(
  p_event_id text,p_event_type text,p_order_id uuid,p_session_id text,
  p_payment_intent_id text,p_amount_cents bigint,p_currency text,p_owner_id uuid
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_order public.mars_usd_parcel_orders%rowtype; v_inserted integer;
begin
  if coalesce(current_setting('request.jwt.claim.role',true),'') <> 'service_role' then raise exception 'forbidden'; end if;
  insert into public.mars_stripe_webhook_events(stripe_event_id,event_type)
    values(p_event_id,p_event_type) on conflict do nothing;
  get diagnostics v_inserted=row_count;
  if v_inserted=0 then return jsonb_build_object('ok',true,'duplicate',true); end if;
  select * into v_order from public.mars_usd_parcel_orders where id=p_order_id for update;
  if not found then raise exception 'ไม่พบคำสั่งซื้อ USD'; end if;
  if v_order.status='paid' then return jsonb_build_object('ok',true,'already_paid',true); end if;
  if v_order.status<>'pending' then raise exception 'USD order is not pending'; end if;
  if v_order.expires_at<=now() then raise exception 'USD order expired'; end if;
  if v_order.stripe_checkout_session_id is distinct from p_session_id then raise exception 'USD checkout session mismatch'; end if;
  if v_order.amount_cents<>p_amount_cents or lower(v_order.currency)<>lower(p_currency) or lower(p_currency)<>'usd' then
    raise exception 'USD amount or currency mismatch';
  end if;
  if exists(select 1 from public.world_claims where parcel_id=v_order.parcel_id) then raise exception 'แปลงนี้ถูกจองแล้ว ไม่สามารถโอนสิทธิ์ซ้ำ'; end if;
  insert into public.world_claims(parcel_id,owner_id) values(v_order.parcel_id,v_order.buyer_id);
  update public.mars_usd_parcel_orders set status='paid',stripe_payment_intent_id=p_payment_intent_id,paid_at=now(),updated_at=now()
    where id=v_order.id;
  insert into public.world_events(actor_id,event_type,parcel_id,payload)
    values(v_order.buyer_id,'parcel_paid_and_claimed_usd',v_order.parcel_id,
      jsonb_build_object('order_id',v_order.id,'amount_cents',v_order.amount_cents,'currency','usd'));
  insert into public.mars_owner_wallet_entries_usd(owner_id,order_id,entry_type,gross_amount_cents,net_amount_cents,settlement_status)
    values(p_owner_id,v_order.id,'parcel_sale',v_order.amount_cents,0,'pending') on conflict do nothing;
  return jsonb_build_object('ok',true,'order_id',v_order.id,'parcel_id',v_order.parcel_id);
end; $$;

revoke all on function public.mars_create_usd_parcel_order(uuid,text) from public,anon,authenticated;
revoke all on function public.mars_attach_usd_checkout_session(uuid,text,text) from public,anon,authenticated;
revoke all on function public.mars_fulfill_paid_order_usd(text,text,uuid,text,text,bigint,text,uuid) from public,anon,authenticated;
grant execute on function public.mars_create_usd_parcel_order(uuid,text) to service_role;
grant execute on function public.mars_attach_usd_checkout_session(uuid,text,text) to service_role;
grant execute on function public.mars_fulfill_paid_order_usd(text,text,uuid,text,text,bigint,text,uuid) to service_role;
commit;
