-- LOCAL MARS: server-verified second-factor password gate for M-003.
-- Run after migrations 008 and 021. Password hashes are PBKDF2-SHA256; plaintext is never stored.
create table if not exists public.m003_access_credentials (
  user_id uuid primary key references auth.users(id) on delete cascade,
  password_salt text not null,
  password_hash text not null,
  failed_attempts integer not null default 0 check (failed_attempts between 0 and 5),
  locked_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.m003_access_credentials enable row level security;
revoke all on public.m003_access_credentials from anon, authenticated, public;
comment on table public.m003_access_credentials is 'M-003 second-factor credentials; accessible only by trusted server-side function using service role.';
-- Remove direct authenticated reads so the second-factor gate cannot be bypassed with the public client.
drop policy if exists m003_private_base_owner_read on public.m003_private_base;
revoke all on public.m003_private_base from anon, authenticated, public;

