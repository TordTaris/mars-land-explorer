-- MARS LAND: additive online community + demo wallet + marketplace
-- Apply once in Supabase SQL Editor. Safe additive migration; does not drop existing data.
create extension if not exists pgcrypto;

-- Public-safe member profiles. Private email/auth data remains in auth.users.
create table if not exists public.mars_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Explorer' check (char_length(display_name) between 1 and 40),
  avatar_url text,
  bio text not null default '' check (char_length(bio) <= 240),
  updated_at timestamptz not null default now()
);
alter table public.mars_profiles enable row level security;
drop policy if exists mars_profiles_read_self on public.mars_profiles;
create policy mars_profiles_read_self on public.mars_profiles for select to authenticated using (auth.uid() = user_id);
drop policy if exists mars_profiles_update_self on public.mars_profiles;
create policy mars_profiles_update_self on public.mars_profiles for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists mars_profiles_insert_self on public.mars_profiles;
create policy mars_profiles_insert_self on public.mars_profiles for insert to authenticated with check (auth.uid() = user_id);
create or replace view public.mars_public_profiles with (security_invoker=true) as
  select user_id, display_name, avatar_url, bio from public.mars_profiles;
grant select on public.mars_public_profiles to anon, authenticated;

create or replace function public.mars_create_profile()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.mars_profiles(user_id, display_name)
  values(new.id, coalesce(nullif(new.raw_user_meta_data->>'display_name',''),'Explorer'))
  on conflict(user_id) do nothing;
  return new;
end $$;
drop trigger if exists mars_auth_user_profile on auth.users;
create trigger mars_auth_user_profile after insert on auth.users
for each row execute function public.mars_create_profile();

-- Member-owned cities; public visibility is opt-in.
create table if not exists public.mars_cities (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  description text not null default '' check (char_length(description) <= 500),
  parcel_id text references public.world_parcels(id) on delete set null,
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists mars_cities_owner_idx on public.mars_cities(owner_id);
create index if not exists mars_cities_public_idx on public.mars_cities(is_public, created_at desc);
alter table public.mars_cities enable row level security;
drop policy if exists mars_cities_read_public_or_owner on public.mars_cities;
create policy mars_cities_read_public_or_owner on public.mars_cities for select to anon, authenticated using (is_public or auth.uid() = owner_id);
drop policy if exists mars_cities_insert_owner on public.mars_cities;
create policy mars_cities_insert_owner on public.mars_cities for insert to authenticated with check (auth.uid() = owner_id);
drop policy if exists mars_cities_update_owner on public.mars_cities;
create policy mars_cities_update_owner on public.mars_cities for update to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
drop policy if exists mars_cities_delete_owner on public.mars_cities;
create policy mars_cities_delete_owner on public.mars_cities for delete to authenticated using (auth.uid() = owner_id);

create table if not exists public.mars_city_buildings (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.mars_cities(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  building_type text not null check (building_type in ('habitat','lab','greenhouse','solar','road','landing_pad')),
  name text not null check (char_length(name) between 1 and 60),
  position jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists mars_city_buildings_city_idx on public.mars_city_buildings(city_id);
alter table public.mars_city_buildings enable row level security;
drop policy if exists mars_city_buildings_read_visible_city on public.mars_city_buildings;
create policy mars_city_buildings_read_visible_city on public.mars_city_buildings for select to anon, authenticated
using (exists(select 1 from public.mars_cities c where c.id=city_id and (c.is_public or c.owner_id=auth.uid())));
drop policy if exists mars_city_buildings_insert_owner on public.mars_city_buildings;
create policy mars_city_buildings_insert_owner on public.mars_city_buildings for insert to authenticated
with check (auth.uid()=owner_id and exists(select 1 from public.mars_cities c where c.id=city_id and c.owner_id=auth.uid()));
drop policy if exists mars_city_buildings_update_owner on public.mars_city_buildings;
create policy mars_city_buildings_update_owner on public.mars_city_buildings for update to authenticated
using (auth.uid()=owner_id and exists(select 1 from public.mars_cities c where c.id=city_id and c.owner_id=auth.uid()))
with check (auth.uid()=owner_id and exists(select 1 from public.mars_cities c where c.id=city_id and c.owner_id=auth.uid()));
drop policy if exists mars_city_buildings_delete_owner on public.mars_city_buildings;
create policy mars_city_buildings_delete_owner on public.mars_city_buildings for delete to authenticated using (auth.uid()=owner_id);

-- Fictional game-resource ledger only. No cash, crypto, deposits, withdrawals or redemption.
create table if not exists public.mars_wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key text not null,
  resource text not null check (resource in ('credits','energy','metal')),
  amount integer not null check (amount <> 0 and abs(amount) <= 1000000),
  reason text not null check (char_length(reason) between 1 and 100),
  created_at timestamptz not null default now(),
  unique(user_id, idempotency_key, resource)
);
create index if not exists mars_wallet_user_created_idx on public.mars_wallet_ledger(user_id, created_at desc);
alter table public.mars_wallet_ledger enable row level security;
drop policy if exists mars_wallet_read_self on public.mars_wallet_ledger;
create policy mars_wallet_read_self on public.mars_wallet_ledger for select to authenticated using (auth.uid()=user_id);
revoke insert, update, delete on public.mars_wallet_ledger from anon, authenticated;
grant select on public.mars_wallet_ledger to authenticated;

create or replace function public.mars_wallet_balances()
returns table(resource text, balance bigint)
language sql security invoker set search_path=public as $$
  select l.resource, coalesce(sum(l.amount),0)::bigint
  from public.mars_wallet_ledger l
  where l.user_id=auth.uid()
  group by l.resource
$$;
grant execute on function public.mars_wallet_balances() to authenticated;

create or replace function public.mars_wallet_grant_starter(p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid();
begin
  if u is null then raise exception 'กรุณาเข้าสู่ระบบ'; end if;
  if p_idempotency_key is null or p_idempotency_key !~ '^[a-zA-Z0-9:_-]{8,80}$' then raise exception 'รหัสรายการไม่ถูกต้อง'; end if;
  insert into public.mars_wallet_ledger(user_id,idempotency_key,resource,amount,reason) values
    (u,p_idempotency_key,'credits',500,'DEMO starter grant'),
    (u,p_idempotency_key,'energy',100,'DEMO starter grant'),
    (u,p_idempotency_key,'metal',50,'DEMO starter grant')
  on conflict(user_id,idempotency_key,resource) do nothing;
  return jsonb_build_object('ok',true,'demo_only',true);
end $$;

create or replace function public.mars_wallet_spend(p_resource text,p_amount integer,p_idempotency_key text,p_reason text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); current_balance bigint;
begin
  if u is null then raise exception 'กรุณาเข้าสู่ระบบ'; end if;
  if p_resource not in ('credits','energy','metal') then raise exception 'ชนิดทรัพยากรไม่ถูกต้อง'; end if;
  if p_amount is null or p_amount <= 0 or p_amount > 100000 then raise exception 'จำนวนไม่ถูกต้อง'; end if;
  if p_idempotency_key is null or p_idempotency_key !~ '^[a-zA-Z0-9:_-]{8,80}$' then raise exception 'รหัสรายการไม่ถูกต้อง'; end if;
  if p_reason is null or char_length(p_reason) not between 1 and 100 then raise exception 'เหตุผลไม่ถูกต้อง'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text || ':' || p_resource,0));
  select coalesce(sum(amount),0) into current_balance from public.mars_wallet_ledger where user_id=u and resource=p_resource;
  if current_balance < p_amount then raise exception 'ทรัพยากร DEMO ไม่เพียงพอ'; end if;
  insert into public.mars_wallet_ledger(user_id,idempotency_key,resource,amount,reason)
  values(u,p_idempotency_key,p_resource,-p_amount,'DEMO: '||p_reason)
  on conflict(user_id,idempotency_key,resource) do nothing;
  return jsonb_build_object('ok',true,'demo_only',true);
end $$;
revoke all on function public.mars_wallet_grant_starter(text) from public;
revoke all on function public.mars_wallet_spend(text,integer,text,text) from public;
grant execute on function public.mars_wallet_grant_starter(text) to authenticated;
grant execute on function public.mars_wallet_spend(text,integer,text,text) to authenticated;

-- Simulated listings only. No real transfer or ownership title.
create table if not exists public.mars_market_listings (
  id uuid primary key default gen_random_uuid(),
  parcel_id text not null references public.world_parcels(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  demo_price integer not null check (demo_price between 1 and 100000000),
  description text not null default '' check (char_length(description) <= 500),
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(parcel_id)
);
create index if not exists mars_market_public_idx on public.mars_market_listings(is_published, created_at desc);
alter table public.mars_market_listings enable row level security;
drop policy if exists mars_market_read_published_or_owner on public.mars_market_listings;
create policy mars_market_read_published_or_owner on public.mars_market_listings for select to anon, authenticated using (is_published or auth.uid()=seller_id);
drop policy if exists mars_market_insert_owner on public.mars_market_listings;
create policy mars_market_insert_owner on public.mars_market_listings for insert to authenticated with check (
  auth.uid()=seller_id and exists(select 1 from public.world_claims c where c.parcel_id=parcel_id and c.owner_id=auth.uid())
);
drop policy if exists mars_market_update_owner on public.mars_market_listings;
create policy mars_market_update_owner on public.mars_market_listings for update to authenticated using (auth.uid()=seller_id) with check (
  auth.uid()=seller_id and exists(select 1 from public.world_claims c where c.parcel_id=parcel_id and c.owner_id=auth.uid())
);
drop policy if exists mars_market_delete_owner on public.mars_market_listings;
create policy mars_market_delete_owner on public.mars_market_listings for delete to authenticated using (auth.uid()=seller_id);
grant select, insert, update, delete on public.mars_cities, public.mars_city_buildings, public.mars_market_listings to authenticated;
grant select on public.mars_cities, public.mars_city_buildings, public.mars_market_listings to anon;
do $$ begin alter publication supabase_realtime add table public.mars_cities; exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.mars_city_buildings; exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.mars_market_listings; exception when duplicate_object then null; when undefined_object then null; end $$;
