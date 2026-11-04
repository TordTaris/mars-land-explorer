-- LOCAL MARS 014: rename legacy USD reference columns to THB.
-- Existing numeric values are preserved; this does not create a payment or convert funds.
do $$
begin
  if to_regclass('public.land_plots') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='land_plots' and column_name='price_usd')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='land_plots' and column_name='price_thb') then
    alter table public.land_plots rename column price_usd to price_thb;
  end if;
  if to_regclass('public.marketplace_listings') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='marketplace_listings' and column_name='asking_price_usd')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='marketplace_listings' and column_name='asking_price_thb') then
    alter table public.marketplace_listings rename column asking_price_usd to asking_price_thb;
  end if;
end $$;
