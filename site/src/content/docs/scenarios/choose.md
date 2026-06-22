---
title: Choose a scenario
description: A short decision guide to pick the right Azure Launchpad scenario based on egress, hybrid connectivity, and subscription model.
---

Not sure which scenario fits? Answer three questions.

## 1. Do you need outbound traffic inspection?

A central egress chokepoint that logs and (optionally) filters all internet-bound traffic from the spoke.

- **No** → start with **Baseline** or **VPN** (NAT Gateway only).
- **Yes** → use **Firewall** or **Full** (Azure Firewall Basic).

## 2. Do you need site-to-site (hybrid) connectivity?

A VPN Gateway that terminates an IPsec tunnel from the customer's on-prem network or another cloud.

- **No** → stick with **Baseline** or **Firewall**.
- **Yes** → use **VPN** or **Full** (adds a `VpnGw2AZ` gateway).

## 3. Single subscription or split across multiple?

- **Single subscription** → any of the four scenarios above land in one sub.
- **Connectivity / Management / Landing Zone in separate subs** → see [Multi-subscription (ALZ split)](/scenarios/multi-subscription/).

## Decision flow

```mermaid
flowchart TD
  A[Need outbound traffic inspection?] -->|No| B[Need site-to-site VPN?]
  A -->|Yes| C[Need site-to-site VPN?]
  B -->|No| Baseline([Baseline ~$48/mo])
  B -->|Yes| VPN([VPN ~$327/mo])
  C -->|No| Firewall([Firewall ~$336/mo])
  C -->|Yes| Full([Full ~$616/mo])
  Baseline --> S{Split across<br/>subscriptions?}
  VPN --> S
  Firewall --> S
  Full --> S
  S -->|No| Single[Use single-sub scenario as-is]
  S -->|Yes| Multi([Multi-subscription ALZ split])
```

## Quick reference

| If you need…                          | Pick                                              |
| ------------------------------------- | ------------------------------------------------- |
| Lowest cost, dev/test, small workload | [Baseline](/scenarios/baseline/)                  |
| Egress filtering / compliance         | [Firewall](/scenarios/firewall/)                  |
| Hybrid connectivity to on-prem        | [VPN](/scenarios/vpn/)                            |
| Both egress filtering and hybrid      | [Full](/scenarios/full/)                          |
| Separate subs per ALZ layer           | [Multi-subscription](/scenarios/multi-subscription/) |

Once you've picked a scenario, the [configuration generator](/wizard/) generates the matching `tfvars` or `bicepparam` file.
