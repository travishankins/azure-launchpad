# Note: this root operates at TENANT scope. The principal running it needs
# `Management Group Contributor` (and `Resource Policy Contributor` on each
# target MG if policy assignments are enabled) at Tenant Root.
#
# subscription_id is required by azurerm 4.x but only used as the home
# subscription for the provider session — no subscription-scoped resources
# are created here.
provider "azurerm" {
  subscription_id = var.subscription_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
