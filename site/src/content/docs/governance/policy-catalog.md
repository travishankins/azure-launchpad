---
title: Policy catalog (pick & choose)
description: Curated list of ALZ-aligned built-in Azure Policy initiatives you can opt into via the management-groups module.
---

The `management-groups` module deliberately ships **zero** policy assignments by default. Customers pick which ALZ-aligned built-in initiatives to assign and at which scope, via the `policy_assignments` map.

Set `enable_policies = true` to deploy them. The variable doubles as a kill switch — flip to `false` to suppress every assignment without removing the map entries.

## Shape of an assignment

```hcl
policy_assignments = {
  "Deny-MgmtPorts-Internet" = {                # name (≤24 chars)
    scope_mg_key      = "landingzones"          # any MG key from the hierarchy
    policy_definition = "/providers/Microsoft.Authorization/policyDefinitions/22730e10-96f6-4aac-ad84-9383d35b5917"
    enforce           = true                    # true = Default, false = DoNotEnforce (Audit)
    parameters        = {}                      # optional, map(any) — keys match initiative parameters
    not_scopes        = []                      # optional, list of MG/sub/RG IDs to exempt
    identity_type     = "None"                  # None | SystemAssigned | UserAssigned
    location          = null                    # required if identity_type != "None"
    non_compliance_msg = null                   # optional human-readable message
  }
}
```

## Recommended starter set (SMB)

Copy any of these into your tfvars. Verify the definition ID against the Azure Portal or [azadvertizer.net](https://www.azadvertizer.net/) before applying — definitions evolve.

### Network & ingress

| Name                      | Scope          | Policy                                                                                                             |
| ------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------ |
| `Deny-MgmtPorts-Internet` | `landingzones` | Block public RDP/SSH on NSGs — `22730e10-96f6-4aac-ad84-9383d35b5917`                                              |
| `Deny-Public-IP`          | `corp`         | Disallow public IP creation on Corp workloads (use the [ALZ ESLZ network initiative](https://aka.ms/alz/policies)) |

### Locations & data residency

| Name                   | Scope  | Policy                                                                               |
| ---------------------- | ------ | ------------------------------------------------------------------------------------ |
| `Allowed-Locations`    | `root` | Restrict resources to your approved regions — `e56962a6-4747-49cd-b67b-bf8b01975c4c` |
| `Allowed-RG-Locations` | `root` | Same for resource groups — `e765b5de-1225-4ba3-bd56-1ac6695af988`                    |

### Defender for Cloud

| Name                 | Scope  | Policy                                                                                                                            |
| -------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `Deploy-MDFC-Config` | `root` | Configure ASC default initiative — `/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8` |

### Diagnostics

| Name                   | Scope          | Policy                              |
| ---------------------- | -------------- | ----------------------------------- |
| `Deploy-Diag-Activity` | `root`         | Send activity logs to Log Analytics |
| `Deploy-VM-Monitoring` | `landingzones` | Auto-deploy AMA + DCR for VMs       |

### Azure Local disconnected workloads (ALZ 2026.04 — preview)

| Name                     | Scope   | Policy                                                                                                                                                                                                        |
| ------------------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Restrict-Local-Disconn` | `local` | Restrict resource types to those supported in Azure Local disconnected ops — `dabf7c7f-5354-42de-a92a-8367f538dd71`. Start with `enforce = false` (Audit), then flip to `true` after validating disconnected workload requirements. |

### Sovereign Public Cloud (per ALZ 2026.04 SLZ update)

If your workloads must align to sovereign control levels L1/L2/L3, see the [Microsoft Learn sovereign controls page](https://learn.microsoft.com/azure/azure-sovereign-clouds/public/overview-controls-principles) and assign:

- **L1 — Data residency:** `[Preview]: Enforce Data Residency across Azure Services`
- **L2 — Encryption-at-rest:** `[Preview]: Enforce Encryption-at-Rest with CMK (AKV Premium)` and the Managed-HSM variant
- **L2 — Encryption-in-transit:** `[Preview]: Enforce Encryption-in-Transit — HTTPS` and `— TLS Version`
- **L3 — Encryption-in-use:** `[Preview]: Enforce Encryption-in-Use across Azure Services` (Confidential Compute)

These are built-in initiatives published by the Sovereign Public product group — you don't have to copy them into your repo.

## Audit first, enforce later

For every new assignment, deploy with `enforce = false` and watch the [Azure Policy compliance dashboard](https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyMenuBlade/Compliance) for a few days. Flip to `true` once you've fixed the existing non-compliant resources or added the necessary `not_scopes` exemptions.

## Where to find more definition IDs

- [aka.ms/alz/policies](https://aka.ms/alz/policies) — the ALZ default policy library
- [azadvertizer.net](https://www.azadvertizer.net/) — searchable, with current definition IDs
- `az policy definition list --query "[?policyType=='BuiltIn'].{name:name, displayName:displayName}" -o table`
