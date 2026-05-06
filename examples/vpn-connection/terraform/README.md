# VPN site-to-site connection — Terraform example

Wires a Local Network Gateway and IPsec connection to the VPN Gateway that the Launchpad foundation deploys. Run this **after** the foundation `vpn` or `full` scenario has applied successfully.

## Usage

```bash
cd examples/vpn-connection/terraform

terraform init

terraform apply \
  -var "vpn_gateway_id=$(terraform -chdir=../../../infra/terraform/foundation output -raw vpn_gateway_id)" \
  -var "peer_ip=203.0.113.10" \
  -var 'peer_address_spaces=["10.100.0.0/16"]' \
  -var "shared_key=$(az keyvault secret show --vault-name <kv-name> --name vpn-psk --query value -o tsv)"
```

## Inputs you need from the on-prem side

| Variable              | Description                                                    |
| --------------------- | -------------------------------------------------------------- |
| `vpn_gateway_id`      | Foundation output `vpn_gateway_id`                             |
| `peer_ip`             | Public IP of the on-premises VPN device                        |
| `peer_address_spaces` | List of on-prem CIDR blocks reachable through the tunnel       |
| `shared_key`          | Pre-shared key (sensitive — pull from Key Vault, never commit) |

## Notes

- BGP is **disabled** on the foundation VPN Gateway. Enabling BGP requires a foundation re-deploy with `bgp_enabled = true`.
- In `firewall` / `full` scenarios the spoke route table sends `0.0.0.0/0` through the firewall. If you want spoke traffic destined for `peer_address_spaces` to take the VPN, add UDR entries pointing those CIDRs to the gateway, or rely on gateway route propagation.
- Rotate the PSK by re-applying with a new `shared_key` value; the connection is updated in place.
