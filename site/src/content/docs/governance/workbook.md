---
title: Foundation Health workbook
description: Opt-in Azure Monitor workbook over the foundation Log Analytics workspace.
---

import { Aside } from '@astrojs/starlight/components';

The **Foundation Health** workbook is a starter Azure Monitor workbook that ships with the foundation. It deploys into the monitoring resource group and is scoped to the foundation Log Analytics workspace.

It's **opt-in** and **off by default** — workbooks themselves cost nothing, but the queries inside them run against your LAW data (which is already paid for by the foundation, but the workbook may surface ingestion you didn't realise you had).

## What it deploys

One `Microsoft.Insights/workbooks` resource (`kind: shared`) in `rg-monitor-<prefix>-<region>`, with four tabs:

| Tab                       | Query                                                                                     | Notes                                                       |
| ------------------------- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| **Workspace ingestion**   | `Usage` table grouped by `DataType`                                                       | Tells you which diagnostic settings are actually emitting.  |
| **Firewall denies**       | `AZFWNetworkRule` where `Action == "Deny"`                                                | Empty on `baseline` / `vpn` scenarios — that's expected.    |
| **Key Vault operations**  | `AzureDiagnostics` filtered to `MICROSOFT.KEYVAULT`                                       | Last 50 control + data plane ops with caller identity.      |
| **Backup job status**     | `AddonAzureBackupJobs` summarised by `JobStatus`                                          | Empty until at least one backup item is being protected.    |

A `TimeRange` parameter at the top lets you pivot from 1h to 7d.

## Why opt-in?

Two reasons:

1. **Doesn't fit every team.** Some shops bring their own workbooks, Grafana, or Datadog. We don't want to leave behind orphaned Azure resources for those teams.
2. **Editable starter, not a finished product.** This is intentionally minimal — it's meant to be cloned and extended, not used as-is.

## Enable it

### Terraform

```hcl
# terraform.tfvars
workbook_enabled = true
```

Then `terraform apply`. The output `workbook_id` will be populated with the new workbook's resource ID.

### Bicep

```bicep
// scenarios/<your>.bicepparam
param workbookEnabled = true
```

Then `az deployment sub create --parameters scenarios/<your>.bicepparam`. The output `workbookId` will be populated.

## Editing the workbook content

The workbook content is two JSON files (one for each IaC tree) — keep them in sync if you edit one:

- [`infra/terraform/foundation/workbooks/foundation-health.workbook.json`](https://github.com/travishankins/azure-launchpad/blob/main/infra/terraform/foundation/workbooks/foundation-health.workbook.json)
- [`infra/bicep/foundation/workbooks/foundation-health.workbook.json`](https://github.com/travishankins/azure-launchpad/blob/main/infra/bicep/foundation/workbooks/foundation-health.workbook.json)

The easiest workflow:

1. Open the deployed workbook in the Azure portal.
2. Edit visually until you like it.
3. Click **Advanced editor** (`</>` icon) → copy the JSON.
4. Paste into **both** `foundation-health.workbook.json` files.
5. Commit. Next `terraform apply` / `az deployment sub create` will diff-update the deployed workbook.

<Aside type="note" title="Resource name is a GUID">
The workbook's `name` is a deterministic GUID derived from your naming suffix (Terraform: `uuidv5("dns", "azure-launchpad-workbook-<suffix>")`; Bicep: `guid('azure-launchpad-workbook', suffix)`). The display name is what you see in the portal — the GUID is just the resource ID.
</Aside>

## Validation

```bash
cd infra/terraform/foundation
terraform test -filter=tests/workbook.tftest.hcl
# Success! 2 passed, 0 failed.
```

The plan-mode tests cover the disabled-by-default and enabled paths without needing Azure auth.

## Removal

Set `workbook_enabled = false` (or `workbookEnabled = false`) and re-apply. The workbook resource will be deleted; the LAW it queried is untouched.
