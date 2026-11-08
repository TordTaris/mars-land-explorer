-- Optimize auth.uid() evaluation in greenhouse row-level security policies.
drop policy if exists "Parcel owners can manage greenhouse nodes" on public.mars_greenhouse_nodes;
create policy "Parcel owners can manage greenhouse nodes"
on public.mars_greenhouse_nodes for all to authenticated
using (exists (select 1 from public.world_claims c where c.parcel_id = mars_greenhouse_nodes.parcel_id and c.owner_id = (select auth.uid())))
with check (exists (select 1 from public.world_claims c where c.parcel_id = mars_greenhouse_nodes.parcel_id and c.owner_id = (select auth.uid())));
drop policy if exists "Parcel owners can create greenhouse simulation runs" on public.mars_greenhouse_simulation_runs;
create policy "Parcel owners can create greenhouse simulation runs"
on public.mars_greenhouse_simulation_runs for insert to authenticated
with check (exists (select 1 from public.world_claims c where c.parcel_id = mars_greenhouse_simulation_runs.parcel_id and c.owner_id = (select auth.uid())));
