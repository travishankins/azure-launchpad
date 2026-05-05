# 0006. Multi-subscription deployment mode

- **Status**: Accepted
- **Date**: 2026-05-05
- **Supersedes (partially)**: ADR 0001 (workspaces) — workspaces still gate scenarios; multi-sub adds an orthogonal axis.

## Context

[ADR 0001](0001-scenarios-as-workspaces.md) and the v1 foundation deployed everything into a single subscription. That works for the SMB starting point but doesn't match the [Microsoft Azure Landing Zones reference architecture](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/) which separates **platform** workloads (connectivity, management, identity) from **application** workloads (corp / online landing zones) into distinct subscriptions.

Customers asked for the ALZ-aligned split without losing the single-sub starter. We needed both.

## Decision

Add a **`deployment_mode`** variable (`single` | `multi`) and three optional layer-specific subscription IDs to the Terraform foundation:

- `connectivity_subscription_id` — hub VNet, Azure Firewall, VPN Gateway, Private DNS
- `management_subscription_id` — Log Analytics, Automation Account, Recovery Services Vault, workbook, budget
- `landingzone_subscription_id` — spoke VNet, NAT Gateway, Key Vault, future workloads

In `single` mode (the default) all three resolve to `subscription_id` — code paths and behaviour are identical to v1, no breaking change. In `multi` mode each layer lands in its own subscription via three Terraform **provider aliases** (`azurerm.connectivity`, `azurerm.management`, `azurerm.landingzone`).

For Bicep, multi-subscription deployment is implemented as **three separate `az deployment sub create` calls** (no tenant-scope orchestrator) wrapped by [`scripts/deploy-multi-sub.sh`](../../scripts/deploy-multi-sub.sh):

1. Connectivity (hub VNet, no peering yet)
2. Landing-zone (spoke VNet + spoke→hub peering using hub VNet ID)
3. Connectivity again (hub→spoke peering using spoke VNet ID)
4. Management (independent)

## Consequences

### Wins

- Existing single-sub customers see zero churn — `deployment_mode = "single"` is the default, all variables backward-compatible.
- Multi-sub deploys match ALZ guidance: platform isolated from workloads, separate billing/RBAC boundaries per layer, room to grow into per-LZ subs.
- Plan-mode test asserts both modes still produce the right resource group counts per layer.
- `Contributor` per sub is enough — no `Owner` at tenant root, no Management Group dependencies.

### Costs / limits

- **Bicep multi-sub uses a deploy wrapper, not a tenant-scope orchestrator.** All four scenarios (`baseline` / `firewall` / `vpn` / `full`) are supported, but they require multiple `az deployment sub create` calls in order to thread cross-sub references (firewall private IP, hub VNet ID, spoke VNet ID, PDZ ID). The [`scripts/deploy-multi-sub.sh`](../../scripts/deploy-multi-sub.sh) wrapper runs the four steps for you. **Terraform multi-sub does it in a single `apply`** because provider aliases are first-class — pick the stack that matches your team.
- Cross-sub **VNet peering** requires the principal deploying the spoke side to have `Network Contributor` on the hub VNet in the connectivity sub. Documented in the multi-subscription scenario page.
- Cross-sub **Private DNS Zone** linking to the spoke VNet (so KV PE name resolution works from spoke workloads) requires `Network Contributor` on the PDZ in the connectivity sub. Both stacks now wire this automatically — Terraform via the `azurerm.connectivity` alias, Bicep via the second connectivity-layer pass that the wrapper script triggers.
- The Wizard now asks **3 subscription IDs instead of 1** when multi-sub is selected. Adds friction, but the answer set is genuinely 3-D.
- The Terraform state file key includes a `.multi` suffix for multi-sub mode (`foundation.<scenario>.multi.tfstate`) so single and multi state files don't collide for the same scenario.

## Alternatives considered

- **Hard cut to multi-sub only**: rejected — would force every existing single-sub customer to refactor. The audience starts small.
- **Separate root modules per layer (no provider aliases)**: rejected for Terraform — would mean three state files and three deploy commands even in single-sub mode. The provider-alias approach lets one apply do everything in single mode while still cleanly splitting in multi mode. _Bicep_ uses this pattern (separate templates) precisely because Bicep doesn't have provider aliases.
- **Tenant-scope Bicep orchestrator** (`targetScope = 'tenant'`): rejected as the default — requires `Owner` or `Management Group Contributor` at Tenant Root which most SMB principals don't have. Could be added as an advanced option later.
- **Identity sub** as a fourth layer: deferred — the Identity sub conventionally hosts AD DS / Entra DS, neither of which the foundation deploys today. Adding the variable without resources would be noise.
