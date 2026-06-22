---
title: Multi-subscription (ALZ split)
description: ALZ-aligned deployment of the Azure Launchpad foundation across Connectivity, Management, and Landing-Zone subscriptions — when to use it, how it works, and how to deploy it with Terraform or Bicep.
---

The foundation deploys in one of two modes:

| Mode       | Subs | Best for                                                                                |
| ---------- | :--: | --------------------------------------------------------------------------------------- |
| **single** |  1   | The SMB starter. Everything lands in one subscription. **This is the default.**         |
| **multi**  |  3   | ALZ-aligned platform/workload separation: Connectivity / Management / Landing-Zone subs |

This page covers `multi` mode end-to-end: when to pick it, how the layers split, the cross-subscription wiring under the hood, the deploy workflow for both Terraform and Bicep, verification, and day-2 operations. Every other page in this site assumes single-sub — read those first if you're not sure which mode you want.

> **TL;DR.** Multi-sub mode runs the foundation across three subscriptions that match the [Microsoft Cloud Adoption Framework's Azure Landing Zones reference](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/). Terraform handles it in one `terraform apply` using provider aliases. Bicep handles it via a 4-step `az deployment sub create` sequence wrapped in [`scripts/deploy-multi-sub.sh`](https://github.com/travishankins/azure-launchpad/blob/main/scripts/deploy-multi-sub.sh). Both stacks support all four scenarios (`baseline` / `firewall` / `vpn` / `full`).

## Should you use multi-sub mode?

| Pick `single` if…                                           | Pick `multi` if…                                                                                      |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| You have one Azure subscription today                       | You already have (or can create) three subscriptions                                                  |
| Your team is one or two engineers wearing every hat         | You have a clear split between platform owners and workload owners                                    |
| You don't need separate billing for networking vs workloads | You want per-layer chargeback (cost center per sub)                                                   |
| You're deploying for a single tenant / single business unit | You're standing up a foundation that other teams will land workloads into                             |
| You don't want to think about cross-sub RBAC                | You're comfortable granting `Contributor` on each sub and `Network Contributor` for cross-sub peering |
| You want the simplest possible migration / teardown story   | You want a foundation you can grow into Microsoft's ALZ over the next 12–24 months                    |

**There is no architectural penalty for starting in `single` mode.** The same Bicep and Terraform code paths run in both modes — multi just routes resources to different subscriptions. If you outgrow single-sub, see [Migrating from single → multi](#migrating-from-single--multi) below.

## Why three subscriptions?

ALZ separates the foundation along **lifecycle and ownership boundaries**:

- **Connectivity** is a long-lived platform asset. Hub VNet, firewall, VPN gateway, and Private DNS rarely change once deployed. They're owned by the network team. Putting them in their own sub means workload teams can't accidentally break them, and a workload outage doesn't risk ripping out the firewall.
- **Management** holds the observability and recovery substrate — Log Analytics, Automation, Recovery Services Vault, budgets, workbook. These are owned by the platform/SRE team and consumed by every other sub. Isolating them keeps audit/compliance scope clean and makes it easy to point new subs at the same shared LAW.
- **Landing-Zone** is where workloads actually live — spoke VNet, Key Vault, application resource groups. This sub is the one that changes the most. Failing here doesn't take out the platform.

Microsoft's full ALZ reference adds an **Identity** sub (AD DS / Entra DS) and per-LZ subs for `corp` / `online`. The foundation doesn't deploy identity resources today, so the Identity sub isn't created — see the [Identity question](#why-isnt-there-an-identity-sub) below.

## Architecture

```text
┌──────────────────────────────────────┐   ┌──────────────────────────────────┐
│  Connectivity sub                    │   │  Management sub                  │
│                                      │   │                                  │
│  rg-hub-<suffix>                     │   │  rg-monitor-<suffix>             │
│  ├─ Hub VNet (10.0.0.0/23)           │   │  ├─ Log Analytics workspace      │
│  ├─ AzureFirewallSubnet      *fw     │   │  ├─ Automation Account           │
│  ├─ AzureFirewallManagement  *fw     │   │  └─ (opt) workbook + budget      │
│  ├─ GatewaySubnet            *vpn    │   │                                  │
│  ├─ default                          │   │  rg-backup-<suffix>              │
│  ├─ Azure Firewall (Basic)   *fw     │   │  └─ Recovery Services Vault      │
│  ├─ VPN Gateway (VpnGw2AZ)   *vpn    │   │                                  │
│  └─ Private DNS Zone (KV)            │   └──────────────────────────────────┘
│      ├─ link → hub VNet                                  ▲
│      └─ link → spoke VNet  ⇠─── cross-sub link  ─────┐   │ diagnostics
└──────────────────────────────────────┘                │   │ (LAW resource ID)
                  ▲                                     │   │
                  │ peer-hub-to-spoke   ▲ peer-spoke-to-hub
                  │ (allowGatewayTransit│
                  │  = true if VPN)     │
┌─────────────────┴────────────────────────────────────┴──────────────────────┐
│  Landing-Zone sub                                                            │
│                                                                              │
│  rg-spoke-prod-<suffix>                                                      │
│  ├─ Spoke VNet (10.0.2.0/23)                                                 │
│  ├─ snet-workload                                                            │
│  │   ├─ NAT Gateway        (baseline / vpn)                                  │
│  │   └─ Route Table → firewall private IP   (firewall / full)                │
│  └─ peer-spoke-to-hub                                                        │
│                                                                              │
│  rg-security-<suffix>                                                        │
│  └─ Key Vault + Private Endpoint (PDZ wired from connectivity sub)           │
│                                                                              │
│  rg-migrate-<suffix>      (empty placeholder for Migrate / staging)          │
└──────────────────────────────────────────────────────────────────────────────┘

  *fw  = firewall / full scenarios only
  *vpn = vpn / full scenarios only
```

Cross-subscription wires are the only thing that distinguishes multi-sub from single-sub:

1. **Spoke → Hub VNet peering** — created in the landing-zone sub, references the hub VNet ID in the connectivity sub.
2. **Hub → Spoke VNet peering** — created in the connectivity sub on a _second pass_, after the spoke exists.
3. **Spoke route table → Firewall private IP** (`firewall` / `full`) — route table lives in the landing-zone sub; the next-hop IP belongs to the firewall in the connectivity sub.
4. **Private DNS Zone → Spoke VNet link** — the PDZ for `privatelink.vaultcore.azure.net` lives in the connectivity sub; the link to the spoke VNet is created on the second connectivity pass.
5. **LAW diagnostics** — every resource that emits diagnostic logs targets the LAW resource ID in the management sub.

## What lands where

| Subscription     | Resource groups                                                         | Resources                                                                                                                                                          |
| ---------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Connectivity** | `rg-hub-<suffix>`                                                       | Hub VNet (4 subnets max), Azure Firewall + policy + 2 PIPs (`firewall`/`full`), VPN Gateway + PIP (`vpn`/`full`), Private DNS Zone for Key Vault, hub-side peering |
| **Management**   | `rg-monitor-<suffix>`, `rg-backup-<suffix>`                             | Log Analytics workspace, Automation Account, Recovery Services Vault, optional Foundation Health workbook, optional subscription budget                            |
| **Landing-Zone** | `rg-spoke-prod-<suffix>`, `rg-security-<suffix>`, `rg-migrate-<suffix>` | Spoke VNet, NAT Gateway (`baseline`/`vpn`) **or** route table → firewall private IP (`firewall`/`full`), Key Vault + private endpoint, spoke-side peering          |

Resource group counts are the same across all four scenarios — only the resources _inside_ the connectivity and landing-zone groups change:

| Layer        | RG count |
| ------------ | :------: |
| Connectivity |    1     |
| Management   |    2     |
| Landing-Zone |    3     |
| **Total**    |  **6**   |

## Coverage matrix

| Scenario   | Terraform multi-sub | Bicep multi-sub |
| ---------- | :-----------------: | :-------------: |
| `baseline` |         ✅          |       ✅        |
| `firewall` |         ✅          |       ✅        |
| `vpn`      |         ✅          |       ✅        |
| `full`     |         ✅          |       ✅        |

**Both stacks support every scenario in multi-sub mode.** Pick the stack your team already knows. The trade-offs:

- **Terraform** runs as a single `terraform apply`. Provider aliases (`azurerm.connectivity`, `azurerm.management`, `azurerm.landingzone`) route each resource to its sub. State is centralized in one backend.
- **Bicep** runs as four `az deployment sub create` calls orchestrated by [`scripts/deploy-multi-sub.sh`](https://github.com/travishankins/azure-launchpad/blob/main/scripts/deploy-multi-sub.sh). Cross-sub references are threaded between deploys via output capture. Deployment history is split across the three subs (which some auditors actually prefer).

## Pre-flight checklist

Before you deploy, confirm the following — multi-sub failures usually trace back to one of these.

### Subscriptions

- Three Azure subscriptions exist and are in the **same Entra ID tenant**.
- All three are **enabled** (not in `Disabled` / `Past Due` / `Warned` state).
- Each subscription has the resource providers you need **registered**: `Microsoft.Network`, `Microsoft.OperationalInsights`, `Microsoft.Automation`, `Microsoft.RecoveryServices`, `Microsoft.KeyVault`, `Microsoft.Insights`, `Microsoft.Storage`, `Microsoft.Consumption`. Quick check:

```bash
for SUB in $CONN_SUB $MGMT_SUB $LZ_SUB; do
  az account set --subscription "$SUB"
  for NS in Microsoft.Network Microsoft.OperationalInsights Microsoft.Automation \
            Microsoft.RecoveryServices Microsoft.KeyVault Microsoft.Insights; do
    az provider register --namespace "$NS" --wait
  done
done
```

### RBAC

| Principal needs       | Scope                                               | Why                                                                           |
| --------------------- | --------------------------------------------------- | ----------------------------------------------------------------------------- |
| `Contributor`         | Each of the three subscriptions                     | Create RGs and resources in every layer                                       |
| `Network Contributor` | Hub VNet in the connectivity sub (or its parent RG) | Required to create the hub-side peering from the second connectivity pass     |
| `Network Contributor` | KV Private DNS Zone in the connectivity sub         | Required to create the cross-sub `link-spoke` on the second connectivity pass |
| `Network Contributor` | Spoke VNet in the landing-zone sub                  | Required to create the spoke-side peering during the landing-zone deploy      |

The foundation itself has **no tenant-root requirement**. `Contributor` on each subscription covers the required network operations when the same identity runs every layer. The optional Management Group configuration is separate and requires the tenant-root roles shown in [Prerequisites](/getting-started/prerequisites/#azure-access).

### Quotas

In the deploy region, confirm the following per-sub quotas are not exhausted:

| Sub          | Resource                  | Default quota | Used by                       |
| ------------ | ------------------------- | :-----------: | ----------------------------- |
| Connectivity | `Standard PIP`            |      10       | 1–3 PIPs (firewall + VPN)     |
| Connectivity | `Azure Firewall (Basic)`  |       1       | 1 if `firewall`/`full`        |
| Connectivity | `Virtual Network Gateway` |       1       | 1 if `vpn`/`full`             |
| Landing-Zone | `Standard PIP`            |      10       | 1 NAT PIP if `baseline`/`vpn` |
| Landing-Zone | `NAT Gateway`             |       1       | 1 if `baseline`/`vpn`         |
| Management   | `Log Analytics workspace` |      10       | 1                             |
| Management   | `Recovery Services Vault` |       5       | 1                             |

### Network plan

The defaults assume non-overlapping `/23`s:

- Hub: `10.0.0.0/23`
- Spoke: `10.0.2.0/23`

Override via `addressSpaceHub` / `addressSpaceSpoke` (Bicep) or `address_space_hub` / `address_space_spoke` (Terraform) if you have an existing on-prem schema to fit into.

## Terraform deploy

Terraform's three provider aliases (`azurerm.connectivity`, `azurerm.management`, `azurerm.landingzone`) collapse to the same subscription in `single` mode and split into three in `multi` mode. From your perspective it's still **one apply**.

> **State file naming.** Multi-sub state lands at key `foundation.<scenario>.multi.tfstate` (note the `.multi` suffix) so it never collides with a single-sub deploy of the same scenario. Single and multi can coexist as separate state files in the same backend if you're staging a migration.

### 1. Author `wizard.auto.tfvars`

```hcl
# Generated by the Azure Launchpad configuration generator (or hand-written)

subscription_id = "22222222-2222-2222-2222-222222222222"  # default / fallback (use the management sub)
scenario        = "full"
location        = "westcentralus"
name_prefix     = "contoso"

# ALZ-aligned multi-subscription split
deployment_mode              = "multi"
connectivity_subscription_id = "11111111-1111-1111-1111-111111111111"
management_subscription_id   = "22222222-2222-2222-2222-222222222222"
landingzone_subscription_id  = "33333333-3333-3333-3333-333333333333"
```

### 2. Bootstrap state (one-time per environment)

State lives in the **management** sub by convention — it's the long-lived platform sub.

```bash
export ARM_SUBSCRIPTION_ID="22222222-2222-2222-2222-222222222222"
./scripts/bootstrap-state.sh
# Note the storage_account_name printed at the end.
```

### 3. Preview + apply

```bash
./scripts/deploy.sh plan --iac terraform --mode multi \
  --connectivity-sub 11111111-1111-1111-1111-111111111111 \
  --management-sub   22222222-2222-2222-2222-222222222222 \
  --landingzone-sub  33333333-3333-3333-3333-333333333333 \
  --scenario full --config infra/terraform/foundation/scenarios/wizard.auto.tfvars

# Review, then apply only the saved plan:
./scripts/deploy.sh apply --iac terraform --mode multi \
  --connectivity-sub 11111111-1111-1111-1111-111111111111 \
  --management-sub   22222222-2222-2222-2222-222222222222 \
  --landingzone-sub  33333333-3333-3333-3333-333333333333 \
  --scenario full --config infra/terraform/foundation/scenarios/wizard.auto.tfvars \
  --plan-file .launchpad/plans/foundation.full.multi.tfplan
```

That's it. The plan output will show resources prefixed with `module.vnet_hub`, `module.vnet_spoke`, etc., each routed to the right sub via its alias.

## Bicep deploy

Bicep doesn't have provider aliases, so multi-sub is implemented as **four `az deployment sub create` calls in a specific order**, each in its own subscription. Cross-sub outputs from earlier calls (firewall private IP, hub VNet ID, spoke VNet ID, PDZ ID) feed into later ones.

The shared deployment script previews or runs the shipped [`scripts/deploy-multi-sub.sh`](https://github.com/travishankins/azure-launchpad/blob/main/scripts/deploy-multi-sub.sh) sequence:

```bash
./scripts/deploy.sh plan --iac bicep --mode multi \
  --connectivity-sub 11111111-1111-1111-1111-111111111111 \
  --management-sub   22222222-2222-2222-2222-222222222222 \
  --landingzone-sub  33333333-3333-3333-3333-333333333333 \
  --scenario full \
  --name-prefix contoso \
  --region westcentralus \
  --region-short wcus

# Review all three layer previews, then deploy:
./scripts/deploy.sh apply --iac bicep --mode multi \
  --connectivity-sub 11111111-1111-1111-1111-111111111111 \
  --management-sub   22222222-2222-2222-2222-222222222222 \
  --landingzone-sub  33333333-3333-3333-3333-333333333333 \
  --scenario full --name-prefix contoso \
  --region westcentralus --region-short wcus
```

`--scenario` accepts `baseline`, `firewall`, `vpn`, or `full`. The plan action runs Bicep what-if for connectivity, landing-zone, and management without creating resources. Apply runs the four dependency-ordered deployment passes.

### What the wrapper does, step by step

#### Step 1 — Connectivity (first pass)

```bash
az account set --subscription "$CONN_SUB"
az deployment sub create \
  --location "$REGION" \
  --template-file infra/bicep/foundation/multi-sub/connectivity.bicep \
  --parameters scenario=full namePrefix=contoso regionShort=wcus location=westcentralus
```

Creates `rg-hub-<suffix>`, the hub VNet, Azure Firewall (`firewall`/`full`), VPN gateway (`vpn`/`full`), and the Key Vault Private DNS Zone (linked to the hub VNet only at this point). Outputs:

- `hubVnetId`
- `firewallPrivateIp` (empty string for `baseline`/`vpn`)
- `keyVaultPdzId`

The wrapper captures all three from the deployment output.

#### Step 2 — Landing-zone

```bash
az account set --subscription "$LZ_SUB"
az deployment sub create \
  --location "$REGION" \
  --template-file infra/bicep/foundation/multi-sub/landingzone.bicep \
  --parameters scenario=full namePrefix=contoso regionShort=wcus location=westcentralus \
               hubVnetId=$HUB_VNET_ID firewallPrivateIp=$FW_PRIVATE_IP keyVaultPdzId=$PDZ_ID
```

Creates `rg-spoke-prod`, `rg-security`, `rg-migrate`, the spoke VNet, the egress path (NAT Gateway for `baseline`/`vpn`, route table → firewall for `firewall`/`full`), Key Vault with a private endpoint, and the **spoke→hub peering** that points at `hubVnetId` in the connectivity sub. Outputs `spokeVnetId`, captured by the wrapper.

#### Step 3 — Connectivity (second pass)

```bash
az account set --subscription "$CONN_SUB"
az deployment sub create \
  --location "$REGION" \
  --template-file infra/bicep/foundation/multi-sub/connectivity.bicep \
  --parameters scenario=full namePrefix=contoso regionShort=wcus location=westcentralus \
               spokeVnetId=$SPOKE_VNET_ID
```

Re-runs the connectivity template **with the spoke VNet ID this time**. Two new resources appear (everything else is a no-op):

- `peer-hub-to-spoke` on the hub VNet (so traffic can flow both ways)
- `link-spoke` on the Private DNS Zone (so KV name resolution works from spoke workloads)

This is why the wrapper has to pass twice through the connectivity sub — these two resources can only be created once the spoke VNet exists in the other sub.

#### Step 4 — Management

```bash
az account set --subscription "$MGMT_SUB"
az deployment sub create \
  --location "$REGION" \
  --template-file infra/bicep/foundation/multi-sub/management.bicep \
  --parameters scenario=full namePrefix=contoso regionShort=wcus location=westcentralus
```

Independent of the network layers. Creates Log Analytics, Automation Account, Recovery Services Vault, and (when enabled) the budget + Foundation Health workbook. Could in principle run first, last, or in parallel — the script runs it last so a network failure doesn't leave orphan management resources.

### Source layout

[`infra/bicep/foundation/multi-sub/`](https://github.com/travishankins/azure-launchpad/tree/main/infra/bicep/foundation/multi-sub):

- `connectivity.bicep` — sub-scope wrapper. Creates `rg-hub`, calls `connectivity-hub.bicep`.
- `connectivity-hub.bicep` — RG-scope. Hub VNet, firewall, VPN, PDZ, hub-side peering, cross-sub PDZ link.
- `landingzone.bicep` — sub-scope wrapper. Creates spoke RGs, calls `landingzone-spoke.bicep` and `../modules/security.bicep`.
- `landingzone-spoke.bicep` — RG-scope. Spoke VNet, NAT or route table, spoke-side peering.
- `management.bicep` — sub-scope wrapper. Creates monitor + backup RGs and their resources.
- `scenarios/{connectivity,landingzone,management}.bicepparam` — example parameter files. Edit and use with `--parameters` instead of inline params if you prefer file-based config.

## Verification

After the deploy completes, run these checks. They take less than a minute and catch the most common issues.

### 1. Resource group inventory

```bash
for SUB in $CONN_SUB $MGMT_SUB $LZ_SUB; do
  az account set --subscription "$SUB"
  echo "--- $SUB ---"
  az group list --query "[?starts_with(name,'rg-')].name" -o tsv
done
```

You should see (with `name_prefix=contoso`, `region_short=wcus`):

```text
--- 11111111-... (connectivity) ---
rg-hub-contoso-wcus
--- 22222222-... (management) ---
rg-monitor-contoso-wcus
rg-backup-contoso-wcus
--- 33333333-... (landingzone) ---
rg-spoke-prod-contoso-wcus
rg-security-contoso-wcus
rg-migrate-contoso-wcus
```

### 2. VNet peering on both sides

```bash
az account set --subscription $CONN_SUB
az network vnet peering list -g rg-hub-contoso-wcus --vnet-name vnet-hub-contoso-wcus \
  --query "[].{name:name, state:peeringState, sync:peeringSyncLevel}" -o table

az account set --subscription $LZ_SUB
az network vnet peering list -g rg-spoke-prod-contoso-wcus --vnet-name vnet-spoke-prod-contoso-wcus \
  --query "[].{name:name, state:peeringState, sync:peeringSyncLevel}" -o table
```

Both peerings should show `state=Connected` and `sync=FullyInSync`. If the hub side is missing, step 3 of the wrapper didn't run — re-run with the same args, it's idempotent.

### 3. Cross-sub PDZ link

```bash
az account set --subscription $CONN_SUB
az network private-dns link vnet list \
  -g rg-hub-contoso-wcus --zone-name privatelink.vaultcore.azure.net \
  --query "[].{name:name, vnet:virtualNetwork.id}" -o table
```

You should see two links: `link-hub` (to hub VNet) and `link-spoke` (to spoke VNet in the landing-zone sub). The spoke link's `vnet` field will reference the landing-zone subscription ID.

### 4. KV name resolution from the spoke

Deploy a tiny test VM in `snet-workload` and run:

```bash
nslookup <kv-name>.vault.azure.net
```

You should get a `privatelink.vaultcore.azure.net` CNAME resolving to a `10.0.2.x` private IP (or whatever your spoke address space is). If it resolves to a public IP, the cross-sub PDZ link is missing.

### 5. (firewall / full only) Egress through firewall

From the test VM:

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://www.microsoft.com
```

Returns `200`. Then check the firewall logs in LAW (give it ~5 min for log ingestion):

```kusto
AZFWApplicationRule
| where TimeGenerated > ago(15m)
| project TimeGenerated, SourceIp, Fqdn, Action
| order by TimeGenerated desc
```

You should see the `microsoft.com` request from the spoke's source IP.

## Troubleshooting

### `BCP053`/`BCP037` on the cross-sub peering

You ran step 3 (the second connectivity pass) before step 2 finished, or step 2 failed silently. Check `az deployment sub list -o table` in the landing-zone sub for the latest deploy state. Re-run the wrapper — both connectivity passes are idempotent.

### `LinkedAuthorizationFailed` on cross-sub peering

The principal creating the spoke→hub peering doesn't have read access to the hub VNet. Either grant `Reader` (or `Network Contributor`) on the hub VNet to the principal, or use the same identity for both deploys (which the wrapper does by switching `az account set` between steps).

### `PrivateDnsZoneVirtualNetworkLinkAlreadyExists`

You re-ran step 3 after partially editing the spoke VNet. The link exists but with a different `vnetId`. Delete the existing `link-spoke` from the PDZ and re-run:

```bash
az account set --subscription $CONN_SUB
az network private-dns link vnet delete \
  -g rg-hub-contoso-wcus --zone-name privatelink.vaultcore.azure.net --name link-spoke -y
```

### Spoke workloads have no internet (firewall / full)

The route table is wired but the firewall isn't fully provisioned yet, or the route table's `nextHopIpAddress` doesn't match the firewall's actual private IP. Verify:

```bash
az account set --subscription $CONN_SUB
az network firewall show -g rg-hub-contoso-wcus -n afw-contoso-wcus \
  --query "ipConfigurations[0].privateIPAddress" -o tsv

az account set --subscription $LZ_SUB
az network route-table route show \
  -g rg-spoke-prod-contoso-wcus --route-table-name rt-spoke-contoso-wcus \
  --name default-via-firewall --query nextHopIpAddress -o tsv
```

Both should match. If they don't, re-run the wrapper — step 1's output gets re-captured and threaded into step 2.

### Spoke can't reach on-prem through VPN (vpn / full)

The peering allows gateway transit on the hub side (`allowGatewayTransit = true` when `hasVpn`), but the spoke side defaults to `useRemoteGateways = false` to avoid a chicken-and-egg with the gateway provisioning timeline. Once the gateway is `Succeeded`, flip the spoke peering manually:

```bash
az account set --subscription $LZ_SUB
az network vnet peering update \
  -g rg-spoke-prod-contoso-wcus --vnet-name vnet-spoke-prod-contoso-wcus \
  --name peer-spoke-to-hub --set useRemoteGateways=true
```

Automating this as a third connectivity pass is on the roadmap.

## Day-2 operations

### Adding another landing zone

The current code creates one landing-zone sub. To add a second (e.g., `corp` and `online`):

- **Terraform**: copy `infra/terraform/foundation` to `infra/terraform/landingzone-online`, drop everything except the spoke VNet + KV modules, and re-use `azurerm.landingzone` (or add a new alias `azurerm.landingzone_online`). Point its spoke→hub peering at the same `hubVnetId`.
- **Bicep**: re-run only steps 2 and 3 of the wrapper with a different `--name-prefix` and `--landingzone-sub`.

Multiple spokes to one hub is a supported pattern — just keep the address spaces non-overlapping.

### Rotating subscriptions

If you need to move a layer to a different subscription (e.g., new finance structure):

1. Stand up the new layer in parallel with `name_prefix=<new>`.
2. Migrate workloads (KV secrets, storage data, route table updates) from old to new.
3. Tear down the old layer.

Don't try to `terraform state mv` across subscription boundaries — Terraform's azurerm provider treats subscription as part of the resource ID.

### Cost visibility per layer

Each sub gets its own invoice. The repo's optional budget module ([Budgets](/governance/budgets/)) lands the budget on the **management** sub by default in multi-sub mode. If you want a budget per layer, deploy the budget module three times (one per sub) with three different `subscription_id` values.

## Migrating from single → multi

You **can't** migrate state files in place — single-sub state holds resources in one sub; multi-sub state expects them in three. The supported path is parallel deploy:

1. **Stand up multi-sub in parallel** with a different `name_prefix` (e.g. `contoso2`). New RGs, new VNets, no overlap with the existing single-sub deploy.
2. **Migrate workloads** at your own pace — KV secrets via `az keyvault secret show` + `az keyvault secret set`, storage data via `azcopy`, etc.
3. **Tear down the old single-sub deploy** once nothing depends on it.

This is intentional. The foundation is small enough that a parallel deploy is cheaper, safer, and faster than a state surgery — and it gives you a real cutover window to validate workloads before flipping DNS.

## Why isn't there an Identity sub?

Microsoft's full ALZ recommends a fourth `identity` subscription for AD DS / Entra Domain Services / Entra Connect. The Azure Launchpad foundation **doesn't deploy any identity resources today**, so adding the variable without backing resources would be noise. When/if a future module deploys Entra DS or AD DS, the Identity sub will be added in the same shape as the other three (provider alias + `identity_subscription_id` variable + opt-in via `deployment_mode`).

In the meantime, if you already run an Identity sub, point the foundation's existing layers at it via your own DNS/peering — nothing in this stack assumes identity lives anywhere specific.

---

For the design rationale (why three subs and not five, why provider aliases not separate state files, why a wrapper script not a tenant-scope orchestrator), see [ADR 0006](https://github.com/travishankins/azure-launchpad/blob/main/docs/adr/0006-multi-subscription-mode.md).
