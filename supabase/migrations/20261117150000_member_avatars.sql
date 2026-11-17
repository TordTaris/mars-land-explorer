-- LOCAL MARS: member-owned avatar appearance. Additive migration.
create table if not exists public.mars_avatars (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Explorer' check (char_length(display_name) between 1 and 40),
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.mars_avatars enable row level security;
drop policy if exists mars_avatars_read_members on public.mars_avatars;
create policy mars_avatars_read_members on public.mars_avatars
  for select to authenticated using (true);
drop policy if exists mars_avatars_insert_self on public.mars_avatars;
create policy mars_avatars_insert_self on public.mars_avatars
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists mars_avatars_update_self on public.mars_avatars;
create policy mars_avatars_update_self on public.mars_avatars
  for update to authenticated using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
grant select, insert, update on public.mars_avatars to authenticated;

-- Restrict live avatar coordinates and appearance presence to authenticated members.
drop policy if exists mars_avatar_presence_read on realtime.messages;
create policy mars_avatar_presence_read on realtime.messages
  for select to authenticated
  using ((select realtime.topic()) = 'mars-avatar-world'
    and extension = 'presence');
drop policy if exists mars_avatar_presence_write on realtime.messages;
create policy mars_avatar_presence_write on realtime.messages
  for insert to authenticated
  with check ((select realtime.topic()) = 'mars-avatar-world'
    and extension = 'presence');
