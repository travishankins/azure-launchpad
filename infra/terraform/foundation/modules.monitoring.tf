###############################################################################
# Log Analytics workspace
###############################################################################
module "log_analytics" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.5.1"

  providers = {
    azurerm = azurerm.management
  }

  name                                               = "log-${local.suffix}"
  resource_group_name                                = local.rg["monitor"].name
  location                                           = var.location
  log_analytics_workspace_retention_in_days          = var.log_retention_days
  log_analytics_workspace_sku                        = "PerGB2018"
  log_analytics_workspace_daily_quota_gb             = 0.5
  log_analytics_workspace_internet_ingestion_enabled = true
  log_analytics_workspace_internet_query_enabled     = true
  tags                                               = local.tags
}

###############################################################################
# Automation Account (linked to Log Analytics)
###############################################################################
module "automation_account" {
  source  = "Azure/avm-res-automation-automationaccount/azurerm"
  version = "0.2.0"

  providers = {
    azurerm = azurerm.management
  }

  name                = "aa-${local.suffix}"
  resource_group_name = local.rg["monitor"].name
  location            = var.location
  sku                 = "Basic"
  tags                = local.tags
}

###############################################################################
# Recovery Services Vault
###############################################################################
module "recovery_vault" {
  source  = "Azure/avm-res-recoveryservices-vault/azurerm"
  version = "1.1.11"

  providers = {
    azurerm = azurerm.management
  }

  name                = "rsv-${local.suffix}"
  resource_group_name = local.rg["backup"].name
  location            = var.location
  sku                 = "Standard"
  storage_mode_type   = "GeoRedundant"
  soft_delete_enabled = true
  tags                = local.tags
}
