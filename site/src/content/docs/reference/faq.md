---
title: FAQ
description: Frequently asked questions about SMB Foundations — Azure Landing Zones.
---

### Why one root module instead of separate modules per scenario?

You'd duplicate the entire hub-spoke baseline four times. Toggling resources by `count = local.use_firewall ? 1 : 0` is uglier in a single file but reads better as a whole because every shared concept (RGs, Key Vault, peering, DNS) is defined exactly once.

### Why workspaces instead of directories?

Workspaces let the same code produce isolated state files (`foundation.<scenario>.tfstate`). Keeps the CI matrix trivial. Directories would mean copy-pasting the backend config four times.

### Why Firewall **Basic** instead of Standard?

SMB cost-tier alignment with the upstream `azure-smb-rf` reference. Standard adds ~$700/mo, IDPS, TLS inspection, threat intel — features most SMB workloads don't need on day one. Switching is a one-line change in `modules.firewall.tf`.

### Why no Bastion / no policy assignments / no management group setup?

Per the architectural decision in the upstream issue, the **`foundation`** module is subscription-scoped only. MG / policy / Defender plans live one layer above the landing zone and would prevent the module from running in customer subscriptions where you only have Contributor.

If you do want them, this repo also ships an **opt-in, separate** root module: [`management-groups`](/governance/management-groups/). It deploys an ALZ-aligned hierarchy (including the new `Local` MG from ALZ 2026.04) and lets you pick exactly which built-in policy initiatives to assign and at which scope — see the [policy catalog](/governance/policy-catalog/). It's a separate module because it needs tenant-root permissions and a separate state file.

### Can I extend this for additional spokes?

Yes — the easiest path is to add another VNet module call + peering in `modules.networking.tf`, parameterized by a `var.additional_spokes = list(object({ name, address_space }))`. The hub side scales linearly.

### Does `terraform destroy` clean everything up?

Almost. Soft-deleted Key Vaults remain for 7 days (and block name reuse). See [Operations](/reference/operations/) for `az keyvault purge`. The state RG (`rg-tfstate-*`) is intentionally **not** Terraform-managed — delete manually after customer offboarding.

### How do I update AVM module versions?

Dependabot opens a weekly PR (`.github/dependabot.yml`). The plan workflow validates the new versions against all four scenarios before merge.

### Where do I report bugs?

Issues on GitHub: [smb-foundations/issues](https://github.com/travishankins/smb-foundations/issues).
