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
mock_provider "azapi" {}
mock_provider "random" {}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  scenario        = "firewall"
}

run "plan" {
  command = plan

  assert {
    condition     = length(azurerm_firewall.this) == 1
    error_message = "firewall scenario must create Azure Firewall"
  }

  assert {
    condition     = length(azurerm_nat_gateway.spoke) == 0
    error_message = "firewall scenario must NOT create NAT gateway"
  }

  assert {
    condition     = length(azurerm_virtual_network_gateway.vpn) == 0
    error_message = "firewall scenario must NOT create VPN Gateway"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_spoke) == 1
    error_message = "firewall scenario must peer hub and spoke"
  }

  assert {
    condition     = length(azurerm_route_table.spoke) == 1
    error_message = "firewall scenario must create spoke route table"
  }
}
