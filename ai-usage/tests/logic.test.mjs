// logic.test.mjs — zero-dependency test harness for Logic.js (v0.3).
//
// Run: node tests/logic.test.mjs
// RED phase: this file is written BEFORE Logic.js v2 exists (TDD).
//
// The runner strips the `.pragma library` directive (QML-only) and evals the
// source, mirroring how Quickshell loads it. No imports from Logic.js exist
// on disk yet — loading must fail loudly in RED and pass in GREEN.

import { readFileSync } from 'node:fs';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

const results = { pass: 0, fail: 0, failures: [] };

function test(name, fn) {
  try {
    fn();
    results.pass++;
    console.log(`  ok  ${name}`);
  } catch (e) {
    results.fail++;
    results.failures.push({ name, e });
    console.log(`FAIL  ${name}\n      ${e.message}`);
  }
}

import { strict as assert } from 'node:assert';
const { equal, ok, notEqual } = assert;

function fixture(name) {
  return JSON.parse(readFileSync(new URL(`./fixtures/${name}.json`, import.meta.url), 'utf8'));
}

// ---------------------------------------------------------------------------
// Load Logic.js
// ---------------------------------------------------------------------------

function loadLogic() {
  const src = readFileSync(new URL('../Logic.js', import.meta.url), 'utf8')
    .replace('.pragma library', '');
  const exportsList = [
    'PROVIDERS', 'parseMoney', 'formatMoney', 'migrateSettings',
    'parseValidUntilDate', 'daysLeft', 'isExpiringSoon', 'newProviderId',
    'severityOf', 'sectionByKey', 'formatDuration', 'remainingMs',
    'safeText', 'finitePercent', 'finiteInt', 'normalizeProviderForm', 'mergeProviderForm', 'compactValue',
    'isEncryptedSecret', 'encryptedSecretParts', 'keyHintOf', 'keyMask',
    'buildEnvelope', 'envelopeHmacMessage', 'sha256Hex', 'hmacSha256Hex',
    'bytesToB64url', 'b64urlToBytes', 'strBytes',
    'claudePlanLabel', 'needsClaudeRefresh', 'applyClaudeRefresh',
    'parseClaudeUsage', 'parseAnthropicCostReport',
    'moneySeverity', 'validUntilInfo', 'planLine', 'prettySectionKey',
  ];
  const factory = (0, eval)(`(function(){${src}\n; return {${exportsList.join(',')}};})()`);
  for (const name of exportsList)
    if (factory[name] === undefined)
      throw new Error(`Logic.js does not export "${name}"`);
  return factory;
}

let Logic;
try {
  Logic = loadLogic();
  console.log('loaded Logic.js v2 OK\n');
} catch (e) {
  console.log(`LOGIC LOAD FAILED (RED phase expected): ${e.message}\n`);
  console.log(`1..0 # ${e.message}`);
  process.exit(1);
}

const NOW = Date.UTC(2026, 7, 24, 12, 0, 0); // 2026-08-24T12:00:00Z fixed clock

// ---------------------------------------------------------------------------
// Registry shape
// ---------------------------------------------------------------------------

test('registry exposes the 4 v0.3 providers', () => {
  for (const key of ['zai', 'deepseek', 'openrouter', 'kimi'])
    ok(Logic.PROVIDERS[key], `missing provider "${key}"`);
});

test('each provider has identity + transport + parse', () => {
  for (const [key, p] of Object.entries(Logic.PROVIDERS)) {
    equal(typeof p.name, 'string', `${key}.name`);
    ok(p.monogram.length >= 1 && p.monogram.length <= 2, `${key}.monogram 1-2 chars`);
    ok(p.color.startsWith('#'), `${key}.color hex`);
    equal(typeof p.parse, 'function', `${key}.parse`);
    // keyless providers (claude) carry URL data for the curl branch instead
    if (p.keyless) {
      ok(p.usageUrl.startsWith('https://'), `${key}.usageUrl https`);
      continue;
    }
    ok(Array.isArray(p.requests) && p.requests.length >= 1, `${key}.requests`);
    for (const r of p.requests) {
      ok(r.id, `${key}.requests[].id`);
      ok(r.url.startsWith('https://'), `${key}.requests[].url https`);
    }
  }
});

test('keyed provider requests build auth headers from the key', () => {
  for (const [, p] of Object.entries(Logic.PROVIDERS)) {
    if (p.keyless)
      continue;
    const h = p.requests[0].headers('SECRET_KEY');
    const auth = h.Authorization || h['x-api-key'];
    ok(String(auth).includes('SECRET_KEY'), `${p.name} carries the key`);
  }
});

// ---------------------------------------------------------------------------
// z.ai adapter (live fixture — must stay compatible with v0.2 behaviour)
// ---------------------------------------------------------------------------

test('zai: parses live quota fixture', () => {
  const r = Logic.PROVIDERS.zai.parse({ main: fixture('zai') }, NOW);
  ok(r.ok, 'parse ok');
  const e = r.entry;
  equal(e.plan, 'pro');
  equal(e.status, 'ready');
  const s = Logic.sectionByKey(e, 'session');
  equal(s.percent, 54);
  equal(s.severity, 'mid');
  equal(s.resetAt, 1787598456843);
  const w = Logic.sectionByKey(e, 'weekly');
  equal(w.value, '92 / 1000');
  const t = Logic.sectionByKey(e, 'tools');
  equal(t.body.length, 3);
  ok(t.body[0].includes('search-prime'));
  // v2.1: structured data for per-tool gauges (name/usage/limit)
  equal(t.limit, 1000, 'tools.limit is the weekly cap');
  ok(Array.isArray(t.items) && t.items.length === 3, 'tools.items array');
  equal(t.items[0].name, 'search-prime');
  equal(t.items[0].usage, 62);
  equal(t.items[2].name, 'zread');
  equal(t.items[2].usage, 25);
});

test('zai: error wrapper degrades to {ok:false}', () => {
  const r = Logic.PROVIDERS.zai.parse({ main: { code: 500, msg: '404 NOT_FOUND' } }, NOW);
  ok(!r.ok);
  equal(r.error, '404 NOT_FOUND');
});

// ---------------------------------------------------------------------------
// DeepSeek adapter (balance, no window)
// ---------------------------------------------------------------------------

test('deepseek: CNY balance maps to money metric + severity thresholds', () => {
  const r = Logic.PROVIDERS.deepseek.parse({ main: fixture('deepseek_cny') }, NOW);
  ok(r.ok);
  const b = Logic.sectionByKey(r.entry, 'balance');
  ok(b.value.includes('110.00'), `value "${b.value}" contains amount`);
  ok(b.value.includes('CNY'), 'value carries currency');
  equal(b.percent, null, 'balance vendors have no percent');
  // 110 CNY sits in the mid band (7 critical / 35 high / 140 mid)
  equal(b.severity, 'mid');
  const breakdown = Logic.sectionByKey(r.entry, 'breakdown');
  ok(breakdown && breakdown.body.some(l => l.includes('10.00')), 'granted in breakdown');
});

test('deepseek: USD low balance is high severity', () => {
  const r = Logic.PROVIDERS.deepseek.parse({ main: fixture('deepseek_usd') }, NOW);
  const b = Logic.sectionByKey(r.entry, 'balance');
  // 3.50 USD: 1 critical / 5 high / 20 mid
  equal(b.severity, 'high');
});

test('deepseek: !is_available is critical', () => {
  const doc = fixture('deepseek_usd');
  doc.is_available = false;
  const r = Logic.PROVIDERS.deepseek.parse({ main: doc }, NOW);
  const b = Logic.sectionByKey(r.entry, 'balance');
  equal(b.severity, 'critical');
});

// ---------------------------------------------------------------------------
// OpenRouter adapter (credits + key, combined)
// ---------------------------------------------------------------------------

test('openrouter: combines credits+key into balance metric', () => {
  const r = Logic.PROVIDERS.openrouter.parse(
    { credits: fixture('openrouter_credits'), key: fixture('openrouter_key') }, NOW);
  ok(r.ok);
  const b = Logic.sectionByKey(r.entry, 'balance');
  equal(b.value, '$74.50');
  equal(b.percent, 26, 'consumed = 25.5/100 rounded');
  equal(b.severity, 'low');
  const meta = Logic.sectionByKey(r.entry, 'key');
  ok(meta.body.some(l => l.includes('sk-or-main')), 'key label in meta');
});

// ---------------------------------------------------------------------------
// Kimi adapter (tolerant window/weekly)
// ---------------------------------------------------------------------------

test('kimi: window + weekly metrics with RFC3339 resets', () => {
  const r = Logic.PROVIDERS.kimi.parse({ main: fixture('kimi') }, NOW);
  ok(r.ok);
  equal(r.entry.plan, 'kimi-pro');
  const s = Logic.sectionByKey(r.entry, 'session');
  equal(s.percent, 75, 'used 75/100');
  equal(s.severity, 'high');
  equal(s.resetAt, Date.parse('2026-08-24T22:00:00Z'));
  const w = Logic.sectionByKey(r.entry, 'weekly');
  equal(w.percent, 20);
  equal(w.severity, 'low');
});

test('kimi: unknown field layout degrades, never throws', () => {
  const r = Logic.PROVIDERS.kimi.parse({ main: { data: { something: 'else' } } }, NOW);
  ok(r.ok, 'tolerant parse still resolves');
  ok(!Logic.sectionByKey(r.entry, 'session'));
});

// ---------------------------------------------------------------------------
// Settings migration (v0.2 → v0.3)
// ---------------------------------------------------------------------------

test('migration: legacy single apiKey becomes providers[0]', () => {
  const m = Logic.migrateSettings({ apiKey: 'legacy-key', refreshMinutes: 5, showWeekly: true });
  equal(m.providers.length, 1);
  equal(m.providers[0].type, 'zai');
  equal(m.providers[0].apiKey, 'legacy-key');
  equal(m.providers[0].enabled, true);
  equal(m.activeProviderId, m.providers[0].id);
  equal(m.refreshMinutes, 5);
});

test('migration: no legacy key → empty providers', () => {
  const m = Logic.migrateSettings({ refreshMinutes: 10 });
  equal(m.providers.length, 0);
  ok(!m.activeProviderId);
});

test('migration: already v0.3 passes through untouched', () => {
  const current = {
    providers: [{ id: 'zai_1', type: 'zai', apiKey: 'k', label: '', planLabel: '', validUntil: '', enabled: true }],
    activeProviderId: 'zai_1',
    refreshMinutes: 5,
  };
  const m = Logic.migrateSettings(JSON.parse(JSON.stringify(current)));
  equal(m.providers[0].id, 'zai_1');
  equal(m.activeProviderId, 'zai_1');
});

test('migration: dangling activeProviderId reset to first provider', () => {
  const s = {
    providers: [
      { id: 'zai_1', type: 'zai', apiKey: 'k', enabled: true },
      { id: 'deepseek_1', type: 'deepseek', apiKey: 'd', enabled: true },
    ],
    activeProviderId: 'openrouter_9', // dropped/unknown id
  };
  const m = Logic.migrateSettings(JSON.parse(JSON.stringify(s)));
  equal(m.activeProviderId, 'zai_1', 'falls back to first surviving provider');
});

test('migration: dangling activeProviderId with all dropped → empty', () => {
  const s = { providers: [], activeProviderId: 'zai_1' };
  const m = Logic.migrateSettings(JSON.parse(JSON.stringify(s)));
  equal(m.activeProviderId, '');
});

test('migration: providers without keys are dropped (keyless exempt)', () => {
  const s = {
    providers: [
      { id: 'zai_1', type: 'zai', apiKey: '', enabled: true },        // keyed, no key → dropped
      { id: 'claude_1', type: 'claude', apiKey: '', enabled: true },  // keyless → kept
    ],
    activeProviderId: 'zai_1',
  };
  const m = Logic.migrateSettings(JSON.parse(JSON.stringify(s)));
  equal(m.providers.length, 1);
  equal(m.providers[0].id, 'claude_1');
  equal(m.activeProviderId, 'claude_1', 'active moved off the dropped provider');
});

test('migration: refreshMinutes clamped to 1..60', () => {
  equal(Logic.migrateSettings({ refreshMinutes: 0 }).refreshMinutes, 1);
  equal(Logic.migrateSettings({ refreshMinutes: 999 }).refreshMinutes, 60);
  equal(Logic.migrateSettings({ refreshMinutes: 'x' }).refreshMinutes, 5);
});

// ---------------------------------------------------------------------------
// validUntil helpers
// ---------------------------------------------------------------------------

test('parseValidUntilDate accepts YYYY-MM-DD only', () => {
  equal(Logic.parseValidUntilDate('2026-09-15'), Date.UTC(2026, 8, 15));
  equal(Logic.parseValidUntilDate('15.09.2026'), null);
  equal(Logic.parseValidUntilDate(''), null);
  equal(Logic.parseValidUntilDate('2026-13-99'), null);
});

test('daysLeft: 22 days ahead; clamped at 0 when past', () => {
  equal(Logic.daysLeft('2026-09-15', Date.UTC(2026, 7, 24)), 22);
  equal(Logic.daysLeft('2026-08-01', Date.UTC(2026, 7, 24)), 0);
});

test('isExpiringSoon: true at ≤7 days', () => {
  equal(Logic.isExpiringSoon(7), true);
  equal(Logic.isExpiringSoon(8), false);
});

test('newProviderId avoids collisions', () => {
  equal(Logic.newProviderId('zai', ['zai_1']), 'zai_2');
  equal(Logic.newProviderId('kimi', ['kimi_1', 'kimi_2']), 'kimi_3');
  equal(Logic.newProviderId('openrouter', []), 'openrouter_1');
});

// ---------------------------------------------------------------------------
// Provider form normalization (add/edit dialog v0.4)
// ---------------------------------------------------------------------------

test('normalizeProviderForm trims every field', () => {
  const f = Logic.normalizeProviderForm({
    apiKey: '  sk-123  ', label: ' Work ', planLabel: ' pro ',
    validUntil: ' 2026-09-15 '
  });
  equal(f.apiKey, 'sk-123');
  equal(f.label, 'Work');
  equal(f.planLabel, 'pro');
  equal(f.validUntil, '2026-09-15');
});

test('normalizeProviderForm drops invalid validUntil', () => {
  const f = Logic.normalizeProviderForm({ apiKey: 'k', validUntil: '15.09.2026' });
  equal(f.validUntil, '');
});

test('normalizeProviderForm survives missing/garbage fields', () => {
  const f = Logic.normalizeProviderForm({ apiKey: undefined, label: null, planLabel: 42, validUntil: {} });
  equal(f.apiKey, '');
  equal(f.label, '');
  equal(f.planLabel, '');
  equal(f.validUntil, '');
});

test('normalizeProviderForm: empty key stays empty', () => {
  const f = Logic.normalizeProviderForm({ apiKey: '   ' });
  equal(f.apiKey, '');
});

test('mergeProviderForm: untouched field keeps the stored key', () => {
  const m = Logic.mergeProviderForm(
    { apiKey: 'sk-old', label: 'old' },
    { type: 'zai', apiKey: '', label: 'new', planLabel: 'pro', validUntil: '' });
  equal(m.apiKey, 'sk-old', 'empty form key must not erase');
  equal(m.label, 'new');
});

test('mergeProviderForm: new key overwrites', () => {
  const m = Logic.mergeProviderForm(
    { apiKey: 'sk-old' },
    { type: 'zai', apiKey: 'sk-new', label: '', planLabel: '', validUntil: '' });
  equal(m.apiKey, 'sk-new');
});

// ---------------------------------------------------------------------------
// Compact bar value (multi-provider capsule v0.4)
// ---------------------------------------------------------------------------

test('compactValue: window vendors render the remaining percent', () => {
  const zai = Logic.PROVIDERS.zai.parse({ main: fixture('zai') }, NOW);
  equal(Logic.compactValue(zai.entry), '46%');
  const kimi = Logic.PROVIDERS.kimi.parse({ main: fixture('kimi') }, NOW);
  equal(Logic.compactValue(kimi.entry), '25%');
});

test('compactValue: money vendors render the balance string', () => {
  const ds = Logic.PROVIDERS.deepseek.parse({ main: fixture('deepseek_cny') }, NOW);
  equal(Logic.compactValue(ds.entry), '110.00 CNY');
  const or_ = Logic.PROVIDERS.openrouter.parse(
    { credits: fixture('openrouter_credits'), key: fixture('openrouter_key') }, NOW);
  equal(Logic.compactValue(or_.entry), '$74.50');
});

test('compactValue: tolerates missing entry/sections', () => {
  equal(Logic.compactValue(null), '');
  equal(Logic.compactValue({ sections: null }), '');
  equal(Logic.compactValue({ sections: [] }), '');
  equal(Logic.compactValue({ sections: [{ type: 'metric', key: 'balance', value: '', percent: null }] }), '');
});

// ---------------------------------------------------------------------------
// API-key envelopes (at-rest encryption, v0.5)
// ---------------------------------------------------------------------------

test('isEncryptedSecret: envelope prefix + shape', () => {
  ok(Logic.isEncryptedSecret('enc:v1:QkxPQg:ZODI0Y2Q:abcd'));
  ok(Logic.isEncryptedSecret('enc:v1:QkxPQg:ZODI0Y2Q')); // hint optional
  ok(!Logic.isEncryptedSecret('sk-6901234567890'));
  ok(!Logic.isEncryptedSecret(''));
  ok(!Logic.isEncryptedSecret(null));
  ok(!Logic.isEncryptedSecret('enc:v1:'));          // no blob/hmac
  ok(!Logic.isEncryptedSecret('enc:v2:AAA:BBB'));   // unknown version
});

test('encryptedSecretParts: full, hint-less, malformed', () => {
  const full = Logic.encryptedSecretParts('enc:v1:QkxPQg:ZODI0Y2Q:abcd');
  equal(full.version, 'v1');
  equal(full.blob, 'QkxPQg');
  equal(full.hmac, 'ZODI0Y2Q');
  equal(full.hint, 'abcd');
  const bare = Logic.encryptedSecretParts('enc:v1:QkxPQg:ZODI0Y2Q');
  equal(bare.hint, '');
  equal(Logic.encryptedSecretParts('garbage'), null);
  equal(Logic.encryptedSecretParts('enc:v1:onlyone'), null);
});

test('keyHintOf: sanitized last 4', () => {
  equal(Logic.keyHintOf('sk-1234567890abcd'), 'abcd');
  equal(Logic.keyHintOf('abc'), 'abc');
  equal(Logic.keyHintOf('k:89'), 'k89');            // ':' dropped, rest kept
  equal(Logic.keyHintOf('::::'), '');
  equal(Logic.keyHintOf(''), '');
});

test('keyMask: tail preserved for plaintext AND envelopes', () => {
  equal(Logic.keyMask('sk-1234567890abcd'), '•••abcd');
  equal(Logic.keyMask('enc:v1:QkxPQg:ZODI0Y2Q:6f2k'), '•••6f2k');
  equal(Logic.keyMask('enc:v1:QkxPQg:ZODI0Y2Q'), '••••');
  equal(Logic.keyMask('abc'), '••••');
  equal(Logic.keyMask(''), '••••');
  equal(Logic.keyMask(null), '••••');
});

test('buildEnvelope / envelopeHmacMessage round-trip the format', () => {
  const env = Logic.buildEnvelope('QkxPQg', 'ZODI0Y2Q', 'abcd');
  equal(env, 'enc:v1:QkxPQg:ZODI0Y2Q:abcd');
  const parts = Logic.encryptedSecretParts(env);
  equal(parts.blob, 'QkxPQg');
  equal(parts.hmac, 'ZODI0Y2Q');
  equal(parts.hint, 'abcd');
  equal(Logic.buildEnvelope('QkxPQg', 'ZODI0Y2Q', ''), 'enc:v1:QkxPQg:ZODI0Y2Q');
  equal(Logic.envelopeHmacMessage('QkxPQg', 'abcd'), 'ai-usage-v1|QkxPQg|abcd');
  equal(Logic.envelopeHmacMessage('QkxPQg', ''), 'ai-usage-v1|QkxPQg|');
});

test('sha256Hex: FIPS 180 vectors', () => {
  equal(Logic.sha256Hex(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
  equal(Logic.sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  equal(Logic.sha256Hex('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1');
});

test('hmacSha256Hex: RFC 4231 test cases 1-2', () => {
  // Case 1: key = 0x0b x20, data = 'Hi There'
  const k1 = '\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b';
  equal(Logic.hmacSha256Hex(k1, 'Hi There'),
        'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7');
  // Case 2: key = 'Jefe'
  equal(Logic.hmacSha256Hex('Jefe', 'what do ya want for nothing?'),
        '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843');
});

test('b64url: vectors and round-trip', () => {
  equal(Logic.bytesToB64url(Logic.strBytes('abc')), 'YWJj');
  equal(Logic.bytesToB64url(Logic.strBytes('ab')), 'YWI');
  equal(Logic.bytesToB64url(Logic.strBytes('a')), 'YQ');
  const all = [];
  for (let i = 0; i < 256; i++) all.push(i);
  const rt = Logic.b64urlToBytes(Logic.bytesToB64url(all));
  equal(rt.length, 256);
  ok(rt.every((b, i) => b === i));
  equal(Logic.bytesToB64url(Logic.b64urlToBytes('QkxPQg')), 'QkxPQg');
});

// ---------------------------------------------------------------------------
// Money helpers
// ---------------------------------------------------------------------------

test('parseMoney: strings and numbers, garbage rejected', () => {
  equal(Logic.parseMoney('110.00'), 110);
  equal(Logic.parseMoney(3.5), 3.5);
  equal(Logic.parseMoney('nope'), null);
});

test('parseMoney: comma decimal separator; mixed separators rejected', () => {
  equal(Logic.parseMoney('1,5'), 1.5, 'comma acts as decimal point');
  equal(Logic.parseMoney('1,100.25'), null, 'comma+dot mix → NaN → null (documented)');
});

test('formatMoney: USD symbol prefix, CNY suffix', () => {
  equal(Logic.formatMoney(74.5, 'USD'), '$74.50');
  equal(Logic.formatMoney(110, 'CNY'), '110.00 CNY');
});

test('prettySectionKey: claude per-model keys become human labels', () => {
  equal(Logic.prettySectionKey('weekly_sonnet'), 'Sonnet weekly');
  equal(Logic.prettySectionKey('limit_fable'), 'Fable limit');
  equal(Logic.prettySectionKey('weekly_opus_4_6'), 'Opus 4 6 weekly');
  equal(Logic.prettySectionKey('session'), 'Session');
  equal(Logic.prettySectionKey('balance'), 'Balance');
  equal(Logic.prettySectionKey(''), '');
});

// ---------------------------------------------------------------------------
// View helpers (deduplicated from Panel/DesktopWidget, v0.5.1)
// ---------------------------------------------------------------------------

test('moneySeverity: USD thresholds, non-USD scaled ×7', () => {
  equal(Logic.moneySeverity(0.5, 'USD'), 'critical');
  equal(Logic.moneySeverity(1, 'USD'), 'critical');
  equal(Logic.moneySeverity(5, 'USD'), 'high');
  equal(Logic.moneySeverity(20, 'USD'), 'mid');
  equal(Logic.moneySeverity(21, 'USD'), 'low');
  equal(Logic.moneySeverity(7, 'CNY'), 'critical');
  equal(Logic.moneySeverity(35, 'CNY'), 'high');
  equal(Logic.moneySeverity(140, 'CNY'), 'mid');
  equal(Logic.moneySeverity(141, 'CNY'), 'low');
  equal(Logic.moneySeverity(null, 'USD'), 'low');
  equal(Logic.moneySeverity('x', 'CNY'), 'low');
});

test('validUntilInfo: epoch+days+soon bundle', () => {
  const now = Date.UTC(2026, 7, 25); // 2026-08-25
  const info = Logic.validUntilInfo('2026-09-15', now);
  equal(info.epochMs, Date.UTC(2026, 8, 15));
  equal(info.days, 21);
  equal(info.soon, false);
  equal(Logic.validUntilInfo('2026-08-27', now).soon, true, 'within 7 days');
  equal(Logic.validUntilInfo('', now), null);
  equal(Logic.validUntilInfo(null, now), null);
  equal(Logic.validUntilInfo('garbage', now), null);
});

test('planLine: provider label wins over entry plan', () => {
  equal(Logic.planLine({ planLabel: 'Max 5x' }, { plan: 'lite' }), 'Max 5x');
  equal(Logic.planLine({ planLabel: '' }, { plan: 'lite' }), 'lite');
  equal(Logic.planLine({}, null), '');
  equal(Logic.planLine(null, { plan: 'pro' }), 'pro');
  equal(Logic.planLine(null, null), '');
});

// ---------------------------------------------------------------------------
// Claude (OAuth subscription usage, contract from ai-usagebar research)
// ---------------------------------------------------------------------------

test('claudePlanLabel: subscription + rateLimitTier suffix', () => {
  equal(Logic.claudePlanLabel('max', 'claude_max_5x'), 'Max 5x');
  equal(Logic.claudePlanLabel('max', 'claude_max_20x'), 'Max 20x');
  equal(Logic.claudePlanLabel('pro', ''), 'Pro');
  equal(Logic.claudePlanLabel('team', null), 'Team');
  equal(Logic.claudePlanLabel('', 'claude_max_5x'), 'Unknown');
  equal(Logic.claudePlanLabel(undefined, undefined), 'Unknown');
});

test('needsClaudeRefresh: 300s buffer', () => {
  const now = 1_000_000;
  equal(Logic.needsClaudeRefresh({ expiresAt: now + 299_999 }, now), true);
  equal(Logic.needsClaudeRefresh({ expiresAt: now + 300_000 }, now), false);
  equal(Logic.needsClaudeRefresh({ expiresAt: now + 3_600_000 }, now), false);
  equal(Logic.needsClaudeRefresh({}, now), true);
  equal(Logic.needsClaudeRefresh(null, now), true);
});

test('applyClaudeRefresh: rotation, expiry, purity', () => {
  const base = { accessToken: 'a1', refreshToken: 'r1', expiresAt: 1,
                 subscriptionType: 'max', rateLimitTier: 'claude_max_5x' };
  const out = Logic.applyClaudeRefresh(base, { access_token: 'a2', refresh_token: 'r2', expires_in: 3600 }, 1000);
  equal(out.accessToken, 'a2');
  equal(out.refreshToken, 'r2');
  equal(out.expiresAt, 1000 + 3_600_000);
  equal(out.subscriptionType, 'max');
  equal(base.accessToken, 'a1', 'input creds not mutated');

  const keep = Logic.applyClaudeRefresh(base, { access_token: 'a2', expires_in: 7200.0 }, 2000);
  equal(keep.refreshToken, 'r1', 'no rotation keeps old refresh token');
  equal(keep.expiresAt, 2000 + 7_200_000, 'integral float expires_in ok');

  const bad = Logic.applyClaudeRefresh(base, { access_token: 'a2' }, 3000);
  equal(bad.expiresAt, 1, 'garbage expires_in keeps old expiry');
});

const CLAUDE_BODY = {
  five_hour: { utilization: 42.4, resets_at: 1787000000 },
  seven_day: { utilization: 71, resets_at: '2026-08-28T00:00:00Z' },
  seven_day_sonnet: { utilization: 15 },
  limits: [{ kind: 'weekly', percent: 35, resets_at: 1787000000,
             scope: { model: { display_name: 'Fable' } } }],
  extra_usage: { is_enabled: true, monthly_limit: 100, used_credits: 23.4, currency: 'USD' }
};

test('parseClaudeUsage: five_hour session + seven_day weekly, rounded+clamped', () => {
  const r = Logic.parseClaudeUsage(CLAUDE_BODY, 5000);
  ok(r.ok);
  equal(r.entry.id, 'claude');
  equal(r.entry.plan, '');
  const session = Logic.sectionByKey(r.entry, 'session');
  equal(session.value, '42%');
  equal(session.percent, 42);
  equal(session.resetAt, 1_787_000_000_000, 'epoch seconds scaled to ms');
  const weekly = Logic.sectionByKey(r.entry, 'weekly');
  equal(weekly.value, '71%');
  equal(weekly.resetAt, Date.parse('2026-08-28T00:00:00Z'), 'ISO resets_at parsed');
});

test('parseClaudeUsage: clamps utilization outside 0..100', () => {
  const r = Logic.parseClaudeUsage({ five_hour: { utilization: 105 }, seven_day: { utilization: -3 } }, 1);
  ok(r.ok);
  equal(Logic.sectionByKey(r.entry, 'session').percent, 100);
  equal(Logic.sectionByKey(r.entry, 'weekly').percent, 0);
});

test('parseClaudeUsage: per-model weekly + extra usage balance', () => {
  const r = Logic.parseClaudeUsage(CLAUDE_BODY, 5000);
  const model = r.entry.sections.find((s) => s.type === 'metric' && s.key !== 'session'
    && s.key !== 'weekly' && s.key !== 'balance');
  ok(model, 'has a per-model metric');
  equal(model.value, '15%');
  ok(model.detail.indexOf('Sonnet') >= 0, 'sonnet window labelled');
  const balance = Logic.sectionByKey(r.entry, 'balance');
  equal(balance.value, '$76.60', 'monthly_limit - used_credits remaining');
});

test('parseClaudeUsage: garbage body rejected', () => {
  equal(Logic.parseClaudeUsage({}, 1).ok, false);
  equal(Logic.parseClaudeUsage(null, 1).ok, false);
  equal(Logic.parseClaudeUsage('nope', 1).ok, false);
});

test('parseClaudeUsage: compactValue shows remaining session %', () => {
  const r = Logic.parseClaudeUsage(CLAUDE_BODY, 5000);
  equal(Logic.compactValue(r.entry), '58%');
});

// ---------------------------------------------------------------------------
// Anthropic Admin API (cost_report, documented)
// ---------------------------------------------------------------------------

test('parseAnthropicCostReport: month-to-date spend from data[].amount', () => {
  const r = Logic.parseAnthropicCostReport({ data: [{ amount: { value: 23.45, currency: 'USD' } }] }, 1000);
  ok(r.ok);
  equal(r.entry.id, 'anthropic');
  const balance = Logic.sectionByKey(r.entry, 'balance');
  equal(balance.value, '$23.45');
  equal(balance.percent, null);
});

test('parseAnthropicCostReport: tolerant amount locations', () => {
  ok(Logic.parseAnthropicCostReport({ amount: { value: 8, currency: 'USD' } }, 1).ok);
  ok(Logic.parseAnthropicCostReport({ total: { value: 8 } }, 1).ok);
  equal(Logic.parseAnthropicCostReport({ data: [] }, 1).ok, false);
  equal(Logic.parseAnthropicCostReport({}, 1).ok, false);
  equal(Logic.parseAnthropicCostReport(null, 1).ok, false);
});

test('PROVIDERS registry: claude keyless-oauth, anthropic api-key', () => {
  ok(Logic.PROVIDERS.claude);
  equal(Logic.PROVIDERS.claude.name, 'Claude');
  equal(Logic.PROVIDERS.claude.monogram, 'C');
  equal(Logic.PROVIDERS.claude.keyless, true);
  ok(Logic.PROVIDERS.claude.usageUrl.indexOf('api.anthropic.com/api/oauth/usage') > 0);
  ok(Logic.PROVIDERS.claude.refreshUrl.indexOf('platform.claude.com/v1/oauth/token') > 0);
  equal(typeof Logic.PROVIDERS.claude.parse, 'function');

  ok(Logic.PROVIDERS.anthropic);
  equal(Logic.PROVIDERS.anthropic.name, 'Anthropic');
  equal(Logic.PROVIDERS.anthropic.monogram, 'A');
  ok(Array.isArray(Logic.PROVIDERS.anthropic.requests));
  const h = Logic.PROVIDERS.anthropic.requests[0].headers('sk-ant-admin01');
  equal(h['x-api-key'], 'sk-ant-admin01');
  equal(h['anthropic-version'], '2023-06-01');
});

// ---------------------------------------------------------------------------
// Preserved v0.2 utilities
// ---------------------------------------------------------------------------

test('severityOf bands 50/75/90', () => {
  equal(Logic.severityOf(10), 'low');
  equal(Logic.severityOf(50), 'mid');
  equal(Logic.severityOf(75), 'high');
  equal(Logic.severityOf(90), 'critical');
  equal(Logic.severityOf('x'), 'low');
});

test('formatDuration and safeText survive the port', () => {
  equal(Logic.formatDuration(4980000, 'h', 'm'), '1h 23m');
  ok(!Logic.safeText('<img>', 50).includes('<'));
});

test('safeText: truncates to maxLength and strips control/bidi chars', () => {
  const noisy = 'a\u0000b\u000bc\u007fd\u202ee\u2066f';
  equal(Logic.safeText(noisy, 400), 'abcdef');
  equal(Logic.safeText('x'.repeat(50), 10), 'xxxxxxxxxx');
});

test('finiteInt: rounds finite, garbage → 0', () => {
  equal(Logic.finiteInt(42.6), 43);
  equal(Logic.finiteInt('7'), 7);
  equal(Logic.finiteInt('x'), 0);
  equal(Logic.finiteInt(null), 0);
});

test('kimi: reset_at epoch-seconds scaled, epoch-ms passed through', () => {
  const seconds = Logic.PROVIDERS.kimi.parse({ main: { data: { window: { used: 4, limit: 10, reset_at: 1787000000 } } } }, 1);
  const sessionS = Logic.sectionByKey(seconds.entry, 'session');
  equal(sessionS.resetAt, 1_787_000_000_000, '<1e12 → ×1000');

  const millis = Logic.PROVIDERS.kimi.parse({ main: { data: { window: { used: 4, limit: 10, reset_at: 1787000000123 } } } }, 1);
  const sessionM = Logic.sectionByKey(millis.entry, 'session');
  equal(sessionM.resetAt, 1_787_000_000_123, '≥1e12 → kept as ms');
});

// ---------------------------------------------------------------------------

console.log(`\n${results.pass} passed, ${results.fail} failed`);
process.exit(results.fail === 0 ? 0 : 1);
