locals {
  # Scenario flags
  use_firewall = contains(["firewall", "full"], var.scenario)
  use_vpn      = contains(["vpn", "full"], var.scenario)
  use_nat      = !local.use_firewall # NAT GW only when no firewall handles egress
  use_peering  = local.use_firewall || local.use_vpn

  # Cross-scenario validation: vpn/full require at least one on-prem CIDR.
  _validate_onprem = (
    local.use_vpn && length(var.on_premises_address_space) == 0
  ) ? tobool("ERROR: on_premises_address_space must be provided for vpn/full scenarios.") : true

  # Naming
  suffix = "${var.name_prefix}-${var.region_short}"

  rg_names = {
    hub      = "rg-hub-${local.suffix}"
    spoke    = "rg-spoke-prod-${local.suffix}"
    monitor  = "rg-monitor-${local.suffix}"
    backup   = "rg-backup-${local.suffix}"
    security = "rg-security-${local.suffix}"
    migrate  = "rg-migrate-${local.suffix}"
  }

  vnet_hub_name   = "vnet-hub-${local.suffix}"
  vnet_spoke_name = "vnet-spoke-prod-${local.suffix}"

  # Subnets — derived from hub/spoke /23 spaces (8 x /26).
  # Hub layout: 0=AzureFirewallSubnet, 1=GatewaySubnet, 2=default, 3=AzureFirewallManagementSubnet (created by modules.firewall.tf)
  hub_subnets = {
    AzureFirewallSubnet = cidrsubnet(var.address_space_hub, 3, 0)
    GatewaySubnet       = cidrsubnet(var.address_space_hub, 3, 1)
    default             = cidrsubnet(var.address_space_hub, 3, 2)
  }
  hub_firewall_mgmt_cidr = cidrsubnet(var.address_space_hub, 3, 3)

  spoke_subnet_workload = cidrsubnet(var.address_space_spoke, 3, 0) # /26

  # Tags
  tags = merge(var.tags, {
    scenario = var.scenario
    location = var.location
  })
}
