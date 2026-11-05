-- LOCAL MARS 016: USD market denomination transition.
-- Reference FX: Bank of Thailand USD reference rate, 2026-11-05 = THB 33.4310 per USD.
-- This is a dated conversion snapshot, NOT a live quote or a guarantee of asset value.
-- Historical THB payment orders and MLC balances are deliberately preserved.
begin;

create table if not exists public.mars_fx_rates (
  base_currency text not null,
  quote_currency text not null,
  rate numeric(18,8) not null check (rate > 0),
  source text not null,
  observed_at date not null,
  created_at timestamptz not null default now(),
  primary key (base_currency, quote_currency, observed_at)
);

insert into public.mars_fx_rates(base_currency,quote_currency,rate,source,observed_at)
values ('USD','THB',33.43100000,'Bank of Thailand reference rate',date '2026-11-05')
on conflict (base_currency,quote_currency,observed_at) do update
set rate=excluded.rate,source=excluded.source;

-- New USD denomination columns. Keep legacy THB columns for audit/history and rollback.
do $$
begin
  if to_regclass('public.world_parcels') is not null then
    alter table public.world_parcels add column if not exists sale_price_usd numeric(14,2);
    update public.world_parcels
      set sale_price_usd=round(sale_price_thb::numeric/33.4310,2)
      where sale_price_usd is null and sale_price_thb is not null;
    alter table public.world_parcels drop constraint if exists world_parcels_sale_price_usd_positive;
    alter table public.world_parcels add constraint world_parcels_sale_price_usd_positive
      check (sale_price_usd is null or sale_price_usd > 0);
  end if;

  if to_regclass('public.land_plots') is not null then
    alter table public.land_plots add column if not exists price_usd numeric(14,2);
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='land_plots' and column_name='price_thb') then
      execute 'update public.land_plots set price_usd=round(price_thb::numeric/33.4310,2) where price_usd is null and price_thb is not null';
    end if;
  end if;

  if to_regclass('public.marketplace_listings') is not null then
    alter table public.marketplace_listings add column if not exists asking_price_usd numeric(14,2);
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='marketplace_listings' and column_name='asking_price_thb') then
      execute 'update public.marketplace_listings set asking_price_usd=round(asking_price_thb::numeric/33.4310,2) where asking_price_usd is null and asking_price_thb is not null';
    end if;
  end if;
end $$;

comment on table public.mars_fx_rates is
  'Dated foreign-exchange reference snapshots. USD is the new display denomination; never treat snapshots as live executable quotes.';
comment on column public.world_parcels.sale_price_usd is
  'USD asking/reference price converted from legacy THB using the dated FX snapshot; not a verified real-world Mars land value.';
commit;

-- IMPORTANT:
-- 1) Keep sale_price_thb and old mars_parcel_orders.amount_satang/currency for historical audit.
-- 2) MLC, mars_mlc_parcel_market.price_mlc, city credits and resource balances are NOT USD and are untouched.
-- 3) Do not enable the legacy PromptPay checkout for new USD listings. PromptPay is THB-only.
-- 4) USD card checkout + webhook validation must be deployed and tested before enabling USD payments.
