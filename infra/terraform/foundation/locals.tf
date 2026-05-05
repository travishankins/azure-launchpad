locals {
  # ---------------------------------------------------------------------------
  # Multi-subscription resolution
  # ---------------------------------------------------------------------------
  # In `single` mode every alias resolves to var.subscription_id. In `multi`
  # mode each layer can be split out; any layer left blank falls back to
  # var.subscription_id so partial migrations work too.
  is_multi_sub = var.deployment_mode == "multi"

  sub_connectivity = local.is_multi_sub && var.connectivity_subscription_id != "" ? var.connectivity_subscription_id : var.subscription_id
  sub_management   = local.is_multi_sub && var.management_subscription_id != "" ? var.management_subscription_id : var.subscription_id
  sub_landingzone  = local.is_multi_sub && var.landingzone_subscription_id != "" ? var.landingzone_subscription_id : var.subscription_id

  # Cross-validation: in multi mode, all three layer sub IDs must be set.
  _validate_multi_sub_ids = (
    local.is_multi_sub && (
      var.connectivity_subscription_id == "" ||
      var.management_subscription_id == "" ||
      var.landingzone_subscription_id == ""
    )
  ) ? tobool("ERROR: deployment_mode = 'multi' requires connectivity_subscription_id, management_subscription_id, and landingzone_subscription_id to all be set.") : true

  # Scenario flags
  use_firewall = contains(["firewall", "full"], var.scenario)
  use_vpn      = contains(["vpn", "full"], var.scenario)
  use_nat      = !local.use_firewall # NAT GW only when no firewall handles egress
  use_peering  = local.use_firewall || local.use_vpn

  # Cross-scenario validation: vpn/full require at least one on-prem CIDR.
  _validate_onprem = (
    local.use_vpn && length(var.on_premises_address_space) == 0
  ) ? tobool("ERROR: on_premises_address_space must be provided for vpn/full scenarios.") : true

  # Budget validation: enabling budgets requires at least one alert email.
  _validate_budget_emails = (
    var.budget_enabled && length(var.budget_alert_emails) == 0
  ) ? tobool("ERROR: budget_alert_emails must contain at least one address when budget_enabled = true.") : true

  # Naming
  suffix = "${var.name_prefix}-${var.region_short}"

  # ---------------------------------------------------------------------------
  # Resource groups split by ALZ layer.
  # In single mode this is purely organisational; in multi mode each group
  # lands in its own subscription via the matching provider alias.
  # ---------------------------------------------------------------------------
  rgs_connectivity = {
    hub = "rg-hub-${local.suffix}"
  }
  rgs_management = {
    monitor = "rg-monitor-${local.suffix}"
    backup  = "rg-backup-${local.suffix}"
  }
  rgs_landingzone = {
    spoke    = "rg-spoke-prod-${local.suffix}"
    security = "rg-security-${local.suffix}"
    migrate  = "rg-migrate-${local.suffix}"
  }
  rg_names = merge(local.rgs_connectivity, local.rgs_management, local.rgs_landingzone)

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

  # Availability zone support varies by region. The list below covers regions
  # that do NOT support AZs (as of 2026); resources in those regions must be
  # zone-less. Anything not in this list defaults to zone-redundant [1,2,3].
  _regions_without_zones = [
    "westcentralus",
    "northcentralus",
    "westus",
    "centralindia",
    "switzerlandwest",
    "norwaywest",
    "uaenorth",
    "francesouth",
    "germanynorth",
    "swedensouth",
    "brazilsoutheast",
    "jioindiawest",
    "jioindiacentral",
    "australiacentral",
    "australiacentral2",
    "australiasoutheast",
    "southindia",
    "westindia",
    "japanwest",
    "koreasouth",
    "canadaeast",
    "ukwest",
  ]
  region_supports_zones = !contains(local._regions_without_zones, var.location)
  availability_zones    = local.region_supports_zones ? ["1", "2", "3"] : []

  # Tags
  tags = merge(var.tags, {
    scenario = var.scenario
    location = var.location
  })
}
