###############################################################################
# Azure Firewall (Basic) + Policy + 2 PIPs + spoke route table
# Enabled when scenario = firewall | full
###############################################################################
resource "azurerm_public_ip" "fw" {
  for_each = local.use_firewall ? toset(["pip1", "pip2"]) : toset([])

  name                = "pip-fw-${each.key}-${local.suffix}"
  resource_group_name = azurerm_resource_group.this["hub"].name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

# Firewall Basic requires a management subnet + management PIP.
resource "azurerm_subnet" "fw_mgmt" {
  count = local.use_firewall ? 1 : 0

  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.this["hub"].name
  virtual_network_name = module.vnet_hub.name
  address_prefixes     = [local.hub_firewall_mgmt_cidr]

  depends_on = [module.vnet_hub]
}

resource "azurerm_public_ip" "fw_mgmt" {
  count = local.use_firewall ? 1 : 0

  name                = "pip-fw-mgmt-${local.suffix}"
  resource_group_name = azurerm_resource_group.this["hub"].name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_firewall_policy" "this" {
  count = local.use_firewall ? 1 : 0

  name                = "fwpol-${local.suffix}"
  resource_group_name = azurerm_resource_group.this["hub"].name
  location            = var.location
  sku                 = "Basic"
  tags                = local.tags
}

resource "azurerm_firewall" "this" {
  count = local.use_firewall ? 1 : 0

  name                = "afw-${local.suffix}"
  resource_group_name = azurerm_resource_group.this["hub"].name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  firewall_policy_id  = azurerm_firewall_policy.this[0].id
  zones               = ["1", "2", "3"]

  ip_configuration {
    name                 = "ipcfg-primary"
    subnet_id            = module.vnet_hub.subnets["AzureFirewallSubnet"].resource_id
    public_ip_address_id = azurerm_public_ip.fw["pip1"].id
  }

  ip_configuration {
    name                 = "ipcfg-secondary"
    public_ip_address_id = azurerm_public_ip.fw["pip2"].id
  }

  management_ip_configuration {
    name                 = "ipcfg-mgmt"
    subnet_id            = azurerm_subnet.fw_mgmt[0].id
    public_ip_address_id = azurerm_public_ip.fw_mgmt[0].id
  }

  tags = local.tags
}

###############################################################################
# Spoke route table — force 0.0.0.0/0 through the firewall
###############################################################################
resource "azurerm_route_table" "spoke" {
  count = local.use_firewall ? 1 : 0

  name                = "rt-spoke-${local.suffix}"
  resource_group_name = azurerm_resource_group.this["spoke"].name
  location            = var.location
  tags                = local.tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.this[0].ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "spoke_workload" {
  count = local.use_firewall ? 1 : 0

  subnet_id      = module.vnet_spoke.subnets["workload"].resource_id
  route_table_id = azurerm_route_table.spoke[0].id
}
