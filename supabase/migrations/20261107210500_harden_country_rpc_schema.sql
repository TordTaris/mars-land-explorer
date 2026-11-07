-- Keep SECURITY DEFINER implementations outside the exposed public API schema.
create schema if not exists mars_private;
revoke all on schema mars_private from public, anon;
grant usage on schema mars_private to authenticated;

create or replace function mars_private.country_create(
  p_country_name text, p_country_code text, p_flag_emoji text, p_capital_parcel_id text,
  p_government_type text default 'republic'
) returns uuid language plpgsql security definer set search_path = public, auth
as $$
declare v_user uuid := auth.uid(); v_country_id uuid;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if char_length(btrim(coalesce(p_country_name,''))) not between 2 and 48 then raise exception 'Country name must be 2–48 characters'; end if;
  if upper(coalesce(p_country_code,'')) !~ '^[A-Z0-9]{2,5}$' then raise exception 'Country code must be 2–5 letters or numbers'; end if;
  if p_government_type not in ('republic','council','federation') then raise exception 'Invalid government type'; end if;
  if not exists(select 1 from public.world_claims where parcel_id=p_capital_parcel_id and owner_id=v_user) then
    raise exception 'You must own the capital parcel before founding a country';
  end if;
  if exists(select 1 from public.mars_country_territories where parcel_id=p_capital_parcel_id) then
    raise exception 'This parcel already belongs to a country';
  end if;
  insert into public.mars_countries(country_code,country_name,flag_emoji,capital_parcel_id,founder_id,government_type)
  values(upper(p_country_code),btrim(p_country_name),coalesce(nullif(btrim(p_flag_emoji),''),'🏳️'),p_capital_parcel_id,v_user,p_government_type)
  returning id into v_country_id;
  insert into public.mars_country_members(country_id,user_id,role) values(v_country_id,v_user,'president');
  insert into public.mars_country_territories(parcel_id,country_id,assigned_by) values(p_capital_parcel_id,v_country_id,v_user);
  insert into public.world_events(actor_id,event_type,parcel_id,payload)
  values(v_user,'country_founded',p_capital_parcel_id,jsonb_build_object('country_id',v_country_id,'country_code',upper(p_country_code),'country_name',btrim(p_country_name)));
  return v_country_id;
end $$;
create or replace function mars_private.country_assign_territory(p_country_id uuid,p_parcel_id text)
returns boolean language plpgsql security definer set search_path = public, auth
as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if not exists(select 1 from public.mars_country_members where country_id=p_country_id and user_id=v_user and role in ('president','minister')) then
    raise exception 'Only a country president or minister can assign territory';
  end if;
  if not exists(select 1 from public.world_claims where parcel_id=p_parcel_id and owner_id=v_user) then
    raise exception 'You must own this parcel to assign it';
  end if;
  insert into public.mars_country_territories(parcel_id,country_id,assigned_by) values(p_parcel_id,p_country_id,v_user);
  insert into public.world_events(actor_id,event_type,parcel_id,payload)
  values(v_user,'country_territory_added',p_parcel_id,jsonb_build_object('country_id',p_country_id));
  return true;
end $$;
create or replace function mars_private.country_join(p_country_id uuid)
returns boolean language plpgsql security definer set search_path = public, auth
as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if not exists(select 1 from public.mars_countries where id=p_country_id and status='active') then raise exception 'Country not found or inactive'; end if;
  insert into public.mars_country_members(country_id,user_id,role)
  values(p_country_id,v_user,'citizen') on conflict(country_id,user_id) do nothing;
  return true;
end $$;
revoke all on function mars_private.country_create(text,text,text,text,text) from public, anon;
revoke all on function mars_private.country_assign_territory(uuid,text) from public, anon;
revoke all on function mars_private.country_join(uuid) from public, anon;
grant execute on function mars_private.country_create(text,text,text,text,text) to authenticated;
grant execute on function mars_private.country_assign_territory(uuid,text) to authenticated;
grant execute on function mars_private.country_join(uuid) to authenticated;

create or replace function public.mars_country_create(
  p_country_name text,p_country_code text,p_flag_emoji text,p_capital_parcel_id text,
  p_government_type text default 'republic'
) returns uuid language sql security invoker set search_path = public, auth
as $$ select mars_private.country_create(p_country_name,p_country_code,p_flag_emoji,p_capital_parcel_id,p_government_type) $$;
create or replace function public.mars_country_assign_territory(p_country_id uuid,p_parcel_id text)
returns boolean language sql security invoker set search_path = public, auth
as $$ select mars_private.country_assign_territory(p_country_id,p_parcel_id) $$;
create or replace function public.mars_country_join(p_country_id uuid)
returns boolean language sql security invoker set search_path = public, auth
as $$ select mars_private.country_join(p_country_id) $$;
revoke all on function public.mars_country_create(text,text,text,text,text) from public, anon;
revoke all on function public.mars_country_assign_territory(uuid,text) from public, anon;
revoke all on function public.mars_country_join(uuid) from public, anon;
grant execute on function public.mars_country_create(text,text,text,text,text) to authenticated;
grant execute on function public.mars_country_assign_territory(uuid,text) to authenticated;
grant execute on function public.mars_country_join(uuid) to authenticated;
