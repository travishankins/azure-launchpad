# Full ALZ-aligned SMB hierarchy with a curated, opt-in starter set of
# ALZ policy assignments. Customers add/remove entries from policy_assignments
# to pick exactly which guardrails to enforce.

name_prefix         = "contoso"
display_name_prefix = "Contoso"

enable_identity_mg       = true
enable_security_mg       = true
enable_local_mg          = true
enable_decommissioned_mg = true
enable_sandboxes_mg      = true

enable_policies = true

policy_assignments = {
  # Block public RDP/SSH inbound on all landing-zone subscriptions.
  "Deny-MgmtPorts-Internet" = {
    scope_mg_key      = "landingzones"
    policy_definition = "/providers/Microsoft.Authorization/policyDefinitions/22730e10-96f6-4aac-ad84-9383d35b5917"
    enforce           = true
  }

  # Restrict deployable resource types under the Local MG to those
  # supported by Azure Local disconnected operations (preview, ALZ 2026.04).
  "Restrict-Local-Disconn" = {
    scope_mg_key      = "local"
    policy_definition = "/providers/Microsoft.Authorization/policyDefinitions/dabf7c7f-5354-42de-a92a-8367f538dd71"
    enforce           = false # start in Audit; flip to true once your exit story is ready
  }
}
