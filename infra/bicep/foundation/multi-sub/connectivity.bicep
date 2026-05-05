// ---------------------------------------------------------------------------
// Connectivity layer — multi-subscription mode
// ---------------------------------------------------------------------------
// Supports all four scenarios: baseline | firewall | vpn | full.
//
// Run TWICE:
//   1. First pass (no spokeVnetId)  — creates hub VNet, firewall, VPN, PDZ.
//      Capture firewallPrivateIp + hubVnetId from outputs.
//   2. Second pass (with spokeVnetId, after landingzone deploys)
//      — wires hub->spoke peering AND PDZ->spoke link.
// ---------------------------------------------------------------------------

targetScope = 'subscription'

param location string = 'westcentralus'

@minLength(2)
@maxLength(8)
param namePrefix string = 'contoso'

param regionShort string = 'wcus'

param addressSpaceHub string = '10.0.0.0/23'

@allowed([
  'baseline'
  'firewall'
  'vpn'
  'full'
])
param scenario string = 'baseline'

@description('Spoke VNet resource ID — pass on the SECOND deploy (after the landingzone layer) to wire hub->spoke peering and PDZ->spoke link. Leave empty on first deploy.')
param spokeVnetId string = ''

param tags object = {
  workload: 'azure-launchpad'
  iac: 'bicep'
  cost_center: 'platform'
  layer: 'connectivity'
}

var suffix = '${namePrefix}-${regionShort}'
var mergedTags = union(tags, {
  scenario: '${scenario}-multi-sub'
  location: location
})

resource rgHub 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-hub-${suffix}'
  location: location
  tags: mergedTags
}

module hub 'connectivity-hub.bicep' = {
  name: 'mod-connectivity-hub'
  scope: rgHub
  params: {
    location: location
    suffix: suffix
    addressSpaceHub: addressSpaceHub
    scenario: scenario
    spokeVnetId: spokeVnetId
    tags: mergedTags
  }
}

output hubRgName string = rgHub.name
output hubVnetId string = hub.outputs.hubVnetId
output keyVaultPdzId string = hub.outputs.keyVaultPdzId
output firewallPrivateIp string = hub.outputs.firewallPrivateIp
output vpnGatewayId string = hub.outputs.vpnGatewayId
