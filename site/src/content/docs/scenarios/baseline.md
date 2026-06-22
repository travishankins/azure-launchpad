---
title: Baseline scenario
description: ~$48/month — hub-spoke with NAT egress and shared services.
---

**Approx. cost:** ~$48 / month.

## What you get

- 6 resource groups (hub, spoke-prod, monitor, backup, security, migrate)
- Hub VNet `10.0.0.0/23` with `AzureFirewallSubnet`, `GatewaySubnet`, `default`
- Spoke VNet `10.0.2.0/23` with `snet-workload`
- NAT Gateway on the spoke (zone-redundant, Standard SKU) for outbound internet
- Private DNS zone `privatelink.vaultcore.azure.net` linked to both VNets
- Key Vault with Private Endpoint into the spoke (RBAC, public access disabled)
- Log Analytics workspace (`PerGB2018`, 0.5 GB/day quota)
- Automation Account (Basic)
- Recovery Services Vault (Standard, GeoRedundant, soft-delete on)

## What you don't get

- No Azure Firewall, no UDRs
- No hub ↔ spoke peering (workloads only need outbound + Azure-private)
- No VPN Gateway

## When to choose it

- You're standing up a low-cost shell for a small workload
- You don't need centralized egress inspection
- The customer has no on-premises footprint to connect to

## Deploy

Use the [configuration generator](/wizard/) and select the baseline options. Its commands run preflight, save a preview, apply only after review, and verify the result. See the [Terraform](/getting-started/quick-start/) or [Bicep](/getting-started/quick-start-bicep/) quick start.
