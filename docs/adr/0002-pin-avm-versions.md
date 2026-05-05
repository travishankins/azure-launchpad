# 0002. Pin Azure Verified Modules to exact versions

- **Status**: Accepted
- **Date**: 2026-04-15

## Context

Every Azure resource in the foundation is wrapped by an [Azure Verified Module](https://aka.ms/avm) (`Azure/avm-res-*/azurerm`). AVMs are versioned independently and ship breaking changes on minor bumps (the AzureRM provider underneath is on `~> 4.x`).

Common patterns:

- `version = "~> 0.5"` (allow patch + minor up to next major)
- `version = "0.5.1"` (exact pin)

## Decision

**Pin every AVM `version` argument to an exact version** (no `~>`, no `>=`). Bumps happen via a deliberate PR that updates the version, regenerates the lockfile, and runs the test suite. Renovate / Dependabot are configured to open a PR per AVM bump.

## Consequences

- `terraform init` produces byte-identical module sources across machines, CI runs, and contributors. No "works on my laptop" caused by an upstream module shipping a breaking change overnight.
- The lockfile (`.terraform.lock.hcl`) further pins provider checksums; combined with exact AVM versions, planning is fully reproducible.
- Cost: AVM updates are a manual review step, not a passive backport. We accept this — AVMs are the most common source of "the plan changed and I don't know why" in pre-production runs.
- The `validate.yml` workflow runs `terraform init -upgrade=false` so CI catches anyone who tries to drift the pin.

## Alternatives considered

- **`~> X.Y` constraints**: rejected — minor AVM versions have shipped renamed inputs before. We want the breakage to surface in a Renovate PR, not at `terraform plan` time.
- **No constraints**: rejected — same problem, worse blast radius.
