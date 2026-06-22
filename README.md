# 🚀 Azure Launchpad (SMB / SMEC Edition)

[![Terraform plan](https://github.com/travishankins/azure-launchpad/actions/workflows/terraform-plan.yml/badge.svg?branch=main)](https://github.com/travishankins/azure-launchpad/actions/workflows/terraform-plan.yml)
[![Bicep plan](https://github.com/travishankins/azure-launchpad/actions/workflows/bicep-plan.yml/badge.svg?branch=main)](https://github.com/travishankins/azure-launchpad/actions/workflows/bicep-plan.yml)
[![Site deploy](https://github.com/travishankins/azure-launchpad/actions/workflows/site-deploy.yml/badge.svg?branch=main)](https://github.com/travishankins/azure-launchpad/actions/workflows/site-deploy.yml)
[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/travishankins/azure-launchpad)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Opinionated Azure **landing zones** for small and midsized organizations, aligned with the Microsoft Cloud Adoption Framework and Azure Landing Zone guidance. Deploy a hub-spoke foundation with **Terraform** or **Bicep** through one consistent lifecycle: configure, preflight, preview, approve, apply, and verify.

## Scenarios

| Scenario   | Approx. cost/mo | Adds                                                                        |
| ---------- | --------------- | --------------------------------------------------------------------------- |
| `baseline` | ~$48            | Hub-spoke VNets, NAT GW, Key Vault + PE, Log Analytics, Automation, RSV     |
| `firewall` | ~$336           | Baseline + Azure Firewall (Basic) + UDRs + hub↔spoke peering (replaces NAT) |
| `vpn`      | ~$327           | Baseline + VPN Gateway (`VpnGw2AZ`) + gateway transit                       |
| `full`     | ~$616           | Firewall + VPN combined                                                     |

📘 **Full docs + interactive configuration generator:** [azurelaunchpad.com](https://azurelaunchpad.com/) — try the [configuration generator](https://azurelaunchpad.com/wizard/). Source for the site lives in [`site/`](./site/) and is published by [`.github/workflows/site-deploy.yml`](./.github/workflows/site-deploy.yml).

> ℹ️ See [Non-goals](https://azurelaunchpad.com/reference/non-goals/) for what Launchpad intentionally does _not_ do.

## Prerequisites

- Terraform `>= 1.9`
- Azure CLI logged in (`az login`) with `Contributor` on each target subscription
- Terraform state users also need `Storage Blob Data Contributor` on the state account; bootstrap requires temporary role-assignment permission
- For post-deploy site-to-site VPN wiring: the customer VPN peer IP, shared key handling, and on-premises CIDRs

> 💡 **Skip the local install.** Three zero-setup paths, fully documented in [Prerequisites → Choose your environment](https://azurelaunchpad.com/getting-started/prerequisites/#choose-your-environment):
>
> - **Azure Cloud Shell** — open <https://shell.azure.com>, `git clone`, deploy. Pre-authenticated, `az` + `terraform` built in.
> - **GitHub Codespaces** — [one-click launch](https://codespaces.new/travishankins/azure-launchpad). Full VS Code with Terraform 1.14, Azure CLI + Bicep, Node 22, GitHub CLI, pre-commit, and `just` preinstalled via [`.devcontainer`](./.devcontainer/devcontainer.json).
> - **VS Code Dev Container** — _Reopen in Container_ on a local Docker. Same image as Codespaces.

## Quick start

Generate a configuration at [azurelaunchpad.com/wizard](https://azurelaunchpad.com/wizard/), then use the emitted commands. The shared entry point is:

```bash
./scripts/deploy.sh plan  --iac terraform|bicep --mode single|multi ...
# Review the Terraform plan or Bicep what-if output.
./scripts/deploy.sh apply --iac terraform|bicep --mode single|multi ...
./scripts/verify.sh ...
```

Terraform `apply` requires the saved plan created by `plan`. See the [Terraform](https://azurelaunchpad.com/getting-started/quick-start/) and [Bicep](https://azurelaunchpad.com/getting-started/quick-start-bicep/) quick starts for complete commands.

## Tests

```bash
cd infra/terraform/foundation
terraform init -backend=false
terraform test
```

All four `tests/*.tftest.hcl` files run plan-mode assertions (no Azure API calls).

## Repository layout

```
.github/workflows/   GitHub Actions: plan-on-PR (matrix), apply-on-dispatch
scripts/             preflight, state bootstrap, preview/apply, and verification
infra/terraform/foundation/
  ├── *.tf           Root module composed from feature files
  ├── scenarios/     Per-scenario tfvars
  └── tests/         .tftest.hcl plan-mode tests (mock providers)
site/                Astro Starlight docs + configuration generator (deploys to GitHub Pages)
```

## CI/CD

GitHub Actions uses OIDC (no secrets). Configure these repository **variables**:

| Variable                                          | Purpose                                 |
| ------------------------------------------------- | --------------------------------------- |
| `AZURE_CLIENT_ID`                                 | App registration (federated credential) |
| `AZURE_TENANT_ID`                                 | Entra tenant                            |
| `AZURE_SUBSCRIPTION_ID`                           | Target subscription                     |
| `TFSTATE_RG` / `TFSTATE_SA` / `TFSTATE_CONTAINER` | From `bootstrap-state.sh` output        |

`terraform-plan.yml` runs on PR for all four scenarios in parallel. `terraform-apply.yml` is a manual workflow gated by the protected `prod` GitHub environment.

## Contributing

Issues and PRs are welcome. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) for the development setup, branch / commit conventions, and local checks. By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). Security issues should be reported privately per [`SECURITY.md`](SECURITY.md).

## License

Apache License 2.0 — see [`LICENSE`](LICENSE).
