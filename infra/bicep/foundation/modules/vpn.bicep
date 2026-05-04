// VPN Gateway + PIP. Site-to-site connection deferred (PSK + on-prem peer needed).

targetScope = 'resourceGroup'

param location string
param suffix string
param gatewaySubnetId string
param tags object

resource vpnPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-vpngw-${suffix}'
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

resource vpnGw 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: 'vpngw-${suffix}'
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    activeActive: false
    enableBgp: false
    sku: {
      name: 'VpnGw1AZ'
      tier: 'VpnGw1AZ'
    }
    vpnGatewayGeneration: 'Generation2'
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnetId
          }
          publicIPAddress: {
            id: vpnPip.id
          }
        }
      }
    ]
  }
}

output vpnGatewayId string = vpnGw.id
