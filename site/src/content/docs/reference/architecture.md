---
title: Architecture
description: Hub-spoke topology shared by all Azure Launchpad scenarios.
---

All four scenarios share the same hub-spoke topology and naming. The diagrams below show what changes between them.

## Address plan

| Network    | CIDR          | Subnets                                                                                                                                     |
| ---------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Hub VNet   | `10.0.0.0/23` | `AzureFirewallSubnet` (`/26`), `GatewaySubnet` (`/26`), `default` (`/26`), `AzureFirewallManagementSubnet` (`/26`, firewall scenarios only) |
| Spoke VNet | `10.0.2.0/23` | `snet-workload` (`/26`)                                                                                                                     |

## Scenarios at a glance

| Capability                            | baseline | firewall | vpn | full |
| ------------------------------------- | :------: | :------: | :-: | :--: |
| Hub + spoke VNets + peering           |    ✅    |    ✅    | ✅  |  ✅  |
| Spoke egress via NAT Gateway          |    ✅    |    —     | ✅  |  —   |
| Spoke egress via Azure Firewall       |    —     |    ✅    |  —  |  ✅  |
| Route Table 0/0 → firewall private IP |    —     |    ✅    |  —  |  ✅  |
| VPN Gateway (S2S to on-prem)          |    —     |    —     | ✅  |  ✅  |
| Gateway transit on peering            |    —     |    —     | ✅  |  ✅  |
| Key Vault + Private Endpoint          |    ✅    |    ✅    | ✅  |  ✅  |
| Log Analytics + Automation + RSV      |    ✅    |    ✅    | ✅  |  ✅  |

## Baseline

Spoke egresses to internet through its own NAT Gateway. Hub is mostly an empty VNet — present so future scenarios can promote in place without re-IP'ing.

```mermaid
flowchart LR
    subgraph Hub["Hub VNet 10.0.0.0/23"]
      H_default["default subnet"]
    end
    subgraph Spoke["Spoke VNet 10.0.2.0/23"]
      S_workload["snet-workload"]
      KV["Key Vault PE"]
      NAT["NAT Gateway"]
      KV --- S_workload
      S_workload --- NAT
    end
    Hub <-- "VNet peering" --> Spoke
    NAT --> Internet(("Internet"))
    LA["Log Analytics"]:::shared
    RSV["Recovery Vault"]:::shared
    classDef shared fill:#eef,stroke:#88a
```

## Firewall

Spoke egress is forced through Azure Firewall Basic in the hub. NAT Gateway is **not** deployed in the spoke — the firewall's public IPs are the egress identity.

```mermaid
flowchart LR
    subgraph Hub["Hub VNet"]
      AF["Azure Firewall Basic<br/>(private IP 10.0.0.4)"]
      MGT["AzureFirewallManagementSubnet"]
      AF --- MGT
    end
    subgraph Spoke["Spoke VNet"]
      S_workload["snet-workload"]
      KV["Key Vault PE"]
      RT["Route Table<br/>0.0.0.0/0 → 10.0.0.4"]
      KV --- S_workload
      S_workload --- RT
    end
    Hub <-- "VNet peering" --> Spoke
    RT -- "0/0" --> AF
    AF --> Internet(("Internet"))
```

## VPN

Spoke egresses to internet via NAT (same as baseline). On-prem reaches the spoke through a VPN Gateway in the hub. Peering uses **gateway transit**.

```mermaid
flowchart LR
    OnPrem(("On-prem network"))
    subgraph Hub["Hub VNet"]
      VPN["VPN Gateway VpnGw2AZ"]
    end
    subgraph Spoke["Spoke VNet"]
      S_workload["snet-workload"]
      KV["Key Vault PE"]
      NAT["NAT Gateway"]
      KV --- S_workload
      S_workload --- NAT
    end
    OnPrem <-- "IPsec S2S" --> VPN
    Hub <-- "peering<br/>(gateway transit)" --> Spoke
    NAT --> Internet(("Internet"))
```

## Full

Both firewall and VPN. Spoke egress goes through the firewall; on-prem reaches the spoke through the VPN gateway via gateway transit.

```mermaid
flowchart LR
    OnPrem(("On-prem"))
    subgraph Hub["Hub VNet"]
      AF["Azure Firewall Basic<br/>(10.0.0.4)"]
      VPN["VPN Gateway VpnGw2AZ"]
    end
    subgraph Spoke["Spoke VNet"]
      S_workload["snet-workload"]
      KV["Key Vault PE"]
      RT["Route Table<br/>0.0.0.0/0 → 10.0.0.4"]
      KV --- S_workload
      S_workload --- RT
    end
    OnPrem <-- "IPsec S2S" --> VPN
    Hub <-- "peering<br/>(gateway transit)" --> Spoke
    RT --> AF --> Internet(("Internet"))
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
