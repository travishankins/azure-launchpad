# 0001. Scenarios as Terraform workspaces

- **Status**: Accepted
- **Date**: 2026-04-15

## Context

Azure Launchpad ships four reference deployments — `baseline`, `firewall`, `vpn`, `full` — that share the same code (one root module under `infra/terraform/foundation`) but differ in which optional modules are enabled (Azure Firewall, VPN Gateway). We needed a way to keep them isolated in state without forking the source.

Three options were on the table:

1. **Separate root modules per scenario** (`foundation-baseline`, `foundation-firewall`, …)
2. **Single root module + Terraform workspaces** (one workspace per scenario, scenario name baked into state file key)
3. **Single root module + Terragrunt** (separate state per scenario via wrapper tooling)

## Decision

Use a **single root module under `infra/terraform/foundation`** and one **Terraform workspace per scenario**. The state file key in the Azure Storage backend is `foundation.<workspace>.tfstate`. Scenarios are selected at plan time with `terraform workspace select -or-create <scenario>` plus `-var-file=scenarios/<scenario>.tfvars`.

## Consequences

- Code stays DRY — no copy-paste across four root modules; module wiring (firewall, vpn) is gated by `local.use_firewall` / `local.use_vpn` derived from the `scenario` variable.
- State files are isolated per scenario; you can have all four deployed in parallel under different workspaces without collisions.
- Workspace names are intentionally identical to scenario names so the two never drift.
- Cost: the operator must remember `terraform workspace select` before every plan. The Justfile recipes (`just plan <scenario>`) abstract this away.
- Cost: workspaces only isolate **state**, not RBAC. All scenarios deploy to whatever subscription is in `subscription_id`.

## Alternatives considered

- **Separate root modules**: rejected — each bug fix would have to be applied four times, the modules would inevitably drift, and contributors would be tempted to "just tweak the firewall one."
- **Terragrunt**: rejected — adds a tooling dependency for a problem that native workspaces solve cleanly. We want a contributor who knows only Terraform to be productive.
