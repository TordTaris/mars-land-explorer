-- LOCAL MARS: one private construction workspace per owned parcel.
-- Parcel workspace rows remain owner-only through mars_cities RLS and its child-table policies.
create unique index if not exists mars_cities_owner_parcel_unique
  on public.mars_cities(owner_id, parcel_id)
  where parcel_id is not null;

create or replace function public.mars_parcel_city_ensure(p_parcel_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  u uuid := auth.uid();
  c public.mars_cities%rowtype;
  r public.mars_city_resources%rowtype;
begin
  if u is null then
    raise exception 'Sign in required to open a private parcel workspace';
  end if;
  if p_parcel_id is null or not exists (
    select 1 from public.world_claims
    where parcel_id = p_parcel_id and owner_id = u
  ) then
    raise exception 'Only the parcel owner can open this private construction workspace';
  end if;

  perform pg_advisory_xact_lock(hashtext(u::text || ':' || p_parcel_id));
  select * into c
  from public.mars_cities
  where owner_id = u and parcel_id = p_parcel_id
  limit 1
  for update;

  if not found then
    insert into public.mars_cities(owner_id, name, description, parcel_id, is_public)
    values (u, p_parcel_id || ' Private Construction', 'Owner-only parcel construction workspace', p_parcel_id, false)
    returning * into c;
  else
    update public.mars_cities
    set is_public = false, updated_at = now()
    where id = c.id
    returning * into c;
  end if;

  insert into public.mars_city_resources(city_id, owner_id)
  values (c.id, u)
  on conflict (city_id) do nothing;

  select * into r from public.mars_city_resources where city_id = c.id and owner_id = u;
  return jsonb_build_object('city_id', c.id, 'parcel_id', p_parcel_id, 'private', true, 'resources', to_jsonb(r));
end;
$$;

create or replace function public.mars_parcel_city_place_structure(
  p_parcel_id text,
  p_type text,
  p_x double precision,
  p_z double precision,
  p_level integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  u uuid := auth.uid();
  workspace jsonb;
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
  if u is null then raise exception 'Sign in before construction'; end if;
  if p_type not in ('hab','green','lab','solar','hub','tower','climate','road') then
    raise exception 'Invalid structure type';
  end if;
  if p_x is null or p_z is null or abs(p_x) > 50 or abs(p_z) > 50 or p_level not between 0 and 2 then
    raise exception 'Invalid construction position';
  end if;

  workspace := public.mars_parcel_city_ensure(p_parcel_id);
  select * into c from public.mars_cities
  where id = (workspace->>'city_id')::uuid and owner_id = u and parcel_id = p_parcel_id and not is_public
  for update;
  if not found then raise exception 'Private parcel workspace unavailable'; end if;

  case p_type
    when 'hab' then cost_credits:=800;cost_metal:=24;cost_polymer:=18;cost_electronics:=4;mapped_type:='habitat';game_name:='hab';
    when 'green' then cost_credits:=650;cost_metal:=16;cost_polymer:=24;cost_electronics:=5;mapped_type:='greenhouse';game_name:='green';
    when 'lab' then cost_credits:=950;cost_metal:=28;cost_polymer:=12;cost_electronics:=12;mapped_type:='lab';game_name:='lab';
    when 'solar' then cost_credits:=500;cost_metal:=18;cost_polymer:=6;cost_electronics:=8;mapped_type:='solar';game_name:='solar';
    when 'hub' then cost_credits:=1200;cost_metal:=36;cost_polymer:=20;cost_electronics:=16;mapped_type:='habitat';game_name:='hub';
    when 'tower' then cost_credits:=400;cost_metal:=14;cost_polymer:=4;cost_electronics:=10;mapped_type:='landing_pad';game_name:='tower';
    when 'climate' then cost_credits:=1800;cost_metal:=32;cost_polymer:=28;cost_electronics:=24;mapped_type:='climate_control';game_name:='climate';
    when 'road' then cost_credits:=40;cost_metal:=3;cost_polymer:=0;cost_electronics:=0;mapped_type:='road';game_name:='road';
  end case;

  update public.mars_city_resources
  set credits=credits-cost_credits, metal=metal-cost_metal, polymer=polymer-cost_polymer,
      electronics=electronics-cost_electronics, updated_at=now()
  where city_id=c.id and owner_id=u
    and credits>=cost_credits and metal>=cost_metal
    and polymer>=cost_polymer and electronics>=cost_electronics;
  if not found then raise exception 'Insufficient credits or construction materials'; end if;

  insert into public.mars_city_buildings(city_id,owner_id,building_type,name,position)
  values (
    c.id,u,mapped_type,game_name,
    jsonb_build_object('game_type',game_name,'x',p_x,'z',p_z,'level',p_level,
      'startedAt',started_ms,'durationMs',60000,'worldParcelId',p_parcel_id,'privateWorkspace',true)
  )
  returning * into new_building;

  return jsonb_build_object('city_id',c.id,'parcel_id',p_parcel_id,'private',true,'building',to_jsonb(new_building));
end;
$$;

revoke all on function public.mars_parcel_city_ensure(text) from public, anon;
revoke all on function public.mars_parcel_city_place_structure(text,text,double precision,double precision,integer) from public, anon;
grant execute on function public.mars_parcel_city_ensure(text) to authenticated;
grant execute on function public.mars_parcel_city_place_structure(text,text,double precision,double precision,integer) to authenticated;
