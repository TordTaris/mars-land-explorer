-- LOCAL MARS 015: apply the confirmed 1.8x THB / simulation-credit adjustment.
-- Run once after migration 014. Idempotency marker prevents repeated multiplication.
-- IMPORTANT: world_parcels.base_price and MLC prices are MLC and are deliberately untouched.
-- Energy, metal, MLC, and completed PromptPay transactions are not changed.
create table if not exists public.local_mars_adjustments (
  adjustment_key text primary key,
  applied_at timestamptz not null default now()
);

do $$
begin
  if exists(select 1 from public.local_mars_adjustments where adjustment_key='thb-value-x1.8-v1') then
    raise notice 'THB x1.8 adjustment already applied; skipping.';
    return;
  end if;

  if to_regclass('public.world_parcels') is not null
     and exists(select 1 from information_schema.columns where table_schema='public' and table_name='world_parcels' and column_name='sale_price_thb') then
    update public.world_parcels
      set sale_price_thb=round(sale_price_thb::numeric*1.8)::bigint
      where sale_price_thb is not null;
  end if;

  if to_regclass('public.land_plots') is not null then
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='land_plots' and column_name='price_thb') then
      execute 'update public.land_plots set price_thb=round(price_thb*1.8)';
    elsif exists(select 1 from information_schema.columns where table_schema='public' and table_name='land_plots' and column_name='price_usd') then
      execute 'update public.land_plots set price_usd=round(price_usd*1.8)';
    end if;
  end if;

  if to_regclass('public.marketplace_listings') is not null then
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='marketplace_listings' and column_name='asking_price_thb') then
      execute 'update public.marketplace_listings set asking_price_thb=round(asking_price_thb*1.8)';
    elsif exists(select 1 from information_schema.columns where table_schema='public' and table_name='marketplace_listings' and column_name='asking_price_usd') then
      execute 'update public.marketplace_listings set asking_price_usd=round(asking_price_usd*1.8)';
    end if;
  end if;

  if to_regclass('public.mars_market_listings') is not null then
    update public.mars_market_listings
      set demo_price=greatest(1,round(demo_price::numeric*1.8)::integer);
  end if;

  if to_regclass('public.mars_city_resources') is not null then
    update public.mars_city_resources
      set credits=greatest(0,round(credits::numeric*1.8)::integer);
    alter table public.mars_city_resources alter column credits set default 9000;
  end if;

  if to_regclass('public.mars_wallet_ledger') is not null then
    update public.mars_wallet_ledger
      set amount=round(amount::numeric*1.8)::integer
      where resource='credits';
  end if;

  insert into public.local_mars_adjustments(adjustment_key)
    values('thb-value-x1.8-v1');
end $$;

create or replace function public.mars_city_place_structure(
  p_type text, p_x double precision, p_z double precision, p_level integer
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  u uuid := auth.uid();
  c public.mars_cities%rowtype;
  cost_credits integer;
  cost_metal integer;
  cost_polymer integer;
  cost_electronics integer;
  mapped_type text;
  game_name text;
  started_ms bigint := floor(extract(epoch from clock_timestamp()) * 1000);
  new_building public.mars_city_buildings%rowtype;
begin
  if u is null then raise exception 'กรุณาเข้าสู่ระบบก่อนก่อสร้าง'; end if;
  if p_type not in ('hab','green','lab','solar','hub','tower','road') then raise exception 'ประเภทสิ่งปลูกสร้างไม่ถูกต้อง'; end if;
  if p_x is null or p_z is null or abs(p_x) > 50 or abs(p_z) > 50 or p_level not between 0 and 2 then
    raise exception 'ตำแหน่งก่อสร้างไม่ถูกต้อง';
  end if;
  select * into c from public.mars_cities where owner_id=u order by created_at limit 1 for update;
  if not found then
    insert into public.mars_cities(owner_id,name,description,is_public)
    values(u,'อาณานิคม LOCAL MARS','Shared Martian colony',true) returning * into c;
  end if;
  insert into public.mars_city_resources(city_id,owner_id)
  values(c.id,u) on conflict(city_id) do nothing;

  case p_type
    when 'hab' then cost_credits:=1440; cost_metal:=24; cost_polymer:=18; cost_electronics:=4; mapped_type:='habitat'; game_name:='hab';
    when 'green' then cost_credits:=1170; cost_metal:=16; cost_polymer:=24; cost_electronics:=5; mapped_type:='greenhouse'; game_name:='green';
    when 'lab' then cost_credits:=1710; cost_metal:=28; cost_polymer:=12; cost_electronics:=12; mapped_type:='lab'; game_name:='lab';
    when 'solar' then cost_credits:=900; cost_metal:=18; cost_polymer:=6; cost_electronics:=8; mapped_type:='solar'; game_name:='solar';
    when 'hub' then cost_credits:=2160; cost_metal:=36; cost_polymer:=20; cost_electronics:=16; mapped_type:='habitat'; game_name:='hub';
    when 'tower' then cost_credits:=720; cost_metal:=14; cost_polymer:=4; cost_electronics:=10; mapped_type:='landing_pad'; game_name:='tower';
    when 'road' then cost_credits:=72; cost_metal:=3; cost_polymer:=0; cost_electronics:=0; mapped_type:='road'; game_name:='road';
  end case;

  update public.mars_city_resources
  set credits=credits-cost_credits, metal=metal-cost_metal,
      polymer=polymer-cost_polymer, electronics=electronics-cost_electronics,
      updated_at=now()
  where city_id=c.id and owner_id=u
    and credits>=cost_credits and metal>=cost_metal
    and polymer>=cost_polymer and electronics>=cost_electronics;
  if not found then raise exception 'เครดิตหรือวัสดุก่อสร้างไม่เพียงพอ'; end if;

  insert into public.mars_city_buildings(city_id,owner_id,building_type,name,position)
  values(c.id,u,mapped_type,game_name,
    jsonb_build_object('game_type',game_name,'x',p_x,'z',p_z,'level',p_level,
      'startedAt',started_ms,'durationMs',60000))
  returning * into new_building;

  return jsonb_build_object('city_id',c.id,'building',to_jsonb(new_building));
end $$;
revoke all on function public.mars_city_place_structure(text,double precision,double precision,integer) from public, anon;
grant execute on function public.mars_city_place_structure(text,double precision,double precision,integer) to authenticated;

create or replace function public.mars_wallet_grant_starter(p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid();
begin
  if u is null then raise exception 'กรุณาเข้าสู่ระบบ'; end if;
  if p_idempotency_key is null or p_idempotency_key !~ '^[a-zA-Z0-9:_-]{8,80}$' then raise exception 'รหัสรายการไม่ถูกต้อง'; end if;
  insert into public.mars_wallet_ledger(user_id,idempotency_key,resource,amount,reason)
  values
    (u,p_idempotency_key,'credits',900,'DEMO starter grant · THB value x1.8'),
    (u,p_idempotency_key,'energy',100,'DEMO starter grant'),
    (u,p_idempotency_key,'metal',50,'DEMO starter grant')
  on conflict(user_id,idempotency_key,resource) do nothing;
  return jsonb_build_object('ok',true,'demo_only',true);
end $$;
revoke all on function public.mars_wallet_grant_starter(text) from public;
grant execute on function public.mars_wallet_grant_starter(text) to authenticated;
