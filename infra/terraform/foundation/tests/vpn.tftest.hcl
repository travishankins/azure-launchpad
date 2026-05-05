mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      client_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000000"
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "azurerm" { alias = "connectivity" }
mock_provider "azurerm" { alias = "management" }
mock_provider "azurerm" { alias = "landingzone" }
mock_provider "azapi" {}
mock_provider "random" {}

variables {
  subscription_id           = "00000000-0000-0000-0000-000000000000"
  scenario                  = "vpn"
  on_premises_address_space = ["192.168.0.0/16"]
}

run "plan" {
  command = plan

  assert {
    condition     = length(azurerm_virtual_network_gateway.vpn) == 1
    error_message = "vpn scenario must create VPN Gateway"
  }

  assert {
    condition     = length(azurerm_nat_gateway.spoke) == 1
    error_message = "vpn scenario must keep NAT gateway for outbound"
  }

  assert {
    condition     = length(azurerm_firewall.this) == 0
    error_message = "vpn scenario must NOT create Azure Firewall"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_spoke) == 1
    error_message = "vpn scenario must peer hub and spoke (gateway transit)"
  }
}
