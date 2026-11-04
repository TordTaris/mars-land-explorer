-- LOCAL MARS canonical parcel record.
-- Creates the shared parcel table if absent, then safely upserts M-003.
create table if not exists public.land_plots (
  id text primary key,
  name text not null,
  latitude numeric(8,4) not null,
  longitude numeric(8,4) not null,
  area_m2 numeric(14,2) not null default 10000,
  price_mlc bigint not null default 100,
  status text not null default 'available'
    check (status in ('available','owned','listed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.land_plots enable row level security;
drop policy if exists "Land plots are publicly readable" on public.land_plots;
create policy "Land plots are publicly readable"
  on public.land_plots for select using (true);

insert into public.land_plots (id,name,latitude,longitude,area_m2,price_mlc,status)
values ('M-003','Crystal Ridge',21.10,230.50,10000,9999999,'available')
on conflict (id) do update set
  name=excluded.name,
  latitude=excluded.latitude,
  longitude=excluded.longitude,
  area_m2=excluded.area_m2,
  price_mlc=excluded.price_mlc,
  status=excluded.status,
  updated_at=now();
