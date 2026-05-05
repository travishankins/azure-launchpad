---
title: Glossary
description: Quick definitions of every Azure, networking, and governance term used across the Azure Launchpad docs.
---

A short, opinionated glossary of every term you'll see in this repo. Linked from scenario pages, the wizard, and the FAQ.

## Azure landing zone (ALZ)

A pre-built, opinionated environment in Azure that's secure, governed, scalable, and ready to host workloads on day one. Azure Launchpad is an SMB/SMEC-sized ALZ implementation aligned to the [Microsoft Cloud Adoption Framework (CAF)](https://learn.microsoft.com/azure/cloud-adoption-framework/).

## Cloud Adoption Framework (CAF)

Microsoft's official guidance for adopting Azure: strategy, plan, ready, adopt, govern, secure, manage. ALZ is the "ready" pillar's reference implementation. See [vs ALZ accelerator](/reference/vs-alz-accelerator/) for how this repo compares.

## Hub-spoke topology

A network pattern where a central **hub** VNet hosts shared services (firewall, VPN, DNS, monitoring) and one or more **spoke** VNets host workloads. Spokes peer to the hub, not to each other. Defaults in this repo:

- Hub: `10.0.0.0/23`
- Spoke: `10.0.2.0/23`

## Spoke

A workload VNet that connects to the hub via VNet peering. In this repo there's a single spoke (`vnet-spoke-<prefix>-<region>`) — add more by duplicating the spoke block in `infra/terraform/foundation/networking.tf` (or the Bicep equivalent).

## VNet peering

A non-transitive connection between two VNets in the same or different regions. Spoke ↔ hub peering uses gateway transit so the spoke can reach on-prem via the hub's VPN gateway.

## Gateway transit

A VNet peering setting that lets a peered VNet use the gateway in the other VNet (typically the hub). Without it, every spoke would need its own VPN gateway.

## NAT gateway

A managed outbound-only NAT service. Cheap (~$32/mo), no inspection. Used in the **baseline** scenario for spoke egress.

## Azure Firewall (Basic SKU)

Managed L3-L7 firewall with built-in HA. The **firewall** and **full** scenarios deploy the **Basic** SKU (~$295/mo) which trades off some features (no IDPS, no TLS inspection) for ~75 % cost savings vs Standard. Replaces the NAT gateway.

## Azure Firewall Manager

The umbrella product that manages firewall policies. Not used directly here — policies are attached to the firewall instance.

## VPN Gateway

Azure's managed IPsec/IKE site-to-site VPN endpoint. Lives in the hub's `GatewaySubnet`. The **vpn** and **full** scenarios deploy `VpnGw2AZ` Generation 2 (~$140/mo).

## GatewaySubnet

A specially-named subnet (`/27` or larger) required by Azure for VPN/ExpressRoute gateways. Don't put anything else in it.

## AzureFirewallSubnet / AzureFirewallManagementSubnet

Specially-named subnets (`/26` or larger) required by Azure Firewall. The Basic SKU requires both.

## User-defined route (UDR)

A custom route table attached to a subnet that overrides Azure's default routing. The firewall scenario attaches a UDR to the spoke that sends `0.0.0.0/0` to the firewall's private IP.

## Network Security Group (NSG)

A stateful L3-L4 firewall attached to subnets or NICs. This repo attaches NSGs to spoke subnets with a baseline deny-inbound, allow-outbound posture.

## Private Endpoint (PE)

A NIC inside a VNet that gets a private IP and resolves to a PaaS resource (Key Vault, Storage, etc.). Eliminates exposure of the resource's public endpoint. The Key Vault in the **baseline** scenario uses a PE in the spoke.

## Private DNS zone

A DNS zone hosted inside Azure that resolves PE names to private IPs (e.g. `privatelink.vaultcore.azure.net`). Auto-linked to the hub and spoke VNets.

## Recovery Services Vault (RSV)

The container for Azure Backup data — VM backups, file shares, SQL, etc. Deployed in the **baseline** scenario but with **no policy attached**; add one when you have workloads to protect.

## Log Analytics workspace (LAW)

The store for Azure Monitor logs. Diagnostic settings on hub VNet, spoke VNet, KV, and (when present) firewall + VPN gateway all flow here. Default retention 30 days.

## Diagnostic setting

The Azure resource that tells a service "send your logs / metrics here." Configured on every resource that produces useful telemetry.

## Automation Account

The container for Azure Automation runbooks (PowerShell, Python). Deployed in **baseline** for future use (secrets rotation, scheduled tasks). Linked to the LAW.

## Management Group (MG)

A container above subscriptions that lets you scope policy and RBAC across many subs at once. The opt-in module here deploys an ALZ-style hierarchy: `<prefix> → platform/{management,connectivity,identity,security} → landingzones/{corp,online,local}`.

## Azure Policy

Declarative rules (`audit`, `deny`, `deployIfNotExists`) applied to subscriptions or MGs. The opt-in MG module includes a starter policy catalog.

## Azure Verified Modules (AVM)

Microsoft's official, tested, version-pinned Terraform/Bicep modules at [aka.ms/avm](https://aka.ms/avm). This repo uses them where one exists; falls back to inline resources otherwise.

## OIDC federation

GitHub Actions → Azure auth using short-lived tokens, no client secret. Configured via federated credentials on the deploying app registration. CI workflows in this repo use OIDC exclusively.

## Conventional Commits

A spec for commit messages (`feat:`, `fix:`, `docs:`, …) that drives automated changelogs and version bumps. Required for PRs in this repo — see [`CONTRIBUTING.md`](https://github.com/travishankins/azure-launchpad/blob/main/CONTRIBUTING.md).

## Workspace (Terraform)

A named state slot. This repo uses one workspace per scenario (`baseline`, `firewall`, `vpn`, `full`) so each is isolated. Switching workspaces does **not** copy state.

## Scenario (this repo)

One of `baseline`, `firewall`, `vpn`, `full`. Each is a tfvars / bicepparam file that toggles which optional modules are deployed. See [Scenarios](/scenarios/).

## SMB / SMEC

The audience for this project.

- **SMB** — small and midsized business; loosely, < 1 000 employees, single-region, lean platform team.
- **SMEC** — small and midsized enterprises and corps; loosely, 1 000-10 000 employees, multi-region appetite, dedicated platform team. Both can run this foundation; the **full** scenario plus the optional MG module is the natural shape for SMEC.
