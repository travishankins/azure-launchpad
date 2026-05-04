---
title: Compare scenarios
description: Pick the right SMB Foundations landing zone scenario for your customer.
---

Every scenario shares the same hub-spoke topology. You only add what the customer actually needs.

|                                | Baseline | Firewall | VPN   | Full  |
| ------------------------------ | -------- | -------- | ----- | ----- |
| **Approx. cost / month**       | ~$48     | ~$336    | ~$187 | ~$476 |
| Hub + spoke VNets              | ✅       | ✅       | ✅    | ✅    |
| Key Vault + Private Endpoint   | ✅       | ✅       | ✅    | ✅    |
| Log Analytics + Recovery Vault | ✅       | ✅       | ✅    | ✅    |
| NAT Gateway (egress)           | ✅       | —        | ✅    | —     |
| Hub ↔ Spoke peering            | —        | ✅       | ✅    | ✅    |
| Azure Firewall (Basic)         | —        | ✅       | —     | ✅    |
| Spoke UDR → Firewall           | —        | ✅       | —     | ✅    |
| VPN Gateway (`VpnGw1AZ`)       | —        | —        | ✅    | ✅    |

## Decision shortcuts

- **Outbound inspection required?** → choose `firewall` or `full`.
- **Site-to-site connectivity?** → choose `vpn` or `full`.
- **Both?** → `full`.
- **Neither?** → `baseline`.

The [wizard](/smb-foundations/wizard/) walks you through this in 30 seconds and emits a tfvars file.
