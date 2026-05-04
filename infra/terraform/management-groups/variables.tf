variable "subscription_id" {
  type        = string
  description = "Home subscription ID for the azurerm provider session. No subscription-scoped resources are deployed."
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "tenant_id" {
  type        = string
  description = "Entra tenant (directory) ID. Used as the parent of the top-level intermediate Management Group."
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "name_prefix" {
  type        = string
  default     = "contoso"
  description = "Lowercase prefix for Management Group names (used as the technical id)."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,8}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-10 chars, lowercase alphanumeric or hyphen, starting with a letter."
  }
}

variable "display_name_prefix" {
  type        = string
  default     = "Contoso"
  description = "Human-friendly prefix for Management Group display names."
}

# --- Hierarchy toggles (SMB-friendly defaults) ---------------------------

variable "enable_identity_mg" {
  type        = bool
  default     = false
  description = "Create the platform/identity Management Group. Recommended once you add a dedicated identity subscription."
}

variable "enable_security_mg" {
  type        = bool
  default     = false
  description = "Create the platform/security Management Group. Recommended once you add a dedicated security subscription."
}

variable "enable_local_mg" {
  type        = bool
  default     = true
  description = "Create the landingzones/local Management Group (per ALZ 2026.04 update — Azure Local / disconnected exit-readiness)."
}

variable "enable_decommissioned_mg" {
  type        = bool
  default     = true
  description = "Create the decommissioned Management Group (parking lot for cancelled subscriptions)."
}

variable "enable_sandboxes_mg" {
  type        = bool
  default     = true
  description = "Create the sandboxes Management Group (developer experimentation)."
}

# --- Subscription placement ---------------------------------------------

variable "subscription_placements" {
  type        = map(string)
  default     = {}
  description = <<-EOT
    Map of subscription GUID => Management Group key to associate.
    Keys must be one of: root, platform, management, connectivity, identity,
    security, landingzones, corp, online, local, decommissioned, sandboxes.

    Example:
      subscription_placements = {
        "00000000-0000-0000-0000-000000000001" = "connectivity"
        "00000000-0000-0000-0000-000000000002" = "management"
        "00000000-0000-0000-0000-000000000003" = "corp"
      }
  EOT
  validation {
    condition = alltrue([
      for sub_id, _ in var.subscription_placements :
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", sub_id))
    ])
    error_message = "All subscription_placements keys must be GUIDs."
  }
  validation {
    condition = alltrue([
      for _, mg in var.subscription_placements :
      contains([
        "root", "platform", "management", "connectivity", "identity", "security",
        "landingzones", "corp", "online", "local", "decommissioned", "sandboxes",
      ], mg)
    ])
    error_message = "subscription_placements values must be a known MG key."
  }
}

# --- Policy assignments (opt-in, pick-and-choose) ------------------------

variable "enable_policies" {
  type        = bool
  default     = false
  description = "Master switch for policy assignments. When false, no policies are assigned regardless of policy_assignments content."
}

variable "policy_assignments" {
  type = map(object({
    scope_mg_key       = string
    policy_definition  = string # Built-in initiative or definition resource ID
    description        = optional(string, "")
    display_name       = optional(string, null)
    parameters         = optional(map(any), {})
    enforce            = optional(bool, true) # true => Default, false => DoNotEnforce
    not_scopes         = optional(list(string), [])
    identity_type      = optional(string, "None") # None | SystemAssigned | UserAssigned
    location           = optional(string, null)   # Required when identity_type != "None"
    non_compliance_msg = optional(string, null)
  }))
  default     = {}
  description = <<-EOT
    Map of policy assignment NAME (24 chars max) => assignment spec. Customers
    pick which built-in (or custom) ALZ-aligned initiatives to apply and at
    which scope. Set enable_policies=true to actually deploy them.

    See variables docs for the curated catalog of recommended built-ins
    (Deny-MgmtPorts-Internet, Deploy-MDFC-Config, Enforce-TLS-SSL, etc.).

    Example:
      policy_assignments = {
        "Deny-MgmtPorts-Internet" = {
          scope_mg_key      = "landingzones"
          policy_definition = "/providers/Microsoft.Authorization/policyDefinitions/22730e10-96f6-4aac-ad84-9383d35b5917"
          enforce           = true
        }
      }
  EOT
  validation {
    condition     = alltrue([for k, _ in var.policy_assignments : length(k) <= 24])
    error_message = "Policy assignment names must be 24 characters or fewer."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to created resources (note: Management Groups themselves do not support tags)."
}
