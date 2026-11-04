-- LOCAL MARS: rename simulated denomination columns from MLC to ETH.
-- Numeric values are intentionally preserved; this is NOT an exchange or conversion.
do $$
begin
  if to_regclass('public.land_plots') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='land_plots' and column_name='price_mlc')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='land_plots' and column_name='price_eth') then
    alter table public.land_plots rename column price_mlc to price_eth;
  end if;
  if to_regclass('public.marketplace_listings') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='marketplace_listings' and column_name='asking_price_mlc')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='marketplace_listings' and column_name='asking_price_eth') then
    alter table public.marketplace_listings rename column asking_price_mlc to asking_price_eth;
  end if;
end $$;
