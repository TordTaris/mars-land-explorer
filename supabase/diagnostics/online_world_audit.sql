-- LOCAL MARS / LOCAL MARS — READ-ONLY Supabase audit
-- Run this ONE file in Supabase SQL Editor for the Marslocal project.
-- It does not create, alter, delete, or update anything and does not expose secrets.
-- IMPORTANT: Do not run every file in supabase/migrations blindly. The repository
-- contains historical migration branches with duplicate numbers and legacy ETH/USD steps.
with
expected_tables(name, purpose) as (
  values
    ('world_parcels','planet parcel catalogue'),
    ('world_claims','current parcel ownership'),
    ('world_structures','shared parcel construction'),
    ('world_events','world activity feed'),
    ('mars_profiles','member profile'),
    ('mars_wallet_ledger','wallet ledger including MLC'),
    ('mars_mlc_parcel_market','MLC parcel market'),
    ('mars_mlc_parcel_reservations','temporary MLC reservations'),
    ('mars_cities','shared city records'),
    ('mars_city_buildings','shared city construction'),
    ('mars_city_national_flags','one national flag per member'),
    ('m003_private_base','private M-003 underground base'),
    ('mars_parcel_orders','THB checkout orders')
),
expected_functions(name, identity_args, purpose) as (
  values
    ('mars_wallet_balances','','member wallet balances'),
    ('mars_wallet_mlc_grant_starter','','one-time MLC starter grant'),
    ('mars_wallet_mlc_transfer','p_recipient uuid, p_amount integer, p_idempotency_key text','MLC member transfer'),
    ('mars_mlc_reserve_parcel','p_parcel_id text','temporary MLC parcel reservation'),
    ('mars_mlc_purchase_parcel','p_parcel_id text','MLC parcel purchase/trade'),
    ('mars_mlc_set_parcel_listing','p_parcel_id text, p_is_listed boolean, p_price_mlc integer','owner parcel listing control'),
    ('build_world_structure','p_parcel_id text, p_type text','shared parcel construction'),
    ('mars_city_place_structure','p_type text, p_x double precision, p_z double precision, p_level integer','shared city simulator construction')
),
expected_columns(table_name, column_name, purpose) as (
  values
    ('world_parcels','sale_price_thb','THB reference sale price'),
    ('world_parcels','is_for_sale','THB sale switch'),
    ('mars_wallet_ledger','resource','wallet currency/resource discriminator'),
    ('mars_mlc_parcel_market','price_mlc','MLC market price'),
    ('mars_mlc_parcel_market','is_listed','market listing state'),
    ('mars_parcel_orders','amount_satang','THB checkout amount in satang'),
    ('mars_parcel_orders','expires_at','checkout expiry')
),
table_checks as (
  select 'TABLE'::text as category, e.name as object_name,
         case when c.oid is null then 'MISSING' else 'OK' end as status,
         e.purpose ||
         case when c.oid is null then '' else
           '; RLS=' || case when c.relrowsecurity then 'ON' else 'OFF' end
         end as details
  from expected_tables e
  left join pg_class c on c.relname=e.name and c.relnamespace='public'::regnamespace
       and c.relkind in ('r','p','v')
),
column_checks as (
  select 'COLUMN'::text, e.table_name||'.'||e.column_name,
         case when a.attnum is null then 'MISSING' else 'OK' end,
         e.purpose
  from expected_columns e
  left join pg_class c on c.relname=e.table_name and c.relnamespace='public'::regnamespace
  left join pg_attribute a on a.attrelid=c.oid and a.attname=e.column_name
       and a.attnum>0 and not a.attisdropped
),
function_checks as (
  select 'FUNCTION'::text, e.name||'('||e.identity_args||')',
         case when p.oid is null then 'MISSING' else 'OK' end,
         e.purpose
  from expected_functions e
  left join pg_proc p on p.proname=e.name and p.pronamespace='public'::regnamespace
       and pg_get_function_identity_arguments(p.oid)=e.identity_args
),
realtime_checks as (
  select 'REALTIME'::text, e.name,
         case when pt.tablename is null then 'NOT_ENABLED' else 'OK' end,
         'Supabase Realtime publication membership'
  from (values
    ('world_claims'),('world_structures'),('world_events'),
    ('mars_city_national_flags'),('mars_city_buildings')
  ) e(name)
  left join pg_publication_tables pt
    on pt.pubname='supabase_realtime' and pt.schemaname='public' and pt.tablename=e.name
),
wallet_check as (
  select 'WALLET_CHECK'::text, 'mars_wallet_ledger.resource includes mlc',
    case when exists (
      select 1 from pg_constraint con
      join pg_class c on c.oid=con.conrelid
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname='mars_wallet_ledger'
        and con.contype='c' and pg_get_constraintdef(con.oid) ilike '%mlc%'
    ) then 'OK' else 'CHECK' end,
    'Confirms the wallet resource CHECK constraint permits MLC'
),
migration_check as (
  select 'MIGRATIONS'::text, 'supabase_migrations.schema_migrations',
    case when to_regclass('supabase_migrations.schema_migrations') is null then 'INFO'
         else 'PRESENT' end,
    case when to_regclass('supabase_migrations.schema_migrations') is null
         then 'No CLI migration history table; normal when SQL was run manually in Supabase SQL Editor. Not an app schema failure.'
         else 'CLI migration history table exists'
    end
)
select * from table_checks
union all select * from column_checks
union all select * from function_checks
union all select * from realtime_checks
union all select * from wallet_check
union all select * from migration_check
order by 1,2;
