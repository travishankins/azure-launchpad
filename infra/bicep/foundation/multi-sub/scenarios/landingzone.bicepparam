using '../landingzone.bicep'

param location = 'westcentralus'
param namePrefix = 'contoso'
param regionShort = 'wcus'
param addressSpaceSpoke = '10.0.2.0/23'

// REQUIRED: paste the hubVnetId output from the connectivity layer deployment.
// Get it with: az deployment sub show -n connectivity-baseline --query properties.outputs.hubVnetId.value -o tsv
param hubVnetId = '/subscriptions/<connectivity-sub>/resourceGroups/rg-hub-contoso-wcus/providers/Microsoft.Network/virtualNetworks/vnet-hub-contoso-wcus'

// Optional: paste keyVaultPdzId from the connectivity layer to wire the KV PE to that PDZ.
// Requires Network Contributor on the PDZ in the connectivity sub.
// param keyVaultPdzId = '/subscriptions/<connectivity-sub>/resourceGroups/rg-hub-contoso-wcus/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
