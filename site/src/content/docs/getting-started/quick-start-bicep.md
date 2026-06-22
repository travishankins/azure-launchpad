---
title: Quick start (Bicep)
description: Deploy the baseline scenario with Bicep in under an hour.
---

If you prefer Microsoft's native IaC, use the Bicep root — it deploys the same architecture as the Terraform root.

> **No-install option** — every command below also works in [Azure Cloud Shell](https://shell.azure.com) (Bash). Cloud Shell is pre-authenticated and `az bicep` is built in. See [Prerequisites → Option A: Cloud Shell](/getting-started/prerequisites/#option-a--azure-cloud-shell) for the full walkthrough.

## 1. Sign in

```bash
git clone https://github.com/travishankins/azure-launchpad.git
cd azure-launchpad
az login
az account set --subscription <subscription-id>
```

> Bicep tracks deployment history in Azure itself — no separate state backend required.

## 2. Pick a scenario

The four scenarios mirror the Terraform side: `baseline`, `firewall`, `vpn`, `full`. Each has a `.bicepparam` file under `infra/bicep/foundation/scenarios/`.

## 3. Preview

```bash
az deployment sub what-if \
  --location westcentralus \
  --name foundation-baseline \
  --parameters infra/bicep/foundation/scenarios/baseline.bicepparam
```

Review the output carefully — Bicep `what-if` shows every resource that will be created, modified, or deleted.

## 4. Deploy

```bash
az deployment sub create \
  --location westcentralus \
  --name foundation-baseline \
  --parameters infra/bicep/foundation/scenarios/baseline.bicepparam
```

That's it. To switch scenarios, just point `--parameters` at a different `.bicepparam` file and pick a new `--name`.

## Switching from Terraform to Bicep (or back)

The two roots manage the _same_ resource names by design (`rg-hub-contoso-wcus`, `vnet-hub-contoso-wcus`, etc.). **Do not** run both against the same subscription with the same `namePrefix`/`name_prefix` — pick one IaC and stick with it for that environment.

> **Tip** — use the [configuration generator](/wizard/) and pick **Bicep** at step 1 to generate a `wizard.bicepparam` file tailored to your customer's needs.

## Management Groups (Bicep, tenant scope)

```bash
az deployment tenant create \
  --location westcentralus \
  --name foundations-mg-full \
  --parameters infra/bicep/management-groups/scenarios/full.bicepparam
```

The principal needs `Management Group Contributor` on the Tenant Root Group (and `Resource Policy Contributor` if you set `enablePolicies = true`).
