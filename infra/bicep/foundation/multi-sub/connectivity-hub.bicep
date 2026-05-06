// Hub VNet + Private DNS zone for KV + (optional) firewall + (optional) VPN gateway
// + (optional) hub-side peering + (optional) cross-sub PDZ link to spoke.
//
// Used by the connectivity layer wrapper (connectivity.bicep).

targetScope = 'resourceGroup'

param location string
param suffix string
param addressSpaceHub string
@description('baseline | firewall | vpn | full')
param scenario string
@description('Spoke VNet resource ID. Pass on the second connectivity deploy to wire hub->spoke peering AND cross-sub PDZ link.')
param spokeVnetId string = ''
param tags object

var hasFirewall = scenario == 'firewall' || scenario == 'full'
var hasVpn = scenario == 'vpn' || scenario == 'full'

// Subnet layout in /23 hub:
//   /26 idx 0: AzureFirewallSubnet            (firewall/full only)
//   /26 idx 1: GatewaySubnet                  (always — used by VPN gateway when present)
//   /26 idx 2: default                        (always)
//   /26 idx 3: AzureFirewallManagementSubnet  (firewall/full — required by Basic SKU)
var firewallSubnetId = '${hubVnet.id}/subnets/AzureFirewallSubnet'
var firewallMgmtSubnetId = '${hubVnet.id}/subnets/AzureFirewallManagementSubnet'
var gatewaySubnetId = '${hubVnet.id}/subnets/GatewaySubnet'

var baseSubnets = [
  {
    name: 'GatewaySubnet'
    properties: {
      addressPrefix: cidrSubnet(addressSpaceHub, 26, 1)
    }
  }
  {
    name: 'default'
    properties: {
      addressPrefix: cidrSubnet(addressSpaceHub, 26, 2)
    }
  }
]
var firewallSubnets = hasFirewall ? [
  {
    name: 'AzureFirewallSubnet'
    properties: {
      addressPrefix: cidrSubnet(addressSpaceHub, 26, 0)
    }
  }
  {
    name: 'AzureFirewallManagementSubnet'
    properties: {
      addressPrefix: cidrSubnet(addressSpaceHub, 26, 3)
    }
  }
] : []

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
    subnets: concat(firewallSubnets, baseSubnets)
  }
}

// -------------------- Azure Firewall (firewall / full) --------------------

resource fwPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (hasFirewall) {
  name: 'pip-afw-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource fwMgmtPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (hasFirewall) {
  name: 'pip-afw-mgmt-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource fwPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = if (hasFirewall) {
  name: 'afwp-${suffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Basic'
    }
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = if (hasFirewall) {
  name: 'afw-${suffix}'
  location: location
  tags: tags
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
        name: 'ipconfig'
        properties: {
          subnet: {
            id: firewallSubnetId
          }
          publicIPAddress: {
            id: fwPip.id
          }
        }
      }
    ]
    managementIpConfiguration: {
      name: 'mgmtipconfig'
      properties: {
        subnet: {
          id: firewallMgmtSubnetId
        }
        publicIPAddress: {
          id: fwMgmtPip.id
        }
      }
    }
  }
}

// -------------------- VPN Gateway (vpn / full) --------------------

resource vpnPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (hasVpn) {
  name: 'pip-vpn-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource vpnGw 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = if (hasVpn) {
  name: 'vpngw-${suffix}'
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: false
    sku: {
      // Azure retired non-AZ VpnGw1-5 SKUs in May 2026 (NonAzSkusNotAllowedForVPNGateway).
      // Use *AZ SKUs even in regions without availability zones.
      name: 'VpnGw2AZ'
      tier: 'VpnGw2AZ'
    }
    vpnGatewayGeneration: 'Generation2'
    ipConfigurations: [
      {
        name: 'vpngw-ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vpnPip.id
          }
          subnet: {
            id: gatewaySubnetId
          }
        }
      }
    ]
  }
}

// -------------------- Private DNS for Key Vault --------------------

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

// Cross-sub link from PDZ (in connectivity sub) to the spoke VNet (in landingzone sub).
// Wired on the SECOND connectivity deploy, after the spoke VNet exists.
resource pdzKvLinkSpoke 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(spokeVnetId)) {
  parent: pdzKv
  name: 'link-spoke'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

// -------------------- Hub <-> Spoke peering (hub side) --------------------

resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = if (!empty(spokeVnetId)) {
  parent: hubVnet
  name: 'peer-hub-to-spoke'
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: hasVpn
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
output firewallPrivateIp string = hasFirewall ? firewall.?properties.ipConfigurations[0].properties.privateIPAddress ?? '' : ''
output vpnGatewayId string = hasVpn ? vpnGw.?id ?? '' : ''
