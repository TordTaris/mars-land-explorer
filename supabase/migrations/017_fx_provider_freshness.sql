-- LOCAL MARS 017: FX provider freshness metadata.
begin;
alter table public.mars_fx_rates
  add column if not exists provider_updated_at timestamptz,
  add column if not exists provider_next_update_at timestamptz,
  add column if not exists provider_payload_date date;
comment on column public.mars_fx_rates.provider_updated_at is
  'Timestamp supplied by the FX provider; distinct from the date this row was ingested.';
comment on column public.mars_fx_rates.provider_next_update_at is
  'Provider-supplied next refresh time; reference rates must not be described as tick/live prices.';
commit;
