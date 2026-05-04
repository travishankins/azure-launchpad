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
  subscription_id           = "00000000-0000-0000-0000-000000000000"
  scenario                  = "full"
  on_premises_address_space = ["192.168.0.0/16"]
}

run "plan" {
  command = plan

  assert {
    condition     = length(azurerm_firewall.this) == 1
    error_message = "full scenario must create Azure Firewall"
  }

  assert {
    condition     = length(azurerm_virtual_network_gateway.vpn) == 1
    error_message = "full scenario must create VPN Gateway"
  }

  assert {
    condition     = length(azurerm_nat_gateway.spoke) == 0
    error_message = "full scenario must NOT create NAT gateway (firewall handles egress)"
  }

  assert {
    condition     = length(azurerm_route_table.spoke) == 1
    error_message = "full scenario must create spoke route table"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_spoke) == 1
    error_message = "full scenario must peer hub and spoke"
  }
}
