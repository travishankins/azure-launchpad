###############################################################################
# Hub VNet
###############################################################################
module "vnet_hub" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.17.1"

  providers = {
    azurerm = azurerm.connectivity
  }

  name          = local.vnet_hub_name
  parent_id     = local.rg["hub"].id
  location      = var.location
  address_space = [var.address_space_hub]
  tags          = local.tags

  subnets = {
    AzureFirewallSubnet = {
      name             = "AzureFirewallSubnet"
      address_prefixes = [local.hub_subnets.AzureFirewallSubnet]
    }
    GatewaySubnet = {
      name             = "GatewaySubnet"
      address_prefixes = [local.hub_subnets.GatewaySubnet]
    }
    default = {
      name             = "default"
      address_prefixes = [local.hub_subnets.default]
    }
  }
}

###############################################################################
# Spoke VNet
###############################################################################
module "vnet_spoke" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.17.1"

  providers = {
    azurerm = azurerm.landingzone
  }

  name          = local.vnet_spoke_name
  parent_id     = local.rg["spoke"].id
  location      = var.location
  address_space = [var.address_space_spoke]
  tags          = local.tags

  subnets = {
    workload = {
      name             = "snet-workload"
      address_prefixes = [local.spoke_subnet_workload]
      nat_gateway = local.use_nat ? {
        id = azurerm_nat_gateway.spoke[0].id
      } : null
    }
  }
}

###############################################################################
# NAT Gateway (baseline + vpn scenarios)
###############################################################################
resource "azurerm_public_ip" "nat" {
  count    = local.use_nat ? 1 : 0
  provider = azurerm.landingzone

  name                = "pip-nat-spoke-${local.suffix}"
  resource_group_name = local.rg["spoke"].name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = local.availability_zones
  tags                = local.tags
}

resource "azurerm_nat_gateway" "spoke" {
  count    = local.use_nat ? 1 : 0
  provider = azurerm.landingzone

  name                    = "natgw-spoke-${local.suffix}"
  resource_group_name     = local.rg["spoke"].name
  location                = var.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
  tags                    = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "spoke" {
  count    = local.use_nat ? 1 : 0
  provider = azurerm.landingzone

  nat_gateway_id       = azurerm_nat_gateway.spoke[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

###############################################################################
# Hub <-> Spoke peering (firewall, vpn, full)
###############################################################################
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  count    = local.use_peering ? 1 : 0
  provider = azurerm.connectivity

  name                         = "peer-hub-to-spoke"
  resource_group_name          = local.rg["hub"].name
  virtual_network_name         = module.vnet_hub.name
  remote_virtual_network_id    = module.vnet_spoke.resource_id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = local.use_vpn
  allow_virtual_network_access = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count    = local.use_peering ? 1 : 0
  provider = azurerm.landingzone

  name                         = "peer-spoke-to-hub"
  resource_group_name          = local.rg["spoke"].name
  virtual_network_name         = module.vnet_spoke.name
  remote_virtual_network_id    = module.vnet_hub.resource_id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  allow_virtual_network_access = true
  # Only consume the remote (hub) gateway once it actually exists.
  use_remote_gateways = local.use_vpn

  depends_on = [azurerm_virtual_network_gateway.vpn]
}

###############################################################################
# Private DNS — Key Vault zone (extend as more PE-enabled services are added)
###############################################################################
module "pdz_keyvault" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.5.0"

  providers = {
    azurerm = azurerm.connectivity
  }

  domain_name = "privatelink.vaultcore.azure.net"
  parent_id   = local.rg["hub"].id
  tags        = local.tags

  virtual_network_links = {
    hub = {
      vnetlinkname = "link-hub"
      vnetid       = module.vnet_hub.resource_id
    }
    spoke = {
      vnetlinkname = "link-spoke"
      vnetid       = module.vnet_spoke.resource_id
    }
  }
}
