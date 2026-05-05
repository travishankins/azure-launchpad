output "scenario" {
  description = "Deployed scenario."
  value       = var.scenario
}

output "resource_group_names" {
  description = "All resource group names by role."
  value       = { for k, rg in azurerm_resource_group.this : k => rg.name }
}

output "vnet_hub_id" {
  description = "Hub VNet resource ID."
  value       = module.vnet_hub.resource_id
}

output "vnet_spoke_id" {
  description = "Spoke VNet resource ID."
  value       = module.vnet_spoke.resource_id
}

output "key_vault_uri" {
  description = "Key Vault URI."
  value       = module.key_vault.uri
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = module.log_analytics.resource_id
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP (null when scenario does not include firewall)."
  value       = local.use_firewall ? azurerm_firewall.this[0].ip_configuration[0].private_ip_address : null
  sensitive   = true
}

output "vpn_gateway_id" {
  description = "VPN Gateway resource ID (null when scenario does not include VPN)."
  value       = local.use_vpn ? azurerm_virtual_network_gateway.vpn[0].id : null
}

output "nat_gateway_id" {
  description = "NAT Gateway resource ID (null when scenario does not include NAT)."
  value       = local.use_nat ? azurerm_nat_gateway.spoke[0].id : null
}
