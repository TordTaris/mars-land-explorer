-- LOCAL MARS 021: provenance-aware records for real, observed, simulated and virtual entities.
-- Additive only. Does not modify existing parcel, member, wallet or simulation records.
-- Public clients can read only verified public records. Member submissions remain pending.
-- Verification/import writes are reserved for trusted server-side credentials.

begin;

create table if not exists public.world_data_sources (
  id uuid primary key default gen_random_uuid(),
  source_key text not null unique check (source_key ~ '^[a-z0-9][a-z0-9_-]{1,63}$'),
  display_name text not null check (char_length(btrim(display_name)) between 2 and 120),
  source_kind text not null check (source_kind in ('government','scientific','open_data','sensor_network','member_report','internal')),
  canonical_url text,
  license_name text,
  attribution_text text,
  trust_tier smallint not null default 3 check (trust_tier between 1 and 5),
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (canonical_url is null or canonical_url ~ '^https?://')
);

create table if not exists public.world_data_records (
  id uuid primary key default gen_random_uuid(),
  source_id uuid references public.world_data_sources(id) on delete restrict,
  external_key text,
  entity_type text not null check (entity_type in ('place','facility','building','business','vehicle','satellite','sensor','event','environment_observation','member_presence','other')),
  reality_scope text not null check (reality_scope in ('earth_real','mars_observed','mars_simulated','virtual_world')),
  title text not null check (char_length(btrim(title)) between 1 and 180),
  description text not null default '' check (char_length(description) <= 5000),
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  altitude_m double precision,
  coordinate_system text not null default 'NONE' check (coordinate_system in ('WGS84','IAU_MARS_2000','LOCAL_SIMULATION','NONE')),
  observed_at timestamptz,
  source_updated_at timestamptz,
  fetched_at timestamptz,
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected','stale')),
  confidence numeric(4,3) check (confidence between 0 and 1),
  is_public boolean not null default false,
  payload jsonb not null default '{}'::jsonb,
  submitted_by uuid references auth.users(id) on delete set null,
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null) = (longitude is null)),
  check (latitude is null or coordinate_system <> 'NONE'),
  check (
    (reality_scope = 'earth_real' and (coordinate_system in ('WGS84','NONE')))
    or (reality_scope = 'mars_observed' and (coordinate_system in ('IAU_MARS_2000','NONE')))
    or (reality_scope in ('mars_simulated','virtual_world') and (coordinate_system in ('LOCAL_SIMULATION','NONE')))
  ),
  check (verification_status <> 'verified' or verified_at is not null),
  check (verification_status = 'verified' or (is_public = false and verified_by is null and verified_at is null))
);

create unique index if not exists world_data_records_source_external_uidx
  on public.world_data_records(source_id, external_key)
  where source_id is not null and external_key is not null;
create index if not exists world_data_records_public_scope_idx
  on public.world_data_records(reality_scope, entity_type, observed_at desc)
  where verification_status = 'verified' and is_public = true;
create index if not exists world_data_records_submitter_idx
  on public.world_data_records(submitted_by, created_at desc);
create index if not exists world_data_records_location_idx
  on public.world_data_records(latitude, longitude)
  where latitude is not null and longitude is not null;

create table if not exists public.world_data_evidence (
  id uuid primary key default gen_random_uuid(),
  record_id uuid not null references public.world_data_records(id) on delete cascade,
  evidence_kind text not null check (evidence_kind in ('source_url','image','document','sensor_reading','official_identifier','other')),
  evidence_uri text not null check (char_length(btrim(evidence_uri)) between 1 and 2048),
  sha256 text check (sha256 is null or sha256 ~ '^[a-fA-F0-9]{64}$'),
  captured_at timestamptz,
  notes text not null default '' check (char_length(notes) <= 1000),
  submitted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists world_data_evidence_record_idx on public.world_data_evidence(record_id, created_at);

alter table public.world_data_sources enable row level security;
alter table public.world_data_records enable row level security;
alter table public.world_data_evidence enable row level security;

drop policy if exists world_data_sources_read_active on public.world_data_sources;
create policy world_data_sources_read_active
  on public.world_data_sources for select to anon, authenticated
  using (is_active = true);

drop policy if exists world_data_records_read_public_verified on public.world_data_records;
create policy world_data_records_read_public_verified
  on public.world_data_records for select to anon, authenticated
  using (verification_status = 'verified' and is_public = true);

drop policy if exists world_data_records_read_own_pending on public.world_data_records;
create policy world_data_records_read_own_pending
  on public.world_data_records for select to authenticated
  using (submitted_by = (select auth.uid()));

drop policy if exists world_data_records_submit_pending on public.world_data_records;
create policy world_data_records_submit_pending
  on public.world_data_records for insert to authenticated
  with check (
    submitted_by = (select auth.uid())
    and verification_status = 'pending'
    and is_public = false
    and verified_by is null
    and verified_at is null
    and (source_id is null or exists (
      select 1 from public.world_data_sources s
      where s.id = world_data_records.source_id and s.is_active = true
    ))
  );

drop policy if exists world_data_records_delete_own_pending on public.world_data_records;
create policy world_data_records_delete_own_pending
  on public.world_data_records for delete to authenticated
  using (submitted_by = (select auth.uid()) and verification_status = 'pending');

drop policy if exists world_data_evidence_read_visible_parent on public.world_data_evidence;
create policy world_data_evidence_read_visible_parent
  on public.world_data_evidence for select to anon, authenticated
  using (
    exists (
      select 1 from public.world_data_records r
      where r.id = world_data_evidence.record_id
        and r.verification_status = 'verified' and r.is_public = true
    )
  );

drop policy if exists world_data_evidence_read_own_pending on public.world_data_evidence;
create policy world_data_evidence_read_own_pending
  on public.world_data_evidence for select to authenticated
  using (
    submitted_by = (select auth.uid())
    and exists (
      select 1 from public.world_data_records r
      where r.id = world_data_evidence.record_id
        and r.submitted_by = (select auth.uid())
        and r.verification_status = 'pending'
    )
  );

drop policy if exists world_data_evidence_submit_own_pending on public.world_data_evidence;
create policy world_data_evidence_submit_own_pending
  on public.world_data_evidence for insert to authenticated
  with check (
    submitted_by = (select auth.uid())
    and exists (
      select 1 from public.world_data_records r
      where r.id = world_data_evidence.record_id
        and r.submitted_by = (select auth.uid())
        and r.verification_status = 'pending'
    )
  );

revoke all on public.world_data_sources from anon, authenticated;
revoke all on public.world_data_records from anon, authenticated;
revoke all on public.world_data_evidence from anon, authenticated;
grant select on public.world_data_sources to anon, authenticated;
grant select, insert, delete on public.world_data_records to authenticated;
grant select on public.world_data_records to anon;
grant select, insert on public.world_data_evidence to authenticated;
grant select on public.world_data_evidence to anon;

comment on table public.world_data_sources is 'Curated provenance registry for trusted real-world and scientific data sources.';
comment on table public.world_data_records is 'Provenance-aware facts. Public clients see only verified public records; member submissions are pending by default.';
comment on table public.world_data_evidence is 'Evidence references and optional content hashes linked to provenance-aware world data records.';

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='world_data_records') then
      alter publication supabase_realtime add table public.world_data_records;
    end if;
  end if;
end
$$;

commit;
