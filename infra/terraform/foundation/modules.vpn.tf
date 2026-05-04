###############################################################################
# VPN Gateway (vpn | full scenarios)
# Site-to-site connection + Local Network Gateway are intentionally deferred —
# wire them up once customer on-prem peer + PSK are known.
###############################################################################
resource "azurerm_public_ip" "vpn" {
  count = local.use_vpn ? 1 : 0

  name                = "pip-vpngw-${local.suffix}"
  resource_group_name = azurerm_resource_group.this["hub"].name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_virtual_network_gateway" "vpn" {
  count = local.use_vpn ? 1 : 0

  name                = "vpngw-${local.suffix}"
  resource_group_name = azurerm_resource_group.this["hub"].name
  location            = var.location

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  bgp_enabled   = false
  sku           = "VpnGw1AZ"
  generation    = "Generation2"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = module.vnet_hub.subnets["GatewaySubnet"].resource_id
  }

  tags = local.tags
}
