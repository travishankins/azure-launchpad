---
title: Full scenario
description: ~$476/month — Firewall + VPN combined. Highest control.
---

**Approx. cost:** ~$476 / month (Firewall Basic + `VpnGw1AZ`).

## What you get

Everything from [Firewall](/scenarios/firewall/) **and** [VPN](/scenarios/vpn/):

- Spoke route table sends `0.0.0.0/0` through the firewall
- VPN Gateway on `GatewaySubnet`, gateway transit enabled across hub ↔ spoke peering
- NAT Gateway is **not** deployed — firewall is the sole egress path

## When to choose it

- Regulated workloads or customer compliance needs
- Hybrid connectivity **and** centralized egress inspection
- Future expansion expected (more spokes can attach via additional peerings)

## Deploy

```bash
terraform workspace select -or-create full
terraform apply -var-file=scenarios/full.tfvars
```

## Operational notes

- Tighten the empty firewall policy to allow only required FQDNs/CIDRs before pushing real workloads
- Add a `azurerm_local_network_gateway` + connection (see [VPN scenario](/scenarios/vpn/) for template)
- Enable diagnostic settings on the firewall + VPN gateway pointing at the Log Analytics workspace already deployed
