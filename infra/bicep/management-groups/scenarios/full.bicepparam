using '../main.bicep'

param namePrefix = 'contoso'
param displayNamePrefix = 'Contoso'

param enableIdentityMg = true
param enableSecurityMg = true
param enableLocalMg = true
param enableDecommissionedMg = true
param enableSandboxesMg = true

param enablePolicies = true

param policyAssignments = {
  'Deny-MgmtPorts-Internet': {
    scopeMgKey: 'landingzones'
    policyDefinition: '/providers/Microsoft.Authorization/policyDefinitions/22730e10-96f6-4aac-ad84-9383d35b5917'
    enforce: true
  }
  'Restrict-Local-Disconn': {
    scopeMgKey: 'local'
    policyDefinition: '/providers/Microsoft.Authorization/policyDefinitions/dabf7c7f-5354-42de-a92a-8367f538dd71'
    enforce: false
  }
}
