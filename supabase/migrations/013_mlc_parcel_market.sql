-- LOCAL MARS 013: MLC parcel reservation and member-to-member marketplace.
-- MLC is an in-app simulated currency only; USD reference values and THB PromptPay stay separate.

create table if not exists public.mars_mlc_parcel_market (
  parcel_id text primary key references public.world_parcels(id) on delete cascade,
  price_mlc integer not null check (price_mlc between 1 and 1000000),
  is_listed boolean not null default true,
  updated_at timestamptz not null default now()
);
insert into public.mars_mlc_parcel_market(parcel_id,price_mlc,is_listed)
select p.id,greatest(1,least(p.base_price,1000000)),
  not exists(select 1 from public.world_claims c where c.parcel_id=p.id)
from public.world_parcels p
on conflict(parcel_id) do nothing;

create table if not exists public.mars_mlc_parcel_reservations (
  parcel_id text primary key references public.world_parcels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists mars_mlc_reservations_expiry_idx
  on public.mars_mlc_parcel_reservations(expires_at);

alter table public.mars_mlc_parcel_market enable row level security;
alter table public.mars_mlc_parcel_reservations enable row level security;
drop policy if exists mars_mlc_market_public_read on public.mars_mlc_parcel_market;
create policy mars_mlc_market_public_read on public.mars_mlc_parcel_market
  for select to anon,authenticated using (true);
revoke all on public.mars_mlc_parcel_reservations from anon,authenticated;
revoke insert,update,delete on public.mars_mlc_parcel_market from anon,authenticated;
grant select on public.mars_mlc_parcel_market to anon,authenticated;

-- A parcel acquired through PromptPay must leave the MLC market until its owner lists it.
-- Prevent simultaneous THB checkout and MLC reservation for the same parcel.
create or replace function public.mars_mlc_guard_promptpay_order()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('parcel:'||new.parcel_id,0));
  if new.status='pending' and exists(
    select 1 from public.mars_mlc_parcel_reservations
    where parcel_id=new.parcel_id and expires_at>now()
  ) then
    raise exception 'แปลงนี้ถูกจองด้วย MLC อยู่ กรุณารอให้การจองหมดอายุหรือเลือกแปลงอื่น';
  end if;
  return new;
end $$;
drop trigger if exists mars_mlc_guard_promptpay_order on public.mars_parcel_orders;
create trigger mars_mlc_guard_promptpay_order
before insert or update of status,parcel_id on public.mars_parcel_orders
for each row execute function public.mars_mlc_guard_promptpay_order();

create or replace function public.mars_mlc_sync_claim_market()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='DELETE' then
    update public.mars_mlc_parcel_market set is_listed=true,updated_at=now()
      where parcel_id=old.parcel_id;
    delete from public.mars_mlc_parcel_reservations where parcel_id=old.parcel_id;
    return old;
  end if;
  update public.mars_mlc_parcel_market set is_listed=false,updated_at=now()
    where parcel_id=new.parcel_id;
  delete from public.mars_mlc_parcel_reservations where parcel_id=new.parcel_id;
  return new;
end $$;
revoke all on function public.mars_mlc_guard_promptpay_order() from public,anon,authenticated;
drop trigger if exists mars_mlc_claim_market_sync on public.world_claims;
create trigger mars_mlc_claim_market_sync
after insert or delete on public.world_claims
for each row execute function public.mars_mlc_sync_claim_market();

create or replace function public.mars_mlc_reserve_parcel(p_parcel_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); m public.mars_mlc_parcel_market%rowtype;
        c public.world_claims%rowtype; r public.mars_mlc_parcel_reservations%rowtype;
begin
  if u is null then raise exception 'กรุณาเข้าสู่ระบบก่อนจองแปลง'; end if;
  perform pg_advisory_xact_lock(hashtextextended('parcel:'||p_parcel_id,0));
  if exists(select 1 from public.mars_parcel_orders where parcel_id=p_parcel_id and status='pending' and expires_at>now()) then
    raise exception 'แปลงนี้มีรายการ PromptPay รอชำระอยู่ กรุณาลองใหม่ภายหลัง';
  end if;
  select * into m from public.mars_mlc_parcel_market where parcel_id=p_parcel_id for update;
  if not found or not m.is_listed then raise exception 'แปลงนี้ไม่ได้เปิดให้จอง'; end if;
  select * into c from public.world_claims where parcel_id=p_parcel_id;
  if found and c.owner_id=u then raise exception 'คุณเป็นเจ้าของแปลงนี้อยู่แล้ว'; end if;
  if found and not m.is_listed then raise exception 'เจ้าของยังไม่ได้ประกาศขายแปลงนี้'; end if;
  select * into r from public.mars_mlc_parcel_reservations where parcel_id=p_parcel_id for update;
  if found and r.expires_at>now() and r.user_id<>u then
    raise exception 'แปลงนี้มีสมาชิกอื่นจองอยู่ กรุณาลองใหม่ภายหลัง';
  end if;
  insert into public.mars_mlc_parcel_reservations(parcel_id,user_id,expires_at)
  values(p_parcel_id,u,now()+interval '15 minutes')
  on conflict(parcel_id) do update set user_id=excluded.user_id,
    expires_at=excluded.expires_at,created_at=now();
  return jsonb_build_object('ok',true,'parcel_id',p_parcel_id,
    'expires_at',now()+interval '15 minutes','hold_minutes',15);
end $$;

create or replace function public.mars_mlc_purchase_parcel(p_parcel_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); m public.mars_mlc_parcel_market%rowtype;
        r public.mars_mlc_parcel_reservations%rowtype; c public.world_claims%rowtype;
        v_balance bigint; v_seller uuid; v_tx text:=replace(gen_random_uuid()::text,'-','');
begin
  if u is null then raise exception 'กรุณาเข้าสู่ระบบก่อนซื้อแปลง'; end if;
  perform pg_advisory_xact_lock(hashtextextended('parcel:'||p_parcel_id,0));
  select * into m from public.mars_mlc_parcel_market where parcel_id=p_parcel_id for update;
  if not found or not m.is_listed then raise exception 'แปลงนี้ไม่ได้เปิดขาย'; end if;
  select * into r from public.mars_mlc_parcel_reservations where parcel_id=p_parcel_id for update;
  if not found or r.user_id<>u or r.expires_at<=now() then
    raise exception 'กรุณาจองแปลงนี้ก่อน และดำเนินการภายใน 15 นาที';
  end if;
  select * into c from public.world_claims where parcel_id=p_parcel_id for update;
  if found then
    if c.owner_id=u then raise exception 'คุณเป็นเจ้าของแปลงนี้อยู่แล้ว'; end if;
    v_seller:=c.owner_id;
  end if;
  select coalesce(sum(amount),0) into v_balance from public.mars_wallet_ledger
    where user_id=u and resource='mlc';
  if v_balance<m.price_mlc then raise exception 'MLC ไม่เพียงพอ ต้องใช้ % MLC',m.price_mlc; end if;

  insert into public.mars_wallet_ledger(user_id,idempotency_key,resource,amount,reason)
    values(u,'mlc:parcel-buy:'||v_tx,'mlc',-m.price_mlc,'Parcel purchase: '||p_parcel_id);
  if v_seller is not null then
    insert into public.mars_wallet_ledger(user_id,idempotency_key,resource,amount,reason)
      values(v_seller,'mlc:parcel-sale:'||v_tx,'mlc',m.price_mlc,'Parcel sold: '||p_parcel_id);
    update public.world_claims set owner_id=u,claimed_at=now() where parcel_id=p_parcel_id;
  else
    insert into public.world_claims(parcel_id,owner_id) values(p_parcel_id,u);
  end if;
  update public.mars_mlc_parcel_market set is_listed=false,updated_at=now() where parcel_id=p_parcel_id;
  delete from public.mars_mlc_parcel_reservations where parcel_id=p_parcel_id;
  insert into public.world_events(actor_id,event_type,parcel_id,payload)
    values(u,case when v_seller is null then 'mlc_parcel_purchased' else 'mlc_parcel_traded' end,
      p_parcel_id,jsonb_build_object('price_mlc',m.price_mlc,'seller_id',v_seller));
  return jsonb_build_object('ok',true,'parcel_id',p_parcel_id,'price_mlc',m.price_mlc,
    'previous_owner',v_seller,'new_owner',u,'currency','MLC','demo_only',true);
end $$;

create or replace function public.mars_mlc_set_parcel_listing(
  p_parcel_id text,p_is_listed boolean,p_price_mlc integer default null
) returns jsonb language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); c public.world_claims%rowtype;
begin
  if u is null then raise exception 'กรุณาเข้าสู่ระบบ'; end if;
  if p_is_listed and (p_price_mlc is null or p_price_mlc<1 or p_price_mlc>1000000) then
    raise exception 'ราคาขายต้องอยู่ระหว่าง 1 ถึง 1,000,000 MLC';
  end if;
  perform 1 from public.mars_mlc_parcel_market where parcel_id=p_parcel_id for update;
  if not found then raise exception 'ไม่พบข้อมูลตลาดของแปลงนี้'; end if;
  select * into c from public.world_claims where parcel_id=p_parcel_id for update;
  if not found or c.owner_id<>u then raise exception 'เฉพาะเจ้าของแปลงเท่านั้นที่จัดการประกาศขายได้'; end if;
  update public.mars_mlc_parcel_market set is_listed=p_is_listed,
    price_mlc=case when p_is_listed then p_price_mlc else price_mlc end,
    updated_at=now() where parcel_id=p_parcel_id;
  if not found then raise exception 'ไม่พบข้อมูลตลาดของแปลงนี้'; end if;
  if not p_is_listed then
    delete from public.mars_mlc_parcel_reservations where parcel_id=p_parcel_id;
  end if;
  return jsonb_build_object('ok',true,'parcel_id',p_parcel_id,'is_listed',p_is_listed,
    'price_mlc',case when p_is_listed then p_price_mlc else null end);
end $$;

revoke all on function public.mars_mlc_sync_claim_market() from public,anon,authenticated;
revoke all on function public.mars_mlc_reserve_parcel(text) from public,anon;
revoke all on function public.mars_mlc_purchase_parcel(text) from public,anon;
revoke all on function public.mars_mlc_set_parcel_listing(text,boolean,integer) from public,anon;
grant execute on function public.mars_mlc_reserve_parcel(text) to authenticated;
grant execute on function public.mars_mlc_purchase_parcel(text) to authenticated;
grant execute on function public.mars_mlc_set_parcel_listing(text,boolean,integer) to authenticated;

-- Broadcast listing changes to every connected LOCAL MARS client.
do $$ begin alter publication supabase_realtime add table public.mars_mlc_parcel_market; exception when duplicate_object then null; when undefined_object then null; end $$;
