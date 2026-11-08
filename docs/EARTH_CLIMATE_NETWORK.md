# Earth Climate Network — LOCAL MARS

## Purpose
Provide a read-only Earth weather/climate reference feed for scientific comparison with LOCAL MARS habitat and Mars-atmosphere simulations. This is not a weather-modification control system.

## Data providers
- Open-Meteo Forecast API: current model conditions and up to 7 days of forecast for a WGS84 coordinate. The provider combines numerical weather-model outputs; current conditions are model-derived, not a direct local sensor reading. API: https://open-meteo.com/en/docs
- NASA POWER Daily Point API: satellite-derived/analysis-ready meteorological reference parameters (T2M, PRECTOTCORR, RH2M, WS2M). Daily data are delayed and should not be described as live telemetry. Docs: https://power.larc.nasa.gov/api/pages/

## Implementation
- `earth-climate.html`: mobile-friendly Earth climate dashboard, coordinate input, current conditions, 7-day forecast and recent NASA POWER daily reference.
- `earth-climate.js`: direct read-only API requests, validation of coordinates, safe DOM text rendering, explicit unavailable states and no fabricated fallback values.
- Default sample coordinates are Bangkok (13.7563, 100.5018), editable by the user.
- No credentials or API keys are embedded.

## Data integrity
Store provider, query coordinates, provider timestamp, timezone, variable, unit, model/archive designation, retrieval time and any quality/uncertainty metadata with future persisted records. Keep model forecasts, satellite-derived analysis and in-situ observations as distinct provenance classes.

## Safety and authorization boundary
This page does not seed clouds, disperse substances, release aerosols, control aircraft/satellites, steer storms or alter atmospheric processes. No operational weather-modification interface or actuator is implemented. Any field activity must be separately authorized by the relevant competent authority and undergo independent scientific, environmental and legal review.

WMO notes that weather modification is generally local/regional and that claims of large-scale weather control lack a sound scientific basis. NOAA states it does not modify weather or conduct cloud seeding. References:
- https://public.wmo.int/content/wmo-statement-weather-modification
- https://www.noaa.gov/news/fact-check-debunking-weather-modification-claims
