#!/usr/bin/env bash
# Shared preview/apply entry point for Terraform and Bicep foundations.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/deploy.sh plan|apply --iac terraform|bicep --mode single|multi [options]

Common options:
  --scenario baseline|firewall|vpn|full
  --config PATH
  --subscription GUID
  --connectivity-sub GUID --management-sub GUID --landingzone-sub GUID
  --name-prefix NAME --region REGION --region-short SHORT
Terraform apply:
  --plan-file PATH          Required; must be produced by this script's plan action
EOF
}

[[ $# -gt 0 ]] || { usage >&2; exit 2; }
ACTION="$1"
shift
[[ "$ACTION" == "plan" || "$ACTION" == "apply" ]] || { echo "Action must be plan or apply." >&2; exit 2; }

IAC=""
MODE="single"
SCENARIO="baseline"
CONFIG=""
SUBSCRIPTION=""
CONN_SUB=""
MGMT_SUB=""
LZ_SUB=""
NAME_PREFIX="contoso"
REGION="westcentralus"
REGION_SHORT="wcus"
PLAN_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iac) IAC="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --scenario) SCENARIO="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --subscription) SUBSCRIPTION="$2"; shift 2 ;;
    --connectivity-sub) CONN_SUB="$2"; shift 2 ;;
    --management-sub) MGMT_SUB="$2"; shift 2 ;;
    --landingzone-sub) LZ_SUB="$2"; shift 2 ;;
    --name-prefix) NAME_PREFIX="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --region-short) REGION_SHORT="$2"; shift 2 ;;
    --plan-file) PLAN_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$SCENARIO" in baseline|firewall|vpn|full) ;; *) echo "Invalid scenario: $SCENARIO" >&2; exit 2 ;; esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PREFLIGHT=(./scripts/preflight.sh --iac "$IAC" --mode "$MODE")
[[ -n "$CONFIG" ]] && PREFLIGHT+=(--config "$CONFIG")
if [[ "$MODE" == "single" ]]; then
  PREFLIGHT+=(--subscription "$SUBSCRIPTION")
else
  PREFLIGHT+=(--connectivity-sub "$CONN_SUB" --management-sub "$MGMT_SUB" --landingzone-sub "$LZ_SUB")
fi
"${PREFLIGHT[@]}"

if [[ "$IAC" == "terraform" ]]; then
  TF_DIR="infra/terraform/foundation"
  CONFIG_ABS="$(cd "$(dirname "$CONFIG")" && pwd)/$(basename "$CONFIG")"
  HOME_SUB="$SUBSCRIPTION"
  WORKSPACE="$SCENARIO"
  STATE_KEY="foundation.${SCENARIO}.tfstate"
  if [[ "$MODE" == "multi" ]]; then
    HOME_SUB="$MGMT_SUB"
    WORKSPACE="${SCENARIO}-multi"
    STATE_KEY="foundation.${SCENARIO}.multi.tfstate"
  fi
  export ARM_SUBSCRIPTION_ID="$HOME_SUB"
  export TF_VAR_subscription_id="$HOME_SUB"
  az account set --subscription "$HOME_SUB"
  terraform -chdir="$TF_DIR" init -reconfigure \
    -backend-config="$REPO_ROOT/.launchpad/backend.hcl" \
    -backend-config="key=$STATE_KEY"
  terraform -chdir="$TF_DIR" workspace select -or-create "$WORKSPACE"

  if [[ "$ACTION" == "plan" ]]; then
    mkdir -p .launchpad/plans
    PLAN_FILE="${PLAN_FILE:-.launchpad/plans/foundation.${SCENARIO}.${MODE}.tfplan}"
    if [[ "$PLAN_FILE" = /* ]]; then
      PLAN_ABS="$PLAN_FILE"
    else
      PLAN_ABS="$REPO_ROOT/$PLAN_FILE"
    fi
    terraform -chdir="$TF_DIR" plan -var-file="$CONFIG_ABS" -out="$PLAN_ABS"
    echo "Saved plan: $PLAN_FILE"
    echo "Apply only this reviewed plan: ./scripts/deploy.sh apply ... --plan-file $PLAN_FILE"
  else
    [[ -n "$PLAN_FILE" && -f "$PLAN_FILE" ]] || {
      echo "Terraform apply requires --plan-file from a prior plan action." >&2
      exit 1
    }
    PLAN_ABS="$(cd "$(dirname "$PLAN_FILE")" && pwd)/$(basename "$PLAN_FILE")"
    terraform -chdir="$TF_DIR" apply "$PLAN_ABS"
  fi
elif [[ "$IAC" == "bicep" ]]; then
  if [[ "$MODE" == "multi" ]]; then
    MULTI_ARGS=(--mode "$([[ "$ACTION" == "plan" ]] && echo what-if || echo apply)" \
      --connectivity-sub "$CONN_SUB" --management-sub "$MGMT_SUB" --landingzone-sub "$LZ_SUB" \
      --scenario "$SCENARIO" --name-prefix "$NAME_PREFIX" --region "$REGION" --region-short "$REGION_SHORT")
    ./scripts/deploy-multi-sub.sh "${MULTI_ARGS[@]}"
  else
    az account set --subscription "$SUBSCRIPTION"
    if [[ "$ACTION" == "plan" ]]; then
      az deployment sub what-if --location "$REGION" --name "foundation-${SCENARIO}" --parameters "$CONFIG"
    else
      az deployment sub create --location "$REGION" --name "foundation-${SCENARIO}" --parameters "$CONFIG"
    fi
  fi
else
  echo "--iac must be terraform or bicep" >&2
  exit 2
fi
