#!/usr/bin/env bash
# Bootstraps the Azure Storage backend used for Terraform remote state.
# Idempotent: safe to re-run. Requires `az` logged in to the target subscription.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

LOCATION="${LOCATION:-westcentralus}"
PREFIX="${PREFIX:-contoso}"
REGION_SHORT="${REGION_SHORT:-wcus}"
RG_NAME="${RG_NAME:-rg-tfstate-${PREFIX}-${REGION_SHORT}}"

if [[ -n "${ARM_SUBSCRIPTION_ID:-}" ]]; then
  az account set --subscription "${ARM_SUBSCRIPTION_ID}"
fi

# Storage account names are globally unique, 3-24 lowercase alphanumerics.
# Append a stable hash of the subscription id to avoid collisions.
SUB_ID="$(az account show --query id -o tsv)"
SUFFIX="$(printf '%s' "$SUB_ID" | shasum -a 256 | cut -c1-6)"
SA_NAME="${SA_NAME:-st${PREFIX}tfstate${SUFFIX}}"
CONTAINER="${CONTAINER:-tfstate}"

echo "Subscription : ${SUB_ID}"
echo "Resource grp : ${RG_NAME}"
echo "Storage acct : ${SA_NAME}"
echo "Container    : ${CONTAINER}"
echo "Location     : ${LOCATION}"
echo

az group create --name "${RG_NAME}" --location "${LOCATION}" --output none

az storage account create \
  --name "${SA_NAME}" \
  --resource-group "${RG_NAME}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --https-only true \
  --output none

SA_ID="$(az storage account show --name "${SA_NAME}" --resource-group "${RG_NAME}" --query id -o tsv)"
ACCOUNT_TYPE="$(az account show --query user.type -o tsv)"
ACCOUNT_NAME="$(az account show --query user.name -o tsv)"
PRINCIPAL_ID="${TFSTATE_PRINCIPAL_ID:-}"
PRINCIPAL_TYPE="${TFSTATE_PRINCIPAL_TYPE:-}"
if [[ -z "$PRINCIPAL_ID" ]]; then
  if [[ "$ACCOUNT_TYPE" == "user" ]]; then
    PRINCIPAL_ID="$(az ad signed-in-user show --query id -o tsv)"
    PRINCIPAL_TYPE="User"
  else
    PRINCIPAL_ID="$(az ad sp show --id "$ACCOUNT_NAME" --query id -o tsv)"
    PRINCIPAL_TYPE="ServicePrincipal"
  fi
fi
PRINCIPAL_TYPE="${PRINCIPAL_TYPE:-ServicePrincipal}"

ensure_blob_role() {
  local principal_id="$1" principal_type="$2"
  local count
  count="$(az role assignment list --assignee "$principal_id" --scope "$SA_ID" \
    --role "Storage Blob Data Contributor" --query 'length(@)' -o tsv)"
  if [[ "$count" == "0" ]]; then
    echo "Granting Storage Blob Data Contributor to ${principal_id}..."
    az role assignment create \
      --assignee-object-id "$principal_id" \
      --assignee-principal-type "$principal_type" \
      --role "Storage Blob Data Contributor" \
      --scope "$SA_ID" \
      --output none
  fi
}

ensure_blob_role "$PRINCIPAL_ID" "$PRINCIPAL_TYPE"
if [[ -n "${TFSTATE_EXTRA_PRINCIPAL_ID:-}" ]]; then
  ensure_blob_role "$TFSTATE_EXTRA_PRINCIPAL_ID" "${TFSTATE_EXTRA_PRINCIPAL_TYPE:-ServicePrincipal}"
fi

# Enable blob versioning + soft delete for state safety.
az storage account blob-service-properties update \
  --account-name "${SA_NAME}" \
  --resource-group "${RG_NAME}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  --output none

for attempt in {1..12}; do
  if az storage container create \
    --name "${CONTAINER}" \
    --account-name "${SA_NAME}" \
    --auth-mode login \
    --output none 2>/dev/null; then
    break
  fi
  if [[ "$attempt" == "12" ]]; then
    echo "Blob data-plane access did not become available after 2 minutes." >&2
    exit 1
  fi
  echo "Waiting for the blob role assignment to propagate (${attempt}/12)..."
  sleep 10
done

mkdir -p "$REPO_ROOT/.launchpad"
cat > "$REPO_ROOT/.launchpad/backend.hcl" <<EOF
resource_group_name  = "${RG_NAME}"
storage_account_name = "${SA_NAME}"
container_name       = "${CONTAINER}"
use_azuread_auth     = true
EOF

cat <<EOF

Backend bootstrap complete. Generated backend config:

  ${REPO_ROOT}/.launchpad/backend.hcl

Initialize with:

  terraform init \\
    -backend-config="${REPO_ROOT}/.launchpad/backend.hcl" \\
    -backend-config="key=foundation.tfstate"
EOF
