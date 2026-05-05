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
| **Landing-Zone** | `rg-spoke-prod-<suffix>`, `rg-security-<suffix>`, `rg-migrate-<suffix>` | Spoke VNet, NAT Gateway (when no firewall) **or** route table → firewall private IP (`firewall`/`full`), Key Vault with private endpoint, spoke-side peering |

## Coverage matrix

| Scenario   | Terraform multi-sub | Bicep multi-sub |
| ---------- | :-----------------: | :-------------: |
| `baseline` | ✅                  | ✅              |
| `firewall` | ✅                  | ✅              |
| `vpn`      | ✅                  | ✅              |
| `full`     | ✅                  | ✅              |

Both stacks now support all four scenarios in multi-sub mode. The Bicep path uses the [`scripts/deploy-multi-sub.sh`](https://github.com/travishankins/azure-launchpad/blob/main/scripts/deploy-multi-sub.sh) wrapper to thread cross-sub references (firewall private IP, hub VNet ID, spoke VNet ID, PDZ ID) through the four deploy steps. The Terraform path uses provider aliases (`azurerm.connectivity`, `azurerm.management`, `azurerm.landingzone`) and runs as a single `terraform apply`.

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

## Bicep deploy

The shipped wrapper runs all four deploy steps in order, threading cross-sub outputs (`hubVnetId`, `firewallPrivateIp`, `spokeVnetId`, `keyVaultPdzId`) between them:

```bash
./scripts/deploy-multi-sub.sh \
  --connectivity-sub <conn-sub> \
  --management-sub   <mgmt-sub> \
  --landingzone-sub  <lz-sub> \
  --scenario full \
  --name-prefix contoso \
  --region westcentralus \
  --region-short wcus
```

`--scenario` accepts `baseline`, `firewall`, `vpn`, or `full`. Internally the script does:

1. **Connectivity** (first pass) — hub VNet, plus Azure Firewall + policy (`firewall`/`full`) and VPN gateway (`vpn`/`full`). Captures `firewallPrivateIp`, `hubVnetId`, `keyVaultPdzId` from outputs.
2. **Landing-zone** — spoke VNet + spoke→hub peering. NAT Gateway for `baseline`/`vpn`; route table forwarding `0.0.0.0/0` to the firewall private IP for `firewall`/`full`. Key Vault private endpoint optionally wired to the PDZ in the connectivity sub.
3. **Connectivity** (second pass) — wires hub→spoke peering AND the cross-sub PDZ→spoke virtual-network link so KV name resolution works from spoke workloads.
4. **Management** — Log Analytics, Automation Account, Recovery Services Vault (independent of network layers).

> The deploy uses `useRemoteGateways: false` on the spoke side. If you're using `vpn` or `full` and want spoke workloads to reach on-prem through the VPN gateway, flip `useRemoteGateways` to `true` on the spoke peering after the first apply. This is documented as a manual fourth step today; automating it is on the roadmap.

Source files live under [`infra/bicep/foundation/multi-sub/`](https://github.com/travishankins/azure-launchpad/tree/main/infra/bicep/foundation/multi-sub):

- `connectivity.bicep` — sub-scope wrapper that creates `rg-hub` and the hub VNet (+ firewall / VPN as scenario dictates)
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
