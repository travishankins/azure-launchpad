---
title: Multi-subscription (ALZ split)
description: ALZ-aligned deployment across Connectivity / Management / Landing-Zone subscriptions.
---

The foundation supports two deployment modes:

| Mode     | Subs | Best for                                                                            |
| -------- | ---- | ----------------------------------------------------------------------------------- |
| `single` | 1    | SMB starter — everything in one sub. **Default.**                                   |
| `multi`  | 3    | ALZ-aligned platform/workload separation — Connectivity / Management / Landing-Zone |

This page covers **`multi`** mode. For the simpler default, see the rest of the docs — single-sub is what every other page assumes.

## What lands where

| Subscription     | Resource groups                                                         | Resources                                                                                                                                              |
| ---------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Connectivity** | `rg-hub-<suffix>`                                                       | Hub VNet, Azure Firewall (`firewall`/`full`), VPN Gateway (`vpn`/`full`), Private DNS for Key Vault, hub-side peering                                  |
| **Management**   | `rg-monitor-<suffix>`, `rg-backup-<suffix>`                             | Log Analytics workspace, Automation Account, Recovery Services Vault, optional Foundation Health workbook + subscription budget                        |
| **Landing-Zone** | `rg-spoke-prod-<suffix>`, `rg-security-<suffix>`, `rg-migrate-<suffix>` | Spoke VNet, NAT Gateway (when no firewall), Key Vault with private endpoint, spoke-side peering, spoke route table (`firewall`/`full` — TF only in v1) |

## Coverage matrix

| Scenario   | Terraform multi-sub | Bicep multi-sub                                      |
| ---------- | ------------------- | ---------------------------------------------------- |
| `baseline` | ✅                  | ✅                                                   |
| `firewall` | ✅                  | ⚠️ v1 follow-up (cross-sub spoke route table needed) |
| `vpn`      | ✅                  | ⚠️ v1 follow-up                                      |
| `full`     | ✅                  | ⚠️ v1 follow-up                                      |

If you want firewall or VPN with multi-sub today, use the Terraform path — its provider-alias model handles all four scenarios cleanly.

## Required RBAC

| Principal needs       | On                                                                                                                                |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `Contributor`         | Each of the three subscriptions                                                                                                   |
| `Network Contributor` | Hub VNet in the connectivity sub (granted automatically by Azure on cross-sub peering, or explicit RBAC if you peer manually)     |
| `Network Contributor` | KV Private DNS Zone in the connectivity sub (required to link the PDZ to the spoke VNet for name resolution from spoke workloads) |

There is **no tenant-root requirement**. No `Owner`, no `Management Group Contributor`.

## Terraform deploy

> **State file naming:** Multi-sub state lands at key `foundation.<scenario>.multi.tfstate` (note the `.multi` suffix) so it never collides with a single-sub deploy of the same scenario.

```hcl
# wizard.auto.tfvars (or hand-rolled)
subscription_id              = "<management-sub>"  # default / fallback
scenario                     = "baseline"
location                     = "westcentralus"
name_prefix                  = "contoso"

deployment_mode              = "multi"
connectivity_subscription_id = "11111111-1111-1111-1111-111111111111"
management_subscription_id   = "22222222-2222-2222-2222-222222222222"
landingzone_subscription_id  = "33333333-3333-3333-3333-333333333333"
```

```bash
# 1. Bootstrap state in the management sub
export ARM_SUBSCRIPTION_ID=<management-sub>
./scripts/bootstrap-state.sh

# 2. Init + apply
cd infra/terraform/foundation
terraform init \
  -backend-config="resource_group_name=rg-tfstate-contoso-wcus" \
  -backend-config="storage_account_name=<from-bootstrap>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=foundation.baseline.multi.tfstate"

terraform workspace select -or-create baseline-multi
terraform apply -var-file=wizard.auto.tfvars
```

The provider aliases `azurerm.connectivity`, `azurerm.management`, `azurerm.landingzone` route every resource to its assigned sub. In single-sub mode all three aliases collapse to the same sub.

## Bicep deploy (baseline only in v1)

The shipped wrapper runs all four steps in order:

```bash
./scripts/deploy-multi-sub.sh \
  --connectivity-sub <conn-sub> \
  --management-sub   <mgmt-sub> \
  --landingzone-sub  <lz-sub> \
  --name-prefix contoso \
  --region westcentralus \
  --region-short wcus
```

Internally it does:

1. `az deployment sub create` in **connectivity** sub — hub VNet, no peering yet
2. `az deployment sub create` in **landing-zone** sub — spoke VNet + spoke→hub peering using hub VNet ID
3. `az deployment sub create` in **connectivity** sub again — wires hub→spoke peering using spoke VNet ID
4. `az deployment sub create` in **management** sub — LAW + Automation + RSV (+ optional budget + workbook)

Source files live under [`infra/bicep/foundation/multi-sub/`](https://github.com/travishankins/azure-launchpad/tree/main/infra/bicep/foundation/multi-sub):

- `connectivity.bicep` — sub-scope wrapper that creates `rg-hub` and the hub VNet
- `landingzone.bicep` — sub-scope wrapper that creates spoke RGs, spoke VNet, KV
- `management.bicep` — sub-scope wrapper that creates monitor + backup RGs and their resources
- `scenarios/*.bicepparam` — example parameter files for each layer

## Migrating from single → multi

You can't migrate state files in place — single-sub state holds resources in one sub; multi-sub state expects them in three. The path forward is:

1. Stand up multi-sub in parallel with a different `name_prefix` (e.g. `contoso2`).
2. Migrate workloads at your own pace.
3. Tear down the old single-sub deploy once nothing depends on it.

This is intentional — the foundation is small enough that a parallel deploy is cheaper and safer than a state surgery.

## Why isn't there an Identity sub?

ALZ recommends a fourth `identity` sub for AD DS / Entra DS. The foundation doesn't deploy any identity resources today — adding the variable without backing resources would be noise. When/if a future module deploys Entra DS, the Identity sub will be added in the same shape as the other three.

See [ADR 0006](https://github.com/travishankins/azure-launchpad/blob/main/docs/adr/0006-multi-subscription-mode.md) for the design rationale.
