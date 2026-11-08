-- LOCAL MARS security hardening:
-- 1) Keep private member identifiers/event payloads out of anonymous reads.
-- 2) Enforce one structure of each type per parcel under concurrent requests.
-- 3) Enforce the A'ARU colony's M-001 restriction in the database RPC.
begin;

-- Authenticated members retain the existing full world-state read needed for ownership checks.
-- Anonymous visitors use narrowly projected public views instead of raw member tables.
drop policy if exists claims_public_read on public.world_claims;
drop policy if exists claims_members_read on public.world_claims;
create policy claims_members_read on public.world_claims
  for select to authenticated using (true);

drop policy if exists structures_public_read on public.world_structures;
drop policy if exists structures_members_read on public.world_structures;
create policy structures_members_read on public.world_structures
  for select to authenticated using (true);

drop policy if exists events_public_read on public.world_events;
drop policy if exists events_members_read on public.world_events;
create policy events_members_read on public.world_events
  for select to authenticated using (true);

create or replace view public.world_claims_public
  with (security_barrier = true, security_invoker = false) as
  select parcel_id, claimed_at
  from public.world_claims;

create or replace view public.world_structures_public
  with (security_barrier = true, security_invoker = false) as
  select id, parcel_id, structure_type, level, created_at
  from public.world_structures;

create or replace view public.world_events_public
  with (security_barrier = true, security_invoker = false) as
  select id, event_type, parcel_id, created_at
  from public.world_events;

revoke all on public.world_claims_public, public.world_structures_public, public.world_events_public from public;
grant select on public.world_claims_public, public.world_structures_public, public.world_events_public to anon, authenticated;

comment on view public.world_claims_public is
  'Anonymous-safe parcel occupancy projection; deliberately excludes owner_id.';
comment on view public.world_structures_public is
  'Anonymous-safe structure projection; deliberately excludes owner_id.';
comment on view public.world_events_public is
  'Anonymous-safe event projection; deliberately excludes actor_id and payload.';

-- Runtime pre-check on 2026-11-09 found no duplicate (parcel_id, structure_type) pairs.
-- The unique index is the authoritative concurrency-safe guard; a prior SELECT check alone is not.
create unique index if not exists world_structures_parcel_type_uidx
  on public.world_structures(parcel_id, structure_type);

-- Permit the A'ARU colony structure type in the canonical table constraint.
alter table public.world_structures
  drop constraint if exists world_structures_structure_type_check;
alter table public.world_structures
  add constraint world_structures_structure_type_check
  check (structure_type = any (array[
    'ฐานที่อยู่อาศัย'::text,
    'ห้องปฏิบัติการ'::text,
    'โรงเรือนปลูกพืช'::text,
    'แผงพลังงานแสงอาทิตย์'::text,
    'โรงไฟฟ้านิวเคลียร์ขนาดใหญ่'::text,
    'ศูนย์จัดเก็บข้อมูล'::text,
    'โรงงานปรับสภาพอากาศ'::text,
    'A’ARU 1.1 Colony'::text
  ]));

-- Keep the RPC as the source of truth for construction authorization and parcel restrictions.
create or replace function public.build_world_structure(p_parcel_id text, p_type text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  u uuid := auth.uid();
  new_id uuid;
begin
  if u is null then
    raise exception 'Sign in before construction';
  end if;

  if not exists (select 1 from public.world_parcels where id = p_parcel_id) then
    raise exception 'Parcel not found';
  end if;

  if p_type not in (
    'ฐานที่อยู่อาศัย',
    'ห้องปฏิบัติการ',
    'โรงเรือนปลูกพืช',
    'แผงพลังงานแสงอาทิตย์',
    'โรงไฟฟ้านิวเคลียร์ขนาดใหญ่',
    'ศูนย์จัดเก็บข้อมูล',
    'โรงงานปรับสภาพอากาศ',
    'A’ARU 1.1 Colony'
  ) then
    raise exception 'Invalid structure type';
  end if;

  if p_type = 'โรงไฟฟ้านิวเคลียร์ขนาดใหญ่' and p_parcel_id <> 'M-003' then
    raise exception 'Nuclear power plant is restricted to M-003';
  end if;
  if p_type in ('ศูนย์จัดเก็บข้อมูล', 'โรงงานปรับสภาพอากาศ', 'A’ARU 1.1 Colony')
     and p_parcel_id <> 'M-001' then
    raise exception 'This structure type is restricted to M-001';
  end if;

  if not exists (
    select 1 from public.world_claims
    where parcel_id = p_parcel_id and owner_id = u
  ) then
    raise exception 'You must own this parcel';
  end if;

  if exists (
    select 1 from public.world_structures
    where parcel_id = p_parcel_id and structure_type = p_type
  ) then
    raise exception 'This parcel already contains this structure type';
  end if;

  insert into public.world_structures(parcel_id, owner_id, structure_type)
  values (p_parcel_id, u, p_type)
  returning id into new_id;

  insert into public.world_events(actor_id, event_type, parcel_id, payload)
  values (
    u,
    'structure_built',
    p_parcel_id,
    jsonb_build_object('structure_id', new_id, 'type', p_type)
  );

  return jsonb_build_object(
    'ok', true,
    'structure_id', new_id,
    'parcel_id', p_parcel_id,
    'type', p_type,
    'owner_id', u
  );
end;
$function$;

revoke all on function public.build_world_structure(text, text) from public, anon, authenticated;
grant execute on function public.build_world_structure(text, text) to authenticated;

commit;
