# VPN site-to-site connection — Bicep example

Wires a Local Network Gateway and IPsec connection to the VPN Gateway that the Launchpad foundation deploys. Run this **after** the foundation `vpn` or `full` scenario has deployed successfully.

## Usage

```bash
cd examples/vpn-connection/bicep

VPN_GW_ID=$(az deployment sub show \
  --name foundation-vpn \
  --query 'properties.outputs.vpnGatewayId.value' -o tsv)

VPN_RG=$(echo "$VPN_GW_ID" | cut -d/ -f5)

az deployment group create \
  --resource-group "$VPN_RG" \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters vpnGatewayId="$VPN_GW_ID" \
               sharedKey="$(az keyvault secret show --vault-name <kv-name> --name vpn-psk --query value -o tsv)"
```

## Inputs you need from the on-prem side

| Parameter           | Description                                                |
| ------------------- | ---------------------------------------------------------- |
| `vpnGatewayId`      | Foundation output `vpnGatewayId`                           |
| `peerIp`            | Public IP of the on-premises VPN device                    |
| `peerAddressSpaces` | Array of on-prem CIDR blocks reachable through the tunnel  |
| `sharedKey`         | Pre-shared key (sensitive — pull from Key Vault on deploy) |

## Notes

- BGP is **disabled** on the foundation VPN Gateway. Enabling BGP requires a foundation re-deploy with `enableBgp: true`.
- In `firewall` / `full` scenarios the spoke route table sends `0.0.0.0/0` through the firewall. To force spoke traffic destined for `peerAddressSpaces` to take the VPN, add UDR entries pointing those CIDRs to the gateway, or rely on gateway route propagation.
- Rotate the PSK by re-deploying with a new `sharedKey`; the connection is updated in place.
