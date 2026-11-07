-- M-003 / Level 17 IBM 5100 program archive integrity.
-- Keep program names unique per owner and automatically maintain updated_at.

create unique index if not exists m003_ibm5100_programs_owner_name_uidx
  on public.m003_ibm5100_programs (owner_id, lower(btrim(program_name)));

create index if not exists m003_ibm5100_programs_owner_updated_idx
  on public.m003_ibm5100_programs (owner_id, updated_at desc);

create or replace function public.set_m003_ibm5100_program_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists set_m003_ibm5100_program_updated_at
  on public.m003_ibm5100_programs;

create trigger set_m003_ibm5100_program_updated_at
before update on public.m003_ibm5100_programs
for each row execute function public.set_m003_ibm5100_program_updated_at();

comment on table public.m003_ibm5100_programs is
  'M-003 / Level 17 IBM 5100 educational workstation cloud archive. One record per saved program. Owner-only access. BASIC and APL are limited educational interpreters, not original IBM firmware.';
comment on column public.m003_ibm5100_programs.parcel_id is 'Parcel identifier. Fixed to M-003.';
comment on column public.m003_ibm5100_programs.floor_no is 'Underground level. Fixed to Level 17.';
comment on column public.m003_ibm5100_programs.owner_id is 'LOCAL MARS account that owns M-003 and saved this program.';
comment on column public.m003_ibm5100_programs.program_name is 'Human-readable program title, unique per owner (case-insensitive).';
comment on column public.m003_ibm5100_programs.language is 'Interpreter mode: BASIC or APL educational subset.';
comment on column public.m003_ibm5100_programs.source_code is 'Program source text, maximum 20,000 characters.';
