resource "azurerm_resource_group" "this" {
  for_each = local.rg_names

  name     = each.value
  location = var.location
  tags     = local.tags
}
