using '../connectivity.bicep'

param location = 'westcentralus'
param namePrefix = 'contoso'
param regionShort = 'wcus'
param addressSpaceHub = '10.0.0.0/23'

// Leave empty on the first deploy; pass landingzone.outputs.spokeVnetId on the second deploy.
param spokeVnetId = ''
