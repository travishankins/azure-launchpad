// Key Vault with private endpoint into the spoke workload subnet.

targetScope = 'resourceGroup'

param location string
param suffix string
param spokeWorkloadSubnetId string
param keyVaultPdzId string
param tags object

var kvSuffix = take(uniqueString(resourceGroup().id, suffix), 5)
var kvName = 'kv-${suffix}-${kvSuffix}'

resource kv 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-kv-${suffix}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: spokeWorkloadSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-kv'
        properties: {
          privateLinkServiceId: kv.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource pdzGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: pe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kv'
        properties: {
          privateDnsZoneId: keyVaultPdzId
        }
      }
    ]
  }
}

output keyVaultId string = kv.id
output keyVaultUri string = kv.properties.vaultUri
