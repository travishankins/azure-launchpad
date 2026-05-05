// Optional: subscription budget + email alerts.
//
// Disabled unless `budgetEnabled` = true. Creates one subscription-scoped
// monthly consumption budget with Actual notifications at the configured
// thresholds plus a single Forecasted-100% notification.
//
// Cost impact: $0 — Cost Management is free.

targetScope = 'subscription'

@description('Short suffix used in the budget name (e.g. contoso-wcus).')
param suffix string

@description('Monthly budget amount in the subscription billing currency.')
@minValue(1)
param amount int = 100

@description('Percent-of-budget thresholds for Actual-spend alerts.')
param thresholds array = [
  50
  80
  100
]

@description('Email recipients for budget alerts. At least one required.')
@minLength(1)
param alertEmails array

@description('Optional list of resource group names to scope the budget to. Empty => entire subscription.')
param resourceGroupNames array = []

@description('First-of-month start date for the budget time period (YYYY-MM-DDT00:00:00Z).')
param startDate string = '${utcNow('yyyy-MM')}-01T00:00:00Z'

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: 'budget-${suffix}'
  properties: {
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
    }
    category: 'Cost'
    filter: empty(resourceGroupNames) ? null : {
      dimensions: {
        name: 'ResourceGroupName'
        operator: 'In'
        values: resourceGroupNames
      }
    }
    notifications: union(
      toObject(thresholds, t => 'Actual_GreaterThan_${t}_Percent', t => {
        enabled: true
        operator: 'GreaterThan'
        threshold: t
        thresholdType: 'Actual'
        contactEmails: alertEmails
      }),
      {
        Forecasted_GreaterThan_100_Percent: {
          enabled: true
          operator: 'GreaterThan'
          threshold: 100
          thresholdType: 'Forecasted'
          contactEmails: alertEmails
        }
      }
    )
  }
}

output budgetId string = budget.id
output budgetName string = budget.name
