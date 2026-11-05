-- LOCAL MARS security hardening. Preserve all existing rows and balances.
do $$
declare t record;
begin
  for t in select quote_ident(schemaname)||'.'||quote_ident(tablename) as fqtn
    from pg_tables where schemaname='public'
  loop
    execute format('revoke truncate, references, trigger on table %s from anon, authenticated', t.fqtn);
  end loop;
end $$;

revoke all on function public.mars_wallet_mlc_grant_starter() from public, anon, authenticated;
grant execute on function public.mars_wallet_mlc_grant_starter() to authenticated;
revoke all on function public.mars_wallet_mlc_transfer(uuid, integer, text) from public, anon, authenticated;
grant execute on function public.mars_wallet_mlc_transfer(uuid, integer, text) to authenticated;
revoke all on function public.mars_wallet_grant_starter() from public, anon, authenticated;
grant execute on function public.mars_wallet_grant_starter() to authenticated;
revoke all on function public.mars_city_remove_structure(uuid) from public, anon, authenticated;
grant execute on function public.mars_city_remove_structure(uuid) to authenticated;
revoke all on function public.mars_wallet_spend(text, integer, text, text) from public, anon, authenticated;
grant execute on function public.mars_wallet_spend(text, integer, text, text) to authenticated;
revoke all on function public.build_world_structure(text, text) from public, anon, authenticated;
grant execute on function public.build_world_structure(text, text) to authenticated;
revoke all on function public.mars_city_ensure() from public, anon, authenticated;
grant execute on function public.mars_city_ensure() to authenticated;
revoke all on function public.mars_city_place_structure(text, double precision, double precision, integer) from public, anon, authenticated;
grant execute on function public.mars_city_place_structure(text, double precision, double precision, integer) to authenticated;
revoke all on function public.mars_mlc_reserve_parcel(text) from public, anon, authenticated;
grant execute on function public.mars_mlc_reserve_parcel(text) to authenticated;
revoke all on function public.mars_mlc_purchase_parcel(text) from public, anon, authenticated;
grant execute on function public.mars_mlc_purchase_parcel(text) to authenticated;
revoke all on function public.mars_mlc_set_parcel_listing(text, boolean, integer) from public, anon, authenticated;
grant execute on function public.mars_mlc_set_parcel_listing(text, boolean, integer) to authenticated;

revoke all on function public.mars_create_parcel_order(uuid, text) from public, anon, authenticated;
grant execute on function public.mars_create_parcel_order(uuid, text) to service_role;
revoke all on function public.mars_attach_checkout_session(uuid, text, text) from public, anon, authenticated;
grant execute on function public.mars_attach_checkout_session(uuid, text, text) to service_role;
revoke all on function public.mars_fulfill_paid_order(text, text, uuid, text, text, bigint, text, uuid) from public, anon, authenticated;
grant execute on function public.mars_fulfill_paid_order(text, text, uuid, text, text, bigint, text, uuid) to service_role;
revoke all on function public.mars_attach_usd_checkout_session(uuid, text, text) from public, anon, authenticated;
grant execute on function public.mars_attach_usd_checkout_session(uuid, text, text) to service_role;
revoke all on function public.mars_mark_usd_order_status(text, text, uuid, text, text) from public, anon, authenticated;
grant execute on function public.mars_mark_usd_order_status(text, text, uuid, text, text) to service_role;
revoke all on function public.mars_create_usd_parcel_order(uuid, text) from public, anon, authenticated;
grant execute on function public.mars_create_usd_parcel_order(uuid, text) to service_role;
revoke all on function public.mars_fulfill_paid_order_usd(text, text, uuid, text, text, bigint, text, uuid) from public, anon, authenticated;
grant execute on function public.mars_fulfill_paid_order_usd(text, text, uuid, text, text, bigint, text, uuid) to service_role;

revoke all on function public.rls_auto_enable() from public, anon, authenticated;
revoke all on function public.mars_create_profile() from public, anon, authenticated;
revoke all on function public.mars_mlc_guard_promptpay_order() from public, anon, authenticated;
revoke all on function public.mars_mlc_sync_claim_market() from public, anon, authenticated;
revoke all on function public.claim_world_parcel(text) from public, anon, authenticated;

drop policy if exists mars_market_insert_owner on public.mars_market_listings;
create policy mars_market_insert_owner on public.mars_market_listings
for insert to authenticated
with check (seller_id = (select auth.uid()) and exists (
  select 1 from public.world_claims c
  where c.parcel_id = mars_market_listings.parcel_id and c.owner_id = (select auth.uid())
));
drop policy if exists mars_market_update_owner on public.mars_market_listings;
create policy mars_market_update_owner on public.mars_market_listings
for update to authenticated
using (seller_id = (select auth.uid()) and exists (
  select 1 from public.world_claims c
  where c.parcel_id = mars_market_listings.parcel_id and c.owner_id = (select auth.uid())
))
with check (seller_id = (select auth.uid()) and exists (
  select 1 from public.world_claims c
  where c.parcel_id = mars_market_listings.parcel_id and c.owner_id = (select auth.uid())
));

drop policy if exists mars_fx_rates_public_read on public.mars_fx_rates;
create policy mars_fx_rates_public_read on public.mars_fx_rates for select to anon, authenticated using (true);

create index if not exists idx_mars_cities_parcel_id on public.mars_cities(parcel_id);
create index if not exists idx_mars_city_buildings_owner_id on public.mars_city_buildings(owner_id);
create index if not exists idx_mars_city_resources_owner_id on public.mars_city_resources(owner_id);
create index if not exists idx_mars_market_listings_seller_id on public.mars_market_listings(seller_id);
create index if not exists idx_mars_mlc_parcel_reservations_user_id on public.mars_mlc_parcel_reservations(user_id);
create index if not exists idx_mars_owner_wallet_entries_order_id on public.mars_owner_wallet_entries(order_id);
create index if not exists idx_mars_owner_wallet_entries_usd_order_id on public.mars_owner_wallet_entries_usd(order_id);
create index if not exists idx_world_claims_owner_id on public.world_claims(owner_id);
create index if not exists idx_world_events_actor_id on public.world_events(actor_id);
create index if not exists idx_world_events_parcel_id on public.world_events(parcel_id);
create index if not exists idx_world_structures_owner_id on public.world_structures(owner_id);
