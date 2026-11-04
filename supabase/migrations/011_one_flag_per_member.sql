-- LOCAL MARS: keep exactly one active national flag per member.
-- Keeps each member's most recently placed flag and removes older duplicates.
with ranked_flags as (
  select id,
         row_number() over (
           partition by owner_id
           order by created_at desc, id desc
         ) as position_rank
  from public.mars_city_national_flags
)
delete from public.mars_city_national_flags f
using ranked_flags r
where f.id = r.id
  and r.position_rank > 1;

-- A member can own only one active flag. Upserting by owner_id moves it.
create unique index if not exists mars_city_national_flags_one_per_owner_uidx
  on public.mars_city_national_flags(owner_id);
