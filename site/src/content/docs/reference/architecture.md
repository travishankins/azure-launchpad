---
title: Architecture
description: Hub-spoke topology shared by all Azure Launchpad (SMEC Edition) scenarios.
---

All four scenarios share the same hub-spoke topology and naming. The diagrams below show what changes between them.

## Address plan

| Network    | CIDR          | Subnets                                                                                                                                     |
| ---------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Hub VNet   | `10.0.0.0/23` | `AzureFirewallSubnet` (`/26`), `GatewaySubnet` (`/26`), `default` (`/26`), `AzureFirewallManagementSubnet` (`/26`, firewall scenarios only) |
| Spoke VNet | `10.0.2.0/23` | `snet-workload` (`/26`)                                                                                                                     |

## Baseline

```mermaid
flowchart LR
    subgraph Hub[Hub VNet 10.0.0.0/23]
      H_default[default subnet]
    end
    subgraph Spoke[Spoke VNet 10.0.2.0/23]
      S_workload[snet-workload]
      NAT[NAT Gateway]
      S_workload --- NAT
    end
    NAT --> Internet((Internet))
    KV[Key Vault PE] --- S_workload
    LA[Log Analytics]:::shared
    RSV[Recovery Vault]:::shared
    classDef shared fill:#eef
```

## Firewall

```mermaid
flowchart LR
    subgraph Hub[Hub VNet]
      AF[Azure Firewall Basic]
      MGT[ManagementSubnet]
      AF --- MGT
    end
    subgraph Spoke[Spoke VNet]
      S_workload[snet-workload]
      RT[Route Table 0/0 → AF]
      S_workload --- RT
    end
    Spoke <-- peering --> Hub
    S_workload -- 0/0 --> AF
    AF --> Internet((Internet))
```

## VPN

```mermaid
flowchart LR
    subgraph Hub[Hub VNet]
      VPN[VPN Gateway VpnGw2AZ]
    end
    subgraph Spoke[Spoke VNet]
      S_workload[snet-workload]
      NAT[NAT Gateway]
      S_workload --- NAT
    end
    Spoke <-- peering<br/>(gateway transit) --> Hub
    OnPrem((On-prem network)) <-- IPsec --> VPN
    NAT --> Internet((Internet))
```

## Full

```mermaid
flowchart LR
    subgraph Hub[Hub VNet]
      AF[Azure Firewall Basic]
      VPN[VPN Gateway VpnGw2AZ]
    end
    subgraph Spoke[Spoke VNet]
      S_workload[snet-workload]
      RT[Route Table 0/0 → AF]
    end
    Spoke <-- peering<br/>(gateway transit) --> Hub
    S_workload --> RT
    RT --> AF --> Internet((Internet))
    OnPrem((On-prem)) <-- IPsec --> VPN
```

## Module composition

```
infra/terraform/foundation/
├── terraform.tf            # required_providers + Azure backend
├── providers.tf            # azurerm + azapi configuration
├── variables.tf            # subscription_id, scenario, location, prefix, on-prem CIDRs
├── locals.tf               # scenario flags (use_firewall, use_vpn, use_nat, use_peering)
├── resource_groups.tf      # 6 RGs via for_each
├── modules.networking.tf   # VNets (AVM), NAT, peering, Private DNS
├── modules.security.tf     # Key Vault (AVM) + PE
├── modules.monitoring.tf   # Log Analytics + Automation + RSV (AVM)
├── modules.firewall.tf     # count = use_firewall — Firewall, mgmt subnet, route table
├── modules.vpn.tf          # count = use_vpn — VPN GW + PIP
├── outputs.tf
├── scenarios/*.tfvars      # one file per scenario
└── tests/*.tftest.hcl      # plan-mode assertions per scenario
```
