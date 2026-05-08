using './main.bicep'

// Required from CLI: vpnGatewayId, sharedKey
// e.g. --parameters vpnGatewayId=<id> sharedKey=<psk>

param connectionName = 'onprem'
param peerIp = '203.0.113.10'
param peerAddressSpaces = [
  '10.100.0.0/16'
]
param tags = {
  workload: 'vpn-connection'
  managedBy: 'azure-launchpad'
}

// Stub values — actual values must be supplied via --parameters on the
// `az deployment group create` command. Bicepparam files cannot accept
// secure params from outside; they get overridden at deploy time.
param vpnGatewayId = ''
param sharedKey = ''
