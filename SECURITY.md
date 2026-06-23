# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in **Azure Launchpad**, please report it privately so we can fix it before public disclosure.

**Do not** open a public GitHub issue.

### How to report

- **Preferred:** open a [GitHub Security Advisory](https://github.com/travishankins/azure-launchpad/security/advisories/new) (private). This keeps the discussion confidential and lets us coordinate a fix and CVE.
- **Alternative:** email the maintainer through the address listed on their [GitHub profile](https://github.com/travishankins). Please include `[azure-launchpad security]` in the subject.

### What to include

- Affected component (Terraform module, Bicep module, wizard, docs site, CI workflow)
- Affected version / commit SHA
- Steps to reproduce, including any `tfvars` / `bicepparam` values needed
- Impact assessment (what can an attacker do — credential theft, lateral movement, cost, data exposure, etc.)
- Any suggested remediation

### What to expect

| Stage                                            | Target                 |
| ------------------------------------------------ | ---------------------- |
| Acknowledgement of report                        | within 3 business days |
| Initial assessment + severity rating (CVSS v3.1) | within 7 business days |
| Fix in `main` for High / Critical                | within 30 days         |
| Public advisory + credit (if you want it)        | after fix is released  |

### Scope

In scope:

- Terraform and Bicep modules in [`infra/`](infra/)
- The configuration generator in [`site/public/scripts/wizard.js`](site/public/scripts/wizard.js) (in particular: anything that could leak `subscription_id` / `tenant_id` / on-prem CIDRs to a third party)
- GitHub Actions workflows in [`.github/workflows/`](.github/workflows/) (OIDC misconfig, secret exfiltration, supply chain)
- The bootstrap script [`scripts/bootstrap-state.sh`](scripts/bootstrap-state.sh)

Out of scope (please report to the upstream project):

- Vulnerabilities in HashiCorp Terraform itself, the AzureRM provider, or [Azure Verified Modules](https://github.com/Azure/terraform-azurerm-avm-template) — report at the respective repos
- Vulnerabilities in Bicep, Azure CLI, or Azure platform services — report via [Microsoft Security Response Center](https://msrc.microsoft.com/create-report)
- Vulnerabilities in Astro / Starlight / npm dependencies — Dependabot / `npm audit` will surface these; PRs welcome

### Safe harbor

We will not pursue legal action against researchers who:

- Make a good-faith effort to follow this policy
- Avoid privacy violations, data destruction, or service disruption
- Give us a reasonable time to fix the issue before public disclosure

Thank you for helping keep the project and its users safe.
