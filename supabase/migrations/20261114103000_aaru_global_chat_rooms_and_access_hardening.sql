-- A'ARU / LOCAL MARS global chat rooms.
-- Existing messages remain in the global room; member-only RLS is retained and tightened.
alter table public.mars_chat_messages
  add column if not exists room_key text not null default 'global';

alter table public.mars_chat_messages
  drop constraint if exists mars_chat_messages_room_key_check;
alter table public.mars_chat_messages
  add constraint mars_chat_messages_room_key_check
  check (room_key in ('global','aaru','command','habitat','medical','energy','logistics'));

alter table public.mars_chat_messages
  drop constraint if exists mars_chat_messages_body_length_check;
alter table public.mars_chat_messages
  add constraint mars_chat_messages_body_length_check
  check (char_length(btrim(body)) between 1 and 1000);

create index if not exists mars_chat_messages_room_created_idx
  on public.mars_chat_messages (room_key, created_at desc);

alter table public.mars_chat_messages enable row level security;

drop policy if exists "Signed-in members can read LOCAL MARS chat" on public.mars_chat_messages;
drop policy if exists "Members can send chat as themselves" on public.mars_chat_messages;

create policy "Authenticated members can read chat rooms"
  on public.mars_chat_messages for select
  to authenticated
  using (true);

create policy "Members can send messages as themselves"
  on public.mars_chat_messages for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and char_length(btrim(body)) between 1 and 1000
    and room_key in ('global','aaru','command','habitat','medical','energy','logistics')
  );

revoke all on table public.mars_chat_messages from anon;
revoke update, delete, truncate, references, trigger on table public.mars_chat_messages from authenticated;
grant select, insert on table public.mars_chat_messages to authenticated;
