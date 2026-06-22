---
title: Quick start (Bicep)
description: Deploy the baseline scenario with Bicep in under an hour.
---

If you prefer Microsoft's native IaC, use Bicep for the shortest path: **configure → preflight/what-if → review → deploy → verify**. It deploys the same architecture as Terraform without a separate state backend.

> **No-install option** — every command below also works in [Azure Cloud Shell](https://shell.azure.com) (Bash). Cloud Shell is pre-authenticated and `az bicep` is built in. See [Prerequisites → Option A: Cloud Shell](/getting-started/prerequisites/#option-a--azure-cloud-shell) for the full walkthrough.

## 1. Clone, sign in, and configure

```bash
git clone https://github.com/travishankins/azure-launchpad.git
cd azure-launchpad
az login
az account set --subscription <subscription-id>
```

Use the [configuration generator](/wizard/), choose Bicep at step 2, and save its output as `infra/bicep/foundation/scenarios/wizard.bicepparam`.

## 2. Preflight and preview

```bash
./scripts/deploy.sh plan --iac bicep --mode single \
  --subscription <subscription-id> --scenario baseline \
  --config infra/bicep/foundation/scenarios/wizard.bicepparam \
  --region westcentralus
```

Review every change in the Bicep what-if output.

## 3. Deploy

```bash
./scripts/deploy.sh apply --iac bicep --mode single \
  --subscription <subscription-id> --scenario baseline \
  --config infra/bicep/foundation/scenarios/wizard.bicepparam \
  --region westcentralus
```

## 4. Verify

```bash
./scripts/verify.sh --mode single --subscription <subscription-id> \
  --scenario baseline --name-prefix contoso --region-short wcus
```

Bicep deployment history is stored in Azure. To switch scenarios, regenerate the parameter file and repeat preview/deploy with the matching scenario.

## Switching from Terraform to Bicep (or back)

The two roots manage the _same_ resource names by design (`rg-hub-contoso-wcus`, `vnet-hub-contoso-wcus`, etc.). **Do not** run both against the same subscription with the same `namePrefix`/`name_prefix` — pick one IaC and stick with it for that environment.

## Management Groups (Bicep, tenant scope)

```bash
az deployment tenant create \
  --location westcentralus \
  --name foundations-mg-full \
  --parameters infra/bicep/management-groups/scenarios/full.bicepparam
```

The principal needs `Management Group Contributor` on the Tenant Root Group (and `Resource Policy Contributor` if you set `enablePolicies = true`).
