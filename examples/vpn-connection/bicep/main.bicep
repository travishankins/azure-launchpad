// Site-to-site VPN connection wiring for the Launchpad foundation VPN Gateway.
// Deploy at resource-group scope against the hub RG that contains the gateway.

targetScope = 'resourceGroup'

@description('Resource ID of the foundation VPN Gateway (output `vpnGatewayId`).')
param vpnGatewayId string

@description('Short name used to derive the LNG and connection resource names (e.g. `hq` -> lng-hq, cn-hq).')
param connectionName string = 'onprem'

@description('Public IP address of the on-premises VPN device.')
param peerIp string

@description('On-premises CIDR blocks reachable through the tunnel.')
param peerAddressSpaces array

@secure()
@description('Pre-shared key for the IPsec tunnel.')
param sharedKey string

@description('Tags applied to the LNG and connection.')
param tags object = {}

var location = resourceGroup().location

// Reference the existing gateway so the connection can target it by ID.
resource vpnGw 'Microsoft.Network/virtualNetworkGateways@2024-05-01' existing = {
  name: last(split(vpnGatewayId, '/'))
}

resource lng 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: 'lng-${connectionName}'
  location: location
  tags: tags
  properties: {
    gatewayIpAddress: peerIp
    localNetworkAddressSpace: {
      addressPrefixes: peerAddressSpaces
    }
  }
}

resource connection 'Microsoft.Network/connections@2024-05-01' = {
  name: 'cn-${connectionName}'
  location: location
  tags: tags
  properties: {
    connectionType: 'IPsec'
    enableBgp: false
    sharedKey: sharedKey
    virtualNetworkGateway1: {
      id: vpnGw.id
      properties: {}
    }
    localNetworkGateway2: {
      id: lng.id
      properties: {}
    }
  }
}

output connectionId string = connection.id
output localNetworkGatewayId string = lng.id
