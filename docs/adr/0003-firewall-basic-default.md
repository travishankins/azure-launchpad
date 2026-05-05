# 0003. Azure Firewall Basic as the default SKU

- **Status**: Accepted
- **Date**: 2026-04-15

## Context

The `firewall` and `full` scenarios deploy an Azure Firewall in the hub. Azure Firewall ships in three SKUs:

| SKU      | List price (West Central US) | Features                                                      |
| -------- | ---------------------------- | ------------------------------------------------------------- |
| Basic    | ~$295/mo                     | App + Network rules, threat intel (alert), max 250 Mbps       |
| Standard | ~$880/mo                     | + URL filtering, IDPS (alert), DNS proxy, threat intel (deny) |
| Premium  | ~$1,750/mo                   | + TLS inspection, IDPS (deny), web categories                 |

Azure Launchpad's target audience is SMB / SMEC: organisations standing up their first regulated landing zone, often with one or two workloads behind the firewall.

## Decision

**Default to Azure Firewall Basic** in both `firewall` and `full` scenarios. Basic is hard-coded today; the SKU is **not** exposed as a variable.

A future Wizard "advanced mode" option may surface SKU selection, but the default stays Basic.

## Consequences

- Monthly cost for `firewall` lands at ~$336 instead of ~$921 (Standard) or ~$1,791 (Premium) — an order-of-magnitude difference for a starter landing zone.
- Basic requires both `AzureFirewallSubnet` AND `AzureFirewallManagementSubnet` (a Basic-only requirement) and a separate management public IP. The TF + Bicep modules already account for this.
- Customers who outgrow Basic (need IDPS, TLS inspection, or >250 Mbps) currently have to re-deploy with the SKU edited inline. We accept the friction in exchange for the lower default cost.
- The Bicep + TF code paths for "Standard / Premium" are documented in the architecture page but not implemented today.

## Alternatives considered

- **Default Standard**: rejected on cost — triples the monthly bill for a feature set most starter deployments don't use yet.
- **Make SKU a required variable with no default**: rejected — adds friction for the 80% case (someone trying the firewall scenario for the first time). Defaults should reflect the most common starting point.
