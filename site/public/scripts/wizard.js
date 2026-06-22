// Azure Launchpad — interactive configuration generator.
// Plain ES module, no framework, served from /public.

const QUESTIONS = [
  {
    id: 'intent',
    label: 'What would you like to do?',
    help: "Choose your goal and we'll tailor the questions and defaults accordingly. You can always adjust individual settings later.",
    impact: {
      bullets: [
        ['Evaluate safely: ', 'Deploys a minimal baseline (~$48/mo) with no production commitments. Great for exploring the architecture.'],
        ['Small production foundation: ', 'Deploys a hub-spoke with logging, backup, budgets, and optional firewall/VPN. Right-sized for a single team.'],
        ['Multi-subscription platform: ', 'ALZ-aligned split (Connectivity / Management / Landing-Zone subs) with management groups and policy. For platform teams managing multiple workloads.'],
      ],
    },
    type: 'radio',
    options: [
      { value: 'evaluate', label: 'Evaluate safely — deploy a minimal baseline to explore.' },
      { value: 'production', label: 'Deploy a small production foundation — hub-spoke + monitoring + backup.' },
      { value: 'platform', label: 'Deploy an ALZ-style multi-subscription platform.' },
    ],
  },
  {
    id: 'iac_platform',
    label: 'Which Infrastructure-as-Code platform do you want to use?',
    help: 'Both options deploy the same Azure architecture (identical resource groups, networking, security, monitoring) — pick the one your team already knows.',
    impact: {
      bullets: [
        ['Terraform: ', 'HCL + Azure provider, state stored in Azure Storage. Multi-subscription mode supports all four scenarios.'],
        ['Bicep: ', 'native ARM-based, deployment history stored in Azure. Multi-subscription mode supports all four scenarios via the deploy-multi-sub.sh wrapper.'],
      ],
      note: 'The generator will tailor the rest of the questions and emit the right files + commands for your choice.',
    },
    type: 'radio',
    options: [
      { value: 'terraform', label: 'Terraform — HCL + AzureRM provider, AVM modules, remote state.' },
      { value: 'bicep', label: 'Bicep — Microsoft’s native DSL, deployments tracked in Azure itself.' },
    ],
  },
  {
    id: 'deploy_method',
    label: 'How will you deploy?',
    help: 'Local / Cloud Shell runs commands directly from your terminal. GitHub Actions uses OIDC for automated, approval-gated deployments.',
    impact: {
      bullets: [
        ['Local / Cloud Shell: ', 'You run preflight, preview, and apply commands interactively. Best for first-time evaluation or single-operator teams.'],
        ['GitHub Actions: ', 'Generates an environment setup checklist: OIDC federated credentials, repo variables, environment protection rules, and approval gates.'],
      ],
    },
    type: 'radio',
    options: [
      { value: 'local', label: 'Local / Cloud Shell — run commands interactively.' },
      { value: 'actions', label: 'GitHub Actions — automated CI/CD with OIDC and approval gates.' },
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
    impact: 'Adds ~$140/mo. This deploys the VPN gateway; configure the on-premises CIDRs, device public IP, and shared key afterward using the post-deploy VPN connection guide.',
    type: 'radio',
    options: [
      { value: 'no', label: 'No — workloads only need internet + Azure-private connectivity.' },
      { value: 'yes', label: 'Yes — establish a VPN tunnel to the on-premises network.' },
    ],
  },
  {
    id: 'subscription_id',
    label: 'Target Azure subscription ID (single-sub mode)',
    help: 'Single subscription that hosts everything. The signed-in identity must have Contributor here. Find with: az account show --query id -o tsv',
    impact: 'Used as the home subscription for the azurerm provider. All 6 resource groups (rg-hub, rg-monitor, rg-backup, rg-spoke-prod, rg-security, rg-migrate) land here.',
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
    impact: 'Naming pattern: <type>-<prefix>-<region>[-suffix]. Examples: rg-hub-contoso-wcus, vnet-hub-contoso-wcus, kv-contoso-wcus-<rand5>, afw-contoso-wcus.',
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
  // Intent-driven skips: evaluate forces single, platform forces multi
  if (qid === 'deployment_mode') {
    return answers.intent === 'evaluate' || answers.intent === 'platform';
  }
  // Evaluate forces baseline: skip egress, hybrid, and mg
  if (qid === 'egress' || qid === 'hybrid') {
    return answers.intent === 'evaluate';
  }
  if (qid === 'mg_enable') {
    // Evaluate skips MG entirely; platform defaults to yes (skip the question)
    return answers.intent === 'evaluate' || answers.intent === 'platform';
  }
  if (qid === 'subscription_id') {
    const mode = resolveDeploymentMode(answers);
    return mode === 'multi';
  }
  if (qid === 'connectivity_subscription_id' || qid === 'management_subscription_id' || qid === 'landingzone_subscription_id') {
    const mode = resolveDeploymentMode(answers);
    return mode !== 'multi';
  }
  if (qid === 'tenant_id' || qid === 'mg_optional' || qid === 'mg_policies') {
    const mgEnabled = resolveMgEnable(answers);
    return mgEnabled !== 'yes';
  }
  if (qid === 'log_retention_days' || qid === 'budget_amount' || qid === 'budget_alert_emails' || qid === 'workbook_enabled') {
    return answers.advanced_mode !== 'yes';
  }
  return false;
}

// Resolve effective deployment_mode based on intent or explicit answer
function resolveDeploymentMode(answers) {
  if (answers.intent === 'evaluate') return 'single';
  if (answers.intent === 'platform') return 'multi';
  return answers.deployment_mode;
}

// Resolve effective mg_enable based on intent or explicit answer
function resolveMgEnable(answers) {
  if (answers.intent === 'evaluate') return 'no';
  if (answers.intent === 'platform') return 'yes';
  return answers.mg_enable;
}

function visibleStepCount(answers) {
  return QUESTIONS.filter((q) => !isStepSkipped(q.id, answers)).length;
}

function deriveScenario(answers) {
  if (answers.intent === 'evaluate') return 'baseline';
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

const DEFAULT_ANSWERS = {
  iac_platform: 'terraform',
  name_prefix: 'contoso',
  location: 'westcentralus',
  mg_optional: ['local', 'decommissioned', 'sandboxes'],
};

function createInitialAnswers() {
  return { ...DEFAULT_ANSWERS, mg_optional: [...DEFAULT_ANSWERS.mg_optional] };
}

function buildTfvars(answers) {
  const scenario = deriveScenario(answers);
  const isMulti = resolveDeploymentMode(answers) === 'multi';
  const lines = [
    `# Generated by the Azure Launchpad configuration generator`,
    `subscription_id = "${isMulti ? answers.management_subscription_id : answers.subscription_id}"  # default / fallback (management sub in multi-sub)`,
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
    `// Generated by the Azure Launchpad configuration generator`,
    `using '../main.bicep'`,
    ``,
    `param scenario = '${scenario}'`,
    `param location = '${answers.location}'`,
    `param namePrefix = '${answers.name_prefix}'`,
  ];
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
  const isMulti = resolveDeploymentMode(answers) === 'multi';
  const bootstrapSub = isMulti ? answers.management_subscription_id : answers.subscription_id;
  const modeArgs = isMulti
    ? `--mode multi \\
  --connectivity-sub ${answers.connectivity_subscription_id} \\
  --management-sub ${answers.management_subscription_id} \\
  --landingzone-sub ${answers.landingzone_subscription_id}`
    : `--mode single --subscription ${answers.subscription_id}`;
  const planFile = `.launchpad/plans/foundation.${scenario}.${isMulti ? 'multi' : 'single'}.tfplan`;
  return `# 1. One-time: create the Azure Storage backend for Terraform state${isMulti ? `\n#    (multi-sub mode: state lives in the MANAGEMENT sub)` : ''}
export ARM_SUBSCRIPTION_ID=${bootstrapSub}
./scripts/bootstrap-state.sh

# 2. Preflight + save a reviewable plan
./scripts/deploy.sh plan --iac terraform ${modeArgs} \\
  --scenario ${scenario} \\
  --config infra/terraform/foundation/scenarios/wizard.auto.tfvars

# 3. After review, apply only the saved plan
./scripts/deploy.sh apply --iac terraform ${modeArgs} \\
  --scenario ${scenario} \\
  --config infra/terraform/foundation/scenarios/wizard.auto.tfvars \\
  --plan-file ${planFile}

# 4. Verify the expected foundation resources
./scripts/verify.sh ${modeArgs} --scenario ${scenario} \\
  --name-prefix ${answers.name_prefix} --region-short ${shortRegion(answers.location)}
`;
}

function buildBicepCommands(answers) {
  const scenario = deriveScenario(answers);
  if (resolveDeploymentMode(answers) === 'multi') {
    return `# Multi-subscription Bicep deployment (scenario: ${scenario})

az login

# 1. Preview every layer without creating resources
./scripts/deploy.sh plan --iac bicep --mode multi \\
  --connectivity-sub ${answers.connectivity_subscription_id} \\
  --management-sub   ${answers.management_subscription_id} \\
  --landingzone-sub  ${answers.landingzone_subscription_id} \\
  --scenario ${scenario} \\
  --name-prefix ${answers.name_prefix} \\
  --region ${answers.location} \\
  --region-short ${shortRegion(answers.location)}

# 2. After review, deploy all layers in dependency order
./scripts/deploy.sh apply --iac bicep --mode multi \\
  --connectivity-sub ${answers.connectivity_subscription_id} \\
  --management-sub   ${answers.management_subscription_id} \\
  --landingzone-sub  ${answers.landingzone_subscription_id} \\
  --scenario ${scenario} \\
  --name-prefix ${answers.name_prefix} \\
  --region ${answers.location} \\
  --region-short ${shortRegion(answers.location)}

# 3. Verify the expected foundation resources
./scripts/verify.sh --mode multi \\
  --connectivity-sub ${answers.connectivity_subscription_id} \\
  --management-sub ${answers.management_subscription_id} \\
  --landingzone-sub ${answers.landingzone_subscription_id} \\
  --scenario ${scenario} --name-prefix ${answers.name_prefix} \\
  --region-short ${shortRegion(answers.location)}
`;
  }
  return `# 1. Sign in and preview the deployment
az login
./scripts/deploy.sh plan --iac bicep --mode single \\
  --subscription ${answers.subscription_id} --scenario ${scenario} \\
  --config infra/bicep/foundation/scenarios/wizard.bicepparam \\
  --region ${answers.location}

# 2. After review, deploy the same parameter file
./scripts/deploy.sh apply --iac bicep --mode single \\
  --subscription ${answers.subscription_id} --scenario ${scenario} \\
  --config infra/bicep/foundation/scenarios/wizard.bicepparam \\
  --region ${answers.location}

# 3. Verify the expected foundation resources
./scripts/verify.sh --mode single --subscription ${answers.subscription_id} \\
  --scenario ${scenario} --name-prefix ${answers.name_prefix} \\
  --region-short ${shortRegion(answers.location)}
`;
}

function buildMgTfvars(answers) {
  const opt = new Set(answers.mg_optional || []);
  const isMulti = resolveDeploymentMode(answers) === 'multi';
  const homeSubscriptionId = isMulti ? answers.management_subscription_id : answers.subscription_id;
  const lines = [
    `# Generated by the Azure Launchpad configuration generator (Management Groups)`,
    `subscription_id = "${homeSubscriptionId}"`,
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
  if (isMulti) {
    lines.push(
      ``,
      `# Place each platform subscription under its ALZ-aligned Management Group.`,
      `subscription_placements = {`,
      `  "${answers.connectivity_subscription_id}" = "connectivity"`,
      `  "${answers.management_subscription_id}"   = "management"`,
      `  "${answers.landingzone_subscription_id}"  = "corp"`,
      `}`,
    );
  }
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

terraform plan  -var-file=mg.auto.tfvars -out=mg.tfplan
# Review the plan above, then apply the saved plan:
terraform apply mg.tfplan
`;
}

function buildMgBicepParams(answers) {
  const opt = new Set(answers.mg_optional || []);
  const isMulti = resolveDeploymentMode(answers) === 'multi';
  const lines = [
    `// Generated by the Azure Launchpad configuration generator (Management Groups)`,
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
  if (isMulti) {
    lines.push(
      ``,
      `// Place each platform subscription under its ALZ-aligned Management Group.`,
      `param subscriptionPlacements = {`,
      `  '${answers.connectivity_subscription_id}': 'connectivity'`,
      `  '${answers.management_subscription_id}': 'management'`,
      `  '${answers.landingzone_subscription_id}': 'corp'`,
      `}`,
    );
  }
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



function buildDeploymentReadme(answers) {
  const scenario = deriveScenario(answers);
  const isBicep = answers.iac_platform === 'bicep';
  const isMulti = resolveDeploymentMode(answers) === 'multi';
  const isActions = answers.deploy_method === 'actions';
  const hasMg = resolveMgEnable(answers) === 'yes';
  const paramFileName = isBicep ? 'wizard.bicepparam' : 'wizard.auto.tfvars';
  const paramFolder = isBicep
    ? 'infra/bicep/foundation/scenarios'
    : 'infra/terraform/foundation/scenarios';

  const header = `# Azure Launchpad \u2014 Deployment Kit

Generated: ${new Date().toISOString().slice(0, 10)}
Scenario: **${scenario}**
IaC: ${isBicep ? 'Bicep' : 'Terraform'}
Mode: ${isMulti ? 'Multi-subscription (ALZ split)' : 'Single subscription'}
Region: ${answers.location}
Name prefix: ${answers.name_prefix}
Deploy method: ${isActions ? 'GitHub Actions (OIDC)' : 'Local / Cloud Shell'}
`;

  if (isActions) {
    const planEnv = 'plan';
    const protectedEnv = isBicep ? 'apply' : 'prod';
    const ciFile = isBicep
      ? `infra/bicep/foundation/scenarios/${scenario}.bicepparam`
      : `infra/terraform/foundation/scenarios/${scenario}.tfvars`;
    const workflowName = isBicep ? 'bicep-apply' : 'terraform-apply';
    const tfVarsStep = !isBicep ? `\n- Set additional variables: \`TFSTATE_RG\`, \`TFSTATE_SA\`, \`TFSTATE_CONTAINER\`.` : '';
    const mgStep = hasMg ? `\n- Create a second app registration with MG Contributor at Tenant Root. Set \`AZURE_MG_CLIENT_ID\`.\n- Add federated credentials for \`plan-mg\` and \`apply-mg\` environments.` : '';
    return header + `## GitHub Actions Setup

- Create an Entra app registration and grant Contributor on target subscription(s).
- Add federated credentials for the \`${planEnv}\` and \`${protectedEnv}\` environments.
- Create GitHub environments: \`${planEnv}\` (unprotected) and \`${protectedEnv}\` (Required Reviewers enabled).
- Set repository variables: \`AZURE_CLIENT_ID\`, \`AZURE_TENANT_ID\`, \`AZURE_SUBSCRIPTION_ID\`.${tfVarsStep}
- Update \`${ciFile}\` with your scenario values (committed, not gitignored).
- Push and trigger \`${workflowName}\` via workflow_dispatch, selecting scenario \`${scenario}\`.${mgStep}

Full guide: https://azurelaunchpad.com/reference/cicd/

## Notes

- The CI param file (\`${ciFile}\`) is committed to the repo (not gitignored).
- Pricing: see https://azure.microsoft.com/en-us/pricing/calculator/
- Day-2 operations: see https://azurelaunchpad.com/reference/day-2-operations/
`;
  }

  // Local / Cloud Shell flow
  const previewCmds = buildPreviewCommands(answers);
  const applyCmds = buildApplyCommands(answers);
  const verifyCmds = buildVerifyCommands(answers);
  const mode = isMulti ? 'multi' : 'single';
  const subArgs = isMulti
    ? `--connectivity-sub ${answers.connectivity_subscription_id} \\\n  --management-sub ${answers.management_subscription_id} \\\n  --landingzone-sub ${answers.landingzone_subscription_id}`
    : `--subscription ${answers.subscription_id}`;
  const configArg = (isBicep && isMulti)
    ? '' // multi-sub Bicep passes values via deploy.sh args
    : `--config ${paramFolder}/${paramFileName}`;
  const configSuffix = configArg ? ` \\\n  ${configArg}` : '';
  const preflightCmd = `./scripts/preflight.sh --iac ${isBicep ? 'bicep' : 'terraform'} --mode ${mode} \\\n  ${subArgs}${configSuffix}`;
  const bootstrapSub = isMulti ? answers.management_subscription_id : answers.subscription_id;
  const bootstrapSection = isBicep ? '' : `
### Bootstrap state backend (first time only)
\`\`\`bash
ARM_SUBSCRIPTION_ID=${bootstrapSub} \
PREFIX=${answers.name_prefix} \
LOCATION=${answers.location} \
REGION_SHORT=${shortRegion(answers.location)} \
  ./scripts/bootstrap-state.sh
\`\`\`
`;

  let mgSection = '';
  if (hasMg) {
    const mgPreview = buildMgPreviewCommands(answers);
    const mgApply = buildMgApplyCommands(answers);
    mgSection = `
## Management Groups (separate, tenant-scoped deployment)

### MG Preview
\`\`\`bash
${mgPreview}
\`\`\`

### MG Apply
\`\`\`bash
${mgApply}
\`\`\`
`;
  }

  return header + `## Quick start
${isBicep && isMulti ? '\nMulti-sub Bicep passes values via command arguments (no param file needed).\n' : `\n1. Copy \`${paramFileName}\` to \`${paramFolder}/\` in the repo.\n2. Run preflight, preview, then apply:\n`}${bootstrapSection}
### Preflight
\`\`\`bash
${preflightCmd}
\`\`\`

### Preview (dry-run, no resources created)
\`\`\`bash
${previewCmds}
\`\`\`

### Apply (creates Azure resources)
\`\`\`bash
${applyCmds}
\`\`\`

### Verify
\`\`\`bash
${verifyCmds}
\`\`\`
${mgSection}
## Notes

- The parameter file contains subscription/tenant IDs. Keep it out of public repos.
- Pricing: see https://azure.microsoft.com/en-us/pricing/calculator/
- Day-2 operations: see https://azurelaunchpad.com/reference/day-2-operations/
`;
}

function buildPreviewCommands(answers) {
  const scenario = deriveScenario(answers);
  const isBicep = answers.iac_platform === 'bicep';
  const isMulti = resolveDeploymentMode(answers) === 'multi';

  if (isBicep) {
    if (isMulti) {
      return `# Preview all layers (no resources created)
./scripts/deploy.sh plan --iac bicep --mode multi \
  --connectivity-sub ${answers.connectivity_subscription_id} \
  --management-sub   ${answers.management_subscription_id} \
  --landingzone-sub  ${answers.landingzone_subscription_id} \
  --scenario ${scenario} --name-prefix ${answers.name_prefix} \
  --region ${answers.location} --region-short ${shortRegion(answers.location)}`;
    }
    return `# Preview the deployment (what-if)
./scripts/deploy.sh plan --iac bicep --mode single \
  --subscription ${answers.subscription_id} --scenario ${scenario} \
  --config infra/bicep/foundation/scenarios/wizard.bicepparam \
  --region ${answers.location}`;
  }

  // Terraform
  const modeArgs = isMulti
    ? `--mode multi \
  --connectivity-sub ${answers.connectivity_subscription_id} \
  --management-sub ${answers.management_subscription_id} \
  --landingzone-sub ${answers.landingzone_subscription_id}`
    : `--mode single --subscription ${answers.subscription_id}`;
  return `# Save a reviewable plan (no resources created)
./scripts/deploy.sh plan --iac terraform ${modeArgs} \
  --scenario ${scenario} \
  --config infra/terraform/foundation/scenarios/wizard.auto.tfvars`;
}

function buildApplyCommands(answers) {
  const scenario = deriveScenario(answers);
  const isBicep = answers.iac_platform === 'bicep';
  const isMulti = resolveDeploymentMode(answers) === 'multi';

  if (isBicep) {
    if (isMulti) {
      return `# Deploy all layers in dependency order
./scripts/deploy.sh apply --iac bicep --mode multi \
  --connectivity-sub ${answers.connectivity_subscription_id} \
  --management-sub   ${answers.management_subscription_id} \
  --landingzone-sub  ${answers.landingzone_subscription_id} \
  --scenario ${scenario} --name-prefix ${answers.name_prefix} \
  --region ${answers.location} --region-short ${shortRegion(answers.location)}`;
    }
    return `# Deploy (creates Azure resources)
./scripts/deploy.sh apply --iac bicep --mode single \
  --subscription ${answers.subscription_id} --scenario ${scenario} \
  --config infra/bicep/foundation/scenarios/wizard.bicepparam \
  --region ${answers.location}`;
  }

  // Terraform
  const modeArgs = isMulti
    ? `--mode multi \
  --connectivity-sub ${answers.connectivity_subscription_id} \
  --management-sub ${answers.management_subscription_id} \
  --landingzone-sub ${answers.landingzone_subscription_id}`
    : `--mode single --subscription ${answers.subscription_id}`;
  const planFile = `.launchpad/plans/foundation.${scenario}.${isMulti ? 'multi' : 'single'}.tfplan`;
  return `# Apply only the saved, reviewed plan
./scripts/deploy.sh apply --iac terraform ${modeArgs} \
  --scenario ${scenario} \
  --config infra/terraform/foundation/scenarios/wizard.auto.tfvars \
  --plan-file ${planFile}`;
}

function buildVerifyCommands(answers) {
  const scenario = deriveScenario(answers);
  const isMulti = resolveDeploymentMode(answers) === 'multi';
  const modeArgs = isMulti
    ? `--mode multi \
  --connectivity-sub ${answers.connectivity_subscription_id} \
  --management-sub ${answers.management_subscription_id} \
  --landingzone-sub ${answers.landingzone_subscription_id}`
    : `--mode single --subscription ${answers.subscription_id}`;
  return `# Verify expected resources exist
./scripts/verify.sh ${modeArgs} \
  --scenario ${scenario} --name-prefix ${answers.name_prefix} \
  --region-short ${shortRegion(answers.location)}`;
}

function buildMgPreviewCommands(answers) {
  const isBicep = answers.iac_platform === 'bicep';
  if (isBicep) {
    return `# Preview MG changes (tenant-scoped what-if)
az login --tenant ${answers.tenant_id}

az deployment tenant what-if \
  --location ${answers.location} \
  --name foundations-mg-wizard \
  --parameters infra/bicep/management-groups/scenarios/wizard.bicepparam`;
  }
  return `# Preview MG changes (terraform plan)
cd infra/terraform/management-groups

terraform init \
  -backend-config="\${REPO_ROOT}/.launchpad/backend.hcl" \
  -backend-config="key=management-groups.tfstate"

terraform plan -var-file=mg.auto.tfvars -out=mg.tfplan`;
}

function buildMgApplyCommands(answers) {
  const isBicep = answers.iac_platform === 'bicep';
  if (isBicep) {
    return `# Apply MG deployment (creates hierarchy at tenant root)
az deployment tenant create \
  --location ${answers.location} \
  --name foundations-mg-wizard \
  --parameters infra/bicep/management-groups/scenarios/wizard.bicepparam`;
  }
  return `# Apply the reviewed MG plan
terraform apply mg.tfplan`;
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
  // Restore progress from sessionStorage (survives accidental refresh)
  const saved = typeof sessionStorage !== 'undefined' && sessionStorage.getItem('launchpad-wizard');
  const restored = saved ? JSON.parse(saved) : null;
  const state = restored
    ? { step: restored.step || 0, answers: { ...createInitialAnswers(), ...restored.answers } }
    : { step: 0, answers: createInitialAnswers() };

  function saveProgress() {
    if (typeof sessionStorage !== 'undefined') {
      sessionStorage.setItem('launchpad-wizard', JSON.stringify({ step: state.step, answers: state.answers }));
    }
  }

  function draw() {
    root.innerHTML = '';
    root.setAttribute('aria-live', 'polite');

    if (state.step >= QUESTIONS.length) {
      drawResult();
      return;
    }

    root.appendChild(el('p', { class: 'wizard-intro' },
      'Answer a few questions about your environment. The generator recommends a scenario, creates a ready-to-use parameter file (Terraform tfvars or Bicep bicepparam), and gives you exact commands to preview, deploy, and verify it.',
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
    const progressPct = Math.round((visibleIdx / total) * 100);
    root.appendChild(el('div', {
      class: 'wizard-progress', role: 'progressbar',
      'aria-valuenow': progressPct, 'aria-valuemin': 0, 'aria-valuemax': 100,
      'aria-label': `Step ${visibleIdx} of ${total}`,
    }, el('div', { class: 'wizard-progress-fill', style: `width:${progressPct}%` })));
    root.appendChild(el('p', { class: 'wizard-step-count' }, `Step ${visibleIdx} of ${total}`));

    // Fieldset + legend for accessibility (groups related inputs with a label)
    const fieldset = el('fieldset', { class: 'wizard-fieldset' });
    fieldset.appendChild(el('legend', {}, q.label));
    root.appendChild(fieldset);

    if (q.help) {
      fieldset.appendChild(el('p', { class: 'wizard-help' }, q.help));
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
      fieldset.appendChild(impactBox);
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
      fieldset.appendChild(wrap);
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
      fieldset.appendChild(wrap);
      input = wrap;
    } else if (q.type === 'select') {
      const sel = el('select', { id: q.id, name: q.id });
      q.options.forEach((opt) => {
        const o = el('option', { value: opt.value }, opt.label);
        if ((state.answers[q.id] || q.default) === opt.value) o.selected = true;
        sel.appendChild(o);
      });
      fieldset.appendChild(sel);
      input = sel;
    } else {
      input = el('input', {
        id: q.id, name: q.id, type: 'text',
        placeholder: q.placeholder || '',
        value: state.answers[q.id] || q.default || '',
        'aria-label': q.label,
        // Don't let browsers / password managers cache subscription IDs,
        // tenant IDs, or name prefixes across sessions.
        autocomplete: 'off',
        autocorrect: 'off',
        autocapitalize: 'off',
        spellcheck: 'false',
      });
      fieldset.appendChild(input);
    }

    const errBox = el('div', { class: 'verdict hidden', id: 'wizard-error' });
    fieldset.appendChild(errBox);

    const actions = el('div', { class: 'actions' });
    if (state.step > 0) {
      actions.appendChild(el('button', {
        type: 'button', class: 'secondary',
        onclick: () => { state._direction = -1; state.step -= 1; saveProgress(); draw(); },
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
        if (q.id === 'tenant_id' && resolveMgEnable(state.answers) === 'yes' && !value) {
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
        saveProgress();
        draw();
      },
    }, isLast ? 'Generate' : 'Next'));
    root.appendChild(actions);
  }

  function drawResult() {
    const scenario = deriveScenario(state.answers);
    const meta = SCENARIO_META[scenario];
    const isBicep = state.answers.iac_platform === 'bicep';
    const isActions = state.answers.deploy_method === 'actions';
    const platformLabel = isBicep ? 'Bicep' : 'Terraform';
    const isMulti = resolveDeploymentMode(state.answers) === 'multi';
    const paramFileName = isBicep ? 'wizard.bicepparam' : 'wizard.auto.tfvars';
    const paramFolder = isBicep
      ? 'infra/bicep/foundation/scenarios'
      : 'infra/terraform/foundation/scenarios';
    const paramFile = isBicep ? buildBicepParams(state.answers) : buildTfvars(state.answers);
    const hasMg = resolveMgEnable(state.answers) === 'yes';

    // Multi-subscription + Actions is not supported by the existing workflows
    if (isActions && isMulti) {
      root.appendChild(el('h2', {}, 'Multi-subscription CI/CD is not yet supported'));
      root.appendChild(el('div', { class: 'verdict' },
        'The existing GitHub Actions workflows deploy to a single subscription. ',
        'Multi-subscription deployment requires the local/Cloud Shell flow, or a custom pipeline. ',
      ));
      root.appendChild(el('div', { class: 'actions' },
        el('button', {
          type: 'button', class: 'secondary',
          onclick: () => { state.step = QUESTIONS.findIndex((q) => q.id === 'deploy_method'); state._direction = 1; draw(); },
        }, 'Change to Local / Cloud Shell'),
        el('button', {
          type: 'button', class: 'secondary',
          onclick: () => { state.step = 0; state._direction = 1; draw(); },
        }, 'Start over'),
      ));
      return;
    }

    // --- Review Summary ---
    root.appendChild(el('h2', {}, 'Review your configuration'));
    const reviewTable = el('table', { class: 'wizard-review-table' });
    const reviewRows = [
      ['Scenario', `${scenario} (${meta.price})`],
      ['IaC', platformLabel],
      ['Deploy method', isActions ? 'GitHub Actions (OIDC)' : 'Local / Cloud Shell'],
      ['Subscription mode', resolveDeploymentMode(state.answers) === 'multi' ? 'Multi-subscription (ALZ split)' : 'Single subscription'],
      ['Region', state.answers.location],
      ['Name prefix', state.answers.name_prefix],
      ['Management Groups', hasMg ? 'Yes (tenant-scoped)' : 'No'],
    ];
    if (state.answers.budget_amount) {
      reviewRows.push(['Budget', `$${state.answers.budget_amount} USD/mo`]);
    }
    const roles = ['Contributor on target subscription(s)'];
    if (isMulti) roles.push('Network Contributor on connectivity subscription');
    if (state.answers.mg_policies === 'starter') roles.push('Resource Policy Contributor');
    if (!isBicep) roles.push('Storage Blob Data Contributor on state storage account');
    if (hasMg) roles.push('Management Group Contributor at Tenant Root');
    reviewRows.push(['Required role(s)', roles.join('; ')]);
    const tbody = el('tbody');
    reviewRows.forEach(([label, value]) => {
      tbody.appendChild(el('tr', {},
        el('td', { class: 'review-label' }, el('strong', {}, label)),
        el('td', {}, value),
      ));
    });
    reviewTable.appendChild(tbody);
    root.appendChild(reviewTable);

    const editBtn = el('button', {
      type: 'button', class: 'secondary',
      onclick: () => { state.step = 0; state._direction = 1; draw(); },
    }, 'Edit answers');
    root.appendChild(el('div', { class: 'actions' }, editBtn));

    // --- Cost context ---
    root.appendChild(el('div', { class: 'wizard-impact' },
      el('strong', {}, `Estimated cost: ${meta.price} `),
      '(USD, West Central US pricing, June 2026). ',
      'Excludes data transfer, log ingestion beyond free tier, backup storage, and VPN tunnel throughput. ',
      el('a', { href: 'https://azure.microsoft.com/en-us/pricing/calculator/' }, 'Azure Pricing Calculator'),
      ' for exact figures.',
    ));

    // --- Deployment Checklist ---
    root.appendChild(el('h2', {}, 'Deployment checklist'));
    root.appendChild(el('p', { class: 'wizard-help' },
      'Complete each stage in order. Expand a stage to see the files and commands.',
    ));

    // Helper for expandable stages
    function stage(number, title, dangerClass, contentFn) {
      const details = el('details', { class: `wizard-stage ${dangerClass || ''}` });
      const summary = el('summary', {},
        el('span', { class: 'stage-number' }, `${number}`),
        el('span', { class: 'stage-title' }, title),
      );
      details.appendChild(summary);
      const body = el('div', { class: 'stage-body' });
      contentFn(body);
      details.appendChild(body);
      return details;
    }

    // Stage 1: Save configuration
    if (isBicep && isMulti) {
      // Multi-sub Bicep passes all values via deploy.sh arguments; no param file needed.
      root.appendChild(stage(1, 'Configuration values (passed via command args)', '', (body) => {
        body.appendChild(el('p', {},
          'Multi-subscription Bicep passes values directly to ',
          el('code', {}, 'deploy.sh'), '. No separate parameter file is needed.',
        ));
        body.appendChild(el('p', {}, el('strong', {}, 'Your values:')));
        const vals = el('ul');
        vals.appendChild(el('li', {}, `Scenario: ${scenario}`));
        vals.appendChild(el('li', {}, `Name prefix: ${state.answers.name_prefix}`));
        vals.appendChild(el('li', {}, `Region: ${state.answers.location}`));
        vals.appendChild(el('li', {}, `Connectivity sub: ${state.answers.connectivity_subscription_id}`));
        vals.appendChild(el('li', {}, `Management sub: ${state.answers.management_subscription_id}`));
        vals.appendChild(el('li', {}, `Landing zone sub: ${state.answers.landingzone_subscription_id}`));
        body.appendChild(vals);
        const readme = buildDeploymentReadme(state.answers);
        body.appendChild(el('a', {
          href: URL.createObjectURL(new Blob([readme], { type: 'text/markdown' })),
          download: 'DEPLOY.md',
          class: 'wizard-download',
        }, 'Download deployment kit (DEPLOY.md)'));
      }));
    } else {
      root.appendChild(stage(1, `Save ${platformLabel} parameter file`, '', (body) => {
        body.appendChild(el('p', {},
          `Save as `, el('code', {}, `${paramFolder}/${paramFileName}`), '.',
        ));
        body.appendChild(el('div', { class: 'wizard-impact wizard-secret-warning' },
          el('strong', {}, 'Keep out of public repos. '),
          `Contains subscription/tenant IDs. The repo\u2019s .gitignore already excludes wizard-generated files.`,
        ));
        const pre = el('pre', {}, el('code', {}, paramFile));
        pre.appendChild(copyButton(paramFile));
        body.appendChild(pre);
        body.appendChild(el('a', {
          href: URL.createObjectURL(new Blob([paramFile], { type: 'text/plain' })),
          download: paramFileName,
          class: 'wizard-download',
        }, `Download ${paramFileName}`));
        const readme = buildDeploymentReadme(state.answers);
        body.appendChild(el('a', {
          href: URL.createObjectURL(new Blob([readme], { type: 'text/markdown' })),
          download: 'DEPLOY.md',
          class: 'wizard-download',
        }, 'Download deployment kit (DEPLOY.md)'));
      }));
    }

    if (isActions) {
      // Stage 2 for Actions: environment setup checklist
      const planEnv = 'plan';
      const protectedEnv = isBicep ? 'apply' : 'prod';
      const ciFileName = isBicep
        ? `infra/bicep/foundation/scenarios/${scenario}.bicepparam`
        : `infra/terraform/foundation/scenarios/${scenario}.tfvars`;
      const workflowName = isBicep ? 'bicep-apply' : 'terraform-apply';
      root.appendChild(stage(2, 'Configure GitHub Actions (OIDC)', '', (body) => {
        body.appendChild(el('p', {}, 'Set up your repository for automated deployment with OIDC:'));
        const checklist = el('ol', { class: 'wizard-steps' });
        checklist.appendChild(el('li', {}, 'Create an Entra app registration and grant Contributor on target subscription(s).'));
        checklist.appendChild(el('li', {},
          'Add federated credentials for the ',
          el('code', {}, planEnv), ' and ',
          el('code', {}, protectedEnv), ' environments',
          hasMg ? ' (and ' : '', hasMg ? el('code', {}, 'apply-mg') : '', hasMg ? ' for MGs).' : '.',
        ));
        checklist.appendChild(el('li', {},
          'Create GitHub environments: ',
          el('code', {}, planEnv), ' (unprotected) and ',
          el('code', {}, protectedEnv), ' (Required Reviewers enabled).',
        ));
        checklist.appendChild(el('li', {}, 'Set repository variables: ', el('code', {}, 'AZURE_CLIENT_ID'), ', ', el('code', {}, 'AZURE_TENANT_ID'), ', ', el('code', {}, 'AZURE_SUBSCRIPTION_ID'), '.'));
        if (!isBicep) {
          checklist.appendChild(el('li', {}, 'Set additional variables: ', el('code', {}, 'TFSTATE_RG'), ', ', el('code', {}, 'TFSTATE_SA'), ', ', el('code', {}, 'TFSTATE_CONTAINER'), '.'));
        }
        checklist.appendChild(el('li', {},
          'Update ', el('code', {}, ciFileName), ' with your values (do ',
          el('strong', {}, 'not'), ' include ', el('code', {}, 'subscription_id'),
          isBicep ? '' : ' — the workflow injects it from ', isBicep ? '' : el('code', {}, 'AZURE_SUBSCRIPTION_ID'),
          isBicep ? ':' : '):',
        ));
        const ciSnippet = isBicep
          ? `// Update in ${ciFileName}\nusing '../main.bicep'\n\nparam scenario = '${scenario}'\nparam location = '${state.answers.location}'\nparam namePrefix = '${state.answers.name_prefix}'`
          : `# Update in ${ciFileName}\nscenario    = "${scenario}"\nlocation    = "${state.answers.location}"\nname_prefix = "${state.answers.name_prefix}"`;
        const ciPre = el('pre', {}, el('code', {}, ciSnippet));
        ciPre.appendChild(copyButton(ciSnippet));
        checklist.appendChild(ciPre);
        checklist.appendChild(el('li', {},
          'Push and trigger ',
          el('code', {}, workflowName),
          ' via workflow_dispatch, selecting scenario ',
          el('code', {}, scenario), '.',
        ));
        body.appendChild(checklist);
        body.appendChild(el('p', {},
          'Full guide: ', el('a', { href: '/reference/cicd/' }, 'CI/CD pipeline reference'), '.',
        ));
      }));
    } else {
      // Stage 2 for Local: Preflight
      const mode = resolveDeploymentMode(state.answers) === 'multi' ? 'multi' : 'single';
      const subArgs = mode === 'multi'
        ? `--connectivity-sub ${state.answers.connectivity_subscription_id} \\\n  --management-sub ${state.answers.management_subscription_id} \\\n  --landingzone-sub ${state.answers.landingzone_subscription_id}`
        : `--subscription ${state.answers.subscription_id}`;
      const configArg = (isBicep && mode === 'multi')
        ? '' // multi-sub Bicep passes values via deploy.sh args; no param file
        : `--config ${paramFolder}/${paramFileName}`;
      const configSuffix = configArg ? ` \\\n  ${configArg}` : '';
      let preflightCmd = isBicep
        ? `./scripts/preflight.sh --iac bicep --mode ${mode} \\\n  ${subArgs}${configSuffix}`
        : `./scripts/preflight.sh --iac terraform --mode ${mode} \\\n  ${subArgs}${configSuffix}`;
      if (!isBicep) {
        const bootstrapSub = mode === 'multi' ? state.answers.management_subscription_id : state.answers.subscription_id;
        preflightCmd = `# Bootstrap Terraform state backend (first time only)\nARM_SUBSCRIPTION_ID=${bootstrapSub} \\\nPREFIX=${state.answers.name_prefix} \\\nLOCATION=${state.answers.location} \\\nREGION_SHORT=${shortRegion(state.answers.location)} \\\n  ./scripts/bootstrap-state.sh\n\n# Validate tooling, auth, and subscription access\n${preflightCmd}`;
      }
      root.appendChild(stage(2, 'Preflight checks', '', (body) => {
        body.appendChild(el('p', {}, isBicep
          ? 'Validates tooling, Azure auth, and subscription access before you deploy.'
          : 'Bootstraps the Terraform state backend (first time only), then validates tooling, auth, and subscription access.',
        ));
        const pre = el('pre', {}, el('code', {}, preflightCmd));
        pre.appendChild(copyButton(preflightCmd));
        body.appendChild(pre);
      }));

      // Stage 3: Preview
      const previewCmds = buildPreviewCommands(state.answers);
      root.appendChild(stage(3, 'Preview changes (dry-run)', '', (body) => {
        body.appendChild(el('p', {}, isBicep
          ? 'Runs what-if to show exactly what Azure resources will be created, modified, or deleted.'
          : 'Saves a Terraform plan file for review. No resources are created yet.',
        ));
        const pre = el('pre', {}, el('code', {}, previewCmds));
        pre.appendChild(copyButton(previewCmds));
        body.appendChild(pre);
      }));

      // Stage 4: Apply
      const applyCmds = buildApplyCommands(state.answers);
      root.appendChild(stage(4, isBicep ? 'Deploy to Azure' : 'Apply reviewed plan', 'wizard-stage-caution', (body) => {
        body.appendChild(el('p', {},
          el('strong', {}, 'Creates real Azure resources. '),
          'Review the preview output above before running this.',
        ));
        const pre = el('pre', {}, el('code', {}, applyCmds));
        pre.appendChild(copyButton(applyCmds));
        body.appendChild(pre);
      }));

      // Stage 5: Verify
      const verifyCmds = buildVerifyCommands(state.answers);
      root.appendChild(stage(5, 'Verify deployment', '', (body) => {
        body.appendChild(el('p', {}, 'Confirms expected resource groups and scenario-specific resources exist.'));
        const pre = el('pre', {}, el('code', {}, verifyCmds));
        pre.appendChild(copyButton(verifyCmds));
        body.appendChild(pre);
      }));
    }

    // MG Stage (separate, visually distinct)
    if (hasMg) {
      root.appendChild(el('h2', {}, 'Management Groups (tenant-scoped, separate deploy)'));
      root.appendChild(el('div', { class: 'verdict' },
        el('strong', {}, 'Runs at tenant root. '),
        'The principal needs ', el('code', {}, 'Management Group Contributor'),
        ' on the Tenant Root Group. This is a separate deployment from the foundation above.',
      ));

      if (isActions) {
        // Actions MG: show the env/variable setup checklist
        const mgWorkflow = isBicep ? 'bicep-mg-apply' : 'terraform-mg-apply';
        const mgCiFile = isBicep
          ? 'infra/bicep/management-groups/scenarios/minimal.bicepparam'
          : 'infra/terraform/management-groups/scenarios/minimal.tfvars';
        root.appendChild(stage('A', 'Configure MG GitHub Actions (OIDC)', '', (body) => {
          body.appendChild(el('p', {}, 'The MG deployment uses a separate service principal with tenant-root permissions:'));
          const checklist = el('ol', { class: 'wizard-steps' });
          checklist.appendChild(el('li', {}, 'Create a second Entra app registration with Management Group Contributor at Tenant Root.'));
          checklist.appendChild(el('li', {},
            'Add federated credentials for the ',
            el('code', {}, 'plan-mg'), ' and ',
            el('code', {}, 'apply-mg'), ' environments.',
          ));
          checklist.appendChild(el('li', {},
            'Create GitHub environments: ',
            el('code', {}, 'plan-mg'), ' (unprotected) and ',
            el('code', {}, 'apply-mg'), ' (Required Reviewers enabled).',
          ));
          checklist.appendChild(el('li', {},
            'Set repository variable ', el('code', {}, 'AZURE_MG_CLIENT_ID'),
            ' (the client ID of the MG service principal).',
          ));
          checklist.appendChild(el('li', {},
            'Update ', el('code', {}, mgCiFile), ' with your MG configuration.',
          ));
          checklist.appendChild(el('li', {},
            'Push and trigger ', el('code', {}, mgWorkflow),
            ' via workflow_dispatch, selecting scenario ', el('code', {}, 'minimal'), '.',
          ));
          body.appendChild(checklist);
        }));
      } else {
        // Local MG: show file + commands
        const mgFile = isBicep ? buildMgBicepParams(state.answers) : buildMgTfvars(state.answers);
        const mgFileName = isBicep ? 'wizard.bicepparam' : 'mg.auto.tfvars';
        const mgPreviewCmds = buildMgPreviewCommands(state.answers);
        const mgApplyCmds = buildMgApplyCommands(state.answers);

        root.appendChild(stage('A', `Save MG ${platformLabel} parameter file`, '', (body) => {
          const pre = el('pre', {}, el('code', {}, mgFile));
          pre.appendChild(copyButton(mgFile));
          body.appendChild(pre);
          body.appendChild(el('a', {
            href: URL.createObjectURL(new Blob([mgFile], { type: 'text/plain' })),
            download: mgFileName,
          }, `Download ${mgFileName}`));
        }));

        root.appendChild(stage('B', 'Preview Management Groups', '', (body) => {
          body.appendChild(el('p', {}, 'Dry-run the tenant-scoped MG deployment.'));
          const pre = el('pre', {}, el('code', {}, mgPreviewCmds));
          pre.appendChild(copyButton(mgPreviewCmds));
          body.appendChild(pre);
        }));

        root.appendChild(stage('C', 'Apply Management Groups', 'wizard-stage-caution', (body) => {
          body.appendChild(el('p', {},
            el('strong', {}, 'Creates MG hierarchy at tenant root. '),
            'Review the preview output first.',
          ));
          const pre = el('pre', {}, el('code', {}, mgApplyCmds));
          pre.appendChild(copyButton(mgApplyCmds));
          body.appendChild(pre);
        }));
      }
    }

    // Next steps
    root.appendChild(el('h3', {}, 'After deployment'));
    const ul = el('ul');
    const nextSteps = [
      ['Wire diagnostic settings to Log Analytics', '/reference/day-2-operations/'],
      [`Architecture diagram for ${scenario}`, `/scenarios/${scenario}/`],
    ];
    if (state.answers.hybrid === 'yes') {
      nextSteps.push(['Configure the on-premises VPN connection', '/reference/vpn-post-deploy/']);
    }
    if (hasMg) {
      nextSteps.push(['Move subscriptions into MG hierarchy', '/governance/management-groups/']);
    }
    nextSteps.push(['Day-2 operations runbook', '/reference/day-2-operations/']);
    nextSteps.forEach(([t, href]) => ul.appendChild(el('li', {}, el('a', { href }, t))));
    root.appendChild(ul);

    // Start over
    const actions = el('div', { class: 'actions' });
    actions.appendChild(el('button', {
      type: 'button', class: 'secondary',
      onclick: () => {
        state.step = 0;
        state.answers = createInitialAnswers();
        state._direction = 1;
        if (typeof sessionStorage !== 'undefined') sessionStorage.removeItem('launchpad-wizard');
        draw();
      },
    }, 'Start over'));
    root.appendChild(actions);
  }

  draw();
}

if (typeof document !== 'undefined') {
  const root = document.getElementById('wizard-root');
  if (root) render(root);
}

// Export for testing (Node.js ESM)
export {
  QUESTIONS,
  createInitialAnswers,
  deriveScenario,
  resolveDeploymentMode,
  resolveMgEnable,
  isStepSkipped,
  shortRegion,
  buildTfvars,
  buildBicepParams,
  buildCommands,
  buildBicepCommands,
  buildPreviewCommands,
  buildApplyCommands,
  buildVerifyCommands,
  buildMgTfvars,
  buildMgBicepParams,
  buildMgPreviewCommands,
  buildMgApplyCommands,
  buildDeploymentReadme,
};
