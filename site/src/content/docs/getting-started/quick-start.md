---
title: Quick start (Terraform)
description: Deploy the baseline scenario with Terraform in under an hour.
---

This path always follows the same lifecycle: **configure → preflight → plan → review → apply saved plan → verify**. Prefer Microsoft's native IaC? See [Quick start (Bicep)](/getting-started/quick-start-bicep/).

> **No-install option** — every command below also works in [Azure Cloud Shell](https://shell.azure.com) (Bash). Cloud Shell is pre-authenticated and ships with `az`, `terraform`, and `git`. See [Prerequisites → Option A: Cloud Shell](/getting-started/prerequisites/#option-a--azure-cloud-shell) for the full walkthrough and Terraform-version pinning tip.

## 1. Clone, authenticate, and configure

```bash
git clone https://github.com/travishankins/azure-launchpad.git
cd azure-launchpad
az login
export ARM_SUBSCRIPTION_ID=<subscription-id>
```

Use the [configuration generator](/wizard/) and save its Terraform output as `infra/terraform/foundation/scenarios/wizard.auto.tfvars`.

## 2. Bootstrap state once

```bash
./scripts/bootstrap-state.sh
```

This creates the storage backend, grants the signed-in identity `Storage Blob Data Contributor`, and writes the ignored `.launchpad/backend.hcl`. See [Prerequisites → Azure access](/getting-started/prerequisites/#azure-access) for the one-time role-assignment requirement.

## 3. Preflight and save a plan

```bash
./scripts/deploy.sh plan --iac terraform --mode single \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --scenario baseline \
  --config infra/terraform/foundation/scenarios/wizard.auto.tfvars
```

The command checks tools, authentication, subscription access, configuration, and backend setup before creating `.launchpad/plans/foundation.baseline.single.tfplan`.

## 4. Review, then apply only that plan

```bash
./scripts/deploy.sh apply --iac terraform --mode single \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --scenario baseline \
  --config infra/terraform/foundation/scenarios/wizard.auto.tfvars \
  --plan-file .launchpad/plans/foundation.baseline.single.tfplan
```

`apply` refuses to run without a saved plan.

## 5. Verify

```bash
./scripts/verify.sh --mode single \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --scenario baseline --name-prefix contoso --region-short wcus
```

To switch scenarios, regenerate the configuration and repeat plan/apply with the matching scenario. Each scenario and deployment mode gets a separate workspace, state key, and plan filename.
