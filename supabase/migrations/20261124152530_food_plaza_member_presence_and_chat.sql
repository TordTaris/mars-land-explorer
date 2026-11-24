-- LOCAL MARS Food Plaza: authenticated realtime presence and durable room chat.
alter table public.mars_chat_messages
  drop constraint if exists mars_chat_messages_room_key_check;
alter table public.mars_chat_messages
  add constraint mars_chat_messages_room_key_check
  check (room_key = any (array['global','aaru','command','habitat','medical','energy','logistics','food-plaza']::text[]));

drop policy if exists food_plaza_presence_read on realtime.messages;
create policy food_plaza_presence_read
on realtime.messages for select to authenticated
using (
  realtime.topic() = 'food-plaza-main'
  and extension = 'presence'
);

drop policy if exists food_plaza_presence_write on realtime.messages;
create policy food_plaza_presence_write
on realtime.messages for insert to authenticated
with check (
  realtime.topic() = 'food-plaza-main'
  and extension = 'presence'
);

comment on constraint mars_chat_messages_room_key_check on public.mars_chat_messages
is 'Allowed LOCAL MARS chat rooms, including Food Plaza.';
