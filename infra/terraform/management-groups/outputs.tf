output "management_group_ids" {
  value       = { for k, mg in azurerm_management_group.this : k => mg.id }
  description = "Map of MG key (root, platform, connectivity, …) to full resource ID."
}

output "management_group_names" {
  value       = local.mg_names
  description = "Map of MG key to the technical name (used as the URI segment)."
}

output "subscription_placements" {
  value       = { for k, p in azurerm_management_group_subscription_association.this : k => p.management_group_id }
  description = "Subscriptions and the MG they were placed under."
}

output "policy_assignment_ids" {
  value       = { for k, a in azurerm_management_group_policy_assignment.this : k => a.id }
  description = "IDs of policy assignments that were created."
}
