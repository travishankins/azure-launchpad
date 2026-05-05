// ---------------------------------------------------------------------------
// Management layer (multi-subscription mode)
// ---------------------------------------------------------------------------
// Deploys monitoring + backup RGs, Log Analytics workspace, Automation
// Account, Recovery Services Vault, and (optionally) the Foundation Health
// workbook + subscription budget alerts.
//
// Run order: SECOND (after connectivity). This layer has no cross-layer
// dependencies on its inputs — it can be deployed independently.
// ---------------------------------------------------------------------------

targetScope = 'subscription'

param location string = 'westcentralus'

@minLength(2)
@maxLength(8)
param namePrefix string = 'contoso'

param regionShort string = 'wcus'

@allowed([
  'baseline'
  'firewall'
  'vpn'
  'full'
])
param scenario string

param logRetentionDays int = 30

param tags object = {
  workload: 'azure-launchpad'
  iac: 'bicep'
  cost_center: 'platform'
  layer: 'management'
}

// --- Optional: subscription budget -----------------------------------------

@description('Enable a subscription-scoped monthly budget with email alerts. Free.')
param budgetEnabled bool = false

@description('Monthly budget amount (USD or subscription billing currency).')
@minValue(1)
param budgetAmount int = 100

@description('Percent-of-budget thresholds for Actual-spend alerts.')
param budgetThresholds array = [50, 80, 100]

@description('Email recipients for budget alerts. Required when budgetEnabled = true.')
param budgetAlertEmails array = []

// --- Optional: Foundation Health workbook ----------------------------------

@description('Deploy the starter Foundation Health workbook.')
param workbookEnabled bool = false

var suffix = '${namePrefix}-${regionShort}'
var mergedTags = union(tags, {
  scenario: scenario
  location: location
})

resource rgMonitor 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-monitor-${suffix}'
  location: location
  tags: mergedTags
}

resource rgBackup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-backup-${suffix}'
  location: location
  tags: mergedTags
}

module monitoring '../modules/monitoring.bicep' = {
  name: 'mod-monitoring'
  scope: rgMonitor
  params: {
    location: location
    suffix: suffix
    logRetentionDays: logRetentionDays
    tags: mergedTags
  }
}

module backupVault '../modules/recovery.bicep' = {
  name: 'mod-backup'
  scope: rgBackup
  params: {
    location: location
    suffix: suffix
    tags: mergedTags
  }
}

module budgets '../modules/budgets.bicep' = if (budgetEnabled) {
  name: 'mod-budgets'
  params: {
    suffix: suffix
    amount: budgetAmount
    thresholds: budgetThresholds
    alertEmails: budgetAlertEmails
  }
}

module workbook '../modules/workbook.bicep' = if (workbookEnabled) {
  name: 'mod-workbook'
  scope: rgMonitor
  params: {
    suffix: suffix
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: mergedTags
  }
}

output monitorRgName string = rgMonitor.name
output backupRgName string = rgBackup.name
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId
output budgetId string = budgetEnabled ? budgets!.outputs.budgetId : ''
output workbookId string = workbookEnabled ? workbook!.outputs.workbookId : ''
