// Hub + spoke VNets, subnets, NAT Gateway (when no firewall), peering, Private DNS for Key Vault.

targetScope = 'resourceGroup'

param location string
param suffix string
param addressSpaceHub string
param addressSpaceSpoke string
param hubSubnetAfw string
param hubSubnetGateway string
param hubSubnetDefault string
param spokeSubnetWorkload string
param spokeRgName string
param useNat bool
param usePeering bool
param useVpn bool
param tags object

// --- Hub VNet ---------------------------------------------------------------

resource vnetHub 'Microsoft.Network/virtualNetworks@2024-05-01' = {
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
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: hubSubnetAfw
        }
      }
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

// --- NAT Gateway (when no firewall) ----------------------------------------

resource natPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (useNat) {
  name: 'pip-nat-spoke-${suffix}'
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

resource natGw 'Microsoft.Network/natGateways@2024-05-01' = if (useNat) {
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

// --- Spoke VNet (different RG) ---------------------------------------------

module spokeVnet 'spoke-vnet.bicep' = {
  name: 'spoke-vnet'
  scope: resourceGroup(spokeRgName)
  params: {
    location: location
    suffix: suffix
    addressSpaceSpoke: addressSpaceSpoke
    workloadSubnetCidr: spokeSubnetWorkload
    natGatewayId: useNat ? natGw.id : ''
    tags: tags
  }
}

// --- Hub <-> Spoke peering --------------------------------------------------

resource peerHubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = if (usePeering) {
  name: 'peer-hub-to-spoke'
  parent: vnetHub
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: useVpn
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVnet.outputs.vnetId
    }
  }
}

module spokePeering 'spoke-peering.bicep' = if (usePeering) {
  name: 'spoke-peering'
  scope: resourceGroup(spokeRgName)
  params: {
    spokeVnetName: spokeVnet.outputs.vnetName
    hubVnetId: vnetHub.id
    useVpn: useVpn
  }
}

// --- Private DNS — Key Vault ------------------------------------------------

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
      id: vnetHub.id
    }
  }
}

resource pdzKvLinkSpoke 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: pdzKv
  name: 'link-spoke'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: spokeVnet.outputs.vnetId
    }
  }
}

// --- Outputs ----------------------------------------------------------------

output hubVnetId string = vnetHub.id
output hubVnetName string = vnetHub.name
output afwSubnetId string = '${vnetHub.id}/subnets/AzureFirewallSubnet'
output gatewaySubnetId string = '${vnetHub.id}/subnets/GatewaySubnet'
output spokeVnetId string = spokeVnet.outputs.vnetId
output spokeWorkloadSubnetId string = spokeVnet.outputs.workloadSubnetId
output natGatewayId string = useNat ? natGw.id : ''
output keyVaultPdzId string = pdzKv.id
