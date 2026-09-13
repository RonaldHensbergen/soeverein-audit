#!/usr/bin/env bash
set -uo pipefail

ROOT="${1:-.}"
REPORT="${2:-dependency-audit.txt}"

cd "$ROOT" || exit 1

: > "$REPORT"

section() {
  {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
  } | tee -a "$REPORT"
}

run_scan() {
  local title="$1"
  local pattern="$2"
  shift 2

  section "$title"

  if grep -RInI \
      --exclude-dir=.git \
      --exclude-dir=node_modules \
      --exclude-dir=venv \
      --exclude-dir=.venv \
      --exclude-dir=dist \
      --exclude-dir=build \
      "$pattern" "$@" 2>/dev/null | tee -a "$REPORT"; then
    :
  else
    echo "No matches found." | tee -a "$REPORT"
  fi
}

echo "Repository dependency and lock-in audit" | tee "$REPORT"
echo "Repository: $(pwd)" | tee -a "$REPORT"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "$REPORT"

section "Dependency manifests and lockfiles"

find . -type f \( \
  -name 'package.json' -o \
  -name 'package-lock.json' -o \
  -name 'yarn.lock' -o \
  -name 'pnpm-lock.yaml' -o \
  -name 'requirements*.txt' -o \
  -name 'pyproject.toml' -o \
  -name 'poetry.lock' -o \
  -name 'Pipfile*' -o \
  -name 'uv.lock' -o \
  -name 'go.mod' -o \
  -name 'go.sum' -o \
  -name 'Cargo.toml' -o \
  -name 'Cargo.lock' -o \
  -name 'pom.xml' -o \
  -name 'build.gradle*' -o \
  -name '*.csproj' -o \
  -name 'Gemfile*' -o \
  -name 'Dockerfile*' \
\) -print | sort | tee -a "$REPORT"

section "Docker base images"

if find . -type f -iname 'Dockerfile*' -print0 | \
    xargs -0 grep -HnE '^[[:space:]]*FROM[[:space:]]+' 2>/dev/null | \
    tee -a "$REPORT"; then
  :
else
  echo "No Docker base images found." | tee -a "$REPORT"
fi

run_scan \
  "External URLs and package sources" \
  'https?://|git\+|git@|--index-url|--extra-index-url|--find-links|registry'

run_scan \
  "Cloud, vendor, and hosted-service references" \
  'aws|amazon|azure|gcp|google[ -]?cloud|github|gitlab|bitbucket|docker|ghcr|quay|ecr|acr|gcr|sentry|datadog|snowflake|openai|copilot' \
  .

run_scan \
  "Potentially proprietary or restricted licensing terms" \
  'proprietary|commercial|source available|non-commercial|enterprise license|evaluation license|all rights reserved|closed source|license required' \
  .

run_scan \
  "GitHub Actions and hosted CI dependencies" \
  '^[[:space:]]*uses:|GITHUB_|github\.com|ghcr\.io|secrets\.|runs-on:' \
  .github

run_scan \
  "Runtime installation commands" \
  'pip[3]?[[:space:]]+install|npm[[:space:]]+install|yarn[[:space:]]+add|pnpm[[:space:]]+add|apt(-get)?[[:space:]]+install|apk[[:space:]]+add|brew[[:space:]]+install|curl.*install|wget.*install' \
  .

section "Potential private dependencies"

run_scan \
  "Private or nonstandard package sources" \
  'git\+ssh://|git@[^:]+:|private|internal|company|corp|artifactory|jfrog|nexus|verdaccio' \
  .

section "Summary"

cat <<'EOF' | tee -a "$REPORT"
Review each match and classify it as:

  [ ] Runtime dependency
  [ ] Development-only dependency
  [ ] CI/CD dependency
  [ ] Optional integration
  [ ] Documentation/example only
  [ ] False positive

For each real dependency, record:

  - Is it proprietary?
  - Is an account required?
  - Can it be self-hosted or replaced?
  - Is the protocol documented?
  - Can the project build without it?
  - Can users migrate their data away from it?
EOF

echo
echo "Audit written to: $REPORT"
