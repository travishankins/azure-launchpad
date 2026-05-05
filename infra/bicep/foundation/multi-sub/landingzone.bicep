// ---------------------------------------------------------------------------
// Landing-zone layer — multi-subscription mode
// ---------------------------------------------------------------------------
// Supports all four scenarios: baseline | firewall | vpn | full.
//
// Cross-sub inputs (from the connectivity layer):
//   - hubVnetId        : required (spoke->hub peering)
//   - firewallPrivateIp: required for firewall/full (spoke route table)
//   - keyVaultPdzId    : optional (KV PE wired to PDZ in connectivity sub)
//
// Run SECOND, after connectivity. Then re-deploy connectivity with
// spokeVnetId from this layer's output to wire hub->spoke peering AND
// PDZ->spoke link.
// ---------------------------------------------------------------------------

targetScope = 'subscription'

param location string = 'westcentralus'

@minLength(2)
@maxLength(8)
param namePrefix string = 'contoso'

param regionShort string = 'wcus'

param addressSpaceSpoke string = '10.0.2.0/23'

@allowed([
  'baseline'
  'firewall'
  'vpn'
  'full'
])
param scenario string = 'baseline'

@description('Hub VNet resource ID from the connectivity layer. Required for spoke->hub peering.')
param hubVnetId string

@description('Firewall private IP from the connectivity layer. Required for firewall/full scenarios; leave empty for baseline/vpn.')
param firewallPrivateIp string = ''

@description('Private DNS Zone ID for KV (privatelink.vaultcore.azure.net), from the connectivity sub. Leave empty to skip wiring.')
param keyVaultPdzId string = ''

param tags object = {
  workload: 'azure-launchpad'
  iac: 'bicep'
  cost_center: 'platform'
  layer: 'landingzone'
}

var suffix = '${namePrefix}-${regionShort}'
var mergedTags = union(tags, {
  scenario: '${scenario}-multi-sub'
  location: location
})

resource rgSpoke 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-spoke-prod-${suffix}'
  location: location
  tags: mergedTags
}

resource rgSecurity 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-security-${suffix}'
  location: location
  tags: mergedTags
}

resource rgMigrate 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-migrate-${suffix}'
  location: location
  tags: mergedTags
}

module spoke 'landingzone-spoke.bicep' = {
  name: 'mod-landingzone-spoke'
  scope: rgSpoke
  params: {
    location: location
    suffix: suffix
    addressSpaceSpoke: addressSpaceSpoke
    hubVnetId: hubVnetId
    scenario: scenario
    firewallPrivateIp: firewallPrivateIp
    tags: mergedTags
  }
}

module security '../modules/security.bicep' = {
  name: 'mod-keyvault'
  scope: rgSecurity
  params: {
    location: location
    suffix: suffix
    spokeWorkloadSubnetId: spoke.outputs.workloadSubnetId
    keyVaultPdzId: keyVaultPdzId
    tags: mergedTags
  }
}

output spokeRgName string = rgSpoke.name
output securityRgName string = rgSecurity.name
output spokeVnetId string = spoke.outputs.spokeVnetId
output keyVaultUri string = security.outputs.keyVaultUri
