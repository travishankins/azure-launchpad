// Hub VNet + Private DNS zone for KV + (optional) hub-side peering.
// Used by the connectivity layer wrapper.

targetScope = 'resourceGroup'

param location string
param suffix string
param addressSpaceHub string
param spokeVnetId string = ''
param tags object

var hubSubnetGateway = cidrSubnet(addressSpaceHub, 26, 1)
var hubSubnetDefault = cidrSubnet(addressSpaceHub, 26, 2)

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-hub-${suffix}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpaceHub
      ]
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: hubSubnetGateway
        }
      }
      {
        name: 'default'
        properties: {
          addressPrefix: hubSubnetDefault
        }
      }
    ]
  }
}

resource pdzKv 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource pdzKvLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: pdzKv
  name: 'link-hub'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = if (!empty(spokeVnetId)) {
  parent: hubVnet
  name: 'peer-hub-to-spoke'
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVnetId
    }
  }
}

output hubVnetId string = hubVnet.id
output hubVnetName string = hubVnet.name
output keyVaultPdzId string = pdzKv.id
