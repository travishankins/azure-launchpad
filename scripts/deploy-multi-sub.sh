#!/usr/bin/env bash
# Deploy the multi-subscription (ALZ-aligned) foundation in 3 layers.
#
# Usage:
#   ./scripts/deploy-multi-sub.sh \
#       --connectivity-sub <guid> \
#       --management-sub   <guid> \
#       --landingzone-sub  <guid> \
#       [--mode what-if|apply] \
#       [--scenario baseline|firewall|vpn|full] \
#       [--name-prefix contoso] [--region westcentralus] [--region-short wcus]
#
# Order:
#   1. Connectivity (creates hub VNet, optionally firewall + VPN)
#   2. Landing-zone (spoke VNet + spoke->hub peering; route table -> firewall
#      private IP for firewall/full)
#   3. Connectivity (re-deploy with spokeVnetId — wires hub->spoke peering AND
#      cross-sub PDZ link to the spoke VNet)
#   4. Management  (LAW + Automation + RSV + opt-in budget/workbook)
#
# Requirements:
#   - Azure CLI signed in
#   - Contributor on each subscription
#   - Network Contributor implicitly required cross-sub for VNet peering and
#     for the cross-sub PDZ link (Azure auto-grants when the resource is
#     created from the owning sub)
#
set -euo pipefail

NAME_PREFIX="contoso"
REGION="westcentralus"
REGION_SHORT="wcus"
SCENARIO="baseline"
MODE="apply"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --connectivity-sub) CONN_SUB="$2"; shift 2 ;;
    --management-sub)   MGMT_SUB="$2"; shift 2 ;;
    --landingzone-sub)  LZ_SUB="$2"; shift 2 ;;
    --scenario)         SCENARIO="$2"; shift 2 ;;
    --mode)             MODE="$2"; shift 2 ;;
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

case "$SCENARIO" in
  baseline|firewall|vpn|full) ;;
  *) echo "--scenario must be one of: baseline | firewall | vpn | full" >&2; exit 2 ;;
esac
case "$MODE" in
  what-if|apply) ;;
  *) echo "--mode must be one of: what-if | apply" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BICEP_DIR="$REPO_ROOT/infra/bicep/foundation/multi-sub"

step() { echo; echo "==> $*"; }

if [[ "$MODE" == "what-if" ]]; then
  SUFFIX="${NAME_PREFIX}-${REGION_SHORT}"
  HUB_VNET_ID="/subscriptions/${CONN_SUB}/resourceGroups/rg-hub-${SUFFIX}/providers/Microsoft.Network/virtualNetworks/vnet-hub-${SUFFIX}"
  SPOKE_VNET_ID="/subscriptions/${LZ_SUB}/resourceGroups/rg-spoke-prod-${SUFFIX}/providers/Microsoft.Network/virtualNetworks/vnet-spoke-prod-${SUFFIX}"
  PDZ_ID="/subscriptions/${CONN_SUB}/resourceGroups/rg-hub-${SUFFIX}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
  FW_PRIVATE_IP=""
  if [[ "$SCENARIO" == "firewall" || "$SCENARIO" == "full" ]]; then
    # What-if needs a syntactically valid next hop before the firewall exists.
    FW_PRIVATE_IP="10.0.0.4"
  fi

  step "[1/3] Previewing connectivity layer ($SCENARIO) in $CONN_SUB"
  az account set --subscription "$CONN_SUB"
  az deployment sub what-if \
    --location "$REGION" \
    --name "azlp-connectivity-preview" \
    --template-file "$BICEP_DIR/connectivity.bicep" \
    --parameters namePrefix="$NAME_PREFIX" regionShort="$REGION_SHORT" location="$REGION" \
                 scenario="$SCENARIO" spokeVnetId="$SPOKE_VNET_ID"

  step "[2/3] Previewing landing-zone layer ($SCENARIO) in $LZ_SUB"
  az account set --subscription "$LZ_SUB"
  az deployment sub what-if \
    --location "$REGION" \
    --name "azlp-landingzone-preview" \
    --template-file "$BICEP_DIR/landingzone.bicep" \
    --parameters namePrefix="$NAME_PREFIX" regionShort="$REGION_SHORT" location="$REGION" \
                 scenario="$SCENARIO" hubVnetId="$HUB_VNET_ID" \
                 firewallPrivateIp="$FW_PRIVATE_IP" keyVaultPdzId="$PDZ_ID"

  step "[3/3] Previewing management layer ($SCENARIO) in $MGMT_SUB"
  az account set --subscription "$MGMT_SUB"
  az deployment sub what-if \
    --location "$REGION" \
    --name "azlp-management-preview" \
    --template-file "$BICEP_DIR/management.bicep" \
    --parameters namePrefix="$NAME_PREFIX" regionShort="$REGION_SHORT" location="$REGION" scenario="$SCENARIO"

  step "Preview complete. Review every change before running with --mode apply."
  exit 0
fi

# -----------------------------------------------------------------------------
# 1. Connectivity (first pass) — hub, firewall, VPN, PDZ; no peering yet
# -----------------------------------------------------------------------------
step "[1/4] Deploying connectivity layer ($SCENARIO) to $CONN_SUB"
az account set --subscription "$CONN_SUB"
CONN_OUT="$(az deployment sub create \
  --location "$REGION" \
  --name "azlp-connectivity-$(date +%s)" \
  --template-file "$BICEP_DIR/connectivity.bicep" \
  --parameters namePrefix="$NAME_PREFIX" regionShort="$REGION_SHORT" location="$REGION" scenario="$SCENARIO" \
  --query 'properties.outputs' -o json)"
HUB_VNET_ID="$(echo "$CONN_OUT"  | jq -r '.hubVnetId.value')"
FW_PRIVATE_IP="$(echo "$CONN_OUT" | jq -r '.firewallPrivateIp.value // ""')"
PDZ_ID="$(echo "$CONN_OUT"        | jq -r '.keyVaultPdzId.value')"
echo "   hubVnetId        = $HUB_VNET_ID"
echo "   firewallPrivateIp= ${FW_PRIVATE_IP:-<none, not a firewall scenario>}"
echo "   keyVaultPdzId    = $PDZ_ID"

# -----------------------------------------------------------------------------
# 2. Landing-zone — spoke VNet (NAT or route table) + spoke->hub peering + KV
# -----------------------------------------------------------------------------
step "[2/4] Deploying landing-zone layer ($SCENARIO) to $LZ_SUB"
az account set --subscription "$LZ_SUB"
LZ_OUT="$(az deployment sub create \
  --location "$REGION" \
  --name "azlp-landingzone-$(date +%s)" \
  --template-file "$BICEP_DIR/landingzone.bicep" \
  --parameters namePrefix="$NAME_PREFIX" regionShort="$REGION_SHORT" location="$REGION" scenario="$SCENARIO" \
               hubVnetId="$HUB_VNET_ID" firewallPrivateIp="$FW_PRIVATE_IP" keyVaultPdzId="$PDZ_ID" \
  --query 'properties.outputs' -o json)"
SPOKE_VNET_ID="$(echo "$LZ_OUT" | jq -r '.spokeVnetId.value')"
echo "   spokeVnetId      = $SPOKE_VNET_ID"

# -----------------------------------------------------------------------------
# 3. Connectivity (second pass) — hub->spoke peering + PDZ->spoke link
# -----------------------------------------------------------------------------
step "[3/4] Re-deploying connectivity to wire hub->spoke peering + PDZ->spoke link"
az account set --subscription "$CONN_SUB"
az deployment sub create \
  --location "$REGION" \
  --name "azlp-connectivity-peer-$(date +%s)" \
  --template-file "$BICEP_DIR/connectivity.bicep" \
  --parameters namePrefix="$NAME_PREFIX" regionShort="$REGION_SHORT" location="$REGION" scenario="$SCENARIO" \
               spokeVnetId="$SPOKE_VNET_ID" \
  --output none

# -----------------------------------------------------------------------------
# 4. Management — LAW + Automation + RSV (independent of network layers)
# -----------------------------------------------------------------------------
step "[4/4] Deploying management layer ($SCENARIO) to $MGMT_SUB"
az account set --subscription "$MGMT_SUB"
az deployment sub create \
  --location "$REGION" \
  --name "azlp-management-$(date +%s)" \
  --template-file "$BICEP_DIR/management.bicep" \
  --parameters namePrefix="$NAME_PREFIX" regionShort="$REGION_SHORT" location="$REGION" scenario="$SCENARIO" \
  --output none

step "Done. Three subscriptions deployed (scenario=$SCENARIO)."
echo "  Connectivity: $CONN_SUB"
echo "  Management:   $MGMT_SUB"
echo "  Landing-zone: $LZ_SUB"
