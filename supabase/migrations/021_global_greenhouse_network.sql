-- LOCAL MARS Global Greenhouse Network
-- Registry and append-only simulation history. This migration mirrors the
-- schema already applied to the linked Supabase project.
create table if not exists public.mars_greenhouse_nodes (
  parcel_id text primary key references public.world_parcels(id) on delete cascade,
  node_name text not null default 'Greenhouse Node',
  region_code text not null default 'UNASSIGNED',
  node_status text not null default 'planned'
    check (node_status in ('planned','standby','simulating','maintenance','offline')),
  data_classification text not null default 'SIMULATED'
    check (data_classification = 'SIMULATED'),
  configuration jsonb not null default '{}'::jsonb
    check (jsonb_typeof(configuration) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mars_greenhouse_simulation_runs (
  id uuid primary key default gen_random_uuid(),
  parcel_id text not null references public.mars_greenhouse_nodes(parcel_id) on delete cascade,
  run_key text not null unique,
  model_version text not null,
  inputs jsonb not null default '{}'::jsonb check (jsonb_typeof(inputs) = 'object'),
  outputs jsonb not null default '{}'::jsonb check (jsonb_typeof(outputs) = 'object'),
  data_classification text not null default 'SIMULATED'
    check (data_classification = 'SIMULATED'),
  created_at timestamptz not null default now()
);

alter table public.mars_greenhouse_nodes enable row level security;
alter table public.mars_greenhouse_simulation_runs enable row level security;

drop policy if exists "Authenticated members can read greenhouse nodes" on public.mars_greenhouse_nodes;
create policy "Authenticated members can read greenhouse nodes"
on public.mars_greenhouse_nodes for select to authenticated using (true);

drop policy if exists "Parcel owners can manage greenhouse nodes" on public.mars_greenhouse_nodes;
create policy "Parcel owners can manage greenhouse nodes"
on public.mars_greenhouse_nodes for all to authenticated
using (exists (
  select 1 from public.world_claims c
  where c.parcel_id = mars_greenhouse_nodes.parcel_id
    and c.owner_id = auth.uid()
))
with check (exists (
  select 1 from public.world_claims c
  where c.parcel_id = mars_greenhouse_nodes.parcel_id
    and c.owner_id = auth.uid()
));

drop policy if exists "Authenticated members can read greenhouse simulation runs" on public.mars_greenhouse_simulation_runs;
create policy "Authenticated members can read greenhouse simulation runs"
on public.mars_greenhouse_simulation_runs for select to authenticated using (true);

drop policy if exists "Parcel owners can create greenhouse simulation runs" on public.mars_greenhouse_simulation_runs;
create policy "Parcel owners can create greenhouse simulation runs"
on public.mars_greenhouse_simulation_runs for insert to authenticated
with check (exists (
  select 1 from public.world_claims c
  where c.parcel_id = mars_greenhouse_simulation_runs.parcel_id
    and c.owner_id = auth.uid()
));

create index if not exists mars_greenhouse_runs_parcel_created_idx
on public.mars_greenhouse_simulation_runs (parcel_id, created_at desc);

alter publication supabase_realtime add table public.mars_greenhouse_nodes;
alter publication supabase_realtime add table public.mars_greenhouse_simulation_runs;

comment on table public.mars_greenhouse_nodes is
'Global LOCAL MARS greenhouse node registry. All values are simulation metadata, not real habitat telemetry.';
comment on table public.mars_greenhouse_simulation_runs is
'Append-only greenhouse simulation history. Values are synthetic model outputs, not measured Mars conditions.';
