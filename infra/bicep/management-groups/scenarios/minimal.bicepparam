using '../main.bicep'

param namePrefix = 'contoso'
param displayNamePrefix = 'Contoso'

param enableIdentityMg = false
param enableSecurityMg = false
param enableLocalMg = true
param enableDecommissionedMg = true
param enableSandboxesMg = true

param enablePolicies = false
