-- LOCAL MARS 010: switch parcel/listing denomination to USD and make flag placement idempotent.
-- Numeric values are preserved 1:1 as display reference values. This is not a currency conversion.
do $$
begin
  if to_regclass('public.land_plots') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='land_plots' and column_name='price_eth')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='land_plots' and column_name='price_usd') then
    alter table public.land_plots rename column price_eth to price_usd;
  end if;
  if to_regclass('public.marketplace_listings') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='marketplace_listings' and column_name='asking_price_eth')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='marketplace_listings' and column_name='asking_price_usd') then
    alter table public.marketplace_listings rename column asking_price_eth to asking_price_usd;
  end if;
end $$;

-- Keep the newest flag for each member/tile/level before enforcing one flag per tile.
do $$
begin
  if to_regclass('public.mars_city_national_flags') is not null then
    delete from public.mars_city_national_flags older
    using public.mars_city_national_flags newer
    where older.owner_id = newer.owner_id
      and older.x = newer.x
      and older.z = newer.z
      and older.level = newer.level
      and (older.created_at < newer.created_at
        or (older.created_at = newer.created_at and older.id < newer.id));
    create unique index if not exists mars_city_national_flags_owner_tile_uidx
      on public.mars_city_national_flags(owner_id, x, z, level);
  end if;
end $$;
