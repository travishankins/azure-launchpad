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
