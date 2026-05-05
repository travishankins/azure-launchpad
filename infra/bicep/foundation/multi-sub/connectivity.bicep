// ---------------------------------------------------------------------------
// Connectivity layer — multi-subscription mode (baseline scenario)
// ---------------------------------------------------------------------------
// v1 supports the BASELINE scenario only (no firewall, no VPN). Multi-sub
// Bicep deployments for firewall/VPN scenarios require cross-sub
// orchestration (spoke route table, cross-sub PDZ link) that is documented
// as a follow-up. For firewall/VPN multi-sub today, use the Terraform path
// — provider aliases there support all four scenarios.
//
// Run: deploy this layer FIRST. Outputs hubVnetId; pass it to landingzone.
// ---------------------------------------------------------------------------

targetScope = 'subscription'

param location string = 'westcentralus'

@minLength(2)
@maxLength(8)
param namePrefix string = 'contoso'

param regionShort string = 'wcus'

param addressSpaceHub string = '10.0.0.0/23'

@description('Spoke VNet resource ID — pass on a SECOND deploy (after the landingzone layer) to wire hub->spoke peering. Leave empty on first deploy.')
param spokeVnetId string = ''

param tags object = {
  workload: 'azure-launchpad'
  iac: 'bicep'
  cost_center: 'platform'
  layer: 'connectivity'
}

var suffix = '${namePrefix}-${regionShort}'
var mergedTags = union(tags, {
  scenario: 'baseline-multi-sub'
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
    spokeVnetId: spokeVnetId
    tags: mergedTags
  }
}

output hubRgName string = rgHub.name
output hubVnetId string = hub.outputs.hubVnetId
output keyVaultPdzId string = hub.outputs.keyVaultPdzId
