// Spoke VNet + (NAT Gateway OR firewall route table) + spoke->hub peering.
// Used by the landingzone layer wrapper (landingzone.bicep).

targetScope = 'resourceGroup'

param location string
param suffix string
param addressSpaceSpoke string
param hubVnetId string
@description('baseline | firewall | vpn | full')
param scenario string
@description('Firewall private IP from the connectivity layer. Required for firewall/full scenarios; leave empty otherwise.')
param firewallPrivateIp string = ''
param tags object

var hasFirewall = scenario == 'firewall' || scenario == 'full'
var workloadCidr = cidrSubnet(addressSpaceSpoke, 26, 0)

// -------------------- NAT Gateway (baseline / vpn — no firewall) --------------------

resource natPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (!hasFirewall) {
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

resource natGw 'Microsoft.Network/natGateways@2024-05-01' = if (!hasFirewall) {
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

// -------------------- Route Table (firewall / full) --------------------

resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = if (hasFirewall) {
  name: 'rt-spoke-${suffix}'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'default-via-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

// -------------------- Spoke VNet --------------------
// Subnet egress wiring branches by scenario:
//   firewall/full -> route table forwards 0.0.0.0/0 to firewall private IP
//   baseline/vpn  -> NAT Gateway provides outbound

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
        properties: hasFirewall ? {
          addressPrefix: workloadCidr
          routeTable: {
            id: routeTable.id
          }
        } : {
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
    // useRemoteGateways requires the hub gateway to exist. The first
    // landingzone deploy runs BEFORE hub<->spoke peering exists, so we
    // leave this false. Customers using vpn/full can flip this manually
    // (or via a third deploy) after the hub gateway provisions.
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVnetId
    }
  }
}

output spokeVnetId string = spokeVnet.id
output workloadSubnetId string = '${spokeVnet.id}/subnets/snet-workload'
