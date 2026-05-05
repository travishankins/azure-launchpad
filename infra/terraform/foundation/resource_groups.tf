###############################################################################
# Resource groups, split by ALZ layer so each lands on its own provider alias.
# In single-sub mode all three providers point at var.subscription_id, so the
# net effect is identical to a flat layout. In multi-sub mode each group lands
# in its assigned subscription.
###############################################################################

resource "azurerm_resource_group" "connectivity" {
  for_each = local.rgs_connectivity
  provider = azurerm.connectivity

  name     = each.value
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "management" {
  for_each = local.rgs_management
  provider = azurerm.management

  name     = each.value
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "landingzone" {
  for_each = local.rgs_landingzone
  provider = azurerm.landingzone

  name     = each.value
  location = var.location
  tags     = local.tags
}

# Merged view used by the rest of the module — drop-in replacement for the
# previous `azurerm_resource_group.this[<key>]` map.
locals {
  rg = merge(
    azurerm_resource_group.connectivity,
    azurerm_resource_group.management,
    azurerm_resource_group.landingzone,
  )
}
