#!/usr/bin/env bash
# Scans source code (not just manifests) for direct calls into specific
# cloud/vendor SDKs — i.e. code that would need to be rewritten, not just
# reconfigured, to move off a given provider.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/scan-common.sh
source "$SCRIPT_DIR/lib/scan-common.sh"

ROOT="${1:-.}"
BASENAME="${2:-cloud-sdk-audit}"
TXT="$BASENAME.txt"
JSON="$BASENAME.json"

cd "$ROOT" || exit 1

CODE_INCLUDES=(
  --include='*.py' --include='*.js' --include='*.jsx' --include='*.ts'
  --include='*.tsx' --include='*.go' --include='*.java' --include='*.rb'
  --include='*.cs' --include='*.rs' --include='*.php'
)

scan_init "Cloud and vendor SDK usage audit" "$(pwd)" "$TXT" "$JSON"

scan_run \
  "AWS SDK usage" \
  'boto3|aws-sdk|@aws-sdk/|aws_sdk|Amazon\.[A-Z][A-Za-z]+|com\.amazonaws' \
  "${CODE_INCLUDES[@]}" .

scan_run \
  "Azure SDK usage" \
  '@azure/|azure-storage|azure-identity|azure\.mgmt|azure\.identity|Microsoft\.Azure' \
  "${CODE_INCLUDES[@]}" .

scan_run \
  "Google Cloud SDK usage" \
  '@google-cloud/|google-cloud-|googleapis|google\.cloud\.|cloud\.google\.com/go|firebase-admin|firebase/app' \
  "${CODE_INCLUDES[@]}" .

scan_run \
  "Other proprietary/hosted-service SDKs (Stripe, Twilio, SendGrid, OpenAI, Auth0, Okta, Sentry, Datadog)" \
  'stripe|twilio|sendgrid|openai|auth0|okta|@sentry/|sentry-sdk|datadog|dd-trace' \
  "${CODE_INCLUDES[@]}" .

scan_finalize
