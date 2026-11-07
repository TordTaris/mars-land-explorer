-- LOCAL MARS Country System: countries govern only parcels claimed by their members.
-- All ownership and role changes are enforced by authenticated RPCs; no client-side role fields are trusted.
create table if not exists public.mars_countries (
  id uuid primary key default gen_random_uuid(),
  country_code text not null unique check (country_code ~ '^[A-Z0-9]{2,5}$'),
  country_name text not null check (char_length(btrim(country_name)) between 2 and 48),
  flag_emoji text not null default '🏳️' check (char_length(flag_emoji) between 1 and 16),
  capital_parcel_id text not null references public.world_parcels(id) on delete restrict,
  founder_id uuid not null references auth.users(id) on delete restrict,
  government_type text not null default 'republic' check (government_type in ('republic','council','federation')),
  status text not null default 'active' check (status in ('active','suspended')),
  created_at timestamptz not null default now()
);
create unique index if not exists mars_countries_name_ci_uidx on public.mars_countries (lower(country_name));
create table if not exists public.mars_country_members (
  country_id uuid not null references public.mars_countries(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'citizen' check (role in ('president','minister','citizen')),
  joined_at timestamptz not null default now(),
  primary key(country_id,user_id)
);
create table if not exists public.mars_country_territories (
  parcel_id text primary key references public.world_parcels(id) on delete restrict,
  country_id uuid not null references public.mars_countries(id) on delete cascade,
  assigned_by uuid not null references auth.users(id) on delete restrict,
  assigned_at timestamptz not null default now()
);
create index if not exists mars_country_territories_country_idx on public.mars_country_territories(country_id);
alter table public.mars_countries enable row level security;
alter table public.mars_country_members enable row level security;
alter table public.mars_country_territories enable row level security;
drop policy if exists mars_countries_public_read on public.mars_countries;
create policy mars_countries_public_read on public.mars_countries for select to anon, authenticated using (status = 'active');
drop policy if exists mars_country_members_self_read on public.mars_country_members;
create policy mars_country_members_self_read on public.mars_country_members for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists mars_country_territories_public_read on public.mars_country_territories;
create policy mars_country_territories_public_read on public.mars_country_territories for select to anon, authenticated using (true);
grant select on public.mars_countries, public.mars_country_territories to anon, authenticated;
grant select on public.mars_country_members to authenticated;
revoke insert, update, delete on public.mars_countries, public.mars_country_members, public.mars_country_territories from anon, authenticated;

create or replace function public.mars_country_create(
  p_country_name text, p_country_code text, p_flag_emoji text, p_capital_parcel_id text,
  p_government_type text default 'republic'
) returns uuid
language plpgsql security definer set search_path = public, auth
as $$
declare v_user uuid := auth.uid(); v_country_id uuid;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if char_length(btrim(coalesce(p_country_name,''))) not between 2 and 48 then raise exception 'Country name must be 2–48 characters'; end if;
  if upper(coalesce(p_country_code,'')) !~ '^[A-Z0-9]{2,5}$' then raise exception 'Country code must be 2–5 letters or numbers'; end if;
  if p_government_type not in ('republic','council','federation') then raise exception 'Invalid government type'; end if;
  if not exists(select 1 from public.world_claims where parcel_id=p_capital_parcel_id and owner_id=v_user) then
    raise exception 'You must own the capital parcel before founding a country';
  end if;
  if exists(select 1 from public.mars_country_territories where parcel_id=p_capital_parcel_id) then
    raise exception 'This parcel already belongs to a country';
  end if;
  insert into public.mars_countries(country_code,country_name,flag_emoji,capital_parcel_id,founder_id,government_type)
  values(upper(p_country_code),btrim(p_country_name),coalesce(nullif(btrim(p_flag_emoji),''),'🏳️'),p_capital_parcel_id,v_user,p_government_type)
  returning id into v_country_id;
  insert into public.mars_country_members(country_id,user_id,role) values(v_country_id,v_user,'president');
  insert into public.mars_country_territories(parcel_id,country_id,assigned_by) values(p_capital_parcel_id,v_country_id,v_user);
  insert into public.world_events(actor_id,event_type,parcel_id,payload)
  values(v_user,'country_founded',p_capital_parcel_id,jsonb_build_object('country_id',v_country_id,'country_code',upper(p_country_code),'country_name',btrim(p_country_name)));
  return v_country_id;
end $$;
revoke all on function public.mars_country_create(text,text,text,text,text) from public, anon;
grant execute on function public.mars_country_create(text,text,text,text,text) to authenticated;

create or replace function public.mars_country_assign_territory(p_country_id uuid,p_parcel_id text)
returns boolean language plpgsql security definer set search_path = public, auth
as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if not exists(select 1 from public.mars_country_members where country_id=p_country_id and user_id=v_user and role in ('president','minister')) then
    raise exception 'Only a country president or minister can assign territory';
  end if;
  if not exists(select 1 from public.world_claims where parcel_id=p_parcel_id and owner_id=v_user) then
    raise exception 'You must own this parcel to assign it';
  end if;
  insert into public.mars_country_territories(parcel_id,country_id,assigned_by)
  values(p_parcel_id,p_country_id,v_user);
  insert into public.world_events(actor_id,event_type,parcel_id,payload)
  values(v_user,'country_territory_added',p_parcel_id,jsonb_build_object('country_id',p_country_id));
  return true;
end $$;
revoke all on function public.mars_country_assign_territory(uuid,text) from public, anon;
grant execute on function public.mars_country_assign_territory(uuid,text) to authenticated;

create or replace function public.mars_country_join(p_country_id uuid)
returns boolean language plpgsql security definer set search_path = public, auth
as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if not exists(select 1 from public.mars_countries where id=p_country_id and status='active') then raise exception 'Country not found or inactive'; end if;
  insert into public.mars_country_members(country_id,user_id,role)
  values(p_country_id,v_user,'citizen') on conflict(country_id,user_id) do nothing;
  return true;
end $$;
revoke all on function public.mars_country_join(uuid) from public, anon;
grant execute on function public.mars_country_join(uuid) to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.mars_countries;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.mars_country_territories;
exception when duplicate_object then null; when undefined_object then null; end $$;
