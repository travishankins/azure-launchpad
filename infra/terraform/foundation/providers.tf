###############################################################################
# Provider aliases for multi-subscription (ALZ-aligned) deployment.
#
# When deployment_mode = "single", all three aliases resolve to the same
# subscription (var.subscription_id). When deployment_mode = "multi", each
# alias resolves to its own subscription, matching the ALZ pattern of
# Connectivity / Management / Landing-Zone subscriptions.
#
# All resources in the foundation set their own `provider = azurerm.<alias>`
# so the same code path serves both modes.
###############################################################################

provider "azurerm" {
  # Default provider — used by data sources that just need any auth context
  # (e.g. data.azurerm_client_config). Resource bodies should always pin to
  # one of the three named aliases below.
  subscription_id = var.subscription_id

  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azurerm" {
  alias           = "connectivity"
  subscription_id = local.sub_connectivity

  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azurerm" {
  alias           = "management"
  subscription_id = local.sub_management

  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azurerm" {
  alias           = "landingzone"
  subscription_id = local.sub_landingzone

  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azapi" {}
