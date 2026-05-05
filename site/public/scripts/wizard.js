// Azure Launchpad (SMB / SMEC Edition) — interactive deployment wizard.
// Plain ES module, no framework, served from /public.

const QUESTIONS = [
  {
    id: 'iac_platform',
    label: 'Which Infrastructure-as-Code platform do you want to use?',
    help: 'Both options deploy the same Azure architecture (identical resource groups, networking, security, monitoring) — pick the one your team already knows.',
    impact: {
      bullets: [
        ['Terraform: ', 'HCL + Azure provider, state stored in Azure Storage. Multi-subscription mode supports all four scenarios.'],
        ['Bicep: ', 'native ARM-based, deployment history stored in Azure. Multi-subscription mode supports all four scenarios via the deploy-multi-sub.sh wrapper.'],
      ],
      note: 'The wizard will tailor the rest of the questions and emit the right files + commands for your choice.',
    },
    type: 'radio',
    options: [
      { value: 'terraform', label: 'Terraform — HCL + AzureRM provider, AVM modules, remote state.' },
      { value: 'bicep', label: 'Bicep — Microsoft’s native DSL, deployments tracked in Azure itself.' },
    ],
  },
  {
    id: 'deployment_mode',
    label: 'Single subscription or ALZ-aligned multi-subscription split?',
    help: 'Single = everything (hub, spoke, monitoring, KV) lands in one subscription. Multi = ALZ-aligned split across three subscriptions: Connectivity (hub VNet, firewall, VPN), Management (Log Analytics, RSV, automation), Landing-Zone (spoke VNet, KV, workloads). Multi requires Contributor on each sub.',
    impact: 'Single: simplest, most SMB-friendly, no cross-sub RBAC. Multi: matches Microsoft ALZ, separates platform from workloads, but needs 3 subscriptions and Network Contributor cross-sub for peering and PDZ wiring. Both Terraform and Bicep multi-sub support all four scenarios (baseline / firewall / vpn / full).',
    type: 'radio',
    options: [
      { value: 'single', label: 'Single subscription — everything in one sub. Default for SMB.' },
      { value: 'multi', label: 'Multi-subscription (ALZ split) — Connectivity / Management / Landing-Zone subs.' },
    ],
  },
  {
    id: 'egress',
    label: 'How should outbound internet traffic from your workloads be controlled?',
    help: 'Picks between NAT Gateway (cheap, no inspection) and Azure Firewall Basic (managed inspection + DNS proxy ready). Drives the firewall scenario flag and replaces the NAT path entirely when chosen.',
    impact: 'NAT: ~$32/mo • Firewall Basic: ~$295/mo (adds AzureFirewallSubnet + AzureFirewallManagementSubnet, forces 0.0.0.0/0 → fw private IP on the spoke route table).',
    type: 'radio',
    options: [
      { value: 'none', label: 'Standard NAT is fine — no centralized inspection required.' },
      { value: 'firewall', label: 'Inspect and filter all egress through a managed Azure firewall.' },
    ],
  },
  {
    id: 'hybrid',
    label: 'Do you need site-to-site connectivity to an on-premises network?',
    help: 'Adds a VPN Gateway (VpnGw2AZ, Generation2) in the hub GatewaySubnet and creates hub↔spoke peerings. AZ SKU is required by Azure as of May 2026 even in non-AZ regions.',
    impact: 'Adds ~$140/mo. Requires at least one on-premises CIDR (next step) for routing and validation.',
    type: 'radio',
    options: [
      { value: 'no', label: 'No — workloads only need internet + Azure-private connectivity.' },
      { value: 'yes', label: 'Yes — establish a VPN tunnel to the on-premises network.' },
    ],
  },
  {
    id: 'subscription_id',
    label: 'Target Azure subscription ID (single-sub mode)',
    help: 'Single subscription that hosts everything. The OIDC service principal used by CI must have Contributor here. Find with: az account show --query id -o tsv',
    impact: 'Used as the home subscription for the azurerm provider. All 6 resource groups (rg-net-hub, rg-net-spoke, rg-security, rg-monitoring, rg-automation, rg-recovery) land here.',
    type: 'text',
    placeholder: '00000000-0000-0000-0000-000000000000',
    pattern: /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/,
    error: 'Must be a valid GUID.',
  },
  {
    id: 'connectivity_subscription_id',
    label: 'Connectivity subscription ID',
    help: 'Hosts hub VNet, Azure Firewall (if used), VPN Gateway (if used), Private DNS zones. Principal needs Contributor here.',
    impact: 'Lands rg-hub. In ALZ this is typically the platform-connectivity sub.',
    type: 'text',
    placeholder: '00000000-0000-0000-0000-000000000000',
    pattern: /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/,
    error: 'Must be a valid GUID.',
  },
  {
    id: 'management_subscription_id',
    label: 'Management subscription ID',
    help: 'Hosts Log Analytics workspace, Automation Account, Recovery Services Vault, Foundation Health workbook, subscription budget. Principal needs Contributor here.',
    impact: 'Lands rg-monitor + rg-backup. In ALZ this is typically the platform-management sub.',
    type: 'text',
    placeholder: '00000000-0000-0000-0000-000000000000',
    pattern: /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/,
    error: 'Must be a valid GUID.',
  },
  {
    id: 'landingzone_subscription_id',
    label: 'Landing-zone subscription ID',
    help: 'Hosts spoke VNet, Key Vault (with private endpoint), workload RGs. Principal needs Contributor here AND Network Contributor on the hub VNet in the connectivity sub for cross-sub peering.',
    impact: 'Lands rg-spoke-prod + rg-security + rg-migrate. In ALZ this is a landingzones/corp or landingzones/online sub.',
    type: 'text',
    placeholder: '00000000-0000-0000-0000-000000000000',
    pattern: /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/,
    error: 'Must be a valid GUID.',
  },
  {
    id: 'name_prefix',
    label: 'Short name prefix for resources (2-8 lowercase alphanumeric)',
    help: 'Used as the org/customer slug in every resource name. Stays the same across scenarios for one customer.',
    impact: 'Naming pattern: <type>-<prefix>-<region>[-suffix]. Examples: rg-net-hub-contoso-wcus, vnet-hub-contoso-wcus, kv-contoso-wcus-<rand6>, fw-contoso-wcus.',
    type: 'text',
    default: 'contoso',
    pattern: /^[a-z0-9]{2,8}$/,
    error: '2-8 lowercase letters or digits.',
  },
  {
    id: 'location',
    label: 'Azure region',
    help: 'Primary region for all hub and spoke resources. Pick one with 3 availability zones if you want zonal NAT/Firewall/VPN gateways.',
    impact: 'Region maps to a short suffix used in names: westcentralus → wcus, eastus → eus, etc. Region appears in every resource name and the state file key.',
    type: 'select',
    default: 'westcentralus',
    options: [
      'westcentralus',
      'westus2',
      'westus3',
      'eastus',
      'eastus2',
      'centralus',
      'northeurope',
      'westeurope',
      'uksouth',
      'australiaeast',
      'southeastasia',
    ].map((r) => ({ value: r, label: r })),
  },
  {
    id: 'on_prem_cidrs',
    label: 'On-premises CIDR(s) — comma-separated (only required if you chose hybrid VPN)',
    help: 'Address spaces of your on-premises networks. Used by the VPN local network gateway and BGP route advertisement.',
    impact: 'Must NOT overlap the hub (10.0.0.0/22) or spoke (10.10.0.0/22) VNets. Multiple CIDRs are allowed.',
    type: 'text',
    placeholder: '192.168.0.0/16, 10.50.0.0/16',
    optional: true,
    pattern: /^(\s*([0-9]{1,3}\.){3}[0-9]{1,3}\/(?:[0-9]|[12][0-9]|3[0-2])\s*)(,\s*([0-9]{1,3}\.){3}[0-9]{1,3}\/(?:[0-9]|[12][0-9]|3[0-2])\s*)*$/,
    error: 'Comma-separated CIDR list, e.g. 192.168.0.0/16',
  },
  {
    id: 'mg_enable',
    label: 'Deploy the optional ALZ-aligned Management Group hierarchy?',
    help: 'Separate root module (management-groups). Creates a tenant-scoped MG tree alongside your subscription deployment. Requires Management Group Contributor at Tenant Root.',
    impact: 'Hierarchy: <prefix> → platform/{management,connectivity[,identity,security]} + landingzones/{corp,online[,local]} [+ decommissioned, sandboxes]. Lets you place subscriptions and apply policies at scale.',
    type: 'radio',
    options: [
      { value: 'no', label: 'No — keep things simple, single subscription only.' },
      { value: 'yes', label: 'Yes — set up MGs (Platform / Landing Zones / Local) for ALZ-style governance.' },
    ],
  },
  {
    id: 'tenant_id',
    label: 'Entra tenant ID (required for MG deployment)',
    help: 'The directory (tenant) GUID. Find with: az account show --query tenantId -o tsv',
    impact: 'Used as the parent of the top-level intermediate MG (the <prefix> root). MGs created: <prefix>, <prefix>-platform, <prefix>-management, <prefix>-connectivity, <prefix>-landingzones, <prefix>-corp, <prefix>-online, plus optionals below.',
    type: 'text',
    placeholder: '00000000-0000-0000-0000-000000000000',
    optional: true,
    pattern: /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/,
    error: 'Must be a valid GUID.',
  },
  {
    id: 'mg_optional',
    label: 'Optional Management Groups to include',
    help: 'Pick which optional MGs to create. Identity & Security are recommended once you have dedicated subscriptions for them. Local is the new MG from ALZ 2026.04 for Azure Local & disconnected exit-readiness.',
    impact: 'Each adds one MG resource at the named parent. No cost. Naming: <prefix>-identity, <prefix>-security, <prefix>-local, <prefix>-decommissioned, <prefix>-sandboxes.',
    type: 'checkbox',
    optional: true,
    options: [
      { value: 'identity', label: 'Identity (platform/identity) — recommended once you have a dedicated identity sub' },
      { value: 'security', label: 'Security (platform/security) — recommended once you have a dedicated security sub' },
      { value: 'local', label: 'Local (landingzones/local) — Azure Local & disconnected exit-readiness (ALZ 2026.04)', default: true },
      { value: 'decommissioned', label: 'Decommissioned — parking lot for cancelled subs', default: true },
      { value: 'sandboxes', label: 'Sandboxes — developer experimentation', default: true },
    ],
  },
  {
    id: 'mg_policies',
    label: 'Assign starter ALZ policies?',
    help: 'Opt-in starter pack of built-in Azure Policy initiatives at the right MG scopes. You can always add or remove policies later by editing policy_assignments in the tfvars.',
    impact: 'Starter set: (1) Deny-MgmtPorts-Internet on landingzones — blocks public RDP/SSH on NSGs; (2) Restrict-Local-Disconn on local — Audit-only check that resource types are Azure-Local-supported. Add more from the policy catalog at any time.',
    type: 'radio',
    optional: true,
    options: [
      { value: 'none', label: 'No policies — I\'ll add them later.' },
      { value: 'starter', label: 'Starter set: Deny public RDP/SSH on Landing Zones + Audit Azure Local exit-readiness.' },
    ],
  },
  {
    id: 'advanced_mode',
    label: 'Show advanced options? (log retention, budget, workbook)',
    help: 'Most teams can skip this and re-deploy later. Turn on if you want to tune Log Analytics retention, set up a subscription budget with email alerts, or deploy the starter Foundation Health workbook in one shot.',
    impact: 'Adds 3 optional questions. Defaults are safe — answering "skip" or leaving fields blank produces the same files you\'d get without advanced mode.',
    type: 'radio',
    options: [
      { value: 'no', label: 'No — keep it simple, use defaults.' },
      { value: 'yes', label: 'Yes — let me tune retention, budget, and workbook.' },
    ],
  },
  {
    id: 'log_retention_days',
    label: 'Log Analytics retention (days)',
    help: 'How long ingested logs are queryable in the foundation Log Analytics workspace. Default is 30. Anything ≤ 31 is included free; longer retention bills per GB-month.',
    impact: '30 = free tier. 90 / 180 / 365 = costs ~$0.10 per GB per month above 31 days. Common picks: 30 (default), 90 (compliance baseline), 365 (audit / regulated).',
    type: 'select',
    optional: true,
    default: '30',
    options: ['30', '60', '90', '180', '365', '730'].map((d) => ({ value: d, label: `${d} days` })),
  },
  {
    id: 'budget_amount',
    label: 'Subscription monthly budget (USD) — leave blank to skip',
    help: 'Deploys an Azure Consumption budget at subscription scope with Actual alerts at 50/80/100% and a Forecasted-100% alert. Free.',
    impact: 'Adds Microsoft.Consumption/budgets at subscription scope. Cost: $0. Requires at least one alert email below.',
    type: 'text',
    placeholder: '500',
    optional: true,
    pattern: /^[1-9][0-9]{0,6}$/,
    error: 'Whole-number USD amount, e.g. 500.',
  },
  {
    id: 'budget_alert_emails',
    label: 'Budget alert emails — comma-separated (only required if you set a budget above)',
    help: 'Where Actual + Forecasted alerts are sent. Distribution lists work fine. Validated as plain RFC-5322-ish email syntax.',
    impact: 'Each address gets one email per crossed threshold per billing period. Set up an inbox rule if you have many.',
    type: 'text',
    placeholder: 'finops@example.com, owner@example.com',
    optional: true,
    pattern: /^(\s*[^@\s,]+@[^@\s,]+\.[^@\s,]+\s*)(,\s*[^@\s,]+@[^@\s,]+\.[^@\s,]+\s*)*$/,
    error: 'Comma-separated email list, e.g. finops@example.com, owner@example.com',
  },
  {
    id: 'workbook_enabled',
    label: 'Deploy the starter Foundation Health workbook?',
    help: 'Adds an Azure Monitor workbook in the monitoring resource group with tabs for ingestion, firewall denies, KV ops, and backup jobs. Edit it freely after deploy.',
    impact: 'One Microsoft.Insights/workbooks resource. Cost: $0 for the workbook itself; queries run against your already-paid LAW data.',
    type: 'radio',
    optional: true,
    options: [
      { value: 'no', label: 'No — I\'ll bring my own dashboards.' },
      { value: 'yes', label: 'Yes — deploy the starter workbook.' },
    ],
  },
];

// Steps that should be skipped depending on prior answers.
function isStepSkipped(qid, answers) {
  if (qid === 'subscription_id') return answers.deployment_mode === 'multi';
  if (qid === 'connectivity_subscription_id' || qid === 'management_subscription_id' || qid === 'landingzone_subscription_id') {
    return answers.deployment_mode !== 'multi';
  }
  if (qid === 'on_prem_cidrs') return answers.hybrid !== 'yes';
  if (qid === 'tenant_id' || qid === 'mg_optional' || qid === 'mg_policies') return answers.mg_enable !== 'yes';
  if (qid === 'log_retention_days' || qid === 'budget_amount' || qid === 'budget_alert_emails' || qid === 'workbook_enabled') {
    return answers.advanced_mode !== 'yes';
  }
  return false;
}

function visibleStepCount(answers) {
  return QUESTIONS.filter((q) => !isStepSkipped(q.id, answers)).length;
}

function deriveScenario(answers) {
  const fw = answers.egress === 'firewall';
  const vpn = answers.hybrid === 'yes';
  if (fw && vpn) return 'full';
  if (fw) return 'firewall';
  if (vpn) return 'vpn';
  return 'baseline';
}

const SCENARIO_META = {
  baseline: { price: '~$48 / month', summary: 'Hub-spoke + NAT egress + shared services. Lowest cost.' },
  firewall: { price: '~$336 / month', summary: 'Adds Azure Firewall (Basic) for managed egress filtering.' },
  vpn:      { price: '~$327 / month', summary: 'Adds a VPN Gateway (VpnGw2AZ) for site-to-site connectivity.' },
  full:     { price: '~$616 / month', summary: 'Firewall + VPN (VpnGw2AZ). Highest control.' },
};

function buildTfvars(answers) {
  const scenario = deriveScenario(answers);
  const isMulti = answers.deployment_mode === 'multi';
  const lines = [
    `# Generated by the Azure Launchpad (SMB / SMEC Edition) wizard`,
    `subscription_id = "${isMulti ? answers.connectivity_subscription_id : answers.subscription_id}"  # default / fallback`,
    `scenario        = "${scenario}"`,
    `location        = "${answers.location}"`,
    `name_prefix     = "${answers.name_prefix}"`,
  ];
  if (isMulti) {
    lines.push('');
    lines.push('# ALZ-aligned multi-subscription split');
    lines.push(`deployment_mode              = "multi"`);
    lines.push(`connectivity_subscription_id = "${answers.connectivity_subscription_id}"`);
    lines.push(`management_subscription_id   = "${answers.management_subscription_id}"`);
    lines.push(`landingzone_subscription_id  = "${answers.landingzone_subscription_id}"`);
  }
  if (scenario === 'vpn' || scenario === 'full') {
    const cidrs = (answers.on_prem_cidrs || '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    lines.push(
      `on_premises_address_space = [${cidrs.map((c) => `"${c}"`).join(', ')}]`,
    );
  }
  // --- Advanced mode -------------------------------------------------------
  if (answers.advanced_mode === 'yes') {
    if (answers.log_retention_days && answers.log_retention_days !== '30') {
      lines.push(`log_retention_days = ${answers.log_retention_days}`);
    }
    if (answers.budget_amount) {
      const emails = (answers.budget_alert_emails || '')
        .split(',').map((s) => s.trim()).filter(Boolean);
      lines.push('');
      lines.push('budget_enabled       = true');
      lines.push(`budget_amount        = ${answers.budget_amount}`);
      lines.push(`budget_alert_emails  = [${emails.map((e) => `"${e}"`).join(', ')}]`);
    }
    if (answers.workbook_enabled === 'yes') {
      lines.push('');
      lines.push('workbook_enabled = true');
    }
  }
  return lines.join('\n') + '\n';
}

function buildBicepParams(answers) {
  const scenario = deriveScenario(answers);
  const lines = [
    `// Generated by the Azure Launchpad (SMB / SMEC Edition) wizard`,
    `using '../main.bicep'`,
    ``,
    `param scenario = '${scenario}'`,
    `param location = '${answers.location}'`,
    `param namePrefix = '${answers.name_prefix}'`,
  ];
  if (scenario === 'vpn' || scenario === 'full') {
    const cidrs = (answers.on_prem_cidrs || '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    lines.push(
      `param onPremisesAddressSpace = [`,
      ...cidrs.map((c) => `  '${c}'`),
      `]`,
    );
  }
  // --- Advanced mode -------------------------------------------------------
  if (answers.advanced_mode === 'yes') {
    if (answers.log_retention_days && answers.log_retention_days !== '30') {
      lines.push(`param logRetentionDays = ${answers.log_retention_days}`);
    }
    if (answers.budget_amount) {
      const emails = (answers.budget_alert_emails || '')
        .split(',').map((s) => s.trim()).filter(Boolean);
      lines.push('');
      lines.push('param budgetEnabled = true');
      lines.push(`param budgetAmount = ${answers.budget_amount}`);
      lines.push(`param budgetAlertEmails = [`);
      emails.forEach((e) => lines.push(`  '${e}'`));
      lines.push(`]`);
    }
    if (answers.workbook_enabled === 'yes') {
      lines.push('');
      lines.push('param workbookEnabled = true');
    }
  }
  return lines.join('\n') + '\n';
}

function buildCommands(answers) {
  const scenario = deriveScenario(answers);
  const isMulti = answers.deployment_mode === 'multi';
  const bootstrapSub = isMulti ? answers.management_subscription_id : answers.subscription_id;
  return `# 1. One-time: create the Azure Storage backend for Terraform state${isMulti ? `\n#    (multi-sub mode: state lives in the MANAGEMENT sub)` : ''}
export ARM_SUBSCRIPTION_ID=${bootstrapSub}
./scripts/bootstrap-state.sh
# (note the storage_account_name printed at the end)

cd infra/terraform/foundation

# 2. Initialize against the backend (replace SA name with bootstrap output)
terraform init \\
  -backend-config="resource_group_name=rg-tfstate-${answers.name_prefix}-${shortRegion(answers.location)}" \\
  -backend-config="storage_account_name=<from-bootstrap>" \\
  -backend-config="container_name=tfstate" \\
  -backend-config="key=foundation.${scenario}${isMulti ? '.multi' : ''}.tfstate"

# 3. Workspace per scenario
terraform workspace select -or-create ${scenario}${isMulti ? '-multi' : ''}

# 4. Plan and apply with the generated tfvars
terraform plan  -var-file=wizard.auto.tfvars
terraform apply -var-file=wizard.auto.tfvars
`;
}

function buildBicepCommands(answers) {
  const scenario = deriveScenario(answers);
  if (answers.deployment_mode === 'multi') {
    // Bicep multi-sub now supports all four scenarios. The wrapper script
    // runs the connectivity → landingzone → connectivity peer-back →
    // management sequence and threads firewall/VPN outputs cross-sub.
    return `# Multi-subscription Bicep deployment (scenario: ${scenario})

az login

# One command runs all 4 deploy steps in the right order
# (connectivity → landingzone → connectivity peer-back → management):
./scripts/deploy-multi-sub.sh \\
  --connectivity-sub ${answers.connectivity_subscription_id} \\
  --management-sub   ${answers.management_subscription_id} \\
  --landingzone-sub  ${answers.landingzone_subscription_id} \\
  --scenario ${scenario} \\
  --name-prefix ${answers.name_prefix} \\
  --region ${answers.location} \\
  --region-short ${shortRegion(answers.location)}
`;
  }
  return `# 1. Sign in to Azure and pin the subscription
az login
az account set --subscription ${answers.subscription_id}

# 2. Preview the deployment (what-if)
az deployment sub what-if \\
  --location ${answers.location} \\
  --name foundation-${scenario} \\
  --parameters infra/bicep/foundation/scenarios/wizard.bicepparam

# 3. Deploy
az deployment sub create \\
  --location ${answers.location} \\
  --name foundation-${scenario} \\
  --parameters infra/bicep/foundation/scenarios/wizard.bicepparam
`;
}

function buildMgTfvars(answers) {
  const opt = new Set(answers.mg_optional || []);
  const lines = [
    `# Generated by the Azure Launchpad (SMB / SMEC Edition) wizard (Management Groups)`,
    `subscription_id = "${answers.subscription_id}"`,
    `tenant_id       = "${answers.tenant_id}"`,
    `name_prefix     = "${answers.name_prefix}"`,
    ``,
    `enable_identity_mg       = ${opt.has('identity')}`,
    `enable_security_mg       = ${opt.has('security')}`,
    `enable_local_mg          = ${opt.has('local')}`,
    `enable_decommissioned_mg = ${opt.has('decommissioned')}`,
    `enable_sandboxes_mg      = ${opt.has('sandboxes')}`,
    ``,
    `enable_policies = ${answers.mg_policies === 'starter'}`,
  ];
  if (answers.mg_policies === 'starter') {
    lines.push(
      ``,
      `policy_assignments = {`,
      `  "Deny-MgmtPorts-Internet" = {`,
      `    scope_mg_key      = "landingzones"`,
      `    policy_definition = "/providers/Microsoft.Authorization/policyDefinitions/22730e10-96f6-4aac-ad84-9383d35b5917"`,
      `    enforce           = true`,
      `  }`,
    );
    if (opt.has('local')) {
      lines.push(
        `  "Restrict-Local-Disconn" = {`,
        `    scope_mg_key      = "local"`,
        `    policy_definition = "/providers/Microsoft.Authorization/policyDefinitions/dabf7c7f-5354-42de-a92a-8367f538dd71"`,
        `    enforce           = false # Audit; flip true once exit story is ready`,
        `  }`,
      );
    }
    lines.push(`}`);
  }
  return lines.join('\n') + '\n';
}

function buildMgCommands(answers) {
  return `# Management Groups deploy at TENANT scope. The principal needs
# 'Management Group Contributor' (and 'Resource Policy Contributor' for
# policies) on Tenant Root Group.

cd infra/terraform/management-groups

terraform init \\
  -backend-config="resource_group_name=rg-tfstate-${answers.name_prefix}-${shortRegion(answers.location)}" \\
  -backend-config="storage_account_name=<from-bootstrap>" \\
  -backend-config="container_name=tfstate" \\
  -backend-config="key=management-groups.wizard.tfstate"

terraform plan  -var-file=mg.auto.tfvars
terraform apply -var-file=mg.auto.tfvars
`;
}

function buildMgBicepParams(answers) {
  const opt = new Set(answers.mg_optional || []);
  const lines = [
    `// Generated by the Azure Launchpad (SMB / SMEC Edition) wizard (Management Groups)`,
    `using '../main.bicep'`,
    ``,
    `param namePrefix = '${answers.name_prefix}'`,
    `param displayNamePrefix = '${answers.name_prefix.toUpperCase()}'`,
    ``,
    `param enableIdentityMg = ${opt.has('identity')}`,
    `param enableSecurityMg = ${opt.has('security')}`,
    `param enableLocalMg = ${opt.has('local')}`,
    `param enableDecommissionedMg = ${opt.has('decommissioned')}`,
    `param enableSandboxesMg = ${opt.has('sandboxes')}`,
    ``,
    `param enablePolicies = ${answers.mg_policies === 'starter'}`,
  ];
  if (answers.mg_policies === 'starter') {
    lines.push(
      ``,
      `param policyAssignments = {`,
      `  'Deny-MgmtPorts-Internet': {`,
      `    scopeMgKey: 'landingzones'`,
      `    policyDefinition: '/providers/Microsoft.Authorization/policyDefinitions/22730e10-96f6-4aac-ad84-9383d35b5917'`,
      `    enforce: true`,
      `  }`,
    );
    if (opt.has('local')) {
      lines.push(
        `  'Restrict-Local-Disconn': {`,
        `    scopeMgKey: 'local'`,
        `    policyDefinition: '/providers/Microsoft.Authorization/policyDefinitions/dabf7c7f-5354-42de-a92a-8367f538dd71'`,
        `    enforce: false  // Audit; flip true once exit story is ready`,
        `  }`,
      );
    }
    lines.push(`}`);
  }
  return lines.join('\n') + '\n';
}

function buildMgBicepCommands(answers) {
  return `# Management Groups deploy at TENANT scope. The principal needs
# 'Management Group Contributor' (and 'Resource Policy Contributor' for
# policies) on Tenant Root Group.

az login --tenant ${answers.tenant_id}

az deployment tenant what-if \\
  --location ${answers.location} \\
  --name foundations-mg-wizard \\
  --parameters infra/bicep/management-groups/scenarios/wizard.bicepparam

az deployment tenant create \\
  --location ${answers.location} \\
  --name foundations-mg-wizard \\
  --parameters infra/bicep/management-groups/scenarios/wizard.bicepparam
`;
}

function shortRegion(loc) {
  const map = {
    westcentralus: 'wcus', westus2: 'wus2', westus3: 'wus3',
    eastus: 'eus', eastus2: 'eus2', centralus: 'cus',
    northeurope: 'neu', westeurope: 'weu', uksouth: 'uks',
    australiaeast: 'aue', southeastasia: 'sea',
  };
  return map[loc] || loc.replace(/[^a-z0-9]/g, '').slice(0, 5);
}

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') node.className = v;
    else if (k === 'html') node.innerHTML = v;
    else if (k.startsWith('on') && typeof v === 'function') node.addEventListener(k.slice(2), v);
    else if (v !== false && v != null) node.setAttribute(k, v);
  }
  for (const c of children.flat()) {
    if (c == null || c === false) continue;
    node.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
  }
  return node;
}

function copyButton(text) {
  return el('button', {
    class: 'copy-btn secondary',
    type: 'button',
    onclick: async (e) => {
      try {
        await navigator.clipboard.writeText(text);
        e.target.textContent = 'Copied!';
        setTimeout(() => (e.target.textContent = 'Copy'), 1500);
      } catch {
        e.target.textContent = 'Press Ctrl-C';
      }
    },
  }, 'Copy');
}

function render(root) {
  const state = { step: 0, answers: { iac_platform: 'terraform', name_prefix: 'contoso', location: 'westcentralus', mg_optional: ['local', 'decommissioned', 'sandboxes'] } };

  function draw() {
    root.innerHTML = '';

    if (state.step >= QUESTIONS.length) {
      drawResult();
      return;
    }

    root.appendChild(el('p', { class: 'wizard-intro' },
      'Answer a few questions about your environment. The wizard recommends a scenario, generates a ready-to-use parameter file (Terraform tfvars or Bicep bicepparam), and gives you the exact CLI commands to deploy it.',
    ));

    const q = QUESTIONS[state.step];
    if (isStepSkipped(q.id, state.answers)) {
      // Skip the step; advance forward (or backward if we got here via Back).
      state.step += state._direction === -1 ? -1 : 1;
      if (state.step < 0) state.step = 0;
      draw();
      return;
    }
    state._direction = 1;

    const total = visibleStepCount(state.answers);
    const visibleIdx = QUESTIONS.slice(0, state.step + 1).filter((qq) => !isStepSkipped(qq.id, state.answers)).length;
    root.appendChild(
      el('div', { class: 'step-indicator' }, el('strong', {}, `Step ${visibleIdx} of ${total}`)),
    );
    root.appendChild(el('label', { for: q.id }, q.label));

    if (q.help) {
      root.appendChild(el('p', { class: 'wizard-help' }, q.help));
    }
    if (q.impact) {
      const impactBox = el('div', { class: 'wizard-impact' },
        el('strong', {}, 'What this changes: '),
      );
      if (typeof q.impact === 'string') {
        impactBox.appendChild(document.createTextNode(q.impact));
      } else {
        if (q.impact.bullets) {
          const ul = el('ul', { class: 'wizard-impact-list' });
          q.impact.bullets.forEach(([label, body]) => {
            ul.appendChild(el('li', {}, el('strong', {}, label), body));
          });
          impactBox.appendChild(ul);
        }
        if (q.impact.note) {
          impactBox.appendChild(el('p', { class: 'wizard-impact-note' }, q.impact.note));
        }
      }
      root.appendChild(impactBox);
    }

    let input;
    if (q.type === 'radio') {
      const wrap = el('div', { class: 'options' });
      q.options.forEach((opt, i) => {
        const id = `${q.id}_${i}`;
        const card = el('label', { class: 'opt', for: id });
        const radio = el('input', { type: 'radio', name: q.id, id, value: opt.value });
        if (state.answers[q.id] === opt.value) radio.checked = true;
        card.appendChild(radio);
        card.appendChild(el('span', {}, opt.label));
        wrap.appendChild(card);
      });
      root.appendChild(wrap);
      input = wrap;
    } else if (q.type === 'checkbox') {
      const current = new Set(state.answers[q.id] || q.options.filter((o) => o.default).map((o) => o.value));
      state.answers[q.id] = Array.from(current);
      const wrap = el('div', { class: 'options' });
      q.options.forEach((opt, i) => {
        const id = `${q.id}_${i}`;
        const card = el('label', { class: 'opt', for: id });
        const cb = el('input', { type: 'checkbox', name: q.id, id, value: opt.value });
        if (current.has(opt.value)) cb.checked = true;
        card.appendChild(cb);
        card.appendChild(el('span', {}, opt.label));
        wrap.appendChild(card);
      });
      root.appendChild(wrap);
      input = wrap;
    } else if (q.type === 'select') {
      const sel = el('select', { id: q.id, name: q.id });
      q.options.forEach((opt) => {
        const o = el('option', { value: opt.value }, opt.label);
        if ((state.answers[q.id] || q.default) === opt.value) o.selected = true;
        sel.appendChild(o);
      });
      root.appendChild(sel);
      input = sel;
    } else {
      input = el('input', {
        id: q.id, name: q.id, type: 'text',
        placeholder: q.placeholder || '',
        value: state.answers[q.id] || q.default || '',
        // Don't let browsers / password managers cache subscription IDs,
        // tenant IDs, CIDRs, or name prefixes across sessions.
        autocomplete: 'off',
        autocorrect: 'off',
        autocapitalize: 'off',
        spellcheck: 'false',
      });
      root.appendChild(input);
    }

    const errBox = el('div', { class: 'verdict hidden', id: 'wizard-error' });
    root.appendChild(errBox);

    const actions = el('div', { class: 'actions' });
    if (state.step > 0) {
      actions.appendChild(el('button', {
        type: 'button', class: 'secondary',
        onclick: () => { state._direction = -1; state.step -= 1; draw(); },
      }, 'Back'));
    }
    const isLast = state.step === QUESTIONS.length - 1
      || QUESTIONS.slice(state.step + 1).every((qq) => isStepSkipped(qq.id, state.answers));
    actions.appendChild(el('button', {
      type: 'button',
      onclick: () => {
        let value;
        if (q.type === 'radio') {
          const checked = input.querySelector('input[type=radio]:checked');
          value = checked ? checked.value : '';
        } else if (q.type === 'checkbox') {
          value = Array.from(input.querySelectorAll('input[type=checkbox]:checked')).map((c) => c.value);
        } else {
          value = input.value.trim();
        }
        const isEmpty = q.type === 'checkbox' ? false : !value;
        if (isEmpty && !q.optional) {
          errBox.textContent = 'Please choose an option.';
          errBox.classList.remove('hidden');
          return;
        }
        if (q.id === 'on_prem_cidrs' && state.answers.hybrid === 'yes' && !value) {
          errBox.textContent = 'Provide at least one on-premises CIDR.';
          errBox.classList.remove('hidden');
          return;
        }
        if (q.id === 'tenant_id' && state.answers.mg_enable === 'yes' && !value) {
          errBox.textContent = 'Tenant ID is required when deploying Management Groups.';
          errBox.classList.remove('hidden');
          return;
        }
        if (q.id === 'budget_alert_emails' && state.answers.budget_amount && !value) {
          errBox.textContent = 'At least one alert email is required when a budget amount is set.';
          errBox.classList.remove('hidden');
          return;
        }
        if (q.type !== 'checkbox' && value && q.pattern && !q.pattern.test(value)) {
          errBox.textContent = q.error || 'Invalid value.';
          errBox.classList.remove('hidden');
          return;
        }
        state.answers[q.id] = value;
        state._direction = 1;
        state.step += 1;
        draw();
      },
    }, isLast ? 'Generate' : 'Next'));
    root.appendChild(actions);
  }

  function drawResult() {
    const scenario = deriveScenario(state.answers);
    const meta = SCENARIO_META[scenario];
    const isBicep = state.answers.iac_platform === 'bicep';
    const platformLabel = isBicep ? 'Bicep' : 'Terraform';
    const paramFileName = isBicep ? 'wizard.bicepparam' : 'wizard.auto.tfvars';
    const paramFolder = isBicep
      ? 'infra/bicep/foundation/scenarios'
      : 'infra/terraform/foundation/scenarios';
    const paramFile = isBicep ? buildBicepParams(state.answers) : buildTfvars(state.answers);
    const cmds = isBicep ? buildBicepCommands(state.answers) : buildCommands(state.answers);
    const hasMg = state.answers.mg_enable === 'yes';

    root.appendChild(el('h2', {}, 'Your deployment plan'));
    root.appendChild(el('p', { class: 'wizard-help' },
      `Based on your answers, the recommended scenario is `,
      el('strong', {}, scenario),
      ` (${meta.price}), deployed with `,
      el('strong', {}, platformLabel),
      `. Follow the steps below to deploy it. Each step shows the file to save and the command to run — copy, paste, and you're done.`,
    ));

    const steps = [
      `Save the generated ${platformLabel} parameter file into the repo at ${paramFolder}/${paramFileName}.`,
      isBicep
        ? `Run az deployment sub what-if and az deployment sub create against your subscription.`
        : `Run terraform init / plan / apply against your subscription.`,
    ];
    if (hasMg) {
      const mgFolder = isBicep ? 'infra/bicep/management-groups/scenarios' : 'infra/terraform/management-groups';
      const mgFile = isBicep ? 'wizard.bicepparam' : 'mg.auto.tfvars';
      steps.push(`Save the Management Groups ${platformLabel} parameter file at ${mgFolder}/${mgFile}.`);
      steps.push(`Deploy the MG hierarchy at tenant scope (separate state / deployment).`);
    }
    const ol = el('ol', { class: 'wizard-steps' });
    steps.forEach((s) => ol.appendChild(el('li', {}, s)));
    root.appendChild(ol);

    root.appendChild(el('div', { class: 'wizard-impact' },
      el('strong', {}, 'Before you start: '),
      isBicep
        ? 'sign in with a principal that has Contributor on the subscription'
        : 'make sure you have run ',
      isBicep ? null : el('code', {}, './scripts/bootstrap-state.sh'),
      isBicep ? null : ' once for this subscription (creates the Azure Storage backend for Terraform state) and that the principal you authenticate as has Contributor on the subscription',
      hasMg ? ' AND Management Group Contributor at Tenant Root.' : '.',
    ));

    root.appendChild(el('h3', {}, `Scenario summary: ${scenario}`));
    root.appendChild(el('div', { class: 'verdict' },
      el('strong', {}, `${meta.price}. `),
      meta.summary,
    ));

    root.appendChild(el('div', { class: 'wizard-impact wizard-secret-warning' },
      el('strong', {}, 'Keep this file out of public repos. '),
      `The generated ${paramFileName} contains your subscription ID and tenant ID. They aren't secrets on their own (no access without an Entra identity + RBAC), but they're useful for phishing and reconnaissance — treat them as internal. Add `,
      el('code', {}, '*.auto.tfvars'),
      ' and ',
      el('code', {}, '*.bicepparam'),
      ' to your ',
      el('code', {}, '.gitignore'),
      ', or commit them only to a private repo.',
    ));

    root.appendChild(el('h3', {}, `1. Save as ${paramFolder}/${paramFileName}`));
    const paramPre = el('pre', {}, el('code', {}, paramFile));
    paramPre.appendChild(copyButton(paramFile));
    root.appendChild(paramPre);

    const dl = el('a', {
      href: URL.createObjectURL(new Blob([paramFile], { type: 'text/plain' })),
      download: paramFileName,
    }, `Download ${platformLabel} parameter file`);
    root.appendChild(dl);

    root.appendChild(el('h3', {}, '2. Run these commands'));
    const cmdsPre = el('pre', {}, el('code', {}, cmds));
    cmdsPre.appendChild(copyButton(cmds));
    root.appendChild(cmdsPre);

    if (state.answers.mg_enable === 'yes') {
      const mgIsBicep = isBicep;
      const mgFile = mgIsBicep ? buildMgBicepParams(state.answers) : buildMgTfvars(state.answers);
      const mgCmds = mgIsBicep ? buildMgBicepCommands(state.answers) : buildMgCommands(state.answers);
      const mgFileName = mgIsBicep ? 'wizard.bicepparam' : 'mg.auto.tfvars';
      const mgFolder = mgIsBicep
        ? 'infra/bicep/management-groups/scenarios'
        : 'infra/terraform/management-groups';

      root.appendChild(el('h2', {}, `Plus: Management Groups (separate, tenant-scoped ${platformLabel} deploy)`));
      root.appendChild(el('div', { class: 'verdict' },
        el('strong', {}, 'Heads up — '),
        'this runs at tenant root, not in your subscription. The principal needs ',
        el('code', {}, 'Management Group Contributor'),
        ' on the Tenant Root Group.',
      ));

      root.appendChild(el('h3', {}, `A. Save as ${mgFolder}/${mgFileName}`));
      const mgFilePre = el('pre', {}, el('code', {}, mgFile));
      mgFilePre.appendChild(copyButton(mgFile));
      root.appendChild(mgFilePre);

      const mgDl = el('a', {
        href: URL.createObjectURL(new Blob([mgFile], { type: 'text/plain' })),
        download: mgFileName,
      }, `Download MG ${platformLabel} parameter file`);
      root.appendChild(mgDl);

      root.appendChild(el('h3', {}, 'B. Deploy the Management Groups'));
      const mgCmdsPre = el('pre', {}, el('code', {}, mgCmds));
      mgCmdsPre.appendChild(copyButton(mgCmds));
      root.appendChild(mgCmdsPre);

      root.appendChild(el('p', {},
        'See ',
        el('a', { href: '/azure-launchpad/governance/management-groups/' }, 'Management Groups'),
        ' and the ',
        el('a', { href: '/azure-launchpad/governance/policy-catalog/' }, 'Policy catalog'),
        ' for details.',
      ));
    }

    root.appendChild(el('h3', {}, 'Next steps'));
    const ul = el('ul');
    [
      ['Read the full prerequisites checklist', '/azure-launchpad/getting-started/prerequisites/'],
      [`Architecture diagram for ${scenario}`, `/azure-launchpad/scenarios/${scenario}/`],
      ['Day-2 operations runbook', '/azure-launchpad/reference/operations/'],
    ].forEach(([t, href]) => ul.appendChild(el('li', {}, el('a', { href }, t))));
    root.appendChild(ul);

    const actions = el('div', { class: 'actions' });
    actions.appendChild(el('button', {
      type: 'button', class: 'secondary',
      onclick: () => { state.step = 0; draw(); },
    }, 'Start over'));
    root.appendChild(actions);
  }

  draw();
}

const root = document.getElementById('wizard-root');
if (root) render(root);
