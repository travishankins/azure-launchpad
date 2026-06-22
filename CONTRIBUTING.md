# Contributing to Azure Launchpad (SMB / SMEC Edition)

Thanks for your interest! This project deploys Azure landing zones via Terraform and Bicep, with an Astro / Starlight docs site that includes an interactive configuration generator. Contributions of all kinds are welcome — bug reports, feature ideas, doc tweaks, new modules, and tests.

## Quick links

- 🐛 **Found a bug?** Open an [issue](https://github.com/travishankins/azure-launchpad/issues/new/choose) using the bug template.
- 💡 **Have an idea?** Open a feature request issue or start a [discussion](https://github.com/travishankins/azure-launchpad/discussions).
- 🔒 **Security?** Read [`SECURITY.md`](SECURITY.md) — please **don't** open a public issue.
- 📖 **Want to write docs?** All docs live in [`site/src/content/docs/`](site/src/content/docs/) — edits + previews are easy.

## Development setup

You'll need:

- **Terraform** `>= 1.9`
- **Azure CLI** (`az login` to a non-prod subscription you can deploy into)
- **Bicep** (bundled with `az`; `az bicep upgrade` to refresh)
- **Node** `>= 20` (for the docs site)
- **gh** CLI (optional, for releases / issue triage)

Clone, install, run the site locally:

```bash
git clone https://github.com/travishankins/azure-launchpad.git
cd azure-launchpad
cd site && npm ci && npm run dev   # http://localhost:4321/azure-launchpad/
```

For Terraform / Bicep, see [Quick start](README.md#quick-start) and [Prerequisites](https://travishankins.github.io/azure-launchpad/getting-started/prerequisites/).

## Branch + PR workflow

1. **Fork** the repo (or create a branch if you have write access).
2. Branch off `main` using a descriptive name:
   - `feat/<short-description>` — new module, scenario, doc page
   - `fix/<short-description>` — bug fix
   - `docs/<short-description>` — docs-only changes
   - `chore/<short-description>` — tooling / CI / dependencies
3. Make your changes. Keep PRs **focused** — one logical change per PR.
4. Run local checks before pushing (see below).
5. Push and open a PR against `main`.
6. Required CI must pass (`terraform-plan`, `bicep-plan`, `site-deploy`) and at least one maintainer must review.

### Commit messages — Conventional Commits

We use [Conventional Commits](https://www.conventionalcommits.org/) so that release notes and changelogs can be generated automatically. Format:

```
<type>(<scope>): <short summary>

<optional body explaining why, what changed, and any breaking changes>
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `perf`, `style`.

Examples:

- `feat(terraform): add backup-policies module for VM RSV policies`
- `fix(bicep): allow VpnGw2AZ in non-AZ regions`
- `docs(scenarios): add troubleshooting page for VPN BGP failures`
- `chore(deps): bump azurerm to ~> 4.20`

A breaking change is signalled with `!` after the type/scope, e.g. `feat(terraform)!: rename var.address_space_hub`.

## Local checks

Before opening a PR, please run:

```bash
# Terraform
cd infra/terraform/foundation
terraform fmt -recursive ../..
terraform validate
terraform test                    # runs scenario .tftest.hcl plans

# Bicep
az bicep build --file infra/bicep/foundation/main.bicep
az bicep build --file infra/bicep/management-groups/main.bicep
az bicep build-params --file infra/bicep/foundation/baseline.bicepparam   # repeat per scenario

# Site
cd site && npm run build
```

CI runs the same checks on PR. If any fail, please fix locally first.

## Coding standards

### Terraform

- All variables must have `description`, `type`, and (where useful) `validation` blocks
- All outputs must have `description`; sensitive values must set `sensitive = true`
- Use [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/) when one exists for the resource you're adding
- Pin AVM modules to an exact version; allow `~>` only for HashiCorp providers
- Add a `*.tftest.hcl` plan-mode assertion when you add a new module or scenario flag

### Bicep

- Parameters must have `@description` and, where applicable, `@allowed`, `@minLength`, `@maxLength`
- Mirror the Terraform module structure where reasonable so users can switch tools without surprises
- Run `az bicep lint --file <module>` clean before opening a PR

### Docs

- Docs live in [`site/src/content/docs/`](site/src/content/docs/); use Markdown or MDX
- Always link to other pages with the workspace-relative URL (Starlight resolves them at build time)
- Code blocks must specify a language (` ```bash`, ` ```hcl`, ` ```bicep`)
- Use sentence case for headings

### Wizard

- The wizard lives entirely in [`site/public/scripts/wizard.js`](site/public/scripts/wizard.js) — no framework, no build step
- Keep it accessible: every input needs a `<label>`, every interactive element should be keyboard-reachable, and every error needs a screen-reader-friendly message
- New questions belong in the `QUESTIONS` array; keep `help` and `impact` short

## Adding a new scenario or module

1. Add Terraform under [`infra/terraform/foundation/`](infra/terraform/foundation/) (module + scenario tfvars + `tests/<scenario>.tftest.hcl`)
2. Add Bicep equivalent under [`infra/bicep/foundation/`](infra/bicep/foundation/) (module + `<scenario>.bicepparam`)
3. Update the wizard's `QUESTIONS` and scenario-selection logic
4. Add or update a docs page in [`site/src/content/docs/scenarios/`](site/src/content/docs/scenarios/)
5. Update the scenarios table in [`README.md`](README.md)

## Release process

Releases are cut from `main`:

1. Maintainer creates a release PR (or uses [`release-please`](https://github.com/googleapis/release-please) once configured)
2. Conventional Commits since the last tag are converted into a CHANGELOG entry
3. PR is reviewed and merged; a `vX.Y.Z` tag is pushed automatically
4. GitHub Pages redeploys the site from `main`

## Code of Conduct

By participating you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).
