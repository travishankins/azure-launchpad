# Plan-mode tests for multi-subscription mode (ALZ split across 3 subs).
# Provider stubs keep the run offline (no Azure auth needed).

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

run "single_mode_is_default" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    scenario        = "baseline"
    location        = "westcentralus"
    name_prefix     = "test"
  }

  assert {
    condition     = length(azurerm_resource_group.connectivity) + length(azurerm_resource_group.management) + length(azurerm_resource_group.landingzone) == 6
    error_message = "Single mode should still create all 6 RGs across the three split resources."
  }
}

run "multi_mode_splits_rgs_by_layer" {
  command = plan

  variables {
    subscription_id              = "00000000-0000-0000-0000-000000000000"
    connectivity_subscription_id = "11111111-1111-1111-1111-111111111111"
    management_subscription_id   = "22222222-2222-2222-2222-222222222222"
    landingzone_subscription_id  = "33333333-3333-3333-3333-333333333333"
    deployment_mode              = "multi"
    scenario                     = "full"
    location                     = "westcentralus"
    name_prefix                  = "test"
    on_premises_address_space    = ["192.168.0.0/16"]
  }

  assert {
    condition     = length(azurerm_resource_group.connectivity) == 1
    error_message = "Connectivity layer should own exactly 1 RG (hub)."
  }

  assert {
    condition     = length(azurerm_resource_group.management) == 2
    error_message = "Management layer should own exactly 2 RGs (monitor + backup)."
  }

  assert {
    condition     = length(azurerm_resource_group.landingzone) == 3
    error_message = "Landing-zone layer should own exactly 3 RGs (spoke + security + migrate)."
  }

  assert {
    condition     = azurerm_resource_group.connectivity["hub"].name == "rg-hub-test-wcus"
    error_message = "Hub RG name should follow the rg-hub-<suffix> pattern."
  }

  assert {
    condition     = azurerm_resource_group.landingzone["spoke"].name == "rg-spoke-prod-test-wcus"
    error_message = "Spoke RG name should follow the rg-spoke-prod-<suffix> pattern."
  }
}
