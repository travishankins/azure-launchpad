using '../management.bicep'

param location = 'westcentralus'
param namePrefix = 'contoso'
param regionShort = 'wcus'
param scenario = 'baseline'
param logRetentionDays = 30

// Optional: enable a $200/mo budget with email alerts.
// param budgetEnabled = true
// param budgetAmount = 200
// param budgetAlertEmails = ['finops@example.com']

// Optional: deploy the Foundation Health workbook.
// param workbookEnabled = true
