// Log Analytics workspace + Automation Account.

targetScope = 'resourceGroup'

param location string
param suffix string
param logRetentionDays int
param tags object

resource law 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'log-${suffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays
    workspaceCapping: {
      dailyQuotaGb: json('0.5')
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource aa 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: 'aa-${suffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Basic'
    }
  }
}

output workspaceId string = law.id
output automationAccountId string = aa.id
