---
title: Operations & teardown
description: Day-2 operations for a deployed Azure Launchpad (SMB / SMEC Edition) landing zone.
---

## Verify the deployment

With **Terraform**:

```bash
cd infra/terraform/foundation
terraform output                       # scenario, RG names, IDs
```

With **Bicep** (deployment outputs are stored in Azure):

```bash
az deployment sub show \
  --name <deployment-name> \
  --query properties.outputs
```

Either way, validate the resources are present:

```bash
az network vnet list -o table          # confirm hub + spoke
az keyvault show -n <kv-name>          # ensure publicNetworkAccess = Disabled
az network firewall list -o table      # firewall + full only
```

## Add diagnostic settings

The Log Analytics workspace is created but no diagnostic settings are wired up automatically (you can hit subscription resource limits if you blanket-attach everything). Common targets:

- Azure Firewall (categories: `AzureFirewallApplicationRule`, `AzureFirewallNetworkRule`, `AzureFirewallDnsProxy`)
- VPN Gateway (`GatewayDiagnosticLog`, `TunnelDiagnosticLog`, `IKEDiagnosticLog`)
- Key Vault (`AuditEvent`)
- NAT Gateway (`AllMetrics`)

Add them in a `diagnostics.tf` (Terraform) referencing `module.log_analytics.resource_id`, or in a new `modules/diagnostics.bicep` module (Bicep) using `Microsoft.Insights/diagnosticSettings`.

## Backup verification

The Recovery Services Vault is created in `Standard / GeoRedundant` with soft-delete enabled. To start backing up VMs:

```bash
az backup protection enable-for-vm \
  --resource-group rg-backup-contoso-wcus \
  --vault-name rsv-contoso-wcus \
  --vm <vm-id> \
  --policy-name DefaultPolicy
```

## Cost tracking

Each resource has the `cost_center` and `workload` tag from `var.tags` plus `scenario` and `location` from `local.tags`. To slice cost in Cost Management:

1. Go to **Cost Management → Cost analysis**
2. Group by tag `scenario`
3. Filter to subscription = your customer subscription

## Teardown

> **Important** — Key Vault has purge protection on. Soft-deleted vaults remain billable and block name reuse for 7 days.

With **Terraform**:

```bash
cd infra/terraform/foundation
terraform workspace select <scenario>
terraform destroy -var "subscription_id=$ARM_SUBSCRIPTION_ID" -var-file=scenarios/<scenario>.tfvars
```

With **Bicep** — there is no `bicep destroy`. Delete the resource groups directly (this removes everything inside them):

```bash
for rg in rg-net-hub-contoso-wcus rg-net-spoke-contoso-wcus \
          rg-security-contoso-wcus rg-monitoring-contoso-wcus \
          rg-automation-contoso-wcus rg-backup-contoso-wcus; do
  az group delete --name "$rg" --yes --no-wait
done
```

If you want to fully purge the Key Vault before the soft-delete window expires (only do this if you're certain):

```bash
az keyvault purge --name <kv-name>
```

The Terraform state backend itself (`rg-tfstate-contoso-wcus`) is **not** managed by Terraform — delete it manually when you're done with the customer. Bicep has no equivalent state backend (deployment history lives in Azure and ages out automatically), but you should still delete the deployment records if desired:

```bash
az deployment sub delete --name <deployment-name>
```
