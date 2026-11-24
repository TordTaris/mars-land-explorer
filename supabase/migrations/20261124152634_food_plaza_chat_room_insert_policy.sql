drop policy if exists "Members can send messages as themselves" on public.mars_chat_messages;
create policy "Members can send messages as themselves"
on public.mars_chat_messages
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and char_length(btrim(body)) between 1 and 1000
  and room_key = any (array['global','aaru','command','habitat','medical','energy','logistics','food-plaza']::text[])
);
