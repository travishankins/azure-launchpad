// Recovery Services Vault (geo-redundant, soft-delete on).

targetScope = 'resourceGroup'

param location string
param suffix string
param tags object

resource rsv 'Microsoft.RecoveryServices/vaults@2024-10-01' = {
  name: 'rsv-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {}
}

resource rsvConfig 'Microsoft.RecoveryServices/vaults/backupconfig@2024-10-01' = {
  parent: rsv
  name: 'vaultconfig'
  properties: {
    enhancedSecurityState: 'Enabled'
    softDeleteFeatureState: 'Enabled'
    storageType: 'GeoRedundant'
    storageTypeState: 'Locked'
  }
}

output vaultId string = rsv.id
