#!/usr/bin/env bash
# Verify the expected resource groups and scenario-specific network resources.
set -euo pipefail

MODE="single"
SCENARIO="baseline"
SUBSCRIPTION=""
CONN_SUB=""
MGMT_SUB=""
LZ_SUB=""
NAME_PREFIX="contoso"
REGION_SHORT="wcus"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --scenario) SCENARIO="$2"; shift 2 ;;
    --subscription) SUBSCRIPTION="$2"; shift 2 ;;
    --connectivity-sub) CONN_SUB="$2"; shift 2 ;;
    --management-sub) MGMT_SUB="$2"; shift 2 ;;
    --landingzone-sub) LZ_SUB="$2"; shift 2 ;;
    --name-prefix) NAME_PREFIX="$2"; shift 2 ;;
    --region-short) REGION_SHORT="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 --mode single|multi --scenario SCENARIO [subscription options]"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ "$MODE" == "single" || "$MODE" == "multi" ]] || { echo "--mode must be single or multi." >&2; exit 2; }
case "$SCENARIO" in baseline|firewall|vpn|full) ;; *) echo "Invalid scenario: $SCENARIO" >&2; exit 2 ;; esac

SUFFIX="${NAME_PREFIX}-${REGION_SHORT}"
failures=0

check_rg() {
  local sub="$1" rg="$2"
  if [[ "$(az group exists --subscription "$sub" --name "$rg")" == "true" ]]; then
    echo "PASS  $sub  $rg"
  else
    echo "FAIL  $sub  $rg" >&2
    failures=$((failures + 1))
  fi
}

if [[ "$MODE" == "single" ]]; then
  [[ -n "$SUBSCRIPTION" ]] || { echo "--subscription is required." >&2; exit 2; }
  CONN_SUB="$SUBSCRIPTION"; MGMT_SUB="$SUBSCRIPTION"; LZ_SUB="$SUBSCRIPTION"
else
  [[ -n "$CONN_SUB" && -n "$MGMT_SUB" && -n "$LZ_SUB" ]] || {
    echo "All three multi-subscription IDs are required." >&2
    exit 2
  }
fi

check_rg "$CONN_SUB" "rg-hub-${SUFFIX}"
check_rg "$MGMT_SUB" "rg-monitor-${SUFFIX}"
check_rg "$MGMT_SUB" "rg-backup-${SUFFIX}"
check_rg "$LZ_SUB" "rg-spoke-prod-${SUFFIX}"
check_rg "$LZ_SUB" "rg-security-${SUFFIX}"
check_rg "$LZ_SUB" "rg-migrate-${SUFFIX}"

if [[ "$SCENARIO" == "firewall" || "$SCENARIO" == "full" ]]; then
  count="$(az network firewall list --subscription "$CONN_SUB" --resource-group "rg-hub-${SUFFIX}" --query 'length(@)' -o tsv)"
  [[ "$count" -gt 0 ]] || { echo "FAIL  Azure Firewall not found" >&2; failures=$((failures + 1)); }
fi
if [[ "$SCENARIO" == "vpn" || "$SCENARIO" == "full" ]]; then
  count="$(az network vnet-gateway list --subscription "$CONN_SUB" --resource-group "rg-hub-${SUFFIX}" --query 'length(@)' -o tsv)"
  [[ "$count" -gt 0 ]] || { echo "FAIL  VPN Gateway not found" >&2; failures=$((failures + 1)); }
fi

if [[ "$failures" -gt 0 ]]; then
  echo "Verification failed: $failures check(s)." >&2
  exit 1
fi
echo "Verification passed."
