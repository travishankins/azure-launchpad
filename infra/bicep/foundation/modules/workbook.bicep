// ---------------------------------------------------------------------------
// Azure Monitor Workbook — Foundation Health (opt-in)
// ---------------------------------------------------------------------------
// Deploys a starter workbook scoped to the foundation Log Analytics workspace.
// ---------------------------------------------------------------------------

targetScope = 'resourceGroup'

@description('Naming suffix (e.g. contoso-wcus). Used to derive a deterministic GUID for the workbook.')
param suffix string

@description('Azure region for the workbook resource.')
param location string

@description('Resource ID of the Log Analytics workspace the workbook is scoped to.')
param logAnalyticsWorkspaceId string

@description('Tags applied to the workbook.')
param tags object = {}

@description('Display name shown in the Azure portal.')
param displayName string = 'Azure Launchpad — Foundation Health'

// Workbook resource names must be GUIDs. Use guid() for determinism per-suffix.
var workbookName = guid('azure-launchpad-workbook', suffix)

var workbookContent = loadTextContent('../workbooks/foundation-health.workbook.json')

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: workbookName
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: displayName
    serializedData: workbookContent
    sourceId: toLower(logAnalyticsWorkspaceId)
    category: 'workbook'
    version: 'Notebook/1.0'
  }
}

output workbookId string = workbook.id
output workbookName string = workbook.name
