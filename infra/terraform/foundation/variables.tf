variable "subscription_id" {
  description = "Target Azure subscription ID (GUID)."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid GUID (e.g. 00000000-0000-0000-0000-000000000000)."
  }
}

variable "scenario" {
  description = "Deployment scenario: baseline | firewall | vpn | full."
  type        = string
  validation {
    condition     = contains(["baseline", "firewall", "vpn", "full"], var.scenario)
    error_message = "scenario must be one of: baseline, firewall, vpn, full."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westcentralus"
}

variable "region_short" {
  description = "Short region code used in resource names."
  type        = string
  default     = "wcus"
}

variable "name_prefix" {
  description = "Short prefix for resource names."
  type        = string
  default     = "contoso"
  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.name_prefix))
    error_message = "name_prefix must be 2-8 lowercase alphanumeric characters."
  }
}

variable "address_space_hub" {
  description = "Hub VNet CIDR."
  type        = string
  default     = "10.0.0.0/23"
}

variable "address_space_spoke" {
  description = "Spoke VNet CIDR."
  type        = string
  default     = "10.0.2.0/23"
}

variable "on_premises_address_space" {
  description = "List of on-premises CIDRs for VPN/Full scenarios. Required when scenario is vpn or full."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for c in var.on_premises_address_space : can(cidrhost(c, 0))])
    error_message = "All entries in on_premises_address_space must be valid CIDRs."
  }
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Base tags applied to all resources."
  type        = map(string)
  default = {
    workload    = "azure-launchpad"
    iac         = "terraform"
    cost_center = "platform"
  }
}

###############################################################################
# Budgets (optional, opt-in)
###############################################################################

variable "budget_enabled" {
  description = "If true, deploy a subscription-scoped monthly budget with email alerts. Free."
  type        = bool
  default     = false
}

variable "budget_amount" {
  description = "Monthly budget amount in the subscription's billing currency (typically USD)."
  type        = number
  default     = 100
  validation {
    condition     = var.budget_amount > 0
    error_message = "budget_amount must be greater than 0."
  }
}

variable "budget_thresholds" {
  description = "Percent-of-budget thresholds at which to send Actual-spend notifications. Forecasted 100% is always sent."
  type        = list(number)
  default     = [50, 80, 100]
  validation {
    condition     = alltrue([for t in var.budget_thresholds : t > 0 && t <= 1000])
    error_message = "All budget_thresholds must be between 1 and 1000 (percent)."
  }
}

variable "budget_alert_emails" {
  description = "Email recipients for budget alerts. Required when budget_enabled = true."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for e in var.budget_alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "All budget_alert_emails entries must look like a valid email address."
  }
}

variable "budget_resource_group_names" {
  description = "Optional list of resource group names to scope the budget to. Empty => entire subscription."
  type        = list(string)
  default     = []
}
