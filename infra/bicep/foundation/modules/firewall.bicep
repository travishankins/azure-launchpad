// Azure Firewall (Basic) + Firewall Policy + 3 PIPs + AFW management subnet
// + spoke route table forcing 0.0.0.0/0 through the firewall.

targetScope = 'resourceGroup'

param location string
param suffix string
param hubVnetName string
param afwSubnetId string
param afwMgmtSubnetCidr string
param spokeRgName string
param spokeWorkloadSubnetId string
param tags object

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: hubVnetName
}

// Add the AzureFirewallManagementSubnet (required for Firewall Basic)
resource fwMgmtSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: 'AzureFirewallManagementSubnet'
  parent: hubVnet
  properties: {
    addressPrefix: afwMgmtSubnetCidr
  }
}

resource fwPip1 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-fw-pip1-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource fwPip2 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-fw-pip2-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource fwMgmtPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-fw-mgmt-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource fwPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: 'fwpol-${suffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Basic'
    }
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: 'afw-${suffix}'
  location: location
  tags: tags
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
    firewallPolicy: {
      id: fwPolicy.id
    }
    ipConfigurations: [
      {
        name: 'ipcfg-primary'
        properties: {
          subnet: {
            id: afwSubnetId
          }
          publicIPAddress: {
            id: fwPip1.id
          }
        }
      }
      {
        name: 'ipcfg-secondary'
        properties: {
          publicIPAddress: {
            id: fwPip2.id
          }
        }
      }
    ]
    managementIpConfiguration: {
      name: 'ipcfg-mgmt'
      properties: {
        subnet: {
          id: fwMgmtSubnet.id
        }
        publicIPAddress: {
          id: fwMgmtPip.id
        }
      }
    }
  }
}

// Spoke route table — created in the spoke RG
module spokeRt 'spoke-route-table.bicep' = {
  name: 'spoke-route-table'
  scope: resourceGroup(spokeRgName)
  params: {
    location: location
    suffix: suffix
    firewallPrivateIp: firewall.properties.ipConfigurations[0].properties.privateIPAddress
    workloadSubnetId: spokeWorkloadSubnetId
    tags: tags
  }
}

output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallId string = firewall.id
