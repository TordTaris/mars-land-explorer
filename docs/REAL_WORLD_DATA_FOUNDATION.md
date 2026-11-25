# LOCAL MARS — Real-World Data Foundation

## Purpose

Make LOCAL MARS capable of storing, displaying, updating and auditing information about the real world and observed Mars data without presenting simulation content as physical fact.

This foundation complements (and does not replace) the existing parcel, city, avatar, chat, climate telemetry, satellite catalogue, activity log and simulation tables.

## Reality model

Every record must declare one scope:

- `earth_real`: a claim about a real place, facility, business, event or physical object on Earth.
- `mars_observed`: an observation or measurement tied to a real Mars mission, instrument, satellite or scientific source.
- `mars_simulated`: a modeled or forecast state that is not itself a direct observation.
- `virtual_world`: member-created LOCAL MARS content such as avatars, virtual buildings and game events.

A virtual parcel claim, avatar location, simulated greenhouse reading or generated building is never proof of physical ownership, a real facility or a real environmental measurement.

## Data lifecycle

1. **Ingest** — use an explicitly configured public API, official open-data feed, sensor integration or member submission.
2. **Preserve provenance** — store source identity, canonical source URL, source update time, observation time, fetch time, coordinate reference system, license/attribution and external identifier.
3. **Validate** — validate schema, coordinate ranges, timestamp, source identity, duplicate keys and payload shape.
4. **Verify** — only trusted server-side importers or authorized verification workflows may set `verification_status = verified`, `verified_at` and public visibility.
5. **Publish** — public clients can read only records marked both verified and public.
6. **Refresh / expire** — stale or expired feeds must be marked stale rather than silently shown as current.
7. **Audit** — retain evidence references and content hashes where available; do not overwrite source history without traceability.

## Database foundation

Migration `021_real_world_data_provenance.sql` adds:

- `world_data_sources`: curated source catalogue, license and attribution metadata.
- `world_data_records`: scope-aware facts, coordinates, observation timestamps, confidence, verification state and source linkage.
- `world_data_evidence`: evidence references and optional SHA-256 digests.

Member-submitted rows are pending, private to their submitter and immutable to browser clients. Public clients only see verified public records. Verification and trusted imports must be performed by a server-side process using protected credentials. Never expose a Supabase service-role or secret key in browser code.

## Realtime and client behaviour

The records table is added to the existing Supabase Realtime publication when it exists. Clients should subscribe to narrowly scoped, RLS-protected changes, show connection and last-sync status, and always be able to reload the current snapshot after reconnecting. Realtime is a notification mechanism, not the source of truth; Postgres remains authoritative.

## Source adapters to implement next

Start with sources that provide stable, attributable public data and do not require paid API keys:

- NASA public APIs and mission datasets for Mars observations and imagery.
- USGS public feeds for earthquakes and geological events on Earth.
- OpenStreetMap data with required ODbL attribution for mapped Earth places.
- NOAA public datasets for weather and climate observations.

Each adapter must document endpoint, terms/license, rate limits, update cadence, fields mapped, validation rules and failure behaviour before it is enabled. Never scrape private social accounts, bypass login, or store account passwords. Do not activate a source merely because a URL exists.

## Security and quality gates

- RLS enabled on every exposed table; explicit grants are required because Supabase Data API exposure is no longer automatic.
- No browser-side service-role key.
- No client policy can create a verified record or change verification fields.
- Member submissions cannot become public until server-side verification.
- Use UTC timestamps and explicit coordinate reference systems.
- Preserve original source timestamps and source identifiers.
- Treat imported text and metadata as untrusted data.
- Keep payment, MLC, land-claim and virtual economy records separate from physical-world ownership or legal title.

## Deployment status

This PR proposes an additive schema migration and architecture documentation. It does not apply the migration to the production Supabase database and does not activate external source adapters. Those steps require schema review, staging tests, security-advisor review and an explicit production rollout.
