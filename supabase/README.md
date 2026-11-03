# MARS LAND — Online World Backend

This repository contains the Supabase database schema for the shared MARS LAND world.

## Setup
1. Create a Supabase project.
2. Open **SQL Editor** in the Supabase dashboard.
3. Run the complete contents of `schema.sql`.
4. In **Project Settings → API**, copy the Project URL and anon/public key.
5. Add those values to the web app configuration. Never put a service-role key in browser code.

## Included tables
- `profiles`: member display profiles linked to Supabase Auth.
- `land_plots`: shared virtual parcels on Mars.
- `structures`: member-built habitats, labs, solar farms, greenhouses, roads.
- `marketplace_listings`: virtual parcel listings.

Row Level Security keeps profile edits, owned-plot edits, structures, and listings tied to the signed-in user. Public read access allows visitors to see the shared world.

## Important
The seeded parcels are game/demo assets only. They do not represent legal ownership of real land on Mars. Real-time sync is enabled for plots, structures, and listings. The frontend still needs the Supabase project URL and public anon key before cloud sync and sign-in can run.
