// ---------------------------------------------------------------------------
// Landing-zone layer — multi-subscription mode (baseline scenario)
// ---------------------------------------------------------------------------
// Deploys spoke RG + spoke VNet + NAT Gateway + spoke->hub peering, plus
// the security RG + Key Vault with a private endpoint into the spoke
// workload subnet.
//
// Cross-sub references:
// - hubVnetId: from connectivity layer output (used for spoke->hub peering)
// - keyVaultPdzId: optional. If empty, KV PE is created without PDZ wiring;
//   you can add a PDZ link from the connectivity sub later.
//
// Run: deploy SECOND, after connectivity. Then re-deploy connectivity with
// spokeVnetId from this layer's output to wire hub->spoke peering.
// ---------------------------------------------------------------------------

targetScope = 'subscription'

param location string = 'westcentralus'

@minLength(2)
@maxLength(8)
param namePrefix string = 'contoso'

param regionShort string = 'wcus'

param addressSpaceSpoke string = '10.0.2.0/23'

@description('Hub VNet resource ID from the connectivity layer. Required for spoke->hub peering.')
param hubVnetId string

@description('Private DNS Zone ID for KV (privatelink.vaultcore.azure.net), from the connectivity sub. Leave empty to skip wiring; add manually later.')
param keyVaultPdzId string = ''

param tags object = {
  workload: 'azure-launchpad'
  iac: 'bicep'
  cost_center: 'platform'
  layer: 'landingzone'
}

var suffix = '${namePrefix}-${regionShort}'
var mergedTags = union(tags, {
  scenario: 'baseline-multi-sub'
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
