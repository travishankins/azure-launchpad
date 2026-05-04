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
  scenario        = "baseline"
}

run "plan" {
  command = plan

  assert {
    condition     = length(azurerm_resource_group.this) == 6
    error_message = "baseline must create exactly 6 resource groups"
  }

  assert {
    condition     = length(azurerm_nat_gateway.spoke) == 1
    error_message = "baseline must include a NAT gateway"
  }

  assert {
    condition     = length(azurerm_firewall.this) == 0
    error_message = "baseline must NOT include Azure Firewall"
  }

  assert {
    condition     = length(azurerm_virtual_network_gateway.vpn) == 0
    error_message = "baseline must NOT include a VPN Gateway"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_spoke) == 0
    error_message = "baseline must NOT peer hub and spoke"
  }
}
