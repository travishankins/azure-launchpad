---
title: Troubleshooting
description: Common errors when deploying Azure Launchpad and how to resolve them — Terraform, Bicep, networking, governance, and the docs site.
---

If something goes wrong, start here. Each entry has the **symptom** you'll see, the **cause**, and the **fix**. If your problem isn't here, please [open an issue](https://github.com/travishankins/azure-launchpad/issues/new/choose) or start a [discussion](https://github.com/travishankins/azure-launchpad/discussions).

## Authentication & permissions

### `Error: building account: getting authenticated object ID: parsing JSON result`

**Cause:** Azure CLI not logged in, or your token expired.

**Fix:**

```bash
az logout
az login
az account set --subscription <your-sub-id>
az account show
```

### `AuthorizationFailed` on `terraform apply` / `az deployment`

**Cause:** The identity running the deployment doesn't have **Contributor** on the target subscription (or **Management Group Contributor** at tenant root for the MG module).

**Fix:**

```bash
# As subscription owner:
az role assignment create \
  --assignee <upn-or-object-id> \
  --role Contributor \
  --scope /subscriptions/<sub-id>
```

For CI: confirm the federated credential's subject (`repo:<owner>/<repo>:ref:refs/heads/main` or `:pull_request`) matches your workflow trigger.

### `KeyVaultAccessForbidden` after deploy succeeds

**Cause:** RBAC took a few minutes to propagate, or your user has no Key Vault role.

**Fix:** Wait 5 minutes, then verify:

```bash
az keyvault secret list --vault-name <kv-name>
# If still forbidden:
az role assignment create \
  --assignee <your-upn> \
  --role "Key Vault Secrets Officer" \
  --scope $(az keyvault show -n <kv-name> --query id -o tsv)
```

## Terraform

### `Backend configuration changed` on `terraform init`

**Cause:** You switched scenarios (which uses a different state file `key`) without explicitly re-initing.

**Fix:**

```bash
terraform init -reconfigure \
  -backend-config="resource_group_name=$TFSTATE_RG" \
  -backend-config="storage_account_name=$TFSTATE_SA" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=foundation.<scenario>.tfstate"
```

### `Workspace already exists`

Use `select -or-create`:

```bash
terraform workspace select -or-create <scenario>
```

### Plan shows tag drift on every resource after upgrading

**Cause:** The default `workload` tag value changed between releases.

**Fix:** Either accept the diff (cheap, metadata-only) or pin the old value in your tfvars:

```hcl
tags = {
  workload    = "smb-foundations"  # or whatever you had
  iac         = "terraform"
  cost_center = "platform"
}
```

### `cidrhost: argument must be a CIDR` on the on-prem CIDR var

**Cause:** You passed a host IP (e.g. `192.168.1.5`) instead of a CIDR.

**Fix:** Use CIDR notation: `192.168.0.0/16`.

### `Error: subscriptionId must be specified`

**Cause:** Provider can't find a subscription. Either `ARM_SUBSCRIPTION_ID` env var is missing or the `subscription_id` variable is empty.

**Fix:**

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
# or pass via -var
terraform plan -var "subscription_id=$ARM_SUBSCRIPTION_ID" ...
```

## Bicep

### `BCP037: The property "X" is not allowed`

**Cause:** Bicep / azure-cli version is older than the API version the module uses.

**Fix:** Upgrade Bicep:

```bash
az bicep upgrade
az bicep version   # should be >= 0.30
az version
```

### `InvalidTemplateDeployment: The template deployment is not valid`

Run `what-if` first — it tells you which resource fails and why:

```bash
az deployment sub what-if \
  --location <region> \
  --name foundation-debug \
  --parameters infra/bicep/foundation/scenarios/<scenario>.bicepparam
```

### Bicep parameter file fails build with `Could not find type of resource`

**Cause:** AVM-style modules are referenced via `br/public:` and the local Bicep registry cache is stale.

**Fix:**

```bash
rm -rf ~/.bicep/cache
az bicep build --file infra/bicep/foundation/main.bicep
```

## Networking

### Subnet address overlap with on-prem after enabling VPN

**Cause:** Hub or spoke CIDR overlaps with one of your on-prem CIDRs.

**Fix:** Pick non-overlapping ranges. Defaults are `10.0.0.0/23` (hub) and `10.0.2.0/23` (spoke); change the VNet ranges in your tfvars or bicepparam, and use non-overlapping on-prem ranges when you add the post-deploy S2S connection:

```hcl
address_space_hub        = "10.20.0.0/23"
address_space_spoke      = "10.20.2.0/23"
```

### Spoke VMs can't reach the internet after switching to firewall scenario

**Cause:** Expected — the firewall scenario replaces NAT. The default route `0.0.0.0/0 → firewall private IP` is in place but the **firewall has no allow rules** by default.

**Fix:** Add a network rule collection, e.g. via portal or:

```bash
az network firewall network-rule create \
  --collection-name allow-egress \
  --firewall-name afw-<prefix>-<region> \
  --resource-group rg-hub-<prefix>-<region> \
  --name allow-https \
  --action Allow --priority 100 \
  --protocols TCP --source-addresses '*' \
  --destination-addresses '*' --destination-ports 443
```

### VPN tunnel is up but no traffic flows

Check, in order:

1. **BGP / static routes** — `az network vnet-gateway list-bgp-peer-status` shows the on-prem ASN.
2. **NSG on the spoke subnet** doesn't block on-prem source ranges.
3. **Route table on the spoke subnet** has a UDR for the on-prem CIDR pointing to `VirtualNetworkGateway` (gateway transit), not the firewall (in `vpn` only) or to the firewall (in `full`).
4. **On-prem firewall** allows the Azure-side IPsec endpoint IP and the negotiated subnets.

### `VpnGatewaySkuNotSupported` in non-AZ regions

**Cause:** As of mid-2025 Azure requires AZ-class SKUs (`VpnGw1AZ`, `VpnGw2AZ`) even in regions without AZs. The repo defaults to `VpnGw2AZ`.

**Fix:** No action needed if you're using the bundled scenarios. If you customised the SKU back to `VpnGw1`, switch it back to `VpnGw2AZ`.

## Governance / Management Groups

### `AuthorizationFailed` deploying the MG module

**Cause:** Subscription Contributor isn't enough — MG operations require **Management Group Contributor** at the tenant-root MG.

**Fix:** As the global admin (or someone with `User Access Administrator` at tenant root):

```bash
az role assignment create \
  --assignee <upn> \
  --role "Management Group Contributor" \
  --scope /providers/Microsoft.Management/managementGroups/<tenant-root-id>
```

### MG hierarchy created but policies aren't taking effect

**Cause:** Policy assignments are inherited from the MG hierarchy but compliance evaluation runs every 24h. New resources are evaluated within ~30 min.

**Fix:** Trigger an on-demand scan:

```bash
az policy state trigger-scan \
  --resource-group rg-spoke-prod-<prefix>-<region>
```

## CI / GitHub Actions

### `Error: Identity not allowed to access subscription`

**Cause:** OIDC federated credential subject doesn't match the workflow's `ref` or `environment`.

**Fix:** In Entra → App registrations → your app → Federated credentials, verify the subject string. Common patterns:

- `repo:travishankins/azure-launchpad:ref:refs/heads/main`
- `repo:travishankins/azure-launchpad:pull_request`
- `repo:travishankins/azure-launchpad:environment:prod`

You typically need one credential per trigger you use.

### `terraform-plan` fails with `Error acquiring the state lock`

**Cause:** A previous run died without releasing the lock, or two runs are in progress.

**Fix:**

```bash
# In the TF backend storage account, delete the lease on the .tfstate blob.
az storage blob lease break \
  --account-name <sa> \
  --container-name tfstate \
  --blob-name foundation.<scenario>.tfstate \
  --auth-mode login
```

### Pages site shows old content after pushing

**Cause:** `site-deploy.yml` only triggers on changes to `site/**`. If you only changed root-level files, Pages won't rebuild.

**Fix:** Re-run the workflow manually:

```bash
gh workflow run site-deploy.yml --repo travishankins/azure-launchpad
```

## Docs site

### Local `npm run dev` shows 404 on every link

**Cause:** Older builds of this site used a base path of `/azure-launchpad/` to match the GitHub Pages project URL. The site now serves from `/` at the custom domain (`azurelaunchpad.com`), so links should resolve at the root.

**Fix:** Open `http://localhost:4321/`. If you're on an older branch / fork that still sets `base: '/azure-launchpad/'` in `astro.config.mjs`, use `http://localhost:4321/azure-launchpad/` instead, or update the config.

### Wizard "Copy" button does nothing

**Cause:** Browser blocks `navigator.clipboard` over plain HTTP.

**Fix:** The button falls back to "Press Ctrl-C" — the textarea is already selected, so just hit Ctrl/Cmd-C. In production (HTTPS) the clipboard API works normally.

## Cost surprises

### Bill is higher than the README estimates

The README costs are **resource-only**, in `westcentralus`, with **no traffic, no log ingestion above the 30-day Free tier, and no backup data**. Real-world overages usually come from:

- **Log Analytics ingestion** — > 5 GB/month is billed; trim diagnostic settings if needed.
- **Egress data transfer** — anything leaving the region incurs bandwidth.
- **Public IPs** — Standard SKU public IPs cost ~$3.65/mo each even when idle. The firewall and VPN scenarios add 2.
- **Backup retention** — RSV deploys with no policy by default; if you've added a policy, retained snapshots are billable.

Set up cost alerts (or use the upcoming `budgets` module — see [the roadmap](https://github.com/travishankins/azure-launchpad/issues)).

## Still stuck?

- Check **GitHub Discussions** — someone may have hit it already.
- Open a [bug issue](https://github.com/travishankins/azure-launchpad/issues/new?template=bug.yml) with the reproduction template.
- For security issues, follow [SECURITY.md](https://github.com/travishankins/azure-launchpad/blob/main/SECURITY.md).
