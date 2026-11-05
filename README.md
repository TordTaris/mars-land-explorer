# LOCAL MARS 4.0 — Planetary Civilization Network

LOCAL MARS is a browser-based planetary settlement simulation published as a static site through GitHub Pages.

- Live site: https://tordtaris.github.io/mars-land-explorer/
- Repository: https://github.com/TordTaris/mars-land-explorer
- Production branch: `main`
- Release line: `4.0`

## Release 4.0 deployment hardening

This release corrects the GitHub Pages artifact so it includes the complete application shell, not only the three primary HTML pages. The deployment now validates and publishes:

- Planet Explorer (`index.html`)
- City Builder (`city.html`)
- Underground Base 24 (`underground.html`)
- M-003 private facility page (`m003-base.html`)
- Civilization page (`civilization.html`)
- Shared online client (`world-server.js`)
- Thai and English dictionaries (`locales/th.json`, `locales/en.json`) and language engine (`i18n.js`)
- PWA manifest, icon and versioned service worker

The workflow runs asset checks and JavaScript syntax checks before publishing. A failed validation stops deployment rather than publishing an incomplete artifact.

## Systems and currency boundaries

- THB is a reference/display currency for the separate PromptPay checkout flow. The current configured display multiplier is 1.8x; it is not an exchange rate or a promise of monetary value.
- MLC is a separate closed-loop simulated in-app currency for parcel reservations, purchases and member-to-member marketplace activity.
- MLC is not THB, ETH, cryptocurrency, cash, a deposit, or a redeemable financial asset.
- Parcel ownership and construction are simulation records, not legal ownership of land on Mars.
- M-003 and the 24-level underground facility are fictional simulation features.

## GitHub Pages deployment

Every push to `main`, and manual workflow dispatch, runs:

1. Required route, localization, PWA and asset validation.
2. JavaScript syntax checks for the main explorer, city builder, underground simulator, language engine, world server and service worker.
3. Complete static artifact assembly, including localization files and the M-003/civilization pages.
4. Deployment to GitHub Pages.

Check [GitHub Actions](https://github.com/TordTaris/mars-land-explorer/actions). The release is live only after **Deploy LOCAL MARS to GitHub Pages** finishes with a successful status.

## Online services — setup still required

The static GitHub Pages deployment does not itself run PostgreSQL or enable Supabase. Shared accounts, realtime world sync, wallet ledger and MLC marketplace operations require the Supabase schema/migrations and correct project configuration to be applied in the Supabase project.

See [WORLD_SERVER_SETUP_TH.md](./WORLD_SERVER_SETUP_TH.md). Never put a Supabase `service_role` key or database password in browser code.

## Underground Base 24 safety note

The underground base is a fictional educational simulation. Resource readings and life-support controls are illustrative only and are not engineering specifications or evidence of real-world habitability.
