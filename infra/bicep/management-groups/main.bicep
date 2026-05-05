// Azure Launchpad (SMEC Edition) — Management Groups (Bicep, tenant scope)
// Functional parity with infra/terraform/management-groups.

targetScope = 'tenant'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Lowercase prefix for Management Group names (used as the technical id). 3-10 chars.')
@minLength(3)
@maxLength(10)
param namePrefix string = 'contoso'

@description('Human-friendly prefix for Management Group display names.')
param displayNamePrefix string = 'Contoso'

// --- Hierarchy toggles -----------------------------------------------------
param enableIdentityMg bool = false
param enableSecurityMg bool = false
param enableLocalMg bool = true
param enableDecommissionedMg bool = true
param enableSandboxesMg bool = true

// --- Subscription placements ----------------------------------------------
@description('Map of subscription GUID => MG key (root|platform|management|connectivity|identity|security|landingzones|corp|online|local|decommissioned|sandboxes).')
param subscriptionPlacements object = {}

// --- Policy assignments ----------------------------------------------------
@description('Master switch for policy assignments. When false, no policies are assigned regardless of policyAssignments content.')
param enablePolicies bool = false

@description('''Map of assignment NAME (24 char max) => assignment spec.
Each value: { scopeMgKey, policyDefinition, displayName?, description?, enforce?, notScopes?, parameters?, identityType?, location?, nonComplianceMsg? }.''')
param policyAssignments object = {}

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var rootMgId = namePrefix
var platformMgId = '${namePrefix}-platform'
var landingZonesMgId = '${namePrefix}-landingzones'

// Static MGs (always created): list, in deployment order (parents first).
var staticMgs = [
  { key: 'root', name: namePrefix, display: displayNamePrefix, parentMgId: tenant().tenantId }
  { key: 'platform', name: platformMgId, display: 'Platform', parentMgId: rootMgId }
  { key: 'management', name: '${namePrefix}-management', display: 'Management', parentMgId: platformMgId }
  { key: 'connectivity', name: '${namePrefix}-connectivity', display: 'Connectivity', parentMgId: platformMgId }
  { key: 'landingzones', name: landingZonesMgId, display: 'Landing zones', parentMgId: rootMgId }
  { key: 'corp', name: '${namePrefix}-corp', display: 'Corp', parentMgId: landingZonesMgId }
  { key: 'online', name: '${namePrefix}-online', display: 'Online', parentMgId: landingZonesMgId }
]

var optionalMgs = concat(
  enableIdentityMg
    ? [{ key: 'identity', name: '${namePrefix}-identity', display: 'Identity', parentMgId: platformMgId }]
    : [],
  enableSecurityMg
    ? [{ key: 'security', name: '${namePrefix}-security', display: 'Security', parentMgId: platformMgId }]
    : [],
  enableLocalMg
    ? [{ key: 'local', name: '${namePrefix}-local', display: 'Local', parentMgId: landingZonesMgId }]
    : [],
  enableDecommissionedMg
    ? [{ key: 'decommissioned', name: '${namePrefix}-decommissioned', display: 'Decommissioned', parentMgId: rootMgId }]
    : [],
  enableSandboxesMg
    ? [{ key: 'sandboxes', name: '${namePrefix}-sandboxes', display: 'Sandboxes', parentMgId: rootMgId }]
    : []
)

var allMgs = concat(staticMgs, optionalMgs)

// Lookup: mgKey => mgName (id segment)
var mgKeyToName = toObject(allMgs, mg => mg.key, mg => mg.name)

// ---------------------------------------------------------------------------
// Management Groups
// ---------------------------------------------------------------------------

// Root first (no dependsOn needed; tenant-root parent).
resource mgRoot 'Microsoft.Management/managementGroups@2023-04-01' = {
  scope: tenant()
  name: namePrefix
  properties: {
    displayName: displayNamePrefix
    details: {
      parent: {
        id: '/providers/Microsoft.Management/managementGroups/${tenant().tenantId}'
      }
    }
  }
}

// Second-tier static MGs (parented to root)
resource mgPlatform 'Microsoft.Management/managementGroups@2023-04-01' = {
  scope: tenant()
  name: platformMgId
  properties: {
    displayName: 'Platform'
    details: {
      parent: {
        id: mgRoot.id
      }
    }
  }
}

resource mgLandingZones 'Microsoft.Management/managementGroups@2023-04-01' = {
  scope: tenant()
  name: landingZonesMgId
  properties: {
    displayName: 'Landing zones'
    details: {
      parent: {
        id: mgRoot.id
      }
    }
  }
}

// Third-tier static MGs
resource mgManagement 'Microsoft.Management/managementGroups@2023-04-01' = {
  scope: tenant()
  name: '${namePrefix}-management'
  properties: {
    displayName: 'Management'
    details: {
      parent: {
        id: mgPlatform.id
      }
    }
  }
}

resource mgConnectivity 'Microsoft.Management/managementGroups@2023-04-01' = {
  scope: tenant()
  name: '${namePrefix}-connectivity'
  properties: {
    displayName: 'Connectivity'
    details: {
      parent: {
        id: mgPlatform.id
      }
    }
  }
}

resource mgCorp 'Microsoft.Management/managementGroups@2023-04-01' = {
  scope: tenant()
  name: '${namePrefix}-corp'
  properties: {
    displayName: 'Corp'
    details: {
      parent: {
        id: mgLandingZones.id
      }
    }
  }
}

resource mgOnline 'Microsoft.Management/managementGroups@2023-04-01' = {
  scope: tenant()
  name: '${namePrefix}-online'
  properties: {
    displayName: 'Online'
    details: {
      parent: {
        id: mgLandingZones.id
      }
    }
  }
}

// Optional MGs
resource mgIdentity 'Microsoft.Management/managementGroups@2023-04-01' = if (enableIdentityMg) {
  scope: tenant()
  name: '${namePrefix}-identity'
  properties: {
    displayName: 'Identity'
    details: {
      parent: {
        id: mgPlatform.id
      }
    }
  }
}

resource mgSecurity 'Microsoft.Management/managementGroups@2023-04-01' = if (enableSecurityMg) {
  scope: tenant()
  name: '${namePrefix}-security'
  properties: {
    displayName: 'Security'
    details: {
      parent: {
        id: mgPlatform.id
      }
    }
  }
}

resource mgLocal 'Microsoft.Management/managementGroups@2023-04-01' = if (enableLocalMg) {
  scope: tenant()
  name: '${namePrefix}-local'
  properties: {
    displayName: 'Local'
    details: {
      parent: {
        id: mgLandingZones.id
      }
    }
  }
}

resource mgDecom 'Microsoft.Management/managementGroups@2023-04-01' = if (enableDecommissionedMg) {
  scope: tenant()
  name: '${namePrefix}-decommissioned'
  properties: {
    displayName: 'Decommissioned'
    details: {
      parent: {
        id: mgRoot.id
      }
    }
  }
}

resource mgSandboxes 'Microsoft.Management/managementGroups@2023-04-01' = if (enableSandboxesMg) {
  scope: tenant()
  name: '${namePrefix}-sandboxes'
  properties: {
    displayName: 'Sandboxes'
    details: {
      parent: {
        id: mgRoot.id
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Subscription placements
// ---------------------------------------------------------------------------

var placementItems = [
  for sub in items(subscriptionPlacements): {
    subId: sub.key
    mgKey: sub.value
  }
]

resource subAssoc 'Microsoft.Management/managementGroups/subscriptions@2023-04-01' = [
  for p in placementItems: {
    name: '${mgKeyToName[p.mgKey]}/${p.subId}'
    dependsOn: [
      mgRoot
      mgPlatform
      mgLandingZones
      mgManagement
      mgConnectivity
      mgCorp
      mgOnline
      mgIdentity
      mgSecurity
      mgLocal
      mgDecom
      mgSandboxes
    ]
  }
]

// ---------------------------------------------------------------------------
// Policy assignments (opt-in, pick-and-choose)
// ---------------------------------------------------------------------------

// Flatten effective assignments (master switch) into a typed array.
var effectivePolicies = enablePolicies ? policyAssignments : {}

var policyEntries = [
  for entry in items(effectivePolicies): {
    name: entry.key
    scopeMgKey: entry.value.scopeMgKey
    policyDefinition: entry.value.policyDefinition
    displayName: entry.value.?displayName ?? entry.key
    description: entry.value.?description ?? ''
    enforce: entry.value.?enforce ?? true
    notScopes: entry.value.?notScopes ?? []
    parameters: entry.value.?parameters ?? {}
    identityType: entry.value.?identityType ?? 'None'
    location: entry.value.?location ?? ''
    nonComplianceMsg: entry.value.?nonComplianceMsg ?? ''
  }
]

module policyMods 'modules/policy-assignment.bicep' = [
  for p in policyEntries: {
    name: 'pol-${p.name}'
    scope: managementGroup(mgKeyToName[p.scopeMgKey])
    params: {
      assignmentName: p.name
      policyDefinition: p.policyDefinition
      displayName: p.displayName
      description: p.description
      enforce: p.enforce
      notScopes: p.notScopes
      parameters: p.parameters
      identityType: p.identityType
      location: p.location
      nonComplianceMsg: p.nonComplianceMsg
    }
    dependsOn: [
      mgRoot
      mgPlatform
      mgLandingZones
      mgManagement
      mgConnectivity
      mgCorp
      mgOnline
      mgIdentity
      mgSecurity
      mgLocal
      mgDecom
      mgSandboxes
    ]
  }
]

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output managementGroupNames object = mgKeyToName
output policyAssignmentCount int = length(policyEntries)
