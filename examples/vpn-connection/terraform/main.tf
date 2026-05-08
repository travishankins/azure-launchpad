terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.16"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Look up the existing VPN gateway by its resource ID so we can reuse its
# resource group + location without re-declaring them.
data "azurerm_virtual_network_gateway" "vpn" {
  name                = element(split("/", var.vpn_gateway_id), length(split("/", var.vpn_gateway_id)) - 1)
  resource_group_name = element(split("/", var.vpn_gateway_id), 4)
}

resource "azurerm_local_network_gateway" "onprem" {
  name                = "lng-${var.connection_name}"
  resource_group_name = data.azurerm_virtual_network_gateway.vpn.resource_group_name
  location            = data.azurerm_virtual_network_gateway.vpn.location
  gateway_address     = var.peer_ip
  address_space       = var.peer_address_spaces
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "onprem" {
  name                = "cn-${var.connection_name}"
  resource_group_name = data.azurerm_virtual_network_gateway.vpn.resource_group_name
  location            = data.azurerm_virtual_network_gateway.vpn.location

  type                       = "IPsec"
  virtual_network_gateway_id = data.azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id

  shared_key  = var.shared_key
  bgp_enabled = false

  tags = var.tags
}
