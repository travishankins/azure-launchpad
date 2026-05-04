#!/usr/bin/env bash
# Bootstraps the Azure Storage backend used for Terraform remote state.
# Idempotent: safe to re-run. Requires `az` logged in to the target subscription.
set -euo pipefail

LOCATION="${LOCATION:-westcentralus}"
PREFIX="${PREFIX:-contoso}"
REGION_SHORT="${REGION_SHORT:-wcus}"
RG_NAME="${RG_NAME:-rg-tfstate-${PREFIX}-${REGION_SHORT}}"
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

# Enable blob versioning + soft delete for state safety.
az storage account blob-service-properties update \
  --account-name "${SA_NAME}" \
  --resource-group "${RG_NAME}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  --output none

az storage container create \
  --name "${CONTAINER}" \
  --account-name "${SA_NAME}" \
  --auth-mode login \
  --output none

cat <<EOF

Backend bootstrap complete. Use the following backend config:

  terraform init \\
    -backend-config="resource_group_name=${RG_NAME}" \\
    -backend-config="storage_account_name=${SA_NAME}" \\
    -backend-config="container_name=${CONTAINER}" \\
    -backend-config="key=foundation.tfstate"

Or via -backend-config=backend.hcl file:

  resource_group_name  = "${RG_NAME}"
  storage_account_name = "${SA_NAME}"
  container_name       = "${CONTAINER}"
  key                  = "foundation.tfstate"
EOF
