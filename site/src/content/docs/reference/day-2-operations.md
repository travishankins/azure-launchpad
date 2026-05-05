---
title: Day-2 operations
description: Verifying, monitoring, backing up, cost-tracking, and tearing down a deployed Azure Launchpad foundation — for both single-sub and multi-sub mode.
---

Day-1 is the deploy. **Day-2 is everything after** — confirming the deploy worked, wiring up diagnostics, protecting the data, watching cost, and (eventually) tearing it down.

This page assumes the foundation is already deployed via either Terraform or Bicep, in either `single` or `multi` subscription mode. Where the steps differ between modes, both are shown.

> **TL;DR.** Use `terraform output` (or `az deployment sub show`) to find what landed. Wire diagnostic settings to the foundation Log Analytics workspace. Enable VM backup on the Recovery Services Vault. Slice cost by the `scenario` tag. Tear down with `terraform destroy` (single state file per workspace) or `az group delete` per RG (Bicep has no destroy).

## 1. Verify the deployment

### Terraform

```bash
cd infra/terraform/foundation
terraform output                       # scenario, RG names, IDs
```

In multi-sub mode, every output is namespaced with its layer (`hub_vnet_id`, `spoke_vnet_id`, `law_id`, etc.) regardless of which sub the resource lives in.

### Bicep

Single-sub:

```bash
az deployment sub show \
  --name <deployment-name> \
  --query properties.outputs
```

Multi-sub: outputs are split across the four wrapper deployments (`connectivity-pass1`, `landingzone`, `connectivity-pass2`, `management`). The wrapper script captures the cross-sub IDs it needs in-flight; for everything else, query each pass:

```bash
az account set --subscription $CONN_SUB
az deployment sub show --name <connectivity-deployment-name> --query properties.outputs
```

Repeat per sub.

### Smoke test

Either way, validate that the resources actually landed:

```bash
# Hub + spoke VNets exist
az network vnet list -o table

# Key Vault has public access disabled (PE-only)
az keyvault show -n <kv-name> --query "properties.publicNetworkAccess" -o tsv
# expect: Disabled

# Firewall present (firewall / full only)
az network firewall list -o table

# Spoke can resolve KV via private DNS
nslookup <kv-name>.vault.azure.net    # from a VM in snet-workload
```

In multi-sub mode, run each `az` command after `az account set --subscription` for the right layer.

## 2. Add diagnostic settings

The Log Analytics workspace is created but **no diagnostic settings are wired up automatically** (you can hit per-resource limits if you blanket-attach everything). Add them to the resources you actually care about. Common targets:

| Resource              | Categories                                                                       |
| --------------------- | -------------------------------------------------------------------------------- |
| Azure Firewall        | `AzureFirewallApplicationRule`, `AzureFirewallNetworkRule`, `AzureFirewallDnsProxy` |
| VPN Gateway           | `GatewayDiagnosticLog`, `TunnelDiagnosticLog`, `IKEDiagnosticLog`                |
| Key Vault             | `AuditEvent`, `AzurePolicyEvaluationDetails`                                     |
| NAT Gateway           | `AllMetrics`                                                                     |
| Network Security Group| `NetworkSecurityGroupEvent`, `NetworkSecurityGroupRuleCounter`                   |
| Recovery Services Vault | `AzureBackupReport`, `AzureSiteRecoveryJobs`                                   |

**Where to add them:**

- Terraform: a new `diagnostics.tf` referencing `module.log_analytics.resource_id` (or in multi-sub mode, output the LAW ID from the management layer and pass it as a `data.azurerm_log_analytics_workspace` lookup).
- Bicep: a new `modules/diagnostics.bicep` using `Microsoft.Insights/diagnosticSettings`. In multi-sub mode the LAW lives in the management sub — pass its resource ID as a parameter to the module from each layer that wires diagnostics.

Once attached, see the [Monitoring workbook](/azure-launchpad/governance/monitoring-workbook/) page for a starter visualization over the data.

## 3. Backup verification

The Recovery Services Vault is created in `Standard / GeoRedundant` with soft-delete enabled. To start backing up VMs:

```bash
az backup protection enable-for-vm \
  --resource-group rg-backup-<prefix>-<region> \
  --vault-name rsv-<prefix>-<region> \
  --vm <vm-id> \
  --policy-name DefaultPolicy
```

In multi-sub mode, run this against the **management** sub. The VM being protected can live in any sub — Azure Backup walks resource IDs across sub boundaries.

To verify a backup actually ran:

```bash
az backup job list \
  --resource-group rg-backup-<prefix>-<region> \
  --vault-name rsv-<prefix>-<region> \
  --query "[].{operation:properties.operation, status:properties.status, started:properties.startTime}" -o table
```

Or open the **Backup job status** tab in the [Monitoring workbook](/azure-launchpad/governance/monitoring-workbook/).

## 4. Cost tracking

Every resource carries the `cost_center` and `workload` tag from `var.tags` plus `scenario` and `location` from `local.tags`. To slice in **Cost Management → Cost analysis**:

1. Scope: subscription (single mode) or **billing account** (multi mode — to see all three layers in one view).
2. Group by tag `scenario` to compare baseline / firewall / vpn / full deltas across customers.
3. Group by tag `workload` to split platform vs landing-zone spend.
4. In multi-sub mode, group by **subscription** to see the Connectivity / Management / Landing-Zone split that's the whole point of the layer separation.

For a per-sub guardrail, see the [Budgets](/azure-launchpad/governance/budgets/) module.

## 5. Routine ops

A few things you'll want to do periodically once the foundation is in steady state:

| Task                                | Cadence | How                                                                          |
| ----------------------------------- | ------- | ---------------------------------------------------------------------------- |
| `terraform plan` drift detection    | Weekly  | CI (see [CI/CD pipeline](/azure-launchpad/reference/cicd/)) or manual        |
| Bicep what-if drift detection       | Weekly  | `az deployment sub what-if --template-file ... --parameters ...`             |
| Firewall rule review                | Monthly | KQL: `AZFWApplicationRule \| summarize count() by Fqdn, Action`              |
| Soft-deleted KV cleanup             | Monthly | `az keyvault list-deleted -o table` then `az keyvault purge` once safe       |
| Cost review                         | Monthly | Cost Management with `scenario` / `workload` group-by                        |
| Provider re-registration            | On Azure announcement | `az provider register --namespace <ns> --wait`                  |
| Module / provider version bumps     | Quarterly | Edit `terraform.tf` (provider versions) / `terraform.lock.hcl`             |

## 6. Teardown

> **Important.** Key Vault has purge protection on. Soft-deleted vaults remain billable and **block name reuse for 7 days**. Don't tear down then immediately re-deploy with the same `name_prefix` unless you also `az keyvault purge`.

### Terraform — single sub

```bash
cd infra/terraform/foundation
terraform workspace select <scenario>
terraform destroy \
  -var "subscription_id=$ARM_SUBSCRIPTION_ID" \
  -var-file=scenarios/<scenario>.tfvars
```

### Terraform — multi sub

Same command — Terraform tears down across all three subs in one apply because it has the provider aliases and state for each:

```bash
cd infra/terraform/foundation
terraform workspace select <scenario>-multi
terraform destroy -var-file=wizard.auto.tfvars
```

### Bicep — there is no destroy

Delete the resource groups directly. This removes everything inside them (including any non-Bicep resources you may have added — be careful):

**Single-sub** (6 RGs):

```bash
for rg in rg-hub-contoso-wcus rg-spoke-prod-contoso-wcus rg-security-contoso-wcus \
          rg-monitor-contoso-wcus rg-backup-contoso-wcus rg-migrate-contoso-wcus; do
  az group delete --name "$rg" --yes --no-wait
done
```

**Multi-sub** (6 RGs across 3 subs):

```bash
# Connectivity (1 RG)
az account set --subscription $CONN_SUB
az group delete --name rg-hub-contoso-wcus --yes --no-wait

# Management (2 RGs)
az account set --subscription $MGMT_SUB
for rg in rg-monitor-contoso-wcus rg-backup-contoso-wcus; do
  az group delete --name "$rg" --yes --no-wait
done

# Landing-zone (3 RGs)
az account set --subscription $LZ_SUB
for rg in rg-spoke-prod-contoso-wcus rg-security-contoso-wcus rg-migrate-contoso-wcus; do
  az group delete --name "$rg" --yes --no-wait
done
```

### Purge soft-deleted Key Vaults

If you want to fully purge the KV before the soft-delete window expires (only do this if you're certain — purged secrets are unrecoverable):

```bash
az keyvault list-deleted --query "[].{name:name, deleted:properties.deletionDate}" -o table
az keyvault purge --name <kv-name>
```

### State / deployment history

- **Terraform state backend** (`rg-tfstate-<prefix>-<region>`) is **not** managed by Terraform — delete manually when you're done with the customer:
  ```bash
  az group delete --name rg-tfstate-contoso-wcus --yes
  ```
- **Bicep deployment history** lives in Azure and ages out automatically. To remove explicitly:
  ```bash
  az deployment sub delete --name <deployment-name>
  ```
  In multi-sub mode there are four deployments per scenario; remove all four (one per sub for management, two on connectivity, one on landing-zone).

### Tear-down order (multi-sub)

If you're tearing down manually rather than via `terraform destroy`, delete in **reverse of deploy order** to avoid orphaned cross-sub references:

1. **Landing-zone** RGs first (so the spoke→hub peering and route table → firewall IP go away).
2. **Connectivity** RG next (after landing-zone is gone, the hub-side peering and PDZ→spoke link have nothing dangling).
3. **Management** RG last (so any final diagnostics from the other layers can land in LAW before it's gone).

Terraform handles this ordering automatically via dependency graph.