# 🚀 Azure Launchpad (SMB / SMEC Edition)

[![Terraform plan](https://github.com/travishankins/azure-launchpad/actions/workflows/terraform-plan.yml/badge.svg?branch=main)](https://github.com/travishankins/azure-launchpad/actions/workflows/terraform-plan.yml)
[![Bicep plan](https://github.com/travishankins/azure-launchpad/actions/workflows/bicep-plan.yml/badge.svg?branch=main)](https://github.com/travishankins/azure-launchpad/actions/workflows/bicep-plan.yml)
[![Site deploy](https://github.com/travishankins/azure-launchpad/actions/workflows/site-deploy.yml/badge.svg?branch=main)](https://github.com/travishankins/azure-launchpad/actions/workflows/site-deploy.yml)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Opinionated Azure **landing zones** for **small and midsized businesses (SMB)** and **small and midsized enterprises and corps (SMEC)** — aligned with the Microsoft Cloud Adoption Framework (CAF) and Azure Landing Zone (ALZ) guidance, sized so a small platform team can actually own it. Deploys a hub-spoke topology with either **Terraform** (AVM-TF) or **Bicep**. One repo, four cost-tiered scenarios, one command. Includes an opt-in Management Groups + Azure Policy module for ALZ-aligned governance.

## Scenarios

| Scenario   | Approx. cost/mo | Adds                                                                        |
| ---------- | --------------- | --------------------------------------------------------------------------- |
| `baseline` | ~$48            | Hub-spoke VNets, NAT GW, Key Vault + PE, Log Analytics, Automation, RSV     |
| `firewall` | ~$336           | Baseline + Azure Firewall (Basic) + UDRs + hub↔spoke peering (replaces NAT) |
| `vpn`      | ~$187           | Baseline + VPN Gateway (`VpnGw1AZ`) + gateway transit                       |
| `full`     | ~$476           | Firewall + VPN combined                                                     |

📘 **Full docs + interactive deployment wizard:** [travishankins.github.io/azure-launchpad](https://travishankins.github.io/azure-launchpad/) — try the [deployment wizard](https://travishankins.github.io/azure-launchpad/wizard/). Source for the site lives in [`site/`](./site/) and is published by [`.github/workflows/site-deploy.yml`](./.github/workflows/site-deploy.yml).

## Prerequisites

- Terraform `>= 1.9`
- Azure CLI logged in (`az login`) with permissions to create resources in the target subscription
- For `vpn`/`full`: the on-premises address space (CIDR list)

## Quick start

```bash
# 1. One-time: create remote state backend
export ARM_SUBSCRIPTION_ID=<your-sub-id>
./scripts/bootstrap-state.sh
# → prints the resource_group_name / storage_account_name to use below

cd infra/terraform/foundation

# 2. Initialize against the Azure backend
terraform init \
  -backend-config="resource_group_name=rg-tfstate-contoso-wcus" \
  -backend-config="storage_account_name=<from bootstrap output>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=foundation.baseline.tfstate"

# 3. Workspace per scenario keeps state isolated
terraform workspace new baseline    # or: select -or-create

# 4. Plan & apply
terraform plan  -var="subscription_id=$ARM_SUBSCRIPTION_ID" -var-file=scenarios/baseline.tfvars
terraform apply -var="subscription_id=$ARM_SUBSCRIPTION_ID" -var-file=scenarios/baseline.tfvars
```

Switch scenarios by selecting the matching workspace and `-var-file`:

```bash
terraform workspace select -or-create firewall
terraform apply -var="subscription_id=$ARM_SUBSCRIPTION_ID" -var-file=scenarios/firewall.tfvars
```

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
scripts/             bootstrap-state.sh — one-time backend creation
infra/terraform/foundation/
  ├── *.tf           Root module composed from feature files
  ├── scenarios/     Per-scenario tfvars
  └── tests/         .tftest.hcl plan-mode tests (mock providers)
site/                Astro Starlight docs + deployment wizard (deploys to GitHub Pages)
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
