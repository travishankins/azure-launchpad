---
title: VPN scenario
description: ~$187/month — adds a zone-redundant VPN Gateway for site-to-site connectivity.
---

**Approx. cost:** ~$187 / month (`VpnGw1AZ`).

## What you get

Everything in [baseline](/scenarios/baseline/) **plus**:

- VPN public IP (Standard, zonal)
- `azurerm_virtual_network_gateway` (`Vpn` / `RouteBased` / `VpnGw1AZ` / Generation 2)
- Hub ↔ Spoke VNet peering with **gateway transit** enabled (spoke uses the hub's gateway)

NAT Gateway on the spoke is kept for outbound internet (only the firewall scenarios disable it).

## What's intentionally deferred

To keep the module deployable without customer-side info, the following are **not** created automatically:

- `azurerm_local_network_gateway` — needs the customer's on-premises peer IP + CIDR(s)
- `azurerm_virtual_network_gateway_connection` — needs the shared key (PSK)

Add them in a small post-deploy file once those values are known. Example template:

```hcl
resource "azurerm_local_network_gateway" "onprem" {
  name                = "lng-onprem-${local.suffix}"
  resource_group_name = azurerm_resource_group.this["hub"].name
  location            = var.location
  gateway_address     = "<customer-public-ip>"
  address_space       = var.on_premises_address_space
}

resource "azurerm_virtual_network_gateway_connection" "s2s" {
  name                       = "cn-s2s-${local.suffix}"
  resource_group_name        = azurerm_resource_group.this["hub"].name
  location                   = var.location
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn[0].id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id
  shared_key                 = var.vpn_shared_key # mark sensitive
}
```

## When to choose it

- The customer needs hybrid connectivity (file shares, AD DS, monitoring agents)
- No requirement for centralized egress inspection
- Cost-sensitive (no firewall)

## Deploy

```bash
terraform workspace select -or-create vpn
terraform apply -var-file=scenarios/vpn.tfvars
```
