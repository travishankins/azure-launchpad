---
title: Compare scenarios
description: Pick the right Azure Launchpad landing zone scenario for your organization.
---

:::tip[Not sure where to start?]
The [Choose a scenario](/scenarios/choose/) decision guide narrows it down in three questions.
:::

Every scenario shares the same hub-spoke topology. You only add what the customer actually needs.

|                                | Baseline | Firewall | VPN   | Full  |
| ------------------------------ | -------- | -------- | ----- | ----- |
| **Approx. cost / month**       | ~$48     | ~$336    | ~$327 | ~$616 |
| Hub + spoke VNets              | ✅       | ✅       | ✅    | ✅    |
| Key Vault + Private Endpoint   | ✅       | ✅       | ✅    | ✅    |
| Log Analytics + Recovery Vault | ✅       | ✅       | ✅    | ✅    |
| NAT Gateway (egress)           | ✅       | —        | ✅    | —     |
| Hub ↔ Spoke peering            | —        | ✅       | ✅    | ✅    |
| Azure Firewall (Basic)         | —        | ✅       | —     | ✅    |
| Spoke UDR → Firewall           | —        | ✅       | —     | ✅    |
| VPN Gateway (`VpnGw2AZ`)       | —        | —        | ✅    | ✅    |

## Decision shortcuts

- **Outbound inspection required?** → choose `firewall` or `full`.
- **Site-to-site connectivity?** → choose `vpn` or `full`.
- **Both?** → `full`.
- **Neither?** → `baseline`.

The [configuration generator](/wizard/) walks you through this in about 30 seconds and emits a parameter file plus preview, apply, and verification commands.
