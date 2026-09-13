#!/usr/bin/env bash
# Scans CI/CD configs, app configs, and env files for references to hosted
# SaaS products (observability, data/infra, comms/marketing, auth, hosting)
# that create operational or contractual lock-in even without any code-level
# SDK usage.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/scan-common.sh
source "$SCRIPT_DIR/lib/scan-common.sh"

ROOT="${1:-.}"
BASENAME="${2:-saas-audit}"
TXT="$BASENAME.txt"
JSON="$BASENAME.json"

cd "$ROOT" || exit 1

scan_init "SaaS and hosted-service dependency audit" "$(pwd)" "$TXT" "$JSON"

scan_run \
  "Hosted CI/CD" \
  'circleci|travis-ci|buildkite|codeship|appveyor|drone\.io' \
  .

scan_run \
  "Observability / monitoring SaaS" \
  'sentry|datadog|newrelic|new relic|pagerduty|honeycomb\.io|rollbar|bugsnag' \
  .

scan_run \
  "Data / infra SaaS" \
  'snowflake|mongodb[[:space:]]*atlas|planetscale|supabase|firebase|redis(labs|cloud)|elastic\.co|algolia' \
  .

scan_run \
  "Communication / marketing SaaS" \
  'twilio|sendgrid|mailchimp|segment\.com|mixpanel|amplitude|intercom|zendesk' \
  .

scan_run \
  "Auth / identity SaaS" \
  'auth0|okta|onelogin|clerk\.dev|workos' \
  .

scan_run \
  "Hosting / CDN / PaaS" \
  'vercel|netlify|heroku|cloudflare|fastly|render\.com|railway\.app' \
  .

scan_finalize
