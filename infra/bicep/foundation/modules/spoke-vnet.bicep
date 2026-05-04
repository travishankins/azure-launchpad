// Spoke VNet (in spoke RG)

targetScope = 'resourceGroup'

param location string
param suffix string
param addressSpaceSpoke string
param workloadSubnetCidr string
@description('NAT Gateway resource ID. Pass empty string to skip NAT association.')
param natGatewayId string
param tags object

var useNat = !empty(natGatewayId)

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
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
        properties: union(
          {
            addressPrefix: workloadSubnetCidr
          },
          useNat ? {
            natGateway: {
              id: natGatewayId
            }
          } : {}
        )
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output workloadSubnetId string = '${vnet.id}/subnets/snet-workload'
