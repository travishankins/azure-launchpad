# Plan-mode tests for the optional Azure Monitor workbook module.
# Provider stub keeps the run offline (no Azure auth needed).

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

run "workbook_disabled_by_default" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    scenario        = "baseline"
    location        = "westcentralus"
    name_prefix     = "test"
  }

  assert {
    condition     = length(azurerm_application_insights_workbook.foundation_health) == 0
    error_message = "Workbook resource should not be planned when workbook_enabled = false."
  }
}

run "workbook_enabled_creates_one" {
  command = plan

  variables {
    subscription_id  = "00000000-0000-0000-0000-000000000000"
    scenario         = "baseline"
    location         = "westcentralus"
    name_prefix      = "test"
    workbook_enabled = true
  }

  assert {
    condition     = length(azurerm_application_insights_workbook.foundation_health) == 1
    error_message = "Workbook resource should be planned exactly once when workbook_enabled = true."
  }

  assert {
    condition     = azurerm_application_insights_workbook.foundation_health[0].display_name == "Azure Launchpad — Foundation Health"
    error_message = "Workbook display name should be the foundation default."
  }
}
