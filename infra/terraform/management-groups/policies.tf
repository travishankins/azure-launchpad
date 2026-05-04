# Optional, fully customer-driven Azure Policy assignments.
#
# Customers pick which policies/initiatives to assign and where via
# `var.policy_assignments`. Nothing is assigned unless `enable_policies = true`.
#
# Recommended ALZ-aligned built-ins (paste the definition_id into your tfvars):
#
#   Deny-MgmtPorts-Internet     (Audit/Deny SSH/RDP from internet)
#     /providers/Microsoft.Authorization/policyDefinitions/22730e10-96f6-4aac-ad84-9383d35b5917
#
#   Deploy-MDFC-DefenderSQL     (Defender for Cloud — SQL plan)
#     /providers/Microsoft.Authorization/policySetDefinitions/ASC-Default
#
#   Enforce-TLS-SSL-H224        (TLS 1.2 minimum on App Services / Storage)
#     Use built-in policy initiatives from Azure Policy "Security" category.
#
#   Restrict-ResourceTypes-Local  (Azure Local exit-readiness — preview)
#     /providers/Microsoft.Authorization/policyDefinitions/dabf7c7f-5354-42de-a92a-8367f538dd71
#
#   Allowed-Locations / Audit-Allowed-Locations
#     /providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c
#
#   Sovereign Baseline initiatives (per ALZ 2026.04 SLZ update)
#     See https://learn.microsoft.com/azure/azure-sovereign-clouds/public/overview-controls-principles

locals {
  effective_assignments = var.enable_policies ? var.policy_assignments : {}
}

resource "azurerm_management_group_policy_assignment" "this" {
  for_each = local.effective_assignments

  name                 = each.key
  management_group_id  = azurerm_management_group.this[each.value.scope_mg_key].id
  policy_definition_id = each.value.policy_definition

  display_name = coalesce(each.value.display_name, each.key)
  description  = each.value.description
  enforce      = each.value.enforce
  not_scopes   = each.value.not_scopes
  parameters   = length(each.value.parameters) > 0 ? jsonencode(each.value.parameters) : null
  location     = each.value.location

  dynamic "identity" {
    for_each = each.value.identity_type == "None" ? [] : [each.value.identity_type]
    content {
      type = identity.value
    }
  }

  dynamic "non_compliance_message" {
    for_each = each.value.non_compliance_msg == null ? [] : [each.value.non_compliance_msg]
    content {
      content = non_compliance_message.value
    }
  }
}
