-- LOCAL MARS: update the shared M-003 parcel value.
-- Safe to run more than once; affects only parcel M-003.
update public.land_plots
set price_mlc = 9999999,
    updated_at = now()
where id = 'M-003';
