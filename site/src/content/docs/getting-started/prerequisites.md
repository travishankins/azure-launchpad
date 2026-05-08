---
title: Prerequisites
description: What you need before deploying the Azure Launchpad (SMB / SMEC Edition) landing zone — Cloud Shell, Codespaces, or local install.
---

## Choose your environment

Pick whichever matches the situation. All three deploy the same foundation; the difference is where the tooling lives.

| Option                                  | Best for                                                  | Setup time | Cost         | Persistence                         |
| --------------------------------------- | --------------------------------------------------------- | ---------- | ------------ | ----------------------------------- |
| **A. Azure Cloud Shell** (browser)      | One-off deploys, evaluations, customer demos, no laptop install | ~1 min     | Free shell + ~$0.05/mo for 5 GB clouddrive | 5 GB home dir survives sessions    |
| **B. GitHub Codespaces** (browser / VS Code) | Multi-day work, contributing back, working from a Chromebook / iPad | ~2 min (first) / ~30 s (resume) | Free tier 60 h/mo on 2-core; then per-hour | Whole container survives until deleted |
| **C. Local install** (your laptop)      | Daily driver, offline work, custom toolchain pinning      | 10–30 min  | Free         | Forever                             |

If you've never deployed Launchpad before, start with **Cloud Shell**. If you're going to maintain it, switch to **Codespaces** or **local**.

## Option A — Azure Cloud Shell

[Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) is a browser-hosted bash shell that comes pre-authenticated to Azure with Terraform, the Azure CLI, Bicep, and Git already installed. Nothing to download.

**1. Open it.** Either:

- Click the `>_` icon in the top bar of the [Azure Portal](https://portal.azure.com), or
- Go to <https://shell.azure.com> directly.

First-time use prompts you to create a 5 GB Azure Files share for `~` persistence (≈ $0.05/mo). Pick **Bash** (not PowerShell).

**2. Clone and deploy.**

```bash
git clone https://github.com/travishankins/azure-launchpad.git
cd azure-launchpad

# Cloud Shell is already authenticated to your tenant.
az account set --subscription <subscription-id>
export ARM_SUBSCRIPTION_ID=<subscription-id>

./scripts/bootstrap-state.sh
```

Then continue with the [Terraform](/getting-started/quick-start/) or [Bicep](/getting-started/quick-start-bicep/) quick start.

**What's preinstalled in Cloud Shell** (versions move; check with `--version`):

| Tool       | Available?                  | Notes                                                |
| ---------- | --------------------------- | ---------------------------------------------------- |
| Azure CLI  | ✅ latest, with `bicep` ext  | `az`, `az bicep build`                               |
| Terraform  | ✅ 1.x                       | If older than 1.9, see "Pinning Terraform" below     |
| Bicep      | ✅ via `az bicep`            | Standalone `bicep` binary also available             |
| Git        | ✅                          |                                                      |
| GitHub CLI | ✅                          | `gh`                                                 |
| jq, curl   | ✅                          |                                                      |
| `just`     | ❌ not preinstalled          | Optional — install once: `brew install just` won't work; use the binary release from <https://just.systems> or skip and run the underlying commands directly |
| `tflint`, `pre-commit` | ❌                | Only needed for contributing back, not for deploys   |

**Pinning Terraform.** If Cloud Shell's bundled Terraform is older than what the repo requires (≥ 1.9), the easiest fix is `tfenv`:

```bash
git clone --depth 1 https://github.com/tfutils/tfenv.git ~/.tfenv
export PATH="$HOME/.tfenv/bin:$PATH"
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
tfenv install 1.14.9 && tfenv use 1.14.9
```

The `~/.tfenv` directory persists in your clouddrive across sessions.

**Cloud Shell caveats:**

- **20-minute idle timeout.** Long applies (e.g. firewall + VPN scenarios) usually finish in under 20 min, but if your tunnel drops mid-apply, just re-run — Terraform/Bicep are both idempotent.
- **No outbound to private endpoints.** If you've already deployed and the workload is locked down behind a private endpoint, you can't `curl` it from Cloud Shell unless it's on a peered VNet (Cloud Shell supports VNet integration; out of scope here).
- **Editor.** `code .` opens the in-shell Monaco editor (read-write on `~`). Good enough for tweaking `.tfvars` / `.bicepparam`.
- **No GUI for the wizard.** The [deployment wizard](/wizard/) runs in your browser at azurelaunchpad.com — generate the file there, paste it into Cloud Shell.

## Option B — GitHub Codespaces

A Codespace is a containerized VS Code workspace running on GitHub-hosted infrastructure. Because the repo ships a [`.devcontainer/devcontainer.json`](https://github.com/travishankins/azure-launchpad/blob/main/.devcontainer/devcontainer.json), every tool is preinstalled at a known version — no drift between contributors.

**1. Launch.** One-click:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/travishankins/azure-launchpad)

…or in the repo, _Code → Codespaces → Create codespace on main_. First boot takes ~90 s while features install; subsequent resumes are seconds.

**2. Authenticate to Azure.**

```bash
az login --use-device-code
az account set --subscription <subscription-id>
export ARM_SUBSCRIPTION_ID=<subscription-id>
```

`--use-device-code` is required because Codespaces is browser-side; the redirect flow can't reach your localhost.

**3. Deploy.** Same as local — pick Terraform or Bicep quick start.

**What's inside the dev container:**

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

VS Code extensions are pre-pinned: HashiCorp Terraform, Bicep, Azure Resource Groups, GitHub Actions, GitHub Copilot, markdownlint, Astro, just. Port `4321` is auto-forwarded so `cd site && npm run dev` opens the live docs preview in a browser tab.

`postCreateCommand` runs `pre-commit install` and `npm install` in `site/` on first open — give it ~2 min, then you're ready to `az login`.

**Working in Codespaces — practical tips:**

- **Two surfaces, same container.** Open the codespace in the [browser](https://github.com/codespaces) for quick edits, or _Code → Open in VS Code Desktop_ for full extensions and local keybindings. Both attach to the same remote container, so your shell history and uncommitted changes are shared.
- **Stop, don't delete.** Stopped codespaces don't burn compute hours but keep your full filesystem. Delete only when you're done with the customer.
- **Free tier math.** GitHub gives 60 h/mo of 2-core (or 30 h/mo of 4-core) for personal accounts. A 2-core is plenty for `terraform plan` against this repo. Watch usage at <https://github.com/settings/billing>.
- **Secrets.** Store `ARM_SUBSCRIPTION_ID`, customer prefixes, etc. as [Codespace secrets](https://docs.github.com/codespaces/managing-codespaces-for-your-organization/managing-secrets-for-your-repository-and-organization-for-github-codespaces) so they're injected as env vars on every boot. Never paste a service principal secret into a chat or commit it.
- **Rebuild on devcontainer changes.** If `devcontainer.json` is updated upstream, _Command Palette → Codespaces: Rebuild Container_ picks up the changes; existing files survive.
- **Same image, locally.** The container also runs under VS Code Dev Containers on a local Docker — install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) and _Reopen in Container_. Identical tooling, no GitHub compute usage.

## Option C — Local install

Useful if you want offline work, custom Terraform pinning, or zero browser dependency.

| Tool                  | Minimum version | Why                             |
| --------------------- | --------------- | ------------------------------- |
| Terraform             | 1.9             | Module syntax, validation rules |
| Azure CLI             | 2.60            | `az login`, bootstrap script    |
| Bicep CLI             | 0.30            | Bundled with `az bicep install` |
| GitHub CLI (optional) | 2.40            | OIDC federated credential setup |
| `git`                 | 2.30            | Clone the repo                  |
| `just` (optional)     | latest          | Recipe runner — `brew install just` |

```bash
# macOS
brew install terraform azure-cli gh just
az bicep install
```

Then continue with [Local prep](#local-prep).

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
