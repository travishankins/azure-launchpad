// Azure Launchpad (SMB / SMEC Edition) — foundation root (Bicep)
// Functional parity with infra/terraform/foundation.
//
// Deploys hub-spoke networking, optional Azure Firewall (Basic), optional VPN
// Gateway, Private DNS, Key Vault (with PE), Log Analytics, Automation Account,
// and Recovery Services Vault — driven by the `scenario` parameter.

targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Deployment scenario.')
@allowed([
  'baseline'
  'firewall'
  'vpn'
  'full'
])
param scenario string

@description('Azure region for all resources.')
param location string = 'westcentralus'

@description('Short region code used in resource names (e.g. wcus, eus).')
param regionShort string = 'wcus'

@description('Short prefix for resource names. 2-8 lowercase alphanumerics.')
@minLength(2)
@maxLength(8)
param namePrefix string = 'contoso'

@description('Hub VNet CIDR (must be a /23 to fit firewall + gateway + default + mgmt subnets).')
param addressSpaceHub string = '10.0.0.0/23'

@description('Spoke VNet CIDR.')
param addressSpaceSpoke string = '10.0.2.0/23'

@description('On-premises CIDRs. Required for vpn/full scenarios (used by VPN local network gateways and route tables).')
param onPremisesAddressSpace array = []

@description('Log Analytics workspace retention in days.')
@minValue(30)
@maxValue(730)
param logRetentionDays int = 30

@description('Base tags applied to all resources.')
param tags object = {
  workload: 'azure-launchpad'
  iac: 'bicep'
  cost_center: 'platform'
}

// --- Optional: subscription budget -----------------------------------------

@description('Enable a subscription-scoped monthly budget with email alerts. Free.')
param budgetEnabled bool = false

@description('Monthly budget amount (USD or subscription billing currency).')
@minValue(1)
param budgetAmount int = 100

@description('Percent-of-budget thresholds for Actual-spend alerts.')
param budgetThresholds array = [
  50
  80
  100
]

@description('Email recipients for budget alerts. Required when budgetEnabled = true.')
param budgetAlertEmails array = []

// --- Optional: Azure Monitor workbook --------------------------------------

@description('Deploy the starter Foundation Health workbook into the monitoring RG.')
param workbookEnabled bool = false

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var useFirewall = scenario == 'firewall' || scenario == 'full'
var useVpn = scenario == 'vpn' || scenario == 'full'
var useNat = !useFirewall
var usePeering = useFirewall || useVpn

// Regions without availability zone support. When deploying here, zonal
// resources (PIPs, NAT GW, Azure Firewall, VPN PIP) must omit `zones`.
// Note: VPN Gateway SKU still must be *AZ even in non-AZ regions (Azure
// requirement as of May 2026 — NonAzSkusNotAllowedForVPNGateway).
var regionsWithoutZones = [
  'westcentralus'
  'northcentralus'
  'westus'
  'centralindia'
  'switzerlandwest'
  'norwaywest'
  'uaenorth'
  'francesouth'
  'germanynorth'
  'swedensouth'
  'brazilsoutheast'
  'jioindiawest'
  'jioindiacentral'
  'australiacentral'
  'australiacentral2'
  'australiasoutheast'
  'southindia'
  'westindia'
  'japanwest'
  'koreasouth'
  'canadaeast'
  'ukwest'
]
var regionSupportsZones = !contains(regionsWithoutZones, location)
var availabilityZones = regionSupportsZones ? [
  '1'
  '2'
  '3'
] : []

var suffix = '${namePrefix}-${regionShort}'

var rgNames = {
  hub: 'rg-hub-${suffix}'
  spoke: 'rg-spoke-prod-${suffix}'
  monitor: 'rg-monitor-${suffix}'
  backup: 'rg-backup-${suffix}'
  security: 'rg-security-${suffix}'
  migrate: 'rg-migrate-${suffix}'
}

// /23 split into 8 x /26: 0=AFW, 1=Gateway, 2=default, 3=AFW-Mgmt
var hubSubnetAfw = cidrSubnet(addressSpaceHub, 26, 0)
var hubSubnetGateway = cidrSubnet(addressSpaceHub, 26, 1)
var hubSubnetDefault = cidrSubnet(addressSpaceHub, 26, 2)
var hubSubnetAfwMgmt = cidrSubnet(addressSpaceHub, 26, 3)
var spokeSubnetWorkload = cidrSubnet(addressSpaceSpoke, 26, 0)

var mergedTags = union(tags, {
  scenario: scenario
  location: location
})

// ---------------------------------------------------------------------------
// Resource groups
// ---------------------------------------------------------------------------

resource rgHub 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgNames.hub
  location: location
  tags: mergedTags
}

resource rgSpoke 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgNames.spoke
  location: location
  tags: mergedTags
}

resource rgMonitor 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgNames.monitor
  location: location
  tags: mergedTags
}

resource rgBackup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgNames.backup
  location: location
  tags: mergedTags
}

resource rgSecurity 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgNames.security
  location: location
  tags: mergedTags
}

resource rgMigrate 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgNames.migrate
  location: location
  tags: mergedTags
}

// ---------------------------------------------------------------------------
// Networking (hub + spoke + NAT + peering + Private DNS)
// ---------------------------------------------------------------------------

module networking 'modules/networking.bicep' = {
  name: 'mod-networking'
  scope: rgHub
  params: {
    location: location
    suffix: suffix
    addressSpaceHub: addressSpaceHub
    addressSpaceSpoke: addressSpaceSpoke
    hubSubnetAfw: hubSubnetAfw
    hubSubnetGateway: hubSubnetGateway
    hubSubnetDefault: hubSubnetDefault
    spokeSubnetWorkload: spokeSubnetWorkload
    spokeRgName: rgNames.spoke
    useNat: useNat
    usePeering: usePeering
    useVpn: useVpn
    availabilityZones: availabilityZones
    tags: mergedTags
  }
  dependsOn: [
    rgSpoke
  ]
}

// ---------------------------------------------------------------------------
// Firewall (firewall + full)
// ---------------------------------------------------------------------------

module firewall 'modules/firewall.bicep' = if (useFirewall) {
  name: 'mod-firewall'
  scope: rgHub
  params: {
    location: location
    suffix: suffix
    hubVnetName: networking.outputs.hubVnetName
    afwSubnetId: networking.outputs.afwSubnetId
    afwMgmtSubnetCidr: hubSubnetAfwMgmt
    spokeRgName: rgNames.spoke
    spokeWorkloadSubnetId: networking.outputs.spokeWorkloadSubnetId
    availabilityZones: availabilityZones
    tags: mergedTags
  }
}

// ---------------------------------------------------------------------------
// VPN Gateway (vpn + full)
// ---------------------------------------------------------------------------

module vpn 'modules/vpn.bicep' = if (useVpn) {
  name: 'mod-vpn'
  scope: rgHub
  params: {
    location: location
    suffix: suffix
    gatewaySubnetId: networking.outputs.gatewaySubnetId
    availabilityZones: availabilityZones
    tags: mergedTags
  }
}

// ---------------------------------------------------------------------------
// Security (Key Vault + PE)
// ---------------------------------------------------------------------------

module security 'modules/security.bicep' = {
  name: 'mod-security'
  scope: rgSecurity
  params: {
    location: location
    suffix: suffix
    spokeWorkloadSubnetId: networking.outputs.spokeWorkloadSubnetId
    keyVaultPdzId: networking.outputs.keyVaultPdzId
    tags: mergedTags
  }
}

// ---------------------------------------------------------------------------
// Monitoring (Log Analytics + Automation + Recovery Services Vault)
// ---------------------------------------------------------------------------

module monitoring 'modules/monitoring.bicep' = {
  name: 'mod-monitoring'
  scope: rgMonitor
  params: {
    location: location
    suffix: suffix
    logRetentionDays: logRetentionDays
    tags: mergedTags
  }
}

module backupVault 'modules/recovery.bicep' = {
  name: 'mod-backup'
  scope: rgBackup
  params: {
    location: location
    suffix: suffix
    tags: mergedTags
  }
}

// ---------------------------------------------------------------------------
// Budgets (optional)
// ---------------------------------------------------------------------------

module budgets 'modules/budgets.bicep' = if (budgetEnabled) {
  name: 'mod-budgets'
  params: {
    suffix: suffix
    amount: budgetAmount
    thresholds: budgetThresholds
    alertEmails: budgetAlertEmails
  }
}

// ---------------------------------------------------------------------------
// Workbook (optional)
// ---------------------------------------------------------------------------

module workbook 'modules/workbook.bicep' = if (workbookEnabled) {
  name: 'mod-workbook'
  scope: rgMonitor
  params: {
    suffix: suffix
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: mergedTags
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output scenarioOut string = scenario
output resourceGroupNames object = rgNames
output hubVnetId string = networking.outputs.hubVnetId
output spokeVnetId string = networking.outputs.spokeVnetId
output keyVaultUri string = security.outputs.keyVaultUri
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId
output firewallPrivateIp string = useFirewall ? firewall!.outputs.firewallPrivateIp : ''
output vpnGatewayId string = useVpn ? vpn!.outputs.vpnGatewayId : ''
output natGatewayId string = useNat ? networking.outputs.natGatewayId : ''
output budgetId string = budgetEnabled ? budgets!.outputs.budgetId : ''
output workbookId string = workbookEnabled ? workbook!.outputs.workbookId : ''
