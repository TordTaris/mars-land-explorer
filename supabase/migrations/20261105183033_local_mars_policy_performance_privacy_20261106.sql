drop policy if exists mars_profiles_insert_self on public.mars_profiles;
drop policy if exists mars_profiles_update_self on public.mars_profiles;

-- Enforce caller RLS on the public profile projection.
alter view public.mars_public_profiles set (security_invoker = true);
revoke all on public.mars_public_profiles from anon;
grant select on public.mars_public_profiles to authenticated;

-- Wrap auth.uid() calls to avoid per-row re-evaluation in RLS predicates.
do $$
declare
  p record;
  role_list text;
  using_expr text;
  check_expr text;
  stmt text;
begin
  for p in
    select * from pg_policies
    where schemaname='public'
      and (coalesce(qual,'') ~* 'auth\.uid\(\)' or coalesce(with_check,'') ~* 'auth\.uid\(\)')
  loop
    select string_agg(quote_ident(r), ', ') into role_list from unnest(p.roles) as r;
    using_expr := nullif(replace(p.qual, 'auth.uid()', '(select auth.uid())'), '');
    check_expr := nullif(replace(p.with_check, 'auth.uid()', '(select auth.uid())'), '');
    execute format('drop policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
    stmt := format('create policy %I on %I.%I as %s for %s to %s',
      p.policyname, p.schemaname, p.tablename, p.permissive, p.cmd, role_list);
    if using_expr is not null then stmt := stmt || format(' using (%s)', using_expr); end if;
    if check_expr is not null then stmt := stmt || format(' with check (%s)', check_expr); end if;
    execute stmt;
  end loop;
end $$;
