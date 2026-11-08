# LOCAL MARS — Mars Data Integration Layer

## Purpose
Discover real, already-published Mars science data and make it usable by LOCAL MARS with traceable provenance. This connector does not command spacecraft, collect new observations, or represent archive products as live telemetry.

## Current implementation
- `mars-data.html`: mobile-friendly data observatory and official archive catalogue.
- `mars-data.js`: browser-side metadata search against the documented NASA PDS Search API (`https://pds.nasa.gov/api/search/1/products`) using the documented `keywords` and `limit` parameters.
- The page renders returned metadata as text only (no HTML injection), reports API/network failures honestly, and never substitutes synthetic records.
- Sources: MOLA MEGDR, THEMIS global mosaics, Mars Express HRSC, and MRO CTX/HiRISE/SHARAD archives.

## Data model required before persistence
Each ingested item must preserve:
- source agency, archive node, mission, spacecraft and instrument
- PDS LID/LIDVID or original product identifier
- acquisition start/stop time (UTC)
- original file URL, checksum and product label
- coordinate reference / map projection and spatial footprint
- pixel scale, units, processing level, calibration and quality flags
- license/access terms, citation, retrieval timestamp
- uncertainty and a provenance class: `published_observation`, `derived_product`, `interpretation`, or `synthetic_simulation`

## Staged integration
1. Discover metadata through PDS Search API and mission archives.
2. Validate labels, identifiers, time, projection, units, processing and quality.
3. Ingest product metadata and footprints into a staging catalogue (not production parcel tables).
4. Process selected public raster products into documented GIS derivatives.
5. Publish map layers only after QA, attribution, uncertainty and access review.

## Known limitations
- PDS API documentation warns that its registry is not fully populated; some valid archive datasets may be absent or return 404.
- Browser fetch may be blocked by CORS/network policy; the page exposes this failure and retains direct archive links.
- This initial increment is metadata discovery only. It does not download bulk imagery, build a full global mosaic, write Supabase records, or change the production map.
- MOLA is a historical global topography product; THEMIS/HRSC/CTX/HiRISE coverage and resolution vary by product and footprint.

## Official references
- NASA PDS Search API: https://nasa-pds.github.io/pds-api/guides/search/endpoints.html
- PDS MOLA MEGDR: https://pds-geosciences.wustl.edu/missions/mgs/megdr.html
- ASU THEMIS global datasets: https://www.mars.asu.edu/data/
- PDS Mars Express HRSC: https://pds-geosciences.wustl.edu/missions/mars_express/hrsc.htm
- PDS MRO: https://pds-geosciences.wustl.edu/missions/mro/
