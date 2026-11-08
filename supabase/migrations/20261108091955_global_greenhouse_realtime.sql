-- Enable change streams for the global greenhouse dashboard.
alter publication supabase_realtime add table public.mars_greenhouse_nodes;
alter publication supabase_realtime add table public.mars_greenhouse_simulation_runs;
