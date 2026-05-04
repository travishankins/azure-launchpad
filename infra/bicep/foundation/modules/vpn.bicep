// VPN Gateway + PIP. Site-to-site connection deferred (PSK + on-prem peer needed).

targetScope = 'resourceGroup'

param location string
param suffix string
param gatewaySubnetId string
@description('Availability zones for the VPN gateway PIP. Pass [] in regions without AZ support. The gateway SKU itself remains *AZ regardless (Azure requirement as of May 2026).')
param availabilityZones array = []
param tags object

resource vpnPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-vpngw-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  zones: availabilityZones
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
      // Azure retired non-AZ VpnGw1-5 SKUs in May 2026 (NonAzSkusNotAllowedForVPNGateway).
      // Use *AZ SKUs even in regions without availability zones.
      name: 'VpnGw2AZ'
      tier: 'VpnGw2AZ'
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
