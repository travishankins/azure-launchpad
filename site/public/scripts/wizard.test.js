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
  deriveScenario,
  resolveDeploymentMode,
  isStepSkipped,
  shortRegion,
  buildTfvars,
  buildBicepParams,
  buildCommands,
  buildBicepCommands,
} from './wizard.js';

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
    assert.match(out, /-out=wizard\.tfplan/);
    assert.match(out, /terraform apply wizard\.tfplan/);
    assert.ok(!out.includes('terraform apply -var-file'));
  });
});

// ---------------------------------------------------------------------------
// buildBicepCommands
// ---------------------------------------------------------------------------
describe('buildBicepCommands', () => {
  test('single-sub includes what-if preview step', () => {
    const out = buildBicepCommands({
      intent: 'production',
      deployment_mode: 'single',
      egress: 'none',
      hybrid: 'no',
      subscription_id: '11111111-1111-1111-1111-111111111111',
      location: 'eastus',
      name_prefix: 'test',
    });
    assert.match(out, /what-if/);
    assert.match(out, /deployment sub create/);
  });

  test('multi-sub uses deploy-multi-sub.sh wrapper', () => {
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
    assert.match(out, /deploy-multi-sub\.sh/);
    assert.match(out, /--scenario firewall/);
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
});
