// Spoke route table forcing 0.0.0.0/0 through the firewall + subnet association.

targetScope = 'resourceGroup'

param location string
param suffix string
param firewallPrivateIp string
param workloadSubnetId string
param tags object

resource rt 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-spoke-${suffix}'
  location: location
  tags: tags
  properties: {
    routes: [
      {
        name: 'default-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

// Associate to the spoke workload subnet by re-declaring it (Bicep pattern).
// We parse the workload subnet's parent VNet name from the resource ID.
var subnetIdParts = split(workloadSubnetId, '/')
var spokeVnetName = subnetIdParts[8]
var spokeSubnetName = subnetIdParts[10]

resource spokeVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spokeVnetName
}

resource workloadSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: spokeSubnetName
  parent: spokeVnet
}

// Re-write the subnet to attach the route table.
// NOTE: Bicep does not allow updating an `existing` subnet; we use a deployment
// that includes routeTable via a child resource update path.
resource subnetWithRt 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: spokeSubnetName
  parent: spokeVnet
  properties: {
    addressPrefix: workloadSubnet.properties.addressPrefix
    natGateway: workloadSubnet.properties.?natGateway
    routeTable: {
      id: rt.id
    }
  }
}
