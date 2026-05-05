---
title: Budgets (optional)
description: Opt-in subscription budget with email alerts at 50/80/100% of monthly spend, available in both Terraform and Bicep.
---

A free, opt-in module that creates a **subscription-scoped monthly budget** with email alerts. Disabled by default.

## What it deploys

- 1 × `Microsoft.Consumption/budgets` (subscription scope, monthly grain)
- N notifications at the percent thresholds you configure (default: 50 %, 80 %, 100 %) on **Actual** spend
- 1 notification at 100 % of **Forecasted** spend, so you get warned before you actually overrun
- (Optional) Filter to a list of resource group names — empty means whole subscription

**Cost: $0.** Azure Cost Management is free.

## Why opt-in?

- Budgets need at least one email recipient — there's no sensible default.
- Many SMB customers already have org-wide cost alerts in Cost Management; deploying duplicates is noisy.
- Currency depends on the subscription's billing profile; we don't want to silently set USD for a EUR-billed sub.

## Enable in Terraform

In your tfvars (or per-scenario file under `infra/terraform/foundation/scenarios/`):

```hcl
# Existing scenario settings
scenario = "baseline"
location = "westcentralus"

# Enable the budget
budget_enabled      = true
budget_amount       = 200                                    # USD/EUR/etc per month
budget_alert_emails = ["platform@example.com", "finance@example.com"]
budget_thresholds   = [50, 80, 100]                          # percent of budget
# budget_resource_group_names = []                           # default: whole subscription
```

Plan + apply as normal:

```bash
terraform plan -var-file=scenarios/baseline.tfvars -var "subscription_id=$ARM_SUBSCRIPTION_ID"
terraform apply
```

The output `budget_id` returns the ARM resource ID (or `null` when disabled).

## Enable in Bicep

In your `*.bicepparam`:

```bicep
using '../main.bicep'

param scenario = 'baseline'
param location = 'westcentralus'

param budgetEnabled = true
param budgetAmount = 200
param budgetAlertEmails = [
  'platform@example.com'
  'finance@example.com'
]
param budgetThresholds = [
  50
  80
  100
]
```

Deploy:

```bash
az deployment sub create \
  --location <region> \
  --name foundation-baseline-with-budget \
  --parameters infra/bicep/foundation/scenarios/baseline.bicepparam
```

The output `budgetId` returns the ARM resource ID (empty string when disabled).

## How alerts work

| Trigger                | When you get an email                                                                             |
| ---------------------- | ------------------------------------------------------------------------------------------------- |
| **Actual ≥ 50 %**      | When your billed month-to-date spend crosses 50 % of the budget                                   |
| **Actual ≥ 80 %**      | When billed spend crosses 80 %                                                                    |
| **Actual ≥ 100 %**     | When billed spend crosses 100 % (the budget is informational; Azure will not stop deployments)    |
| **Forecasted ≥ 100 %** | When the projected end-of-month spend crosses 100 % — usually fires days before the actual breach |

You can change the Actual thresholds by overriding `budget_thresholds` (TF) / `budgetThresholds` (Bicep). The Forecasted-100 % notification is always enabled.

## Scoping to a subset of resource groups

If you only want to track spend for a specific workload (not the whole subscription), pass the RG names:

```hcl
budget_resource_group_names = ["rg-spoke-prod-contoso-wcus"]
```

Bicep equivalent:

```bicep
// Add to your bicepparam
param budgetResourceGroupNames = [
  'rg-spoke-prod-contoso-wcus'
]
```

> **Note:** This is built into the Terraform variable surface today; the Bicep main currently exposes a sub-wide budget only. Add `param budgetResourceGroupNames array = []` in `main.bicep` if you need RG scoping in Bicep — the underlying `modules/budgets.bicep` already supports it.

## Validation rules

The Terraform module rejects invalid input at plan time:

- `budget_amount` must be > 0
- Each entry of `budget_thresholds` must be 1–1000
- Each entry of `budget_alert_emails` must look like an email address
- If `budget_enabled = true`, `budget_alert_emails` must contain at least one address (enforced via locals)

Bicep enforces `@minValue(1)` on `budgetAmount` and `@minLength(1)` on the budget module's `alertEmails` parameter.

## Tests

A `*.tftest.hcl` plan-mode test ships with the module:

```bash
cd infra/terraform/foundation
terraform test -filter=tests/budgets.tftest.hcl
```

It asserts:

- Default state (no `budget_enabled`) creates **0** budgets
- Enabling with valid emails creates **1** budget with the right amount + monthly grain

## Removing the budget

Set `budget_enabled = false` (TF) or `budgetEnabled = false` (Bicep) and re-apply. The budget resource is destroyed; Cost Management retains historical spend data regardless.
