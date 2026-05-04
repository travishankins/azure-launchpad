---
title: Operations & teardown
description: Day-2 operations for a deployed SMB Foundations landing zone.
---

## Verify the deployment

```bash
terraform output                       # scenario, RG names, IDs
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

Add them in a `diagnostics.tf` referencing `module.log_analytics.resource_id`.

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

```bash
cd infra/terraform/foundation
terraform workspace select <scenario>
terraform destroy -var "subscription_id=$ARM_SUBSCRIPTION_ID" -var-file=scenarios/<scenario>.tfvars
```

If you want to fully purge the Key Vault before the soft-delete window expires (only do this if you're certain):

```bash
az keyvault purge --name <kv-name>
```

The state backend itself (`rg-tfstate-contoso-wcus`) is **not** managed by Terraform — delete it manually when you're done with the customer.
