#!/usr/bin/env bash
# Validate local tooling, Azure authentication, subscriptions, and config before deployment.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/preflight.sh --iac terraform|bicep --mode single|multi [options]

Options:
  --config PATH              Terraform tfvars or single-sub Bicep parameter file
  --subscription GUID        Single-subscription target
  --connectivity-sub GUID    Multi-sub connectivity subscription
  --management-sub GUID      Multi-sub management subscription
  --landingzone-sub GUID     Multi-sub landing-zone subscription
EOF
}

IAC=""
MODE=""
CONFIG=""
SUBSCRIPTION=""
CONN_SUB=""
MGMT_SUB=""
LZ_SUB=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iac) IAC="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --subscription) SUBSCRIPTION="$2"; shift 2 ;;
    --connectivity-sub) CONN_SUB="$2"; shift 2 ;;
    --management-sub) MGMT_SUB="$2"; shift 2 ;;
    --landingzone-sub) LZ_SUB="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$IAC" == "terraform" || "$IAC" == "bicep" ]] || { echo "--iac must be terraform or bicep" >&2; exit 2; }
[[ "$MODE" == "single" || "$MODE" == "multi" ]] || { echo "--mode must be single or multi" >&2; exit 2; }

command -v az >/dev/null || { echo "Azure CLI (az) is required." >&2; exit 1; }
command -v git >/dev/null || { echo "Git is required." >&2; exit 1; }
az account show --output none 2>/dev/null || { echo "Azure CLI is not authenticated. Run: az login" >&2; exit 1; }

if [[ "$IAC" == "terraform" ]]; then
  command -v terraform >/dev/null || { echo "Terraform >= 1.9 is required." >&2; exit 1; }
  [[ -n "$CONFIG" && -f "$CONFIG" ]] || { echo "--config must point to an existing tfvars file." >&2; exit 1; }
  [[ -f .launchpad/backend.hcl ]] || {
    echo "Terraform backend config is missing. Run ./scripts/bootstrap-state.sh first." >&2
    exit 1
  }
else
  az bicep version >/dev/null
  command -v jq >/dev/null || { echo "jq is required for Bicep deployment output handling." >&2; exit 1; }
  if [[ "$MODE" == "single" ]]; then
    [[ -n "$CONFIG" && -f "$CONFIG" ]] || { echo "--config must point to an existing bicepparam file." >&2; exit 1; }
    az bicep build-params --file "$CONFIG" --stdout >/dev/null
  else
    for template in infra/bicep/foundation/multi-sub/{connectivity,landingzone,management}.bicep; do
      az bicep build --file "$template" --stdout >/dev/null
    done
  fi
fi

if [[ "$MODE" == "single" ]]; then
  [[ -n "$SUBSCRIPTION" ]] || { echo "--subscription is required in single mode." >&2; exit 2; }
  SUBSCRIPTIONS=("$SUBSCRIPTION")
else
  [[ -n "$CONN_SUB" && -n "$MGMT_SUB" && -n "$LZ_SUB" ]] || {
    echo "All three multi-subscription IDs are required." >&2
    exit 2
  }
  SUBSCRIPTIONS=("$CONN_SUB" "$MGMT_SUB" "$LZ_SUB")
fi

for sub in "${SUBSCRIPTIONS[@]}"; do
  az account show --subscription "$sub" --output none 2>/dev/null || {
    echo "Subscription is unavailable to the signed-in identity: $sub" >&2
    exit 1
  }
done

echo "Preflight passed: iac=$IAC mode=$MODE subscriptions=${#SUBSCRIPTIONS[@]}"
