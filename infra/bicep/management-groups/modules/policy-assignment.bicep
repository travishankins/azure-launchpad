// Single Azure Policy assignment at MG scope.

targetScope = 'managementGroup'

@maxLength(24)
param assignmentName string
param policyDefinition string
param displayName string
param description string = ''
param enforce bool = true
param notScopes array = []
param parameters object = {}
@allowed([
  'None'
  'SystemAssigned'
  'UserAssigned'
])
param identityType string = 'None'
param location string = ''
param nonComplianceMsg string = ''

var hasIdentity = identityType != 'None'

resource assign 'Microsoft.Authorization/policyAssignments@2024-05-01' = {
  name: assignmentName
  location: hasIdentity ? location : null
  identity: hasIdentity ? {
    type: identityType
  } : null
  properties: {
    displayName: displayName
    description: description
    enforcementMode: enforce ? 'Default' : 'DoNotEnforce'
    policyDefinitionId: policyDefinition
    notScopes: notScopes
    parameters: parameters
    nonComplianceMessages: empty(nonComplianceMsg) ? [] : [
      {
        message: nonComplianceMsg
      }
    ]
  }
}

output assignmentId string = assign.id
