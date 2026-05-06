---
title: Post-deploy VPN connection
description: Wire a site-to-site IPsec tunnel to the Launchpad foundation VPN Gateway after the vpn or full scenario has deployed.
---

The Launchpad foundation provisions the VPN Gateway (`VpnGw2AZ`) but stops short of wiring up the on-premises side. That part needs customer-specific inputs — peer IP, on-prem CIDRs, pre-shared key — which is why it lives outside the foundation deploy. See [Non-goals](/reference/non-goals/) for the full reasoning.

This page shows the minimal Terraform and Bicep needed to finish the job.

## What the foundation already gives you

After a successful `vpn` or `full` deploy, the following outputs are available:

| Terraform output | Bicep output    | Description                              |
| ---------------- | --------------- | ---------------------------------------- |
| `vpn_gateway_id` | `vpnGatewayId`  | Resource ID of the VPN Gateway           |

The gateway itself is configured as:

- **SKU:** `VpnGw2AZ` (Generation 2, route-based)
- **BGP:** disabled (enabling requires a foundation re-deploy)
- **Active-active:** off

## What you need from the on-prem side

- Public IP address of the on-prem VPN device (peer IP).
- One or more on-prem CIDR blocks reachable through the tunnel.
- A pre-shared key (PSK). Store it in Key Vault, not in source control.

## Terraform example

Located in [`examples/vpn-connection/terraform/`](https://github.com/travishankins/azure-launchpad/tree/main/examples/vpn-connection/terraform).

```hcl
data "azurerm_virtual_network_gateway" "vpn" {
  name                = element(split("/", var.vpn_gateway_id), length(split("/", var.vpn_gateway_id)) - 1)
  resource_group_name = element(split("/", var.vpn_gateway_id), 4)
}

resource "azurerm_local_network_gateway" "onprem" {
  name                = "lng-${var.connection_name}"
  resource_group_name = data.azurerm_virtual_network_gateway.vpn.resource_group_name
  location            = data.azurerm_virtual_network_gateway.vpn.location
  gateway_address     = var.peer_ip
  address_space       = var.peer_address_spaces
}

resource "azurerm_virtual_network_gateway_connection" "onprem" {
  name                       = "cn-${var.connection_name}"
  resource_group_name        = data.azurerm_virtual_network_gateway.vpn.resource_group_name
  location                   = data.azurerm_virtual_network_gateway.vpn.location
  type                       = "IPsec"
  virtual_network_gateway_id = data.azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id
  shared_key                 = var.shared_key
  bgp_enabled                = false
}
```

Apply with the gateway ID piped from the foundation outputs:

```bash
cd examples/vpn-connection/terraform
terraform init
terraform apply \
  -var "subscription_id=$ARM_SUBSCRIPTION_ID" \
  -var "vpn_gateway_id=$(terraform -chdir=../../../infra/terraform/foundation output -raw vpn_gateway_id)" \
  -var "peer_ip=203.0.113.10" \
  -var 'peer_address_spaces=["10.100.0.0/16"]' \
  -var "shared_key=$(az keyvault secret show --vault-name <kv-name> --name vpn-psk --query value -o tsv)"
```

## Bicep example

Located in [`examples/vpn-connection/bicep/`](https://github.com/travishankins/azure-launchpad/tree/main/examples/vpn-connection/bicep).

```bicep
resource vpnGw 'Microsoft.Network/virtualNetworkGateways@2024-05-01' existing = {
  name: last(split(vpnGatewayId, '/'))
}

resource lng 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: 'lng-${connectionName}'
  location: resourceGroup().location
  properties: {
    gatewayIpAddress: peerIp
    localNetworkAddressSpace: { addressPrefixes: peerAddressSpaces }
  }
}

resource connection 'Microsoft.Network/connections@2024-05-01' = {
  name: 'cn-${connectionName}'
  location: resourceGroup().location
  properties: {
    connectionType: 'IPsec'
    enableBgp: false
    sharedKey: sharedKey
    virtualNetworkGateway1: { id: vpnGw.id, properties: {} }
    localNetworkGateway2:   { id: lng.id,   properties: {} }
  }
}
```

Deploy at the hub resource-group scope:

```bash
VPN_GW_ID=$(az deployment sub show --name foundation-vpn \
  --query 'properties.outputs.vpnGatewayId.value' -o tsv)
VPN_RG=$(echo "$VPN_GW_ID" | cut -d/ -f5)

az deployment group create \
  --resource-group "$VPN_RG" \
  --template-file examples/vpn-connection/bicep/main.bicep \
  --parameters examples/vpn-connection/bicep/main.bicepparam \
  --parameters vpnGatewayId="$VPN_GW_ID" \
               sharedKey="$(az keyvault secret show --vault-name <kv-name> --name vpn-psk --query value -o tsv)"
```

## Routing considerations

In the `firewall` and `full` scenarios the spoke route table sends `0.0.0.0/0` through the Azure Firewall. If you want spoke traffic destined for the on-prem CIDRs to take the VPN tunnel instead, you have two options:

1. Add explicit UDR entries on the spoke route table that send each on-prem CIDR to the VPN Gateway (`nextHopType: VirtualNetworkGateway`).
2. Enable BGP on the foundation gateway (requires re-deploy) so on-prem routes propagate automatically.

In the `vpn`-only scenario (no firewall) gateway route propagation handles this by default.

## Validate

```bash
az network vpn-connection show \
  --resource-group "$VPN_RG" \
  --name cn-onprem \
  --query '{status:connectionStatus, ingress:ingressBytesTransferred, egress:egressBytesTransferred}'
```

A healthy tunnel reports `connectionStatus: Connected` and non-zero byte counters once traffic is flowing.

## Rotating the PSK

Re-run `terraform apply` (or `az deployment group create`) with a new `shared_key` / `sharedKey` value. The connection updates in place; existing tunnels rekey on the next IKE renegotiation.
