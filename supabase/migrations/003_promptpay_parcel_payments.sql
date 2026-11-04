-- LOCAL MARS: secure foundation for one-time THB PromptPay parcel sales.
-- Apply manually in Supabase SQL Editor. This migration does NOT activate live payments.
-- Prices are intentionally separate from legacy base_price (which is a game/demo value).

create extension if not exists pgcrypto;

alter table public.world_parcels
  add column if not exists sale_price_thb bigint,
  add column if not exists is_for_sale boolean not null default false;

alter table public.world_parcels
  drop constraint if exists world_parcels_sale_price_positive;
alter table public.world_parcels
  add constraint world_parcels_sale_price_positive
  check (sale_price_thb is null or sale_price_thb > 0);

create table if not exists public.mars_parcel_orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references auth.users(id) on delete restrict,
  parcel_id text not null references public.world_parcels(id) on delete restrict,
  amount_satang bigint not null check (amount_satang > 0),
  currency text not null default 'thb' check (currency = 'thb'),
  status text not null default 'pending'
    check (status in ('pending','paid','expired','cancelled','refunded','failed')),
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text unique,
  checkout_url text,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists mars_parcel_orders_buyer_idx on public.mars_parcel_orders(buyer_id, created_at desc);
create index if not exists mars_parcel_orders_parcel_status_idx on public.mars_parcel_orders(parcel_id, status);

create table if not exists public.mars_stripe_webhook_events (
  stripe_event_id text primary key,
  event_type text not null,
  processed_at timestamptz not null default now()
);

create table if not exists public.mars_store_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.mars_owner_wallet_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  order_id uuid references public.mars_parcel_orders(id) on delete restrict,
  entry_type text not null check (entry_type in ('parcel_sale','refund','payout_adjustment')),
  gross_amount_satang bigint not null default 0,
  stripe_fee_satang bigint not null default 0,
  net_amount_satang bigint not null default 0,
  settlement_status text not null default 'pending'
    check (settlement_status in ('pending','available','paid_out','reversed')),
  stripe_balance_transaction_id text unique,
  stripe_payout_id text,
  created_at timestamptz not null default now()
);
create index if not exists mars_owner_wallet_owner_idx on public.mars_owner_wallet_entries(owner_id, created_at desc);

create table if not exists public.mars_owner_payout_requests (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  amount_satang bigint not null check (amount_satang > 0),
  status text not null default 'requested'
    check (status in ('requested','processing','paid','failed','cancelled')),
  stripe_payout_id text unique,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists mars_owner_payout_owner_idx on public.mars_owner_payout_requests(owner_id, created_at desc);

alter table public.mars_parcel_orders enable row level security;
alter table public.mars_stripe_webhook_events enable row level security;
alter table public.mars_store_admins enable row level security;
alter table public.mars_owner_wallet_entries enable row level security;
alter table public.mars_owner_payout_requests enable row level security;

drop policy if exists mars_parcel_orders_buyer_read on public.mars_parcel_orders;
create policy mars_parcel_orders_buyer_read on public.mars_parcel_orders
  for select to authenticated using (auth.uid() = buyer_id);
drop policy if exists mars_store_admins_self_read on public.mars_store_admins;
create policy mars_store_admins_self_read on public.mars_store_admins
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists mars_owner_wallet_admin_read on public.mars_owner_wallet_entries;
create policy mars_owner_wallet_admin_read on public.mars_owner_wallet_entries
  for select to authenticated using (
    exists (select 1 from public.mars_store_admins a where a.user_id = auth.uid())
    and owner_id = auth.uid()
  );
drop policy if exists mars_owner_payout_admin_read on public.mars_owner_payout_requests;
create policy mars_owner_payout_admin_read on public.mars_owner_payout_requests
  for select to authenticated using (
    exists (select 1 from public.mars_store_admins a where a.user_id = auth.uid())
    and owner_id = auth.uid()
  );

-- No browser/user may create or fulfill a claim for free.
-- The trusted webhook Edge Function will insert world_claims with service_role only
-- after verifying a signed Stripe event and a paid order.
create or replace function public.claim_world_parcel(p_parcel_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'การจองพื้นที่ต้องชำระเงินผ่านระบบ PromptPay ก่อน ระบบชำระเงินยังอยู่ระหว่างตั้งค่า';
end;
$$;
revoke all on function public.claim_world_parcel(text) from public, anon, authenticated;

-- Browser clients can read their own orders only. All writes are server-side.
revoke all on public.mars_parcel_orders from anon, authenticated;
grant select on public.mars_parcel_orders to authenticated;
revoke all on public.mars_stripe_webhook_events from anon, authenticated;
revoke all on public.mars_store_admins from anon, authenticated;
grant select on public.mars_store_admins to authenticated;
revoke all on public.mars_owner_wallet_entries from anon, authenticated;
grant select on public.mars_owner_wallet_entries to authenticated;
revoke all on public.mars_owner_payout_requests from anon, authenticated;
grant select on public.mars_owner_payout_requests to authenticated;
