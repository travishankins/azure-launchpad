resource "azurerm_management_group" "this" {
  for_each = local.mgs

  name                       = local.mg_names[each.key]
  display_name               = each.value.display
  parent_management_group_id = each.value.parent
}

# Subscription placements (idempotent: moves the sub under the chosen MG).
resource "azurerm_management_group_subscription_association" "this" {
  for_each = local.sub_placements

  management_group_id = azurerm_management_group.this[each.value.mg_key].id
  subscription_id     = "/subscriptions/${each.value.subscription_id}"
}
