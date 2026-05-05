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
  subscription_id = "00000000-0000-0000-0000-000000000000"
  scenario        = "baseline"
}

run "budgets_disabled_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_consumption_budget_subscription.this) == 0
    error_message = "Budget must NOT be deployed when budget_enabled is false (default)."
  }
}

run "budgets_enabled_creates_one" {
  command = plan

  variables {
    budget_enabled      = true
    budget_amount       = 250
    budget_alert_emails = ["platform@example.com", "finance@example.com"]
    budget_thresholds   = [50, 80, 100]
  }

  assert {
    condition     = length(azurerm_consumption_budget_subscription.this) == 1
    error_message = "Budget must be deployed when budget_enabled = true."
  }

  assert {
    condition     = azurerm_consumption_budget_subscription.this[0].amount == 250
    error_message = "Budget amount must equal the configured value."
  }

  assert {
    condition     = azurerm_consumption_budget_subscription.this[0].time_grain == "Monthly"
    error_message = "Budget must be Monthly."
  }
}
