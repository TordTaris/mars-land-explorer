-- Remove the one-time M-001 10,000 MLC claim endpoint.
-- Existing wallet ledger entries and balances are intentionally preserved.
revoke all on function public.mars_wallet_mlc_claim_m001_allocation() from public;
revoke all on function public.mars_wallet_mlc_claim_m001_allocation() from anon;
revoke all on function public.mars_wallet_mlc_claim_m001_allocation() from authenticated;
drop function if exists public.mars_wallet_mlc_claim_m001_allocation();
