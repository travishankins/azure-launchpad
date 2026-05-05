---
title: FAQ
description: Frequently asked questions about Azure Launchpad (SMB / SMEC Edition) (Terraform + Bicep).
---

## Picking an IaC platform

### Terraform or Bicep — which should I pick?

Both produce **the exact same Azure architecture** (identical RGs, networking, security baseline, monitoring, optional firewall/VPN). Pick what your team already knows.

- **Terraform** — best if you're multi-cloud, already use HashiCorp tooling, or want a single state file you can `import` and refactor freely. Brings the AVM ecosystem and a mature testing story (`terraform test`).
- **Bicep** — best if you're Microsoft-only, want zero extra tooling beyond `az`, prefer ARM-native deployments tracked in the portal, and don't want to manage a remote state backend.

The [deployment wizard](/azure-launchpad/wizard/) asks this as question #1 and emits the matching parameter file + commands.

### Can I switch from Terraform to Bicep (or vice versa) later?

Yes, but it's a manual cutover — the two stacks don't share state. The cleanest path:

1. Deploy the new stack to the same subscription using a different `name_prefix` (e.g. `contoso2`).
2. Migrate workloads.
3. Tear down the old stack with `terraform destroy` or `az group delete`.

Both deployments are idempotent within their own world but neither will adopt resources created by the other.

### Do I have to pick — can I use both?

You can, but you shouldn't deploy both into the same subscription with the same `name_prefix`/region — they'll fight over resource names. Two valid patterns:

- **Different subscriptions per IaC** (e.g. dev = Bicep, prod = Terraform) — fine.
- **Same subscription, different prefixes** — fine but doubles your cost.

---

## Architecture & design

### Why one root module instead of separate modules per scenario?

You'd duplicate the entire hub-spoke baseline four times. Toggling resources by `count = local.use_firewall ? 1 : 0` (Terraform) or `if (deployFirewall)` (Bicep) is uglier in a single file but reads better as a whole because every shared concept (RGs, Key Vault, peering, DNS) is defined exactly once.

### Why Terraform workspaces instead of directories?

Workspaces let the same code produce isolated state files (`foundation.<scenario>.tfstate`). Keeps the CI matrix trivial. Directories would mean copy-pasting the backend config four times. Bicep doesn't need this — each `az deployment sub create` produces its own deployment record automatically.

### Why Firewall **Basic** instead of Standard?

SMB cost-tier alignment. Standard adds ~$700/mo, IDPS, TLS inspection, threat intel — features most SMB workloads don't need on day one. Switching is a one-line change in `modules.firewall.tf` (Terraform) or `modules/firewall.bicep` (Bicep).

### Why no Bastion / no policy assignments / no management groups in the foundation?

The **foundation** module is intentionally subscription-scoped. MG / policy / Defender plans live one layer above the landing zone and would prevent the module from running in customer subscriptions where you only have Contributor.

If you do want them, this repo also ships an **opt-in, separate** module: [management-groups](/azure-launchpad/governance/management-groups/). It deploys an ALZ-aligned hierarchy (including the new `Local` MG from ALZ 2026.04) and lets you pick which built-in policy initiatives to assign — see the [policy catalog](/azure-launchpad/governance/policy-catalog/). It's separate because it needs tenant-root permissions and its own state.

### Can I extend this for additional spokes?

Yes. **Terraform**: add another VNet module call + peering in `modules.networking.tf`, parameterized by a `var.additional_spokes = list(object({ name, address_space }))`. **Bicep**: add another `module spokeVnet '...spoke-vnet.bicep' = [for spoke in spokes: ...]` loop. The hub side scales linearly either way.

### Can I deploy to multiple regions?

Today the foundation deploys to a single region. For a multi-region pattern, deploy the foundation twice with different `name_prefix`/`location` combinations and add a hub-to-hub VNet peering yourself. A multi-region root module is on the roadmap.

---

## Regional gotchas

### My region doesn't support availability zones — will the deploy fail?

No, but it used to. The foundation now detects non-AZ regions (e.g. `westcentralus`, `northcentralus`, `centralindia`, `switzerlandwest`, `australiacentral`, `canadaeast`, `ukwest`, `japanwest`, etc.) and **omits the `zones` property** on Public IPs, NAT Gateway, Azure Firewall, and the VPN Gateway PIP automatically.

- **Terraform**: see `local.region_supports_zones` and `local.availability_zones` in [`infra/terraform/foundation/locals.tf`](https://github.com/travishankins/azure-launchpad/blob/main/infra/terraform/foundation/locals.tf).
- **Bicep**: same list lives in [`infra/bicep/foundation/main.bicep`](https://github.com/travishankins/azure-launchpad/blob/main/infra/bicep/foundation/main.bicep) as `availabilityZones` and is passed into the networking, firewall, and vpn modules.

If you deploy to a new region not on the list and hit `LocationNotSupportAvailabilityZones`, add the region name to that list and re-apply.

### Why is the VPN Gateway pinned to `VpnGw2AZ`?

In **May 2026** Microsoft retired the non-AZ `VpnGw1`–`VpnGw5` SKUs (`NonAzSkusNotAllowedForVPNGateway`). The `azurerm` provider's validation also dropped `VpnGw1AZ`, leaving `VpnGw2AZ`–`VpnGw5AZ` as the only valid choices. The foundation pins `VpnGw2AZ` (Generation 2) because it's the cheapest still-supported tier:

- **Even in regions without AZs**, Azure now requires an `AZ` SKU. The gateway is created without zones in non-AZ regions but the SKU name still ends in `AZ`.
- To upgrade to `VpnGw3AZ`/`VpnGw4AZ`/`VpnGw5AZ` (more bandwidth, more S2S tunnels), edit `modules.vpn.tf` (Terraform) or `modules/vpn.bicep` (Bicep).

### What about the Firewall — does it need an AZ SKU too?

No. Azure Firewall takes a `zones` array directly. In non-AZ regions the foundation passes `[]` and the firewall deploys non-zonal. Same applies to the firewall's three Public IPs.

---

## State, deployments, and history

### Where is Terraform state stored?

In the Storage Account created by `scripts/bootstrap-state.sh` (`rg-tfstate-<prefix>-<region>`). The state file is `foundation.<scenario>.tfstate` in the `tfstate` container. Versioning is enabled on the container so you can roll back.

### Where is Bicep "state"?

Bicep doesn't have explicit state — every `az deployment sub create` posts an ARM template and Azure tracks the result in the subscription's deployment history (visible in **Subscription → Deployments**). To inspect: `az deployment sub list -o table` and `az deployment sub show --name <name>`. Deployment history is retained for ~90 days by default.

### What happens if a deployment fails halfway?

**Terraform**: state records what succeeded; rerun `apply` and it picks up where it left off. **Bicep**: ARM rolls back the failing resource only; everything that succeeded stays. Rerun `az deployment sub create` and ARM will skip resources that already match.

### Does `terraform destroy` clean everything up?

Almost. Soft-deleted Key Vaults remain for 7 days (and block name reuse). See [Operations & teardown](/azure-launchpad/reference/operations/) for `az keyvault purge`. The state RG (`rg-tfstate-*`) is intentionally **not** Terraform-managed — delete manually after customer offboarding.

### How do I tear down a Bicep deployment?

Bicep has no `destroy`. Delete the resource groups directly: `az group delete --name <rg> --yes --no-wait` for each of the 6 RGs. See [Operations & teardown](/azure-launchpad/reference/operations/) for the full loop.

---

## CI/CD & GitHub Actions

### How do I set up the OIDC service principal?

Full step-by-step is on the [CI/CD pipeline](/azure-launchpad/reference/cicd/) page (steps 2 and 3). One service principal works for all 8 workflows.

### Do I need separate Azure credentials for Terraform vs Bicep?

No — the same Entra app registration / OIDC identity works for both. The only difference is which **GitHub environment** the apply runs under (`prod` for Terraform, `apply` for Bicep), and you add a federated credential per environment.

### Can the wizard's output be committed to a public repo?

Subscription IDs and tenant IDs are **not secrets** on their own (they appear in every resource ID), but they're useful for phishing reconnaissance — treat them as internal. Best practice: keep `*.auto.tfvars` and `*.bicepparam` out of public repos, or use a private repo. The wizard reminds you of this on the result page.

### How do I update AVM module versions (Terraform)?

Dependabot opens a weekly PR ([`.github/dependabot.yml`](https://github.com/travishankins/azure-launchpad/blob/main/.github/dependabot.yml)). The plan workflow validates the new versions against all four scenarios before merge.

### How do I update AVM-Bicep versions?

Bicep modules pin versions in their `br/public:avm/...` references. To bump, search for the module path in `infra/bicep/foundation/modules/*.bicep`, change the version tag, run `az bicep build` locally to validate, and open a PR — `bicep-plan.yml` will run `what-if` for you.

---

## Operations

### How do I add diagnostic settings?

The Log Analytics workspace is created but not wired up by default (to avoid hitting the per-resource diagnostic settings cap). Add them in `diagnostics.tf` (Terraform) or a new `modules/diagnostics.bicep` (Bicep). See [Operations & teardown](/azure-launchpad/reference/operations/) for which categories to enable per resource type.

### Can I add custom resources alongside this?

Yes — both stacks are designed to share the subscription. Deploy your own RGs and resources in the same subscription; just don't reuse the `<prefix>` slug for resources you don't want this module to manage.

### Where do I report bugs?

GitHub: [azure-launchpad/issues](https://github.com/travishankins/azure-launchpad/issues).
