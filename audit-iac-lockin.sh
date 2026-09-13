#!/usr/bin/env bash
# Scans Infrastructure-as-Code (Terraform, CloudFormation, ARM/Bicep, Pulumi,
# Kubernetes manifests) for vendor-specific resource types and providers —
# the parts of an IaC codebase that don't port between clouds.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/scan-common.sh
source "$SCRIPT_DIR/lib/scan-common.sh"

ROOT="${1:-.}"
BASENAME="${2:-iac-lockin-audit}"
TXT="$BASENAME.txt"
JSON="$BASENAME.json"

cd "$ROOT" || exit 1

IAC_INCLUDES=(
  --include='*.tf' --include='*.tf.json' --include='*.yaml' --include='*.yml'
  --include='*.json' --include='*.bicep' --include='*.jsonnet'
)

scan_init "Infrastructure-as-Code vendor lock-in audit" "$(pwd)" "$TXT" "$JSON"

scan_run \
  "Terraform vendor-specific providers" \
  'provider[[:space:]]*"(aws|azurerm|google|google-beta|oci|alicloud)"' \
  --include='*.tf' .

scan_run \
  "Terraform vendor-specific resources" \
  'resource[[:space:]]+"(aws|azurerm|google|oci|alicloud)_[a-zA-Z0-9_]+"' \
  --include='*.tf' .

scan_run \
  "CloudFormation vendor resource types" \
  'AWS::[A-Za-z0-9]+::[A-Za-z0-9]+' \
  --include='*.yaml' --include='*.yml' --include='*.json' .

scan_run \
  "Azure ARM/Bicep resource types" \
  'Microsoft\.[A-Za-z]+/[A-Za-z]+' \
  --include='*.json' --include='*.bicep' .

scan_run \
  "Pulumi vendor-specific providers" \
  '@pulumi/(aws|azure|azure-native|gcp|google-native)|pulumi_(aws|azure|gcp)' \
  "${IAC_INCLUDES[@]}" --include='*.py' --include='*.go' --include='*.ts' --include='*.js' .

scan_run \
  "Cloud-managed Kubernetes annotations/CRDs" \
  'eks\.amazonaws\.com|aks\.azure\.com|gke\.io|cloud\.google\.com/|iam\.amazonaws\.com' \
  --include='*.yaml' --include='*.yml' .

scan_finalize
