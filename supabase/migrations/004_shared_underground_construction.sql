-- Shared underground construction grid. Each member owns their own cells;
-- all signed-in members can see every member's construction across the shared world.
create table if not exists public.mars_underground_cells (
  owner_id uuid not null references auth.users(id) on delete cascade,
  floor_no smallint not null check (floor_no between 1 and 24),
  cell_index smallint not null check (cell_index between 0 and 191),
  cell_type text not null check (cell_type in ('room','corridor','life','storage','lift')),
  updated_at timestamptz not null default now(),
  primary key(owner_id,floor_no,cell_index)
);
create index if not exists mars_underground_cells_floor_idx
  on public.mars_underground_cells(floor_no,cell_index);
alter table public.mars_underground_cells enable row level security;
drop policy if exists underground_cells_read_all on public.mars_underground_cells;
create policy underground_cells_read_all on public.mars_underground_cells
  for select to anon, authenticated using (true);
drop policy if exists underground_cells_insert_owner on public.mars_underground_cells;
create policy underground_cells_insert_owner on public.mars_underground_cells
  for insert to authenticated with check (auth.uid()=owner_id);
drop policy if exists underground_cells_update_owner on public.mars_underground_cells;
create policy underground_cells_update_owner on public.mars_underground_cells
  for update to authenticated using (auth.uid()=owner_id) with check (auth.uid()=owner_id);
drop policy if exists underground_cells_delete_owner on public.mars_underground_cells;
create policy underground_cells_delete_owner on public.mars_underground_cells
  for delete to authenticated using (auth.uid()=owner_id);
do $$ begin
  alter publication supabase_realtime add table public.mars_underground_cells;
exception when duplicate_object then null;
when undefined_object then null;
end $$;
