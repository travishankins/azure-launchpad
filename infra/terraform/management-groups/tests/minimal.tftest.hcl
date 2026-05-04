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

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  tenant_id       = "00000000-0000-0000-0000-000000000000"
  name_prefix     = "contoso"

  enable_identity_mg       = false
  enable_security_mg       = false
  enable_local_mg          = true
  enable_decommissioned_mg = true
  enable_sandboxes_mg      = true
  enable_policies          = false
}

run "plan" {
  command = plan

  # 7 static MGs + local + decommissioned + sandboxes = 10
  assert {
    condition     = length(azurerm_management_group.this) == 10
    error_message = "minimal scenario must create exactly 10 Management Groups"
  }

  assert {
    condition     = length(azurerm_management_group_policy_assignment.this) == 0
    error_message = "minimal scenario must NOT assign any policies"
  }

  assert {
    condition     = length(azurerm_management_group_subscription_association.this) == 0
    error_message = "minimal scenario should not place any subscriptions by default"
  }
}
