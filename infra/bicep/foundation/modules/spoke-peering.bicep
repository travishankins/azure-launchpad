// Spoke -> Hub peering (created in the spoke RG)

targetScope = 'resourceGroup'

param spokeVnetName string
param hubVnetId string
param useVpn bool

resource spokeVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spokeVnetName
}

resource peerSpokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: 'peer-spoke-to-hub'
  parent: spokeVnet
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: useVpn
    remoteVirtualNetwork: {
      id: hubVnetId
    }
  }
}
