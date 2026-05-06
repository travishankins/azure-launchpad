# Architecture Decision Records (ADRs)

This directory captures the **why** behind the structural choices in Azure Launchpad. Each ADR is short, one decision per file, and dated.

Format: lightweight [Michael Nygard ADR](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions). Status is one of `Proposed`, `Accepted`, `Superseded by …`, `Deprecated`.

## Index

| #    | Title                                                                                 | Status   |
| ---- | ------------------------------------------------------------------------------------- | -------- |
| 0001 | [Scenarios as Terraform workspaces](0001-scenarios-as-workspaces.md)                  | Accepted |
| 0002 | [Pin Azure Verified Modules to exact versions](0002-pin-avm-versions.md)              | Accepted |
| 0003 | [Azure Firewall Basic as the default SKU](0003-firewall-basic-default.md)             | Accepted |
| 0004 | [Management Groups are an opt-in second module](0004-management-groups-opt-in.md)     | Accepted |
| 0005 | [Astro `base: '/'` for custom-domain GitHub Pages hosting](0005-astro-base-path.md)   | Accepted |
| 0006 | [Multi-subscription deployment mode](0006-multi-subscription-mode.md)                 | Accepted |

## When to add a new ADR

Add one when you make a decision that:

- changes the shape of the repo (new top-level module, renamed scenario, swapped tooling),
- locks in a defaulted-but-debatable design choice (SKU, region, naming convention),
- or you find yourself explaining the same "why" more than twice.

Do **not** add ADRs for ephemeral fixes, code-style tweaks, or anything reversible in one PR.

## Template

```markdown
# NNNN. Short title

- **Status**: Accepted
- **Date**: YYYY-MM-DD

## Context

What forces / constraints / facts shape this decision?

## Decision

What we chose. Be specific.

## Consequences

Positive, negative, and follow-on work this implies.

## Alternatives considered

Brief — one paragraph each — with why we passed.
```
