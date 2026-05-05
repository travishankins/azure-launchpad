data "azurerm_client_config" "current" {}

###############################################################################
# Key Vault with private endpoint into the spoke
###############################################################################
module "key_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.2"

  providers = {
    azurerm = azurerm.landingzone
  }

  name                = "kv-${local.suffix}-${random_string.kv_suffix.result}"
  resource_group_name = local.rg["security"].name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name                      = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = false

  network_acls = {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  private_endpoints = {
    primary = {
      name                          = "pe-kv-${local.suffix}"
      subnet_resource_id            = module.vnet_spoke.subnets["workload"].resource_id
      private_dns_zone_resource_ids = [module.pdz_keyvault.resource_id]
      subresource_name              = "vault"
    }
  }

  tags = local.tags
}

resource "random_string" "kv_suffix" {
  length  = 5
  upper   = false
  special = false
  numeric = true
}
