-- LOCAL MARS privacy hardening.
-- Keep public planet rendering available while withholding member identifiers
-- and event payloads from unauthenticated (anon) clients.
-- Authenticated members retain the existing full reads and Realtime behavior.

begin;

revoke select on table public.world_claims from anon, public;
grant select (parcel_id, claimed_at) on table public.world_claims to anon;

revoke select on table public.world_structures from anon, public;
grant select (id, parcel_id, structure_type, level, created_at)
  on table public.world_structures to anon;

revoke select on table public.world_events from anon, public;
grant select (id, event_type, parcel_id, created_at)
  on table public.world_events to anon;

commit;
