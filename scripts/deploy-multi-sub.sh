#!/usr/bin/env bash
# Deploy the multi-subscription (ALZ-aligned) baseline foundation in 3 layers.
#
# Usage:
#   ./scripts/deploy-multi-sub.sh \
#       --connectivity-sub <guid> \
#       --management-sub   <guid> \
#       --landingzone-sub  <guid> \
#       [--name-prefix contoso] [--region westcentralus] [--region-short wcus]
#
# Order:
#   1. Connectivity (creates hub VNet)
#   2. Landing-zone (creates spoke VNet + spoke->hub peering using hubVnetId)
#   3. Connectivity (re-deploy with spokeVnetId to wire hub->spoke peering)
#   4. Management (independent — no cross-layer inputs)
#
# Requirements:
#   - Azure CLI signed in
#   - Contributor on each subscription
#   - Network Contributor on the hub VNet from the landing-zone sub principal
#     (Azure auto-grants this when peering is created cross-sub)
#
set -euo pipefail

NAME_PREFIX="contoso"
REGION="westcentralus"
REGION_SHORT="wcus"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --connectivity-sub) CONN_SUB="$2"; shift 2 ;;
    --management-sub)   MGMT_SUB="$2"; shift 2 ;;
    --landingzone-sub)  LZ_SUB="$2"; shift 2 ;;
    --name-prefix)      NAME_PREFIX="$2"; shift 2 ;;
    --region)           REGION="$2"; shift 2 ;;
    --region-short)     REGION_SHORT="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

: "${CONN_SUB:?--connectivity-sub is required}"
: "${MGMT_SUB:?--management-sub is required}"
: "${LZ_SUB:?--landingzone-sub is required}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BICEP_DIR="$REPO_ROOT/infra/bicep/foundation/multi-sub"

step() { echo; echo "==> $*"; }

# -----------------------------------------------------------------------------
# 1. Connectivity (first pass) — hub VNet, no peering yet
# -----------------------------------------------------------------------------
step "[1/4] Deploying connectivity layer to $CONN_SUB"
az account set --subscription "$CONN_SUB"
HUB_VNET_ID="$(az deployment sub create \
  --location "$REGION" \
  --name "azlp-connectivity-$(date +%s)" \
  --template-file "$BICEP_DIR/connectivity.bicep" \
  --parameters namePrefix="$NAME_PREFIX" regionShort="$REGION_SHORT" location="$REGION" \
  --query 'properties.outputs.hubVnetId.value' -o tsv)"
echo "   hubVnetId = $HUB_VNET_ID"

# -----------------------------------------------------------------------------
# 2. Landing-zone — spoke VNet + spoke->hub peering (cross-sub via hubVnetId)
# -----------------------------------------------------------------------------
step "[2/4] Deploying landing-zone layer to $LZ_SUB"
az account set --subscription "$LZ_SUB"
SPOKE_VNET_ID="$(az deployment sub create \
  --location "$REGION" \
  --name "azlp-landingzone-$(date +%s)" \
  --template-file "$BICEP_DIR/landingzone.bicep" \
  --parameters namePrefix="$NAME_PREFIX" regionShort="$REGION_SHORT" location="$REGION" hubVnetId="$HUB_VNET_ID" \
  --query 'properties.outputs.spokeVnetId.value' -o tsv)"
echo "   spokeVnetId = $SPOKE_VNET_ID"

# -----------------------------------------------------------------------------
# 3. Connectivity (second pass) — wire hub->spoke peering
# -----------------------------------------------------------------------------
step "[3/4] Re-deploying connectivity to wire hub->spoke peering"
az account set --subscription "$CONN_SUB"
az deployment sub create \
  --location "$REGION" \
  --name "azlp-connectivity-peer-$(date +%s)" \
  --template-file "$BICEP_DIR/connectivity.bicep" \
  --parameters namePrefix="$NAME_PREFIX" regionShort="$REGION_SHORT" location="$REGION" spokeVnetId="$SPOKE_VNET_ID" \
  --output none

# -----------------------------------------------------------------------------
# 4. Management — LAW + Automation + RSV + (opt-in) budget + workbook
# -----------------------------------------------------------------------------
step "[4/4] Deploying management layer to $MGMT_SUB"
az account set --subscription "$MGMT_SUB"
az deployment sub create \
  --location "$REGION" \
  --name "azlp-management-$(date +%s)" \
  --template-file "$BICEP_DIR/management.bicep" \
  --parameters namePrefix="$NAME_PREFIX" regionShort="$REGION_SHORT" location="$REGION" scenario=baseline \
  --output none

step "Done. Three subscriptions deployed."
echo "  Connectivity: $CONN_SUB"
echo "  Management:   $MGMT_SUB"
echo "  Landing-zone: $LZ_SUB"
