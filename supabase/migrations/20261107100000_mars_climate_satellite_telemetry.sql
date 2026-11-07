-- LOCAL MARS: persistent, owner-authorized climate telemetry for simulated orbital uplinks.
create table public.mars_climate_telemetry (
  id bigint generated always as identity primary key,
  parcel_id text not null references public.world_parcels(id) on delete restrict,
  owner_id uuid not null references auth.users(id) on delete restrict,
  packet_id text not null check (char_length(packet_id) between 8 and 80),
  relay_id text not null check (relay_id in ('MARS-RELAY-01','POLAR-RELAY-02','DEEP-RELAY-03')),
  temperature_c numeric(7,2) not null check (temperature_c between -200 and 100),
  pressure_kpa numeric(8,3) not null check (pressure_kpa between 0 and 200),
  oxygen_pct numeric(6,3) not null check (oxygen_pct between 0 and 100),
  co2_pct numeric(6,2) not null check (co2_pct between 0 and 100),
  dust_index numeric(6,1) not null check (dust_index between 0 and 1000),
  systems jsonb not null default '{}'::jsonb check (jsonb_typeof(systems) = 'object'),
  signal_pct numeric(5,2) not null check (signal_pct between 0 and 100),
  latency_ms integer not null check (latency_ms between 1 and 120000),
  created_at timestamptz not null default now(),
  constraint mars_climate_telemetry_owner_packet_unique unique (owner_id, packet_id)
);

comment on table public.mars_climate_telemetry is
  'LOCAL MARS simulated climate factory telemetry relayed through fictional orbital satellites; not real spacecraft data.';
comment on column public.mars_climate_telemetry.systems is
  'Simulated climate subsystem states; this telemetry does not represent measured real Martian atmosphere.';

alter table public.mars_climate_telemetry enable row level security;
revoke all on table public.mars_climate_telemetry from anon, authenticated;
grant select (id, parcel_id, packet_id, relay_id, temperature_c, pressure_kpa, oxygen_pct, co2_pct, dust_index, systems, signal_pct, latency_ms, created_at)
  on public.mars_climate_telemetry to authenticated;
grant insert (parcel_id, owner_id, packet_id, relay_id, temperature_c, pressure_kpa, oxygen_pct, co2_pct, dust_index, systems, signal_pct, latency_ms)
  on public.mars_climate_telemetry to authenticated;
grant usage, select on sequence public.mars_climate_telemetry_id_seq to authenticated;

create policy "Authenticated members can read climate telemetry"
  on public.mars_climate_telemetry for select
  to authenticated
  using (true);

create policy "Parcel owners can upload climate telemetry"
  on public.mars_climate_telemetry for insert
  to authenticated
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.world_claims wc
      where wc.parcel_id = mars_climate_telemetry.parcel_id
        and wc.owner_id = (select auth.uid())
    )
  );

create index mars_climate_telemetry_parcel_time_idx
  on public.mars_climate_telemetry (parcel_id, created_at desc);
create index mars_climate_telemetry_time_idx
  on public.mars_climate_telemetry (created_at desc);

alter publication supabase_realtime add table public.mars_climate_telemetry;
