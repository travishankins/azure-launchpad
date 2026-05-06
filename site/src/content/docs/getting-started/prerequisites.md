---
title: Prerequisites
description: What you need before deploying the Azure Launchpad (SMB / SMEC Edition) landing zone.
---

## Tooling

The fastest way to get every tool below installed at the right version is to **open the repo in GitHub Codespaces or VS Code Dev Containers** — see [Dev container](#dev-container) below. Otherwise, install locally:

| Tool                  | Minimum version | Why                             |
| --------------------- | --------------- | ------------------------------- |
| Terraform             | 1.9             | Module syntax, validation rules |
| Azure CLI             | 2.60            | `az login`, bootstrap script    |
| GitHub CLI (optional) | 2.40            | OIDC federated credential setup |
| `git`                 | 2.30            | Clone the repo                  |

## Dev container

The repo ships a [`.devcontainer/devcontainer.json`](https://github.com/travishankins/azure-launchpad/blob/main/.devcontainer/devcontainer.json) that pre-installs everything you need to deploy the foundation, build the docs site, and run the test suites — zero local setup required.

**What's inside:**

| Component    | Version / source                                    | Used for                                               |
| ------------ | --------------------------------------------------- | ------------------------------------------------------ |
| Ubuntu 24.04 | `mcr.microsoft.com/devcontainers/base:ubuntu-24.04` | Base image                                             |
| Azure CLI    | latest, with `bicep` extension                      | `az login`, deploys, bootstrap script                  |
| Terraform    | 1.14.9 + tflint                                     | Foundation + management-groups modules                 |
| Node.js      | 20                                                  | Astro / Starlight docs site (`cd site && npm run dev`) |
| Python       | 3.12                                                | Helper scripts                                         |
| GitHub CLI   | latest                                              | OIDC federated credential setup, repo automation       |
| pre-commit   | latest                                              | Auto-runs `terraform fmt`, lint, etc. on commit        |
| just         | latest                                              | Recipe runner (`just plan baseline`, `just docs`, ...) |

Also pre-configures the recommended VS Code extensions (HashiCorp Terraform, Bicep, Astro, GitHub Copilot, markdownlint, just) and forwards port `4321` for the docs dev server.

**How to use it:**

- **GitHub Codespaces:** Click _Code → Codespaces → Create codespace on main_ in the repo. Free tier covers ~60h/mo on a 2-core machine.
- **VS Code (local Docker):** Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers), then _Command Palette → Dev Containers: Reopen in Container_.

On first open, `postCreateCommand` runs `pre-commit install` and `npm install` in `site/` — give it ~2 min, then you're ready to `az login` and deploy.

## Azure access

- An Azure subscription where you have **Owner** at the subscription scope (needed once for the Service Principal + bootstrap RG/storage).
- Permission to create app registrations in Microsoft Entra ID (or an existing app registration you can reuse).
- For post-deploy site-to-site VPN wiring: knowledge of the customer's on-premises VPN device public IP, supported IKE versions, shared key handling, and the on-premises CIDR(s) that should be reachable.

## Local prep

```bash
git clone https://github.com/travishankins/azure-launchpad.git
cd azure-launchpad
az login
az account set --subscription <subscription-id>
```

## State backend (one-time per customer)

```bash
export ARM_SUBSCRIPTION_ID=<subscription-id>
./scripts/bootstrap-state.sh
```

This creates:

- A resource group `rg-tfstate-<prefix>-<region>`
- A storage account `st<prefix>tfstate<6-char-hash>`
- A blob container `tfstate`

The script is idempotent — re-running it just discovers the existing resources.

## CI/CD prerequisites (optional)

If you want plan/apply to run in GitHub Actions, you also need:

- An Entra ID app registration with a federated credential trusting your repo
- The repo variables listed in [CI/CD pipeline](/reference/cicd/)
