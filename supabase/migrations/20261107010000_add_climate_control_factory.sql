-- LOCAL MARS: add Climate Control Factory to shared city and M-001 parcel structures.
create or replace function public.mars_city_place_structure(
  p_type text, p_x double precision, p_z double precision, p_level integer
) returns jsonb language plpgsql security definer set search_path=public as $$
declare
  u uuid:=auth.uid(); c public.mars_cities%rowtype;
  cost_credits integer; cost_metal integer; cost_polymer integer; cost_electronics integer;
  mapped_type text; game_name text;
  started_ms bigint:=floor(extract(epoch from clock_timestamp())*1000);
  new_building public.mars_city_buildings%rowtype;
begin
  if u is null then raise exception 'Sign in before construction'; end if;
  if p_type not in ('hab','green','lab','solar','hub','tower','climate','road') then raise exception 'Invalid structure type'; end if;
  if p_x is null or p_z is null or abs(p_x)>50 or abs(p_z)>50 or p_level not between 0 and 2 then raise exception 'Invalid construction position'; end if;
  select * into c from public.mars_cities where owner_id=u order by created_at limit 1 for update;
  if not found then
    insert into public.mars_cities(owner_id,name,description,is_public)
    values(u,'LOCAL MARS Colony','Shared Martian colony',true) returning * into c;
  end if;
  insert into public.mars_city_resources(city_id,owner_id) values(c.id,u) on conflict(city_id) do nothing;
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
  update public.mars_city_resources set credits=credits-cost_credits,metal=metal-cost_metal,polymer=polymer-cost_polymer,electronics=electronics-cost_electronics,updated_at=now()
  where city_id=c.id and owner_id=u and credits>=cost_credits and metal>=cost_metal and polymer>=cost_polymer and electronics>=cost_electronics;
  if not found then raise exception 'Insufficient credits or construction materials'; end if;
  insert into public.mars_city_buildings(city_id,owner_id,building_type,name,position)
  values(c.id,u,mapped_type,game_name,jsonb_build_object('game_type',game_name,'x',p_x,'z',p_z,'level',p_level,'startedAt',started_ms,'durationMs',60000))
  returning * into new_building;
  return jsonb_build_object('city_id',c.id,'building',to_jsonb(new_building));
end $$;
revoke all on function public.mars_city_place_structure(text,double precision,double precision,integer) from public,anon;
grant execute on function public.mars_city_place_structure(text,double precision,double precision,integer) to authenticated;

alter table public.world_structures drop constraint if exists world_structures_structure_type_check;
alter table public.world_structures add constraint world_structures_structure_type_check check (structure_type = any (array[
 'ฐานที่อยู่อาศัย'::text,'ห้องปฏิบัติการ'::text,'โรงเรือนปลูกพืช'::text,'แผงพลังงานแสงอาทิตย์'::text,
 'โรงไฟฟ้านิวเคลียร์ขนาดใหญ่'::text,'ศูนย์จัดเก็บข้อมูล'::text,'โรงงานปรับสภาพอากาศ'::text
]));

create or replace function public.build_world_structure(p_parcel_id text,p_type text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); new_id uuid;
begin
 if u is null then raise exception 'Sign in before construction'; end if;
 if not exists(select 1 from public.world_parcels where id=p_parcel_id) then raise exception 'Parcel not found'; end if;
 if p_type not in ('ฐานที่อยู่อาศัย','ห้องปฏิบัติการ','โรงเรือนปลูกพืช','แผงพลังงานแสงอาทิตย์','โรงไฟฟ้านิวเคลียร์ขนาดใหญ่','ศูนย์จัดเก็บข้อมูล','โรงงานปรับสภาพอากาศ') then raise exception 'Invalid structure type'; end if;
 if p_type='โรงไฟฟ้านิวเคลียร์ขนาดใหญ่' and p_parcel_id<>'M-003' then raise exception 'Nuclear power plant is restricted to M-003'; end if;
 if p_type='ศูนย์จัดเก็บข้อมูล' and p_parcel_id<>'M-001' then raise exception 'Data storage center is restricted to M-001'; end if;
 if p_type='โรงงานปรับสภาพอากาศ' and p_parcel_id<>'M-001' then raise exception 'Climate control factory is restricted to M-001'; end if;
 if not exists(select 1 from public.world_claims where parcel_id=p_parcel_id and owner_id=u) then raise exception 'You must own this parcel'; end if;
 if exists(select 1 from public.world_structures where parcel_id=p_parcel_id and structure_type=p_type) then raise exception 'This parcel already contains this structure type'; end if;
 insert into public.world_structures(parcel_id,owner_id,structure_type) values(p_parcel_id,u,p_type) returning id into new_id;
 insert into public.world_events(actor_id,event_type,parcel_id,payload) values(u,'structure_built',p_parcel_id,jsonb_build_object('structure_id',new_id,'type',p_type));
 return jsonb_build_object('ok',true,'structure_id',new_id,'parcel_id',p_parcel_id,'type',p_type,'owner_id',u);
end $$;
