---
title: Management Groups (optional)
description: Opt-in ALZ-aligned Management Group hierarchy for Azure Launchpad (SMEC Edition), including the new Local MG.
---

The core `foundation` module deploys into **one subscription** with no Management Groups (MGs). For most SMB customers that's the right starting point.

If you want ALZ-aligned governance — multi-subscription placement, an upgrade path to enterprise ALZ, and tenant-scoped policy assignments — deploy the **separate, opt-in** `management-groups` root module from this repo.

## Why a separate module?

- **Different scope.** MGs live at tenant root; the foundation lives in one subscription. Mixing them would force every customer to grant tenant-root permissions just to deploy a hub-spoke.
- **Different blast radius.** MG and policy changes affect every subscription beneath them.
- **Different state.** Stored under a different backend key (`management-groups.<scenario>.tfstate`).
- **Different RBAC.** The deploying principal needs `Management Group Contributor` (and `Resource Policy Contributor` for policies) at Tenant Root — not just Contributor on a sub.

## Hierarchy (SMB-friendly defaults)

```
Tenant Root
└── contoso                    (intermediate root)
    ├── platform
    │   ├── management
    │   ├── connectivity
    │   ├── identity            (opt-in)
    │   └── security            (opt-in)
    ├── landingzones
    │   ├── corp
    │   ├── online
    │   └── local               (NEW — ALZ 2026.04, opt-in, default ON)
    ├── decommissioned          (opt-in, default ON)
    └── sandboxes               (opt-in, default ON)
```

The `local` MG was added in [ALZ 2026.04](https://techcommunity.microsoft.com/blog/azuregovernanceandmanagementblog/new-local-management-group-for-alz--updated-sovereign-policies-for-slz/4515156) for workloads on (or migratable to) Azure Local disconnected operations.

## Toggles

| Variable                   | Default | Effect                                   |
| -------------------------- | ------- | ---------------------------------------- |
| `enable_identity_mg`       | `false` | Add `platform/identity`                  |
| `enable_security_mg`       | `false` | Add `platform/security`                  |
| `enable_local_mg`          | `true`  | Add `landingzones/local`                 |
| `enable_decommissioned_mg` | `true`  | Add `decommissioned` parking lot         |
| `enable_sandboxes_mg`      | `true`  | Add `sandboxes`                          |
| `enable_policies`          | `false` | Master switch for all policy assignments |

## Subscription placement

Move existing subscriptions under MGs by adding entries to `subscription_placements`:

```hcl
subscription_placements = {
  "00000000-0000-0000-0000-000000000001" = "connectivity"
  "00000000-0000-0000-0000-000000000002" = "management"
  "00000000-0000-0000-0000-000000000003" = "corp"
}
```

Valid MG keys: `root`, `platform`, `management`, `connectivity`, `identity`, `security`, `landingzones`, `corp`, `online`, `local`, `decommissioned`, `sandboxes`.

## Policies

Policy assignments are **opt-in** and **fully customer-driven** — see the [Policy catalog](/azure-launchpad/governance/policy-catalog/) for the recommended list of ALZ-aligned built-in initiatives you can assign.

## Deploy

```bash
cd infra/terraform/management-groups

terraform init \
  -backend-config="resource_group_name=$TFSTATE_RG" \
  -backend-config="storage_account_name=$TFSTATE_SA" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=management-groups.minimal.tfstate"

TF_VAR_subscription_id=$ARM_SUBSCRIPTION_ID \
TF_VAR_tenant_id=$ARM_TENANT_ID \
  terraform plan -var-file=scenarios/minimal.tfvars
```

Apply when you're happy with the plan.

## Upgrade path

Once you've deployed `management-groups`, place the subscription you ran `foundation` into under `corp` (or `online`, or `local`) via `subscription_placements`. Policy guardrails inherited from the MG hierarchy will apply automatically. To grow to enterprise ALZ later, flip `enable_identity_mg` / `enable_security_mg` and assign more initiatives — no foundation re-deploy required.
