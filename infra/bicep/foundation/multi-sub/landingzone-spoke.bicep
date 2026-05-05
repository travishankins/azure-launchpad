// Spoke VNet + NAT Gateway + spoke->hub peering. Used by the landingzone layer wrapper.

targetScope = 'resourceGroup'

param location string
param suffix string
param addressSpaceSpoke string
param hubVnetId string
param tags object

var workloadCidr = cidrSubnet(addressSpaceSpoke, 26, 0)

resource natPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-nat-spoke-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natGw 'Microsoft.Network/natGateways@2024-05-01' = {
  name: 'natgw-spoke-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: natPip.id
      }
    ]
  }
}

resource spokeVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-spoke-prod-${suffix}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpaceSpoke
      ]
    }
    subnets: [
      {
        name: 'snet-workload'
        properties: {
          addressPrefix: workloadCidr
          natGateway: {
            id: natGw.id
          }
        }
      }
    ]
  }
}

resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spokeVnet
  name: 'peer-spoke-to-hub'
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVnetId
    }
  }
}

output spokeVnetId string = spokeVnet.id
output workloadSubnetId string = '${spokeVnet.id}/subnets/snet-workload'
