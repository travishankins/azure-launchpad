---
title: Firewall scenario
description: ~$336/month — adds Azure Firewall (Basic) for centralized egress filtering.
---

**Approx. cost:** ~$336 / month (driven by Azure Firewall Basic).

## What you get

Everything in [baseline](/azure-launchpad/scenarios/baseline/) **except** the spoke NAT Gateway, **plus**:

- `AzureFirewallManagementSubnet` carved from the hub `/23` (required by Firewall Basic)
- Azure Firewall (Basic SKU, zone-redundant `1/2/3`) with two data PIPs + management PIP
- Empty Firewall Policy (Basic) — extend with rule collections as needed
- Hub ↔ Spoke VNet peering (forwarded traffic enabled)
- Spoke route table forcing `0.0.0.0/0` → firewall private IP, applied to `snet-workload`

## When to choose it

- The customer requires managed egress filtering / TLS-less L4 inspection
- You want central audit logging for all outbound flows
- No on-premises connectivity needed

## Deploy

```bash
terraform workspace select -or-create firewall
terraform apply -var-file=scenarios/firewall.tfvars
```

> **Note** — if you upgrade Firewall Basic → Standard later, change `sku_tier` in `modules.firewall.tf` and re-apply. The mgmt subnet/PIP can stay (Basic-only requirement) or be removed.
