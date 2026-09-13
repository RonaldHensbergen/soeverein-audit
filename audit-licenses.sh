#!/usr/bin/env bash
# SBOM + license audit: flags dependencies with proprietary, restrictive, or
# unknown/missing licenses.
#
# If `syft` is installed, generates an SBOM and checks every discovered
# package's declared license against a list of non-permissive / restrictive
# license identifiers. Falls back to a manifest/LICENSE-file keyword scan
# when `syft` is not available (or in addition, for licensing terms that
# don't show up in machine-readable SBOM metadata, e.g. custom EULAs).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/scan-common.sh
source "$SCRIPT_DIR/lib/scan-common.sh"

ROOT="${1:-.}"
BASENAME="${2:-license-audit}"
TXT="$BASENAME.txt"
JSON="$BASENAME.json"

cd "$ROOT" || exit 1
ROOT_ABS="$(pwd)"

scan_init "SBOM and license audit" "$ROOT_ABS" "$TXT" "$JSON"

# --- Restrictive/non-permissive license identifiers to flag ---------------
# (Non-OSI/"source available" or copyleft-with-commercial-strings licenses
# that typically require legal review before use in a commercial product.)
RESTRICTIVE_RE='SSPL|BUSL|Business[[:space:]]*Source[[:space:]]*License|Elastic[[:space:]]*License|Confluent[[:space:]]*Community[[:space:]]*License|Server[[:space:]]*Side[[:space:]]*Public[[:space:]]*License|Commons[[:space:]]*Clause|Prosperity[[:space:]]*Public[[:space:]]*License|proprietary|commercial[[:space:]]*license|source[[:space:]]*available|non-commercial|enterprise[[:space:]]*license|evaluation[[:space:]]*license|all[[:space:]]*rights[[:space:]]*reserved|closed[[:space:]]*source|license[[:space:]]*required'

if command -v syft >/dev/null 2>&1; then
  scan_section "SBOM package licenses (via syft)"

  SBOM_JSON="$(mktemp)"
  if syft "dir:$ROOT_ABS" -o json > "$SBOM_JSON" 2>/dev/null; then
    FLAGGED="$(jq -r --arg re "$RESTRICTIVE_RE" '
      [.artifacts[]? | {
        name: .name,
        version: .version,
        type: .type,
        licenses: [.licenses[]? | (.value // .spdxExpression // .)]
      }]
      | map(select(
          (.licenses | length == 0)
          or (.licenses | any(test($re; "ix")))
        ))
    ' "$SBOM_JSON" 2>/dev/null)"

    COUNT="$(echo "${FLAGGED:-[]}" | jq 'length' 2>/dev/null || echo 0)"
    if [ "${COUNT:-0}" -gt 0 ]; then
      echo "$FLAGGED" | jq -r '.[] | "\(.name)@\(.version // "?") (\(.type)): licenses=\(.licenses | join(", ") // "NONE")"' \
        | tee -a "$TXT"
    else
      echo "No packages with missing or restrictive licenses found." | tee -a "$TXT"
    fi

    TOTAL_PKGS="$(jq '.artifacts | length' "$SBOM_JSON" 2>/dev/null || echo 0)"
    {
      echo
      echo "Total packages scanned: $TOTAL_PKGS"
    } | tee -a "$TXT"

    if [ "$HAVE_JQ" -eq 1 ]; then
      SEC_JSON="$(jq -n --argjson flagged "${FLAGGED:-[]}" --argjson total "${TOTAL_PKGS:-0}" \
        '{title: "SBOM package licenses (via syft)", total_packages: $total, flagged_count: ($flagged | length), flagged_packages: $flagged}')"
      scan_add_json_section "$SEC_JSON"
    fi
  else
    echo "syft failed to generate an SBOM for this path." | tee -a "$TXT"
  fi
  rm -f "$SBOM_JSON"
else
  {
    echo "syft not found — skipping machine-readable SBOM license check."
    echo "Install from https://github.com/anchore/syft for package-level license data."
  } | tee -a "$TXT"
fi

scan_run \
  "Restrictive/proprietary license keywords in repo text" \
  "$RESTRICTIVE_RE" \
  .

scan_section "LICENSE files present"
LICENSE_FILES="$(find . -type f \( -iname 'license*' -o -iname 'copying*' -o -iname 'eula*' \) \
  -not -path '*/.git/*' -not -path '*/node_modules/*' | sort)"
if [ -n "$LICENSE_FILES" ]; then
  echo "$LICENSE_FILES" | tee -a "$TXT"
else
  echo "No LICENSE/COPYING/EULA files found." | tee -a "$TXT"
fi
if [ "$HAVE_JQ" -eq 1 ]; then
  FILES_JSON="$(printf '%s\n' "$LICENSE_FILES" | jq -R -s 'split("\n") | map(select(length > 0))')"
  SEC_JSON="$(jq -n --argjson files "$FILES_JSON" '{title: "LICENSE files present", files: $files}')"
  scan_add_json_section "$SEC_JSON"
fi

scan_finalize
