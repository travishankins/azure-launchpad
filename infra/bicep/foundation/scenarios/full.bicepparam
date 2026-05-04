using '../main.bicep'

param scenario = 'full'
param location = 'westcentralus'

// Replace with the customer on-premises CIDR(s) before deploying.
param onPremisesAddressSpace = [
  '192.168.0.0/16'
]
