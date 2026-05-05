# 0004. Management Groups are an opt-in second module

- **Status**: Accepted
- **Date**: 2026-04-15

## Context

The Azure Landing Zones reference architecture starts with a Management Group hierarchy at tenant root (Platform / Landing Zones / Decommissioned / Sandboxes / Local). Many SMB / SMEC customers don't have, or don't yet need, that hierarchy — they have one subscription, no platform team, and no Tenant Root permissions.

Mixing tenant-scoped MG resources into the subscription-scoped foundation module would force every contributor to have `Management Group Contributor` on Tenant Root, which they usually don't.

## Decision

Ship the MG hierarchy as a **separate root module** at `infra/terraform/management-groups` (Bicep equivalent at `infra/bicep/management-groups`). It has its own state file (`management-groups.<workspace>.tfstate`), its own `provider "azurerm"` block (with `tenant_id` set explicitly), and its own variables.

The foundation module has zero awareness of MGs. The two are deployed independently; ordering does not matter.

## Consequences

- Foundation can be deployed by anyone with `Contributor` on a single subscription. No tenant role required.
- MG deploy is a separate, auditable change with its own state and its own RBAC. `Management Group Contributor` (and `Resource Policy Contributor` for policy assignments) is needed only when actually deploying MGs.
- Doc burden: two getting-started flows. The wizard handles this by treating MG enablement as an explicit yes/no question.
- Cross-module wiring (e.g. assigning a policy at an MG to a subscription created by the foundation) has to be done by hand or via a future cross-state lookup. We accept the gap — most adopters either run MGs or don't.

## Alternatives considered

- **Single combined module with conditional MG resources**: rejected — every plan/apply would need tenant-root permissions even if MGs were disabled, because the provider would still need to refresh against tenant scope.
- **Skip MGs entirely**: rejected — Azure Landing Zones alignment was an explicit goal; an opt-in module gives customers a clear upgrade path without forcing them onto it on day one.
