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

  enable_identity_mg       = true
  enable_security_mg       = true
  enable_local_mg          = true
  enable_decommissioned_mg = true
  enable_sandboxes_mg      = true
  enable_policies          = true

  policy_assignments = {
    "Deny-MgmtPorts-Internet" = {
      scope_mg_key      = "landingzones"
      policy_definition = "/providers/Microsoft.Authorization/policyDefinitions/22730e10-96f6-4aac-ad84-9383d35b5917"
      enforce           = true
    }
    "Restrict-Local-Disconn" = {
      scope_mg_key      = "local"
      policy_definition = "/providers/Microsoft.Authorization/policyDefinitions/dabf7c7f-5354-42de-a92a-8367f538dd71"
      enforce           = false
    }
  }

  subscription_placements = {
    "11111111-1111-1111-1111-111111111111" = "connectivity"
    "22222222-2222-2222-2222-222222222222" = "management"
    "33333333-3333-3333-3333-333333333333" = "corp"
  }
}

run "plan" {
  command = plan

  # 7 static + identity + security + local + decommissioned + sandboxes = 12
  assert {
    condition     = length(azurerm_management_group.this) == 12
    error_message = "full scenario must create exactly 12 Management Groups"
  }

  assert {
    condition     = length(azurerm_management_group_policy_assignment.this) == 2
    error_message = "full scenario must assign exactly 2 policies"
  }

  assert {
    condition     = length(azurerm_management_group_subscription_association.this) == 3
    error_message = "full scenario must place 3 subscriptions"
  }
}

run "policies_disabled_when_master_off" {
  command = plan

  variables {
    enable_policies = false
  }

  assert {
    condition     = length(azurerm_management_group_policy_assignment.this) == 0
    error_message = "enable_policies=false must suppress all policy assignments"
  }
}
