-- MARS LAND online world schema (Supabase / PostgreSQL)
-- Run this file in Supabase SQL Editor after creating a project.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Explorer',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.land_plots (
  id text primary key,
  name text not null,
  latitude numeric(8,4) not null,
  longitude numeric(8,4) not null,
  area_m2 numeric(14,2) not null default 10000,
  price_mlc numeric(14,2) not null default 100,
  status text not null default 'available'
    check (status in ('available','owned','listed')),
  owner_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.structures (
  id uuid primary key default gen_random_uuid(),
  plot_id text not null references public.land_plots(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  structure_type text not null
    check (structure_type in ('habitat','lab','solar','greenhouse','road','custom')),
  name text not null,
  position jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.marketplace_listings (
  id uuid primary key default gen_random_uuid(),
  plot_id text not null unique references public.land_plots(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  asking_price_mlc numeric(14,2) not null check (asking_price_mlc > 0),
  description text not null default '',
  status text not null default 'active'
    check (status in ('active','cancelled','sold')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists land_plots_owner_idx on public.land_plots(owner_id);
create index if not exists structures_plot_idx on public.structures(plot_id);
create index if not exists structures_owner_idx on public.structures(owner_id);
create index if not exists listings_status_idx on public.marketplace_listings(status);

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
drop trigger if exists plots_updated_at on public.land_plots;
create trigger plots_updated_at before update on public.land_plots
for each row execute function public.set_updated_at();
drop trigger if exists structures_updated_at on public.structures;
create trigger structures_updated_at before update on public.structures
for each row execute function public.set_updated_at();
drop trigger if exists listings_updated_at on public.marketplace_listings;
create trigger listings_updated_at before update on public.marketplace_listings
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.land_plots enable row level security;
alter table public.structures enable row level security;
alter table public.marketplace_listings enable row level security;

drop policy if exists "Profiles are publicly readable" on public.profiles;
create policy "Profiles are publicly readable" on public.profiles
for select using (true);
drop policy if exists "Users create own profile" on public.profiles;
create policy "Users create own profile" on public.profiles
for insert to authenticated with check (auth.uid() = id);
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles
for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "Plots are publicly readable" on public.land_plots;
create policy "Plots are publicly readable" on public.land_plots
for select using (true);
drop policy if exists "Owners update their plots" on public.land_plots;
create policy "Owners update their plots" on public.land_plots
for update to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists "Structures are publicly readable" on public.structures;
create policy "Structures are publicly readable" on public.structures
for select using (true);
drop policy if exists "Users create own structures" on public.structures;
create policy "Users create own structures" on public.structures
for insert to authenticated with check (
  auth.uid() = owner_id and exists (
    select 1 from public.land_plots p
    where p.id = plot_id and p.owner_id = auth.uid()
  )
);
drop policy if exists "Users update own structures" on public.structures;
create policy "Users update own structures" on public.structures
for update to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
drop policy if exists "Users delete own structures" on public.structures;
create policy "Users delete own structures" on public.structures
for delete to authenticated using (auth.uid() = owner_id);

drop policy if exists "Listings are publicly readable" on public.marketplace_listings;
create policy "Listings are publicly readable" on public.marketplace_listings
for select using (true);
drop policy if exists "Users create own listings" on public.marketplace_listings;
create policy "Users create own listings" on public.marketplace_listings
for insert to authenticated with check (
  auth.uid() = seller_id and exists (
    select 1 from public.land_plots p
    where p.id = plot_id and p.owner_id = auth.uid()
  )
);
drop policy if exists "Users update own listings" on public.marketplace_listings;
create policy "Users update own listings" on public.marketplace_listings
for update to authenticated using (auth.uid() = seller_id) with check (auth.uid() = seller_id);
drop policy if exists "Users delete own listings" on public.marketplace_listings;
create policy "Users delete own listings" on public.marketplace_listings
for delete to authenticated using (auth.uid() = seller_id);

-- Demo parcels; these are virtual game parcels, not legal property rights.
insert into public.land_plots (id, name, latitude, longitude, area_m2, price_mlc)
values
('M-001','Olympus Gateway',18.65,226.20,10000,120),
('M-002','Red Valley',12.40,221.80,10000,95),
('M-003','Crystal Ridge',21.10,230.50,10000,150),
('M-004','Sunset Basin',-4.20,137.40,10000,110),
('M-005','Ares Frontier',-8.50,145.20,10000,105),
('M-006','Valles View',-13.90,295.30,10000,180),
('M-007','Elysium Field',24.70,147.20,10000,130),
('M-008','Dust Harbor',2.10,155.60,10000,90),
('M-009','Phobos Outlook',10.80,190.10,10000,160),
('M-010','New Horizon',-18.20,210.40,10000,125),
('M-011','Solar Crown',5.60,265.90,10000,145),
('M-012','Terraform Point',-2.30,310.70,10000,170)
on conflict (id) do nothing;

-- Enable Realtime for shared world updates (safe to run more than once).
do $$
begin
  alter publication supabase_realtime add table public.land_plots;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.structures;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.marketplace_listings;
exception when duplicate_object then null;
end $$;
