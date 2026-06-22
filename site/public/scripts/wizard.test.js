// Unit tests for wizard.js (configuration generator) logic.
// Run with: node --test site/public/scripts/wizard.test.js
//
// Uses Node's built-in test runner (no dependencies required).

import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

// Provide a minimal DOM shim so the module can load without a browser.
globalThis.document = { getElementById: () => null, createElement: () => ({}) };
globalThis.URL.createObjectURL = () => '';

import {
  QUESTIONS,
  createInitialAnswers,
  deriveScenario,
  resolveDeploymentMode,
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
} from './wizard.js';

const platformAnswers = {
  intent: 'platform',
  egress: 'none',
  hybrid: 'no',
  connectivity_subscription_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  management_subscription_id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  landingzone_subscription_id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
  tenant_id: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
  location: 'eastus',
  name_prefix: 'test',
  mg_optional: ['local', 'decommissioned', 'sandboxes'],
  mg_policies: 'starter',
};

describe('createInitialAnswers', () => {
  test('returns fresh defaults without retaining prior answers', () => {
    const first = createInitialAnswers();
    first.iac_platform = 'bicep';
    first.mg_optional.push('identity');

    const second = createInitialAnswers();
    assert.equal(second.iac_platform, 'terraform');
    assert.deepEqual(second.mg_optional, ['local', 'decommissioned', 'sandboxes']);
  });
});

// ---------------------------------------------------------------------------
// deriveScenario
// ---------------------------------------------------------------------------
describe('deriveScenario', () => {
  test('returns baseline when no firewall or VPN', () => {
    assert.equal(deriveScenario({ egress: 'none', hybrid: 'no' }), 'baseline');
  });

  test('returns firewall when egress is firewall', () => {
    assert.equal(deriveScenario({ egress: 'firewall', hybrid: 'no' }), 'firewall');
  });

  test('returns vpn when hybrid is yes', () => {
    assert.equal(deriveScenario({ egress: 'none', hybrid: 'yes' }), 'vpn');
  });

  test('returns full when both firewall and VPN', () => {
    assert.equal(deriveScenario({ egress: 'firewall', hybrid: 'yes' }), 'full');
  });
});

// ---------------------------------------------------------------------------
// resolveDeploymentMode
// ---------------------------------------------------------------------------
describe('resolveDeploymentMode', () => {
  test('evaluate intent forces single', () => {
    assert.equal(resolveDeploymentMode({ intent: 'evaluate', deployment_mode: 'multi' }), 'single');
  });

  test('platform intent forces multi', () => {
    assert.equal(resolveDeploymentMode({ intent: 'platform', deployment_mode: 'single' }), 'multi');
  });

  test('production intent uses explicit deployment_mode', () => {
    assert.equal(resolveDeploymentMode({ intent: 'production', deployment_mode: 'multi' }), 'multi');
    assert.equal(resolveDeploymentMode({ intent: 'production', deployment_mode: 'single' }), 'single');
  });
});

// ---------------------------------------------------------------------------
// isStepSkipped
// ---------------------------------------------------------------------------
describe('isStepSkipped', () => {
  test('deployment_mode is skipped for evaluate intent', () => {
    assert.equal(isStepSkipped('deployment_mode', { intent: 'evaluate' }), true);
  });

  test('deployment_mode is skipped for platform intent', () => {
    assert.equal(isStepSkipped('deployment_mode', { intent: 'platform' }), true);
  });

  test('deployment_mode shown for production intent', () => {
    assert.equal(isStepSkipped('deployment_mode', { intent: 'production' }), false);
  });

  test('subscription_id shown for single-sub mode', () => {
    assert.equal(isStepSkipped('subscription_id', { intent: 'evaluate' }), false);
  });

  test('subscription_id hidden for multi-sub mode', () => {
    assert.equal(isStepSkipped('subscription_id', { intent: 'platform' }), true);
  });

  test('multi-sub fields shown for platform intent', () => {
    assert.equal(isStepSkipped('connectivity_subscription_id', { intent: 'platform' }), false);
    assert.equal(isStepSkipped('management_subscription_id', { intent: 'platform' }), false);
    assert.equal(isStepSkipped('landingzone_subscription_id', { intent: 'platform' }), false);
  });

  test('mg fields hidden when mg_enable is not yes', () => {
    assert.equal(isStepSkipped('tenant_id', { mg_enable: 'no', intent: 'production' }), true);
    assert.equal(isStepSkipped('mg_optional', { mg_enable: 'no', intent: 'production' }), true);
  });

  test('advanced fields hidden when advanced_mode is not yes', () => {
    assert.equal(isStepSkipped('log_retention_days', { advanced_mode: 'no', intent: 'production' }), true);
    assert.equal(isStepSkipped('budget_amount', { advanced_mode: 'no', intent: 'production' }), true);
  });

  test('evaluate skips egress and hybrid (forces baseline)', () => {
    assert.equal(isStepSkipped('egress', { intent: 'evaluate' }), true);
    assert.equal(isStepSkipped('hybrid', { intent: 'evaluate' }), true);
  });

  test('evaluate skips mg_enable', () => {
    assert.equal(isStepSkipped('mg_enable', { intent: 'evaluate' }), true);
  });

  test('platform defaults mg_enable to yes', () => {
    assert.equal(isStepSkipped('mg_enable', { intent: 'platform' }), true);
  });
});

// ---------------------------------------------------------------------------
// shortRegion
// ---------------------------------------------------------------------------
describe('shortRegion', () => {
  test('maps known regions', () => {
    assert.equal(shortRegion('westcentralus'), 'wcus');
    assert.equal(shortRegion('eastus'), 'eus');
    assert.equal(shortRegion('northeurope'), 'neu');
  });

  test('truncates unknown regions', () => {
    assert.equal(shortRegion('brazilsouth'), 'brazi');
  });
});

// ---------------------------------------------------------------------------
// buildTfvars
// ---------------------------------------------------------------------------
describe('buildTfvars', () => {
  const baseAnswers = {
    intent: 'production',
    deployment_mode: 'single',
    egress: 'none',
    hybrid: 'no',
    subscription_id: '11111111-1111-1111-1111-111111111111',
    location: 'eastus',
    name_prefix: 'test',
  };

  test('generates single-sub baseline tfvars', () => {
    const out = buildTfvars(baseAnswers);
    assert.match(out, /scenario\s+=\s+"baseline"/);
    assert.match(out, /subscription_id\s+=\s+"11111111/);
    assert.ok(!out.includes('deployment_mode'));
  });

  test('generates multi-sub tfvars for platform intent', () => {
    const multi = {
      ...baseAnswers,
      intent: 'platform',
      connectivity_subscription_id: 'aaaa-aaaa',
      management_subscription_id: 'bbbb-bbbb',
      landingzone_subscription_id: 'cccc-cccc',
    };
    const out = buildTfvars(multi);
    assert.match(out, /deployment_mode\s+=\s+"multi"/);
    assert.match(out, /connectivity_subscription_id/);
  });

  test('multi-sub fallback subscription_id uses management, not connectivity', () => {
    const multi = {
      ...baseAnswers,
      intent: 'platform',
      connectivity_subscription_id: 'conn-sub-id',
      management_subscription_id: 'mgmt-sub-id',
      landingzone_subscription_id: 'lz-sub-id',
    };
    const out = buildTfvars(multi);
    // The top-level fallback line should be mgmt, not connectivity
    assert.match(out, /^subscription_id = "mgmt-sub-id"/m);
  });
});

// ---------------------------------------------------------------------------
// buildBicepParams
// ---------------------------------------------------------------------------
describe('buildBicepParams', () => {
  test('generates valid bicep param file', () => {
    const out = buildBicepParams({
      intent: 'evaluate',
      deployment_mode: 'single',
      egress: 'none',
      hybrid: 'no',
      location: 'westcentralus',
      name_prefix: 'demo',
    });
    assert.match(out, /using '\.\.\/main\.bicep'/);
    assert.match(out, /param scenario = 'baseline'/);
    assert.match(out, /param namePrefix = 'demo'/);
  });
});

// ---------------------------------------------------------------------------
// buildCommands (Terraform)
// ---------------------------------------------------------------------------
describe('buildCommands', () => {
  test('uses -out flag for plan and applies saved plan', () => {
    const out = buildCommands({
      intent: 'production',
      deployment_mode: 'single',
      egress: 'none',
      hybrid: 'no',
      subscription_id: '11111111-1111-1111-1111-111111111111',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.match(out, /deploy\.sh plan --iac terraform/);
    assert.match(out, /deploy\.sh apply --iac terraform/);
    assert.match(out, /--plan-file \.launchpad\/plans\/foundation\.baseline\.single\.tfplan/);
    assert.match(out, /verify\.sh --mode single/);
  });
});

// ---------------------------------------------------------------------------
// buildBicepCommands
// ---------------------------------------------------------------------------
describe('buildBicepCommands', () => {
  test('single-sub previews, applies, and verifies through the shared scripts', () => {
    const out = buildBicepCommands({
      intent: 'production',
      deployment_mode: 'single',
      egress: 'none',
      hybrid: 'no',
      subscription_id: '11111111-1111-1111-1111-111111111111',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.match(out, /deploy\.sh plan --iac bicep --mode single/);
    assert.match(out, /deploy\.sh apply --iac bicep --mode single/);
    assert.match(out, /verify\.sh --mode single/);
  });

  test('multi-sub previews, applies, and verifies through the shared scripts', () => {
    const out = buildBicepCommands({
      intent: 'platform',
      deployment_mode: 'multi',
      egress: 'firewall',
      hybrid: 'no',
      connectivity_subscription_id: 'aaaa',
      management_subscription_id: 'bbbb',
      landingzone_subscription_id: 'cccc',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.match(out, /deploy\.sh plan --iac bicep --mode multi/);
    assert.match(out, /deploy\.sh apply --iac bicep --mode multi/);
    assert.match(out, /verify\.sh --mode multi/);
    assert.match(out, /--scenario firewall/);
  });
});

describe('management-group parameter generation', () => {
  test('Terraform uses the management subscription and places all platform subscriptions', () => {
    const out = buildMgTfvars(platformAnswers);
    assert.match(out, /subscription_id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"/);
    assert.match(out, /"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" = "connectivity"/);
    assert.match(out, /"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"\s+= "management"/);
    assert.match(out, /"cccccccc-cccc-cccc-cccc-cccccccccccc"\s+= "corp"/);
    assert.ok(!out.includes('undefined'));
  });

  test('Bicep places all platform subscriptions', () => {
    const out = buildMgBicepParams(platformAnswers);
    assert.match(out, /'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa': 'connectivity'/);
    assert.match(out, /'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb': 'management'/);
    assert.match(out, /'cccccccc-cccc-cccc-cccc-cccccccccccc': 'corp'/);
    assert.ok(!out.includes('undefined'));
  });
});

// ---------------------------------------------------------------------------
// QUESTIONS array structure
// ---------------------------------------------------------------------------
describe('QUESTIONS', () => {
  test('intent is the first question', () => {
    assert.equal(QUESTIONS[0].id, 'intent');
  });

  test('iac_platform is the second question', () => {
    assert.equal(QUESTIONS[1].id, 'iac_platform');
  });

  test('all questions have id, label, and type', () => {
    for (const q of QUESTIONS) {
      assert.ok(q.id, `missing id`);
      assert.ok(q.label, `missing label for ${q.id}`);
      assert.ok(q.type, `missing type for ${q.id}`);
    }
  });

  test('VPN copy points to post-deploy configuration instead of a nonexistent next step', () => {
    const hybrid = QUESTIONS.find((q) => q.id === 'hybrid');
    assert.match(hybrid.impact, /post-deploy VPN connection guide/);
    assert.doesNotMatch(hybrid.impact, /next step/);
  });

  test('deploy_method is the third question', () => {
    assert.equal(QUESTIONS[2].id, 'deploy_method');
  });
});

// ---------------------------------------------------------------------------
// buildPreviewCommands / buildApplyCommands / buildVerifyCommands
// ---------------------------------------------------------------------------
describe('buildPreviewCommands', () => {
  test('generates terraform single-sub preview command', () => {
    const out = buildPreviewCommands({
      iac_platform: 'terraform',
      intent: 'evaluate',
      egress: 'none',
      hybrid: 'no',
      subscription_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.match(out, /deploy\.sh plan/);
    assert.match(out, /--iac terraform/);
    assert.match(out, /--mode single/);
    assert.match(out, /--scenario baseline/);
  });

  test('generates bicep multi-sub preview command', () => {
    const out = buildPreviewCommands({
      iac_platform: 'bicep',
      intent: 'platform',
      egress: 'firewall',
      hybrid: 'no',
      connectivity_subscription_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      management_subscription_id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      landingzone_subscription_id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      location: 'westcentralus',
      name_prefix: 'plat',
    });
    assert.match(out, /deploy\.sh plan/);
    assert.match(out, /--iac bicep/);
    assert.match(out, /--mode multi/);
    assert.match(out, /--scenario firewall/);
  });
});

describe('buildApplyCommands', () => {
  test('generates terraform single-sub apply command', () => {
    const out = buildApplyCommands({
      iac_platform: 'terraform',
      intent: 'evaluate',
      egress: 'none',
      hybrid: 'no',
      subscription_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.match(out, /deploy\.sh apply/);
    assert.match(out, /--plan-file/);
  });
});

describe('buildVerifyCommands', () => {
  test('generates verify command with scenario and mode', () => {
    const out = buildVerifyCommands({
      iac_platform: 'terraform',
      intent: 'evaluate',
      egress: 'none',
      hybrid: 'no',
      subscription_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.match(out, /verify\.sh/);
    assert.match(out, /--scenario baseline/);
    assert.match(out, /--mode single/);
  });
});

describe('buildMgPreviewCommands', () => {
  test('generates terraform MG preview', () => {
    const out = buildMgPreviewCommands({
      iac_platform: 'terraform',
      tenant_id: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.match(out, /terraform plan/);
    assert.match(out, /mg\.auto\.tfvars/);
    assert.match(out, /backend\.hcl/);
    assert.doesNotMatch(out, /<from-bootstrap>/);
  });

  test('generates bicep MG preview (what-if)', () => {
    const out = buildMgPreviewCommands({
      iac_platform: 'bicep',
      tenant_id: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.match(out, /what-if/);
    assert.match(out, /tenant/);
  });
});

describe('buildMgApplyCommands', () => {
  test('generates terraform MG apply', () => {
    const out = buildMgApplyCommands({ iac_platform: 'terraform' });
    assert.match(out, /terraform apply mg\.tfplan/);
  });

  test('generates bicep MG apply', () => {
    const out = buildMgApplyCommands({
      iac_platform: 'bicep',
      location: 'eastus',
    });
    assert.match(out, /az deployment tenant create/);
  });
});

// ---------------------------------------------------------------------------
// buildDeploymentReadme
// ---------------------------------------------------------------------------
describe('buildDeploymentReadme', () => {
  test('local flow includes preflight with --config arg', () => {
    const out = buildDeploymentReadme({
      deploy_method: 'local',
      iac_platform: 'terraform',
      intent: 'evaluate',
      egress: 'none',
      hybrid: 'no',
      subscription_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.match(out, /preflight\.sh/);
    assert.match(out, /--config/);
    assert.match(out, /bootstrap-state\.sh/);
    assert.match(out, /REGION_SHORT=eus/);
  });

  test('actions flow omits local commands and shows OIDC setup', () => {
    const out = buildDeploymentReadme({
      deploy_method: 'actions',
      iac_platform: 'terraform',
      intent: 'evaluate',
      egress: 'none',
      hybrid: 'no',
      subscription_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.doesNotMatch(out, /preflight\.sh/);
    assert.doesNotMatch(out, /deploy\.sh plan/);
    assert.match(out, /GitHub Actions Setup/);
    assert.match(out, /plan.*prod/s);
  });

  test('bicep actions flow references plan and apply envs', () => {
    const out = buildDeploymentReadme({
      deploy_method: 'actions',
      iac_platform: 'bicep',
      intent: 'evaluate',
      egress: 'none',
      hybrid: 'no',
      subscription_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.match(out, /`plan`.*`apply`/s);
    assert.doesNotMatch(out, /`prod`/);
  });
});
