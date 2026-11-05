#!/usr/bin/env bash
set -euo pipefail

# Build the same static LOCAL MARS artifact used by the GitHub Pages workflow.
rm -rf _site
mkdir -p _site

cp index.html install.html city.html underground.html mission-trainer.html \
  m003-base.html m003-dimension-gate.html top-secret-demo.html civilization.html \
  i18n.js premium-ui.css world-server.js multiverse.js easy-play.js \
  manifest.webmanifest sw.js icon.svg _site/

cp -R locales _site/locales
cp -R parcels _site/parcels
touch _site/.nojekyll

# Fail the Cloudflare build if key app entry points or locale assets are missing.
test -s _site/index.html
test -s _site/install.html
test -s _site/locales/th.json
test -s _site/locales/en.json
test -s _site/mission-trainer.html
test -s _site/m003-base.html
test -s _site/m003-dimension-gate.html
test -s _site/parcels/M-001/index.html
test -s _site/parcels/M-012/index.html

echo "LOCAL MARS static site prepared in _site/"
