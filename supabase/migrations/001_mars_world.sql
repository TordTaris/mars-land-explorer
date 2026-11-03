-- Mars Local World Server schema. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.world_parcels(id text primary key,latitude double precision not null,longitude double precision not null,area_sqm integer not null,terrain text not null,resource text not null,base_price integer not null default 100,created_at timestamptz not null default now());
create table if not exists public.world_claims(parcel_id text primary key references public.world_parcels(id) on delete cascade,owner_id uuid not null references auth.users(id) on delete cascade,claimed_at timestamptz not null default now());
create table if not exists public.world_structures(id uuid primary key default gen_random_uuid(),parcel_id text not null references public.world_parcels(id) on delete cascade,owner_id uuid not null references auth.users(id) on delete cascade,structure_type text not null check(structure_type in('ฐานที่อยู่อาศัย','ห้องปฏิบัติการ','โรงเรือนปลูกพืช','แผงพลังงานแสงอาทิตย์')),level integer not null default 1 check(level between 1 and 20),created_at timestamptz not null default now());
create table if not exists public.world_events(id bigint generated always as identity primary key,actor_id uuid references auth.users(id) on delete set null,event_type text not null,parcel_id text references public.world_parcels(id) on delete set null,payload jsonb not null default '{}'::jsonb,created_at timestamptz not null default now());
create index if not exists world_structures_parcel_idx on public.world_structures(parcel_id);
create index if not exists world_events_created_idx on public.world_events(created_at desc);
insert into public.world_parcels(id,latitude,longitude,area_sqm,terrain,resource,base_price) values
('M-001',-55,-160,1000,'ที่ราบลาวา','น้ำแข็งใต้ผิวดิน',120),('M-002',-26,-93,1275,'หุบเขาหิน','แร่เหล็ก',157),('M-003',3,-26,1550,'ที่ราบสูง','ซิลิกา',194),('M-004',32,41,1825,'ขอบหลุมอุกกาบาต','หินบะซอลต์',231),('M-005',-49,108,2100,'เนินทราย','แร่แมกนีเซียม',268),('M-006',-20,175,2375,'ที่ราบน้ำแข็ง','คาร์บอนไดออกไซด์',305),('M-007',9,-118,2750,'ที่ราบลาวา','น้ำแข็งใต้ผิวดิน',342),('M-008',38,-51,3125,'หุบเขาหิน','แร่เหล็ก',379),('M-009',-43,16,1400,'ที่ราบสูง','ซิลิกา',156),('M-010',-14,83,1675,'ขอบหลุมอุกกาบาต','หินบะซอลต์',193),('M-011',15,150,1950,'เนินทราย','แร่แมกนีเซียม',230),('M-012',44,-143,2225,'ที่ราบน้ำแข็ง','คาร์บอนไดออกไซด์',267) on conflict(id) do nothing;
alter table public.world_parcels enable row level security;
alter table public.world_claims enable row level security;
alter table public.world_structures enable row level security;
alter table public.world_events enable row level security;
drop policy if exists parcels_public_read on public.world_parcels;
create policy parcels_public_read on public.world_parcels for select to anon,authenticated using(true);
drop policy if exists claims_public_read on public.world_claims;
create policy claims_public_read on public.world_claims for select to anon,authenticated using(true);
drop policy if exists structures_public_read on public.world_structures;
create policy structures_public_read on public.world_structures for select to anon,authenticated using(true);
drop policy if exists events_public_read on public.world_events;
create policy events_public_read on public.world_events for select to anon,authenticated using(true);
create or replace function public.claim_world_parcel(p_parcel_id text) returns jsonb language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'กรุณาเข้าสู่ระบบออนไลน์'; end if;
 if not exists(select 1 from public.world_parcels where id=p_parcel_id) then raise exception 'ไม่พบแปลงพื้นที่'; end if;
 insert into public.world_claims(parcel_id,owner_id) values(p_parcel_id,u) on conflict(parcel_id) do nothing;
 if not exists(select 1 from public.world_claims where parcel_id=p_parcel_id and owner_id=u) then raise exception 'แปลงนี้มีสมาชิกอื่นจองแล้ว'; end if;
 insert into public.world_events(actor_id,event_type,parcel_id,payload) values(u,'parcel_claimed',p_parcel_id,jsonb_build_object('parcel_id',p_parcel_id));
 return jsonb_build_object('ok',true,'parcel_id',p_parcel_id);
end $$;
create or replace function public.build_world_structure(p_parcel_id text,p_type text) returns jsonb language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); new_id uuid;
begin
 if u is null then raise exception 'กรุณาเข้าสู่ระบบออนไลน์'; end if;
 if p_type not in('ฐานที่อยู่อาศัย','ห้องปฏิบัติการ','โรงเรือนปลูกพืช','แผงพลังงานแสงอาทิตย์') then raise exception 'ประเภทอาคารไม่ถูกต้อง'; end if;
 if not exists(select 1 from public.world_claims where parcel_id=p_parcel_id and owner_id=u) then raise exception 'ต้องจองแปลงนี้ก่อนก่อสร้าง'; end if;
 insert into public.world_structures(parcel_id,owner_id,structure_type) values(p_parcel_id,u,p_type) returning id into new_id;
 insert into public.world_events(actor_id,event_type,parcel_id,payload) values(u,'structure_built',p_parcel_id,jsonb_build_object('structure_id',new_id,'type',p_type));
 return jsonb_build_object('ok',true,'structure_id',new_id,'parcel_id',p_parcel_id,'type',p_type);
end $$;
revoke all on function public.claim_world_parcel(text) from public;
revoke all on function public.build_world_structure(text,text) from public;
grant execute on function public.claim_world_parcel(text) to authenticated;
grant execute on function public.build_world_structure(text,text) to authenticated;
grant select on public.world_parcels,public.world_claims,public.world_structures,public.world_events to anon,authenticated;
do $$ begin alter publication supabase_realtime add table public.world_claims; exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.world_structures; exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.world_events; exception when duplicate_object then null; when undefined_object then null; end $$;
