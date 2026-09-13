#!/usr/bin/env bash
# Shared helpers for the audit-*.sh scripts in this repo.
# Source this file; do not execute it directly.
#
# Provides:
#   scan_init TITLE ROOT TXT_FILE JSON_FILE   - reset/open the report files
#   scan_section TITLE                        - print a banner section header
#   scan_run TITLE PATTERN [grep-args...]     - grep for PATTERN, record to
#                                                 both the text and JSON report
#   scan_finalize                             - assemble the final JSON report
#
# PATTERN is an extended-regex (grep -E) alternation. Trailing arguments are
# passed straight to grep (e.g. --include='*.py' paths...); default path is
# the scan root when none is given.
#
# JSON output is skipped (with a warning) if `jq` is not installed; the text
# report is always produced.

set -uo pipefail

HAVE_JQ=0
if command -v jq >/dev/null 2>&1; then
  HAVE_JQ=1
fi

_SCAN_EXCLUDES=(
  --exclude-dir=.git
  --exclude-dir=node_modules
  --exclude-dir=venv
  --exclude-dir=.venv
  --exclude-dir=dist
  --exclude-dir=build
)

scan_init() {
  local title="$1" root="$2" txt="$3" json="$4"
  SCAN_TITLE="$title"
  SCAN_ROOT="$root"
  TXT_FILE="$txt"
  JSON_FILE="$json"
  JSONL_TMP="$(mktemp)"

  : > "$TXT_FILE"
  {
    echo "$SCAN_TITLE"
    echo "Repository: $SCAN_ROOT"
    echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  } | tee -a "$TXT_FILE"

  if [ "$HAVE_JQ" -ne 1 ]; then
    echo "Note: 'jq' not found — JSON report ($JSON_FILE) will not be generated." | tee -a "$TXT_FILE"
  fi
}

scan_section() {
  {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
  } | tee -a "$TXT_FILE"
}

# scan_run TITLE PATTERN [grep-args-and-paths...]
scan_run() {
  local title="$1" pattern="$2"
  shift 2

  scan_section "$title"

  local matches
  matches="$(grep -RInE "${_SCAN_EXCLUDES[@]}" "$pattern" "$@" 2>/dev/null || true)"

  if [ -n "$matches" ]; then
    echo "$matches" | tee -a "$TXT_FILE"
  else
    echo "No matches found." | tee -a "$TXT_FILE"
  fi

  if [ "$HAVE_JQ" -eq 1 ]; then
    local sec_json
    if [ -n "$matches" ]; then
      sec_json="$(printf '%s\n' "$matches" | jq -R -s --arg title "$title" --arg pattern "$pattern" '
        split("\n") | map(select(length > 0))
        | map(capture("^(?<file>[^:]+):(?<line>[0-9]+):(?<content>.*)$")? // {file: ., line: null, content: .})
        | {title: $title, pattern: $pattern, match_count: length, matches: .}
      ')"
    else
      sec_json="$(jq -n --arg title "$title" --arg pattern "$pattern" \
        '{title: $title, pattern: $pattern, match_count: 0, matches: []}')"
    fi
    echo "$sec_json" >> "$JSONL_TMP"
  fi
}

# scan_add_json_section <json-object-as-string>
# Lets a script inject a pre-built JSON section (e.g. from syft output)
# instead of one produced by scan_run.
scan_add_json_section() {
  if [ "$HAVE_JQ" -eq 1 ]; then
    printf '%s\n' "$1" >> "$JSONL_TMP"
  fi
}

scan_finalize() {
  if [ "$HAVE_JQ" -eq 1 ]; then
    jq -s --arg repo "$SCAN_ROOT" --arg title "$SCAN_TITLE" --arg date "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      '{title: $title, repository: $repo, generated_at: $date, sections: .}' \
      "$JSONL_TMP" > "$JSON_FILE"
    rm -f "$JSONL_TMP"
  fi
  echo
  echo "Text report:  $TXT_FILE"
  if [ "$HAVE_JQ" -eq 1 ]; then
    echo "JSON report:  $JSON_FILE"
  fi
}
