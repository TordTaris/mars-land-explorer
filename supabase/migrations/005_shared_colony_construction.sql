-- LOCAL MARS 005: shared colony construction and server-validated game resources.
-- Additive only. Run once in Supabase SQL Editor after migration 002.
create table if not exists public.mars_city_resources (
  city_id uuid primary key references public.mars_cities(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  credits integer not null default 5000 check (credits >= 0),
  metal integer not null default 120 check (metal >= 0),
  polymer integer not null default 90 check (polymer >= 0),
  electronics integer not null default 45 check (electronics >= 0),
  updated_at timestamptz not null default now()
);
alter table public.mars_city_resources add column if not exists energy integer not null default 850 check (energy >= 0);
alter table public.mars_city_resources enable row level security;
drop policy if exists mars_city_resources_read_owner on public.mars_city_resources;
create policy mars_city_resources_read_owner on public.mars_city_resources
  for select to authenticated using (auth.uid() = owner_id);
revoke insert, update, delete on public.mars_city_resources from anon, authenticated;
grant select on public.mars_city_resources to authenticated;

-- Shared cities are visible to all explorers by default; only the owner can edit them.
alter table public.mars_cities alter column is_public set default true;
grant select, insert, update, delete on public.mars_cities to authenticated;
grant select on public.mars_cities to anon;
grant select, insert, update, delete on public.mars_city_buildings to authenticated;
grant select on public.mars_city_buildings to anon;

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
    when 'hab' then cost_credits:=800; cost_metal:=24; cost_polymer:=18; cost_electronics:=4; mapped_type:='habitat'; game_name:='hab';
    when 'green' then cost_credits:=650; cost_metal:=16; cost_polymer:=24; cost_electronics:=5; mapped_type:='greenhouse'; game_name:='green';
    when 'lab' then cost_credits:=950; cost_metal:=28; cost_polymer:=12; cost_electronics:=12; mapped_type:='lab'; game_name:='lab';
    when 'solar' then cost_credits:=500; cost_metal:=18; cost_polymer:=6; cost_electronics:=8; mapped_type:='solar'; game_name:='solar';
    when 'hub' then cost_credits:=1200; cost_metal:=36; cost_polymer:=20; cost_electronics:=16; mapped_type:='habitat'; game_name:='hub';
    when 'tower' then cost_credits:=400; cost_metal:=14; cost_polymer:=4; cost_electronics:=10; mapped_type:='landing_pad'; game_name:='tower';
    when 'road' then cost_credits:=40; cost_metal:=3; cost_polymer:=0; cost_electronics:=0; mapped_type:='road'; game_name:='road';
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

create or replace function public.mars_city_remove_structure(p_building_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); removed integer;
begin
  if u is null then raise exception 'กรุณาเข้าสู่ระบบ'; end if;
  delete from public.mars_city_buildings
  where id=p_building_id and owner_id=u;
  get diagnostics removed = row_count;
  if removed=0 then raise exception 'ไม่พบสิ่งปลูกสร้างของคุณ'; end if;
  return jsonb_build_object('ok',true);
end $$;
revoke all on function public.mars_city_remove_structure(uuid) from public, anon;
grant execute on function public.mars_city_remove_structure(uuid) to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.mars_city_resources;
exception when duplicate_object then null; when undefined_object then null; end $$;

create or replace function public.mars_city_ensure()
returns jsonb language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); c public.mars_cities%rowtype; r public.mars_city_resources%rowtype;
begin
 if u is null then raise exception 'กรุณาเข้าสู่ระบบ'; end if;
 select * into c from public.mars_cities where owner_id=u order by created_at limit 1 for update;
 if not found then
  insert into public.mars_cities(owner_id,name,description,is_public)
  values(u,'อาณานิคม LOCAL MARS','Shared Martian colony',true) returning * into c;
 else
  update public.mars_cities set is_public=true,updated_at=now() where id=c.id returning * into c;
 end if;
 insert into public.mars_city_resources(city_id,owner_id) values(c.id,u) on conflict(city_id) do nothing;
 select * into r from public.mars_city_resources where city_id=c.id;
 return jsonb_build_object('city_id',c.id,'resources',to_jsonb(r));
end $$;
revoke all on function public.mars_city_ensure() from public, anon;
grant execute on function public.mars_city_ensure() to authenticated;
