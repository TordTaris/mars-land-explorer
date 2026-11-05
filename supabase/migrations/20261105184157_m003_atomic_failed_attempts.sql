create or replace function public.m003_record_failed_attempt(p_user_id uuid)
returns table(failed_attempts integer, locked_until timestamptz, is_locked boolean)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_attempts integer;
  v_locked_until timestamptz;
begin
  update public.m003_access_credentials as c
  set failed_attempts = least(c.failed_attempts + 1, 5),
      locked_until = case
        when c.failed_attempts + 1 >= 5
          then clock_timestamp() + interval '15 minutes'
        else null
      end,
      updated_at = clock_timestamp()
  where c.user_id = p_user_id
    and (c.locked_until is null or c.locked_until <= clock_timestamp())
  returning c.failed_attempts, c.locked_until
  into v_attempts, v_locked_until;

  if not found then
    select c.failed_attempts, c.locked_until
      into v_attempts, v_locked_until
    from public.m003_access_credentials as c
    where c.user_id = p_user_id;
  end if;

  return query
    select coalesce(v_attempts, 0),
           v_locked_until,
           coalesce(v_locked_until > clock_timestamp(), false);
end;
$function$;

revoke all on function public.m003_record_failed_attempt(uuid) from public, anon, authenticated;
grant execute on function public.m003_record_failed_attempt(uuid) to service_role;
