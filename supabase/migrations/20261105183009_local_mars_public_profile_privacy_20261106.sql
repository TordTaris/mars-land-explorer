-- Anonymous API access is read-only. No anon write policies exist in this schema.
revoke insert, update, delete, truncate, references, trigger on all tables in schema public from anon;

drop policy if exists mars_profiles_read_public_safe on public.mars_profiles;
drop policy if exists mars_profiles_read_own on public.mars_profiles;
create policy mars_profiles_read_own on public.mars_profiles
for select to authenticated using ((select auth.uid()) = user_id);

-- Public profile projection is limited to signed-in users and caller-visible rows.
alter view public.mars_public_profiles set (security_invoker = false);
grant select on public.mars_public_profiles to anon, authenticated;
revoke select on public.mars_profiles from anon;
