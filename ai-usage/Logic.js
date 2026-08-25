// Logic.js v2 — multi-provider data layer of the AI Usage plugin.
//
// Ported from akitaonrails/ai-usagebar (MIT): the vendor registry pattern and
// the defensive parsing rules of kde-plasmoid/package/contents/code/
// plasmoid-logic.mjs (safeText / finitePercent / severity bands), extended
// with native z.ai / DeepSeek / OpenRouter / Kimi adapters.
//
// QML V4 engine rules (from the source project):
//   - no ES2019 optional catch binding (`catch {`)
//   - no Unicode property escapes (`\p{...}`) — silently false in V4
//
// Provider registry contract:
//   PROVIDERS[type] = {
//     name, monogram (1-2 chars), color (#hex),
//     requests: [{ id, url, headers(key) }],
//     parse(responses: { [requestId]: parsedJson }, nowMs)
//       -> { ok: true, entry } | { ok: false, error }
//   }
//
// Entry contract (ai-usagebar-shaped, same as v0.2):
//   { id, label, plan, status: 'ready'|'empty'|'error', error, fetchedAt,
//     sections: [
//       { type:'metric', key, value, percent|null, detail, resetAt(ms), severity },
//       { type:'block',  key, body: [lines] } ] }

.pragma library

// ---------------------------------------------------------------------------
// Shared utilities
// ---------------------------------------------------------------------------

function severityOf(percent) {
  var p = finitePercent(percent);
  if (p === null)
    return 'low';
  return p >= 90 ? 'critical' : p >= 75 ? 'high' : p >= 50 ? 'mid' : 'low';
}

function safeText(value, maxLength) {
  var max = maxLength || 400;
  var s = String(value === null || value === undefined ? '' : value);
  s = s.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f\u202a-\u202e\u2066-\u2069]/g, '');
  s = s.replace(/</g, '‹').replace(/>/g, '›');
  return s.length > max ? s.substring(0, max) : s;
}

function finitePercent(value) {
  var n = Number(value);
  return isFinite(n) ? Math.max(0, Math.min(100, n)) : null;
}

function finiteInt(value) {
  var n = Number(value);
  return isFinite(n) ? Math.round(n) : 0;
}

function formatDuration(ms, hUnit, mUnit) {
  var total = Math.floor(ms / 1000);
  if (total < 0)
    total = 0;
  var h = Math.floor(total / 3600);
  var m = Math.floor((total % 3600) / 60);
  if (h > 0)
    return h + hUnit + ' ' + (m < 10 ? '0' : '') + m + mUnit;
  if (m > 0)
    return m + mUnit;
  return '<1' + mUnit;
}

function remainingMs(resetAt, nowMs) {
  var d = finiteInt(resetAt) - nowMs;
  return d > 0 ? d : 0;
}

function sectionByKey(entry, key) {
  if (!entry || !entry.sections)
    return null;
  for (var i = 0; i < entry.sections.length; i++) {
    if (entry.sections[i].key === key)
      return entry.sections[i];
  }
  return null;
}

function metric(key, value, percent, detail, resetAt, severity) {
  return {
    type: 'metric',
    key: key,
    value: value,
    percent: percent,
    detail: detail || '',
    resetAt: resetAt || 0,
    severity: severity
  };
}

function blockSection(key, body) {
  return { type: 'block', key: key, body: body };
}

// ---------------------------------------------------------------------------
// Money helpers
// ---------------------------------------------------------------------------

function parseMoney(value) {
  if (typeof value === 'number')
    return isFinite(value) ? value : null;
  var n = Number(String(value === null || value === undefined ? '' : value).replace(/,/g, '.'));
  return isFinite(n) ? n : null;
}

function formatMoney(n, currency) {
  var fixed = (Math.round(n * 100) / 100).toFixed(2);
  if (currency === 'USD')
    return '$' + fixed;
  if (currency && currency !== '')
    return fixed + ' ' + currency;
  return fixed;
}

// Remaining-money severity: USD {1,5,20}, non-USD scaled ×7 (CNY {7,35,140}).
function moneySeverity(remaining, currency) {
  var r = typeof remaining === 'number' && isFinite(remaining) ? remaining : null;
  if (r === null)
    return 'low';
  var k = currency === 'USD' ? 1 : 7;
  if (r <= 1 * k)
    return 'critical';
  if (r <= 5 * k)
    return 'high';
  if (r <= 20 * k)
    return 'mid';
  return 'low';
}

// ---------------------------------------------------------------------------
// View helpers (shared by Panel / DesktopWidget; formatting stays in QML)
// ---------------------------------------------------------------------------

// validUntil → {epochMs, days, soon} bundle, or null when unset/unparseable.
function validUntilInfo(validUntil, nowMs) {
  if (!validUntil)
    return null;
  var days = daysLeft(validUntil, nowMs);
  if (days === null)
    return null;
  return {
    epochMs: parseValidUntilDate(validUntil),
    days: days,
    soon: isExpiringSoon(days)
  };
}

// Manual provider label overrides the plan detected from the API response.
function planLine(provider, entry) {
  if (provider && provider.planLabel && provider.planLabel !== '')
    return provider.planLabel;
  if (entry && entry.plan && entry.plan !== '')
    return entry.plan;
  return '';
}

// Human label for a metric key: known keys stay translated in the views;
// unknown compound keys (claude per-model: weekly_sonnet, limit_fable)
// become 'Sonnet weekly', 'Fable limit' — the moved window word stays
// lowercase, model words are capitalized; single words get capitalized.
function prettySectionKey(key) {
  var s = String(key || '');
  if (s === '')
    return '';
  var m = /^(weekly|limit)_(.+)$/.exec(s);
  if (m)
    return m[2].split('_').map(cap).filter(nonEmpty).join(' ') + ' ' + m[1];
  return s.split('_').map(cap).filter(nonEmpty).join(' ');
}

function cap(w) {
  return w.charAt(0).toUpperCase() + w.slice(1);
}

function nonEmpty(w) {
  return w !== '';
}

// ---------------------------------------------------------------------------
// validUntil helpers (manual field — APIs do not expose plan end dates)
// ---------------------------------------------------------------------------

// Strict YYYY-MM-DD → epoch ms, or null. Range-checked by round-trip.
function parseValidUntilDate(s) {
  if (typeof s !== 'string')
    return null;
  var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m)
    return null;
  var y = Number(m[1]), mo = Number(m[2]), d = Number(m[3]);
  if (mo < 1 || mo > 12 || d < 1 || d > 31)
    return null;
  var t = Date.UTC(y, mo - 1, d);
  var dt = new Date(t);
  if (dt.getUTCMonth() !== mo - 1 || dt.getUTCDate() !== d)
    return null;
  return t;
}

// Whole days until the date; 0 when already past; null when not set/invalid.
function daysLeft(validUntil, nowMs) {
  var t = parseValidUntilDate(validUntil);
  if (t === null)
    return null;
  var d = Math.floor((t - nowMs) / 86400000);
  return d > 0 ? d : 0;
}

function isExpiringSoon(days) {
  return days !== null && days !== undefined && days >= 0 && days <= 7;
}

function newProviderId(type, existingIds) {
  var n = 1;
  var ids = existingIds || [];
  while (ids.indexOf(type + '_' + n) >= 0)
    n++;
  return type + '_' + n;
}

// Trim the add/edit form fields; an unparsable validUntil is dropped.
function normalizeProviderForm(fields) {
  var f = fields || {};
  function clean(v) {
    return typeof v === 'string' ? v.trim() : '';
  }
  var validUntil = clean(f.validUntil);
  return {
    apiKey: clean(f.apiKey),
    label: clean(f.label),
    planLabel: clean(f.planLabel),
    validUntil: parseValidUntilDate(validUntil) === null ? '' : validUntil
  };
}

// Edit-mode merge: an empty form key keeps the stored one (an untouched
// field never erases the key); a non-empty key overwrites it.
function mergeProviderForm(provider, form) {
  return {
    type: form.type,
    apiKey: form.apiKey === '' ? provider.apiKey : form.apiKey,
    label: form.label,
    planLabel: form.planLabel,
    validUntil: form.validUntil
  };
}

// One-glance value for the bar capsule: remaining "%" for window vendors
// (session first, then weekly), the money string for balance vendors,
// '' when nothing usable.
function compactValue(entry) {
  if (!entry || !entry.sections)
    return '';
  var balance = null;
  for (var i = 0; i < entry.sections.length; i++) {
    var s = entry.sections[i];
    if (s.type !== 'metric')
      continue;
    if (s.key === 'session' || s.key === 'weekly') {
      if (s.percent !== null && s.percent !== undefined)
        return (100 - s.percent) + '%';
    } else if (s.key === 'balance') {
      balance = s;
    }
  }
  return balance && balance.value !== '' ? balance.value : '';
}

// ---------------------------------------------------------------------------
// API-key envelopes (at-rest encryption, v0.5)
//
// Stored format:  enc:v1:<b64url(ciphertext)>:<hmac-hex>:<hint>
//   blob — openssl enc -aes-256-cbc -pbkdf2 output, base64url
//   hmac — HMAC-SHA256(passphrase, 'ai-usage-v1|'+blob): tamper detection
//   hint — last 4 plaintext chars (GitHub-style last-4) so the user can see
//          WHICH key is stored without decrypting it
// The plaintext key exists only in a fetch-local variable in Main.qml.
// ---------------------------------------------------------------------------

var ENV_PREFIX = 'enc:v1:';

function isEncryptedSecret(s) {
  return typeof s === 'string' && encryptedSecretParts(s) !== null;
}

function encryptedSecretParts(s) {
  if (typeof s !== 'string' || s.indexOf(ENV_PREFIX) !== 0)
    return null;
  var parts = s.substring(ENV_PREFIX.length).split(':');
  if (parts.length < 2 || parts.length > 3)
    return null;
  for (var i = 0; i < parts.length; i++)
    if (parts[i] === '')
      return null;
  return { version: 'v1', blob: parts[0], hmac: parts[1],
           hint: parts.length === 3 ? parts[2] : '' };
}

// Last 4 chars, restricted to key-safe characters; shorter is fine.
function keyHintOf(plain) {
  if (typeof plain !== 'string' || plain.length === 0)
    return '';
  var tail = plain.substring(plain.length - 4);
  var out = '';
  for (var i = 0; i < tail.length; i++)
    if (/[A-Za-z0-9_-]/.test(tail.charAt(i)))
      out += tail.charAt(i);
  return out;
}

// Public mask: envelope → its stored hint, plaintext → last 4.
function keyMask(s) {
  if (typeof s !== 'string' || s.length === 0)
    return '••••';
  if (isEncryptedSecret(s)) {
    var parts = encryptedSecretParts(s);
    return parts.hint !== '' ? '•••' + parts.hint : '••••';
  }
  if (s.length < 4)
    return '••••';
  return '•••' + s.substring(s.length - 4);
}

function buildEnvelope(blob, hmac, hint) {
  return ENV_PREFIX + blob + ':' + hmac + (hint ? ':' + hint : '');
}

// The exact string the envelope HMAC covers (domain-separated): the blob
// AND the displayed hint — everything but the version tag.
function envelopeHmacMessage(blob, hint) {
  return 'ai-usage-v1|' + blob + '|' + (hint || '');
}

// --- sha256 + hmac (pure JS: verified against FIPS/RFC vectors in tests) ---

var B64URL_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

// UTF-8 encode; our envelope inputs are ASCII by construction.
function strBytes(s) {
  var out = [];
  for (var i = 0; i < s.length; i++) {
    var c = s.charCodeAt(i);
    if (c < 0x80)
      out.push(c);
    else if (c < 0x800)
      out.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
    else
      out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
  }
  return out;
}

function bytesToB64url(bytes) {
  var out = '';
  for (var i = 0; i < bytes.length; i += 3) {
    var b0 = bytes[i] & 0xff;
    var b1 = i + 1 < bytes.length ? bytes[i + 1] & 0xff : 0;
    var b2 = i + 2 < bytes.length ? bytes[i + 2] & 0xff : 0;
    out += B64URL_CHARS.charAt(b0 >> 2);
    out += B64URL_CHARS.charAt(((b0 & 3) << 4) | (b1 >> 4));
    if (i + 1 < bytes.length)
      out += B64URL_CHARS.charAt(((b1 & 15) << 2) | (b2 >> 6));
    if (i + 2 < bytes.length)
      out += B64URL_CHARS.charAt(b2 & 63);
  }
  return out;
}

function b64urlToBytes(s) {
  var out = [];
  for (var i = 0; i < s.length; i += 4) {
    var n = s.length - i;
    var c0 = B64URL_CHARS.indexOf(s.charAt(i));
    var c1 = B64URL_CHARS.indexOf(s.charAt(i + 1));
    out.push((c0 << 2) | (c1 >> 4));
    if (n >= 3) {
      var c2 = B64URL_CHARS.indexOf(s.charAt(i + 2));
      out.push(((c1 & 15) << 4) | (c2 >> 2));
      if (n >= 4) {
        var c3 = B64URL_CHARS.indexOf(s.charAt(i + 3));
        out.push(((c2 & 3) << 6) | c3);
      }
    }
  }
  return out;
}

var SHA256_K = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
];

function sha256Bytes(input) {
  var msg = input.slice();
  var bitLen = msg.length * 8;
  msg.push(0x80);
  while (msg.length % 64 !== 56)
    msg.push(0);
  msg.push(0, 0, 0, 0,
           (bitLen >>> 24) & 0xff, (bitLen >>> 16) & 0xff,
           (bitLen >>> 8) & 0xff, bitLen & 0xff);

  var h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
           0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  var w = new Array(64);

  function rotr(x, n) { return (x >>> n) | (x << (32 - n)); }

  for (var block = 0; block < msg.length; block += 64) {
    for (var t = 0; t < 16; t++)
      w[t] = (msg[block + t * 4] << 24) | (msg[block + t * 4 + 1] << 16)
             | (msg[block + t * 4 + 2] << 8) | msg[block + t * 4 + 3];
    for (var t2 = 16; t2 < 64; t2++) {
      var s0 = rotr(w[t2 - 15], 7) ^ rotr(w[t2 - 15], 18) ^ (w[t2 - 15] >>> 3);
      var s1 = rotr(w[t2 - 2], 17) ^ rotr(w[t2 - 2], 19) ^ (w[t2 - 2] >>> 10);
      w[t2] = (w[t2 - 16] + s0 + w[t2 - 7] + s1) | 0;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      var S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      var ch = (e & f) ^ (~e & g);
      var t1 = (hh + S1 + ch + SHA256_K[i] + w[i]) | 0;
      var S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      var maj = (a & b) ^ (a & c) ^ (b & c);
      var t2 = (S0 + maj) | 0;
      hh = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
    }
    h[0] = (h[0] + a) | 0; h[1] = (h[1] + b) | 0; h[2] = (h[2] + c) | 0; h[3] = (h[3] + d) | 0;
    h[4] = (h[4] + e) | 0; h[5] = (h[5] + f) | 0; h[6] = (h[6] + g) | 0; h[7] = (h[7] + hh) | 0;
  }

  var out = [];
  for (var j = 0; j < 8; j++)
    out.push((h[j] >>> 24) & 0xff, (h[j] >>> 16) & 0xff, (h[j] >>> 8) & 0xff, h[j] & 0xff);
  return out;
}

function bytesToHex(bytes) {
  var s = '';
  for (var i = 0; i < bytes.length; i++) {
    var h = (bytes[i] & 0xff).toString(16);
    s += h.length === 1 ? '0' + h : h;
  }
  return s;
}

function sha256Hex(s) {
  return bytesToHex(sha256Bytes(strBytes(s)));
}

function hmacSha256Bytes(key, message) {
  var keyBytes = strBytes(key);
  var block = 64;
  if (keyBytes.length > block)
    keyBytes = sha256Bytes(keyBytes);
  while (keyBytes.length < block)
    keyBytes.push(0);
  var oKey = [], iKey = [];
  for (var i = 0; i < block; i++) {
    oKey.push(keyBytes[i] ^ 0x5c);
    iKey.push(keyBytes[i] ^ 0x36);
  }
  var inner = sha256Bytes(iKey.concat(strBytes(message)));
  return sha256Bytes(oKey.concat(inner));
}

function hmacSha256Hex(key, message) {
  return bytesToHex(hmacSha256Bytes(key, message));
}

// ---------------------------------------------------------------------------
// Settings migration (v0.2 single key → v0.3 provider list)
// ---------------------------------------------------------------------------

function defaultProviderFields(p) {
  return {
    id: String(p.id || ''),
    type: String(p.type || 'zai'),
    apiKey: String(p.apiKey || ''),
    label: String(p.label || ''),
    planLabel: String(p.planLabel || ''),
    validUntil: String(p.validUntil || ''),
    enabled: p.enabled !== false
  };
}

function migrateSettings(settings) {
  var s = settings || {};
  var out = {
    providers: [],
    activeProviderId: '',
    refreshMinutes: 5,
    showBackground: s.showBackground !== undefined ? s.showBackground : true
  };
  var m = Number(s.refreshMinutes);
  // clamp into 1..60 (out-of-range snaps to the border, garbage → default)
  out.refreshMinutes = isFinite(m) ? Math.min(60, Math.max(1, Math.round(m))) : 5;

  if (Array.isArray(s.providers)) {
    for (var i = 0; i < s.providers.length; i++) {
      var p = defaultProviderFields(s.providers[i] || {});
      var keyless = !!PROVIDERS[p.type] && !!PROVIDERS[p.type].keyless;
      if (p.id !== '' && (p.apiKey !== '' || keyless))
        out.providers.push(p);
    }
    out.activeProviderId = String(s.activeProviderId || '');
    var alive = false;
    for (var j = 0; j < out.providers.length; j++) {
      if (out.providers[j].id === out.activeProviderId)
        alive = true;
    }
    if (!alive)
      out.activeProviderId = out.providers.length > 0 ? out.providers[0].id : '';
    return out;
  }

  // Legacy v0.2: single apiKey
  if (s.apiKey) {
    var legacy = defaultProviderFields({ id: 'zai_1', type: 'zai', apiKey: s.apiKey });
    out.providers.push(legacy);
    out.activeProviderId = legacy.id;
  }
  return out;
}

// ---------------------------------------------------------------------------
// z.ai adapter
// ---------------------------------------------------------------------------

function findLimit(limits, type) {
  if (!limits)
    return null;
  for (var i = 0; i < limits.length; i++) {
    if (limits[i] && String(limits[i].type || '') === type)
      return limits[i];
  }
  return null;
}

function parseZai(responses, nowMs) {
  var doc = responses.main;
  if (!doc || typeof doc !== 'object')
    return { ok: false, error: 'empty response' };
  var data = doc.data;
  if (!data || typeof data !== 'object') {
    var apiMsg = doc.msg || doc.message || doc.error;
    return apiMsg ? { ok: false, error: safeText(String(apiMsg), 200) } : { ok: false, error: 'unexpected response shape' };
  }
  var limits = Array.isArray(data.limits) ? data.limits : [];
  var session = findLimit(limits, 'TOKENS_LIMIT');
  var weekly = findLimit(limits, 'TIME_LIMIT');
  var sections = [];

  if (session) {
    var sPct = finitePercent(session.percentage);
    sections.push(metric('session', sPct === null ? '' : String(sPct) + '%', sPct, '',
                         finiteInt(session.nextResetTime), severityOf(sPct)));
  }
  if (weekly) {
    var wPct = finitePercent(weekly.percentage);
    var used = weekly.currentValue !== undefined ? finiteInt(weekly.currentValue) : null;
    var cap = weekly.usage !== undefined ? finiteInt(weekly.usage) : null;
    var value = '';
    if (used !== null && cap !== null && cap > 0)
      value = used + ' / ' + cap;
    else if (used !== null)
      value = String(used);
    sections.push(metric('weekly', value, wPct,
                         weekly.remaining !== undefined ? String(finiteInt(weekly.remaining)) : '',
                         finiteInt(weekly.nextResetTime), severityOf(wPct)));
    var details = weekly.usageDetails;
    if (Array.isArray(details) && details.length > 0) {
      var body = [];
      var items = [];
      for (var d = 0; d < details.length && d < 32; d++) {
        var row = details[d];
        if (row) {
          var name = safeText(row.modelCode, 60);
          var usage = finiteInt(row.usage);
          body.push(name + ' · ' + usage);
          items.push({ name: name, usage: usage });
        }
      }
      if (body.length > 0)
        // items/limit: structured per-tool data for ratio gauges (v2.1 UI)
        sections.push({ type: 'block', key: 'tools', body: body, items: items,
                        limit: cap !== null && cap > 0 ? cap : 0 });
    }
  }
  return {
    ok: true,
    entry: {
      id: 'zai',
      label: 'z.ai',
      plan: safeText(data.level, 40) || '',
      status: sections.length > 0 ? 'ready' : 'empty',
      error: '',
      fetchedAt: nowMs,
      sections: sections
    }
  };
}

// ---------------------------------------------------------------------------
// DeepSeek adapter (balance only — no window/percent; thresholds ×7 for CNY)
// ---------------------------------------------------------------------------

function parseDeepseek(responses, nowMs) {
  var doc = responses.main;
  if (!doc || typeof doc !== 'object')
    return { ok: false, error: 'empty response' };
  var infos = Array.isArray(doc.balance_infos) ? doc.balance_infos : [];
  if (infos.length === 0 || !infos[0])
    return { ok: false, error: 'no balance info' };
  var info = infos[0];
  var currency = String(info.currency || '');
  var total = parseMoney(info.total_balance);
  if (total === null)
    return { ok: false, error: 'unparseable balance' };

  var severity = 'low';
  if (doc.is_available === false)
    severity = 'critical';
  else
    severity = moneySeverity(total, currency);

  var sections = [metric('balance', formatMoney(total, currency), null, '', 0, severity)];
  var granted = parseMoney(info.granted_balance);
  var topped = parseMoney(info.topped_up_balance);
  if (granted !== null || topped !== null) {
    var body = [];
    if (granted !== null)
      body.push('granted ' + formatMoney(granted, currency));
    if (topped !== null)
      body.push('topped up ' + formatMoney(topped, currency));
    sections.push(blockSection('breakdown', body));
  }
  return {
    ok: true,
    entry: {
      id: 'deepseek',
      label: 'DeepSeek',
      plan: '',
      status: doc.is_available === false ? 'error' : 'ready',
      error: doc.is_available === false ? 'account unavailable' : '',
      fetchedAt: nowMs,
      sections: sections
    }
  };
}

// ---------------------------------------------------------------------------
// OpenRouter adapter (credits + key, two requests combined)
// ---------------------------------------------------------------------------

function parseOpenrouter(responses, nowMs) {
  var cr = responses.credits && responses.credits.data ? responses.credits.data : null;
  var ky = responses.key && responses.key.data ? responses.key.data : null;
  if (!cr)
    return { ok: false, error: 'credits unavailable' };
  var total = parseMoney(cr.total_credits);
  var used = parseMoney(cr.total_usage);
  if (total === null)
    return { ok: false, error: 'unparseable credits' };
  if (used === null)
    used = 0;

  var balance = total - used;
  var consumedPct = total > 0 ? Math.round((used / total) * 100) : null;
  var severity = balance < 0 ? 'critical' : severityOf(consumedPct === null ? 0 : consumedPct);

  var sections = [metric('balance', formatMoney(balance, 'USD'), consumedPct,
                         'of ' + formatMoney(total, 'USD'), 0, severity)];
  var body = [];
  if (ky) {
    if (ky.label)
      body.push(safeText(ky.label, 60));
    if (ky.usage !== undefined && ky.usage !== null)
      body.push('usage ' + formatMoney(parseMoney(ky.usage) || 0, 'USD'));
    if (ky.is_free_tier !== undefined)
      body.push(ky.is_free_tier === true ? 'free tier' : 'paid');
    if (ky.rate_limit && ky.rate_limit.requests !== undefined)
      body.push('rate ' + finiteInt(ky.rate_limit.requests) + '/'
                + safeText(ky.rate_limit.interval || '', 12));
  }
  if (body.length > 0)
    sections.push(blockSection('key', body));

  return {
    ok: true,
    entry: {
      id: 'openrouter',
      label: 'OpenRouter',
      plan: ky && ky.is_free_tier === true ? 'free' : '',
      status: 'ready',
      error: '',
      fetchedAt: nowMs,
      sections: sections
    }
  };
}

// ---------------------------------------------------------------------------
// Kimi adapter (undocumented; hunt fields tolerantly, never throw)
// ---------------------------------------------------------------------------

function kimiFirstObject(d, names) {
  for (var i = 0; i < names.length; i++) {
    var v = d[names[i]];
    if (v && typeof v === 'object' && !Array.isArray(v))
      return v;
  }
  return null;
}

function kimiReadWindow(d, names, flatPrefixes) {
  var obj = kimiFirstObject(d, names);
  var src = obj || d;
  var pick = function (fieldNames) {
    for (var i = 0; i < fieldNames.length; i++) {
      if (src[fieldNames[i]] !== undefined && src[fieldNames[i]] !== null)
        return src[fieldNames[i]];
    }
    return undefined;
  };
  var limit = parseMoney(pick(['limit', 'quota', 'total']));
  var used = parseMoney(pick(['used', 'currentValue', 'usage']));
  var remaining = parseMoney(pick(['remaining', 'left']));
  var resetRaw = pick(['reset_at', 'resetAt', 'reset_time', 'resetTime', 'nextResetTime']);
  var pct = finitePercent(pick(['percentage', 'percent']));

  var resetAt = 0;
  if (typeof resetRaw === 'number')
    resetAt = resetRaw < 1e12 ? Math.round(resetRaw * 1000) : Math.round(resetRaw);
  else if (typeof resetRaw === 'string') {
    var t = Date.parse(resetRaw);
    resetAt = isFinite(t) ? Math.round(t) : 0;
  }
  if (limit !== null && used !== null && limit > 0)
    pct = Math.max(0, Math.min(100, Math.round((used / limit) * 100)));
  var detail = '';
  if (used !== null && limit !== null && limit > 0)
    detail = finiteInt(used) + ' / ' + finiteInt(limit);
  else if (remaining !== null)
    detail = '−' + finiteInt(remaining);
  return { limit: limit, used: used, percent: pct, resetAt: resetAt, detail: detail };
}

function parseKimi(responses, nowMs) {
  var doc = responses.main;
  if (!doc || typeof doc !== 'object')
    return { ok: false, error: 'empty response' };
  var d = doc.data && typeof doc.data === 'object' ? doc.data : doc;

  var plan = safeText(d.plan !== undefined ? d.plan : d.level, 40) || '';
  var win = kimiReadWindow(d, ['window', 'five_hour_window', 'session_window', 'fiveHourWindow', 'session'],
                           ['window', 'session']);
  var week = kimiReadWindow(d, ['weekly', 'weekly_window', 'week'], ['weekly']);

  var sections = [];
  if (win.percent !== null)
    sections.push(metric('session', String(win.percent) + '%', win.percent, win.detail,
                         win.resetAt, severityOf(win.percent)));
  if (week.percent !== null)
    sections.push(metric('weekly', String(week.percent) + '%', week.percent, week.detail,
                         week.resetAt, severityOf(week.percent)));

  return {
    ok: true,
    entry: {
      id: 'kimi',
      label: 'Kimi',
      plan: plan,
      status: sections.length > 0 ? 'ready' : 'empty',
      error: '',
      fetchedAt: nowMs,
      sections: sections
    }
  };
}

// ---------------------------------------------------------------------------
// Claude adapter (OAuth subscription usage — the same endpoint the `claude`
// CLI uses; contract cross-checked against ai-usagebar research)
// ---------------------------------------------------------------------------

var CLAUDE_REFRESH_BUFFER_MS = 300000;

function claudePlanLabel(subscriptionType, rateLimitTier) {
  var sub = safeText(subscriptionType, 40);
  if (sub === '')
    return 'Unknown';
  sub = sub.charAt(0).toUpperCase() + sub.substring(1);
  var tier = safeText(rateLimitTier, 60);
  if (tier.indexOf('20x') >= 0)
    return sub + ' 20x';
  if (tier.indexOf('5x') >= 0)
    return sub + ' 5x';
  return sub;
}

function needsClaudeRefresh(creds, nowMs) {
  if (!creds)
    return true;
  var left = Number(creds.expiresAt) - Number(nowMs);
  return !(isFinite(left) && left >= CLAUDE_REFRESH_BUFFER_MS);
}

// Pure: returns the NEXT creds object, never mutates the input. The server
// may rotate the refresh token — a missing one keeps the old (trusted-device
// flow has no refresh token at all).
function applyClaudeRefresh(creds, resp, nowMs) {
  var next = {
    accessToken: creds.accessToken,
    refreshToken: creds.refreshToken || '',
    expiresAt: creds.expiresAt || 0,
    subscriptionType: creds.subscriptionType || '',
    rateLimitTier: creds.rateLimitTier || ''
  };
  if (!resp)
    return next;
  var at = safeText(resp.access_token, 8192);
  if (at !== '')
    next.accessToken = at;
  var rt = safeText(resp.refresh_token, 8192);
  if (rt !== '')
    next.refreshToken = rt;
  var secs = Number(resp.expires_in);
  if (isFinite(secs) && secs >= 0)
    next.expiresAt = Math.round(Number(nowMs) + secs * 1000);
  return next;
}

function claudeResetAt(v) {
  if (typeof v === 'number') {
    if (!isFinite(v) || v <= 0)
      return 0;
    return v < 1e12 ? Math.round(v * 1000) : Math.round(v);
  }
  if (typeof v === 'string') {
    var t = Date.parse(v);
    return isFinite(t) ? Math.round(t) : 0;
  }
  return 0;
}

function claudePercent(v) {
  var n = Number(v);
  if (!isFinite(n))
    return null;
  n = Math.round(n);
  return n < 0 ? 0 : n > 100 ? 100 : n;
}

function claudeApiError(doc) {
  if (!doc || typeof doc !== 'object')
    return '';
  if (doc.error_description)
    return safeText(doc.error_description, 200);
  if (doc.error && typeof doc.error === 'object' && doc.error.message)
    return safeText(doc.error.message, 200);
  if (typeof doc.error === 'string')
    return safeText(doc.error, 200);
  return '';
}

// doc = parsed body of GET /api/oauth/usage. Percent semantics match our other
// window vendors (percent = USED), so compactValue shows remaining %.
function parseClaudeUsage(doc, nowMs) {
  if (!doc || typeof doc !== 'object')
    return { ok: false, error: 'empty response' };
  var apiMsg = claudeApiError(doc);
  if (apiMsg !== '')
    return { ok: false, error: apiMsg };
  var sections = [];
  var w = doc.five_hour;
  var p = w ? claudePercent(w.utilization) : null;
  if (p !== null)
    sections.push(metric('session', p + '%', p, '', claudeResetAt(w.resets_at), severityOf(p)));
  w = doc.seven_day;
  p = w ? claudePercent(w.utilization) : null;
  if (p !== null)
    sections.push(metric('weekly', p + '%', p, '', claudeResetAt(w.resets_at), severityOf(p)));
  // Per-model weekly windows: seven_day_sonnet, seven_day_opus, …
  for (var key in doc) {
    if (doc.hasOwnProperty(key) && key.indexOf('seven_day_') === 0 && doc[key]
        && typeof doc[key] === 'object') {
      var mp = claudePercent(doc[key].utilization);
      if (mp !== null) {
        var model = key.substring('seven_day_'.length);
        var label = model.charAt(0).toUpperCase() + model.substring(1);
        sections.push(metric('weekly_' + model, mp + '%', mp, label + ' weekly',
                             claudeResetAt(doc[key].resets_at), severityOf(mp)));
      }
    }
  }
  // Named limits (e.g. Fable weekly) carry a model scope.
  if (Array.isArray(doc.limits)) {
    for (var i = 0; i < doc.limits.length && i < 16; i++) {
      var lim = doc.limits[i];
      if (!lim)
        continue;
      var lp = claudePercent(lim.percent);
      var name = lim.scope && lim.scope.model && lim.scope.model.display_name
        ? safeText(lim.scope.model.display_name, 40) : '';
      if (lp !== null && name !== '') {
        var slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
        sections.push(metric('limit_' + slug.substring(0, 24), lp + '%', lp, name,
                             claudeResetAt(lim.resets_at), severityOf(lp)));
      }
    }
  }
  var extra = doc.extra_usage;
  if (extra && extra.is_enabled) {
    var limit = parseMoney(extra.monthly_limit);
    var used = parseMoney(extra.used_credits);
    if (limit !== null) {
      var cur = String(extra.currency || 'USD');
      var remaining = Math.max(0, limit - (used === null ? 0 : used));
      sections.push(metric('balance', formatMoney(remaining, cur), null,
                           formatMoney(used === null ? 0 : used, cur) + ' / ' + formatMoney(limit, cur),
                           0, moneySeverity(remaining, cur)));
    }
  }
  if (sections.length === 0)
    return { ok: false, error: 'unexpected response shape' };
  return {
    ok: true,
    entry: {
      id: 'claude',
      label: 'Claude',
      plan: '',
      status: 'ready',
      error: '',
      fetchedAt: nowMs,
      sections: sections
    }
  };
}

// ---------------------------------------------------------------------------
// Anthropic Admin API adapter (documented /v1/organizations/cost_report —
// month-to-date spend)
// ---------------------------------------------------------------------------

function parseAnthropicCostReport(doc, nowMs) {
  var candidates = [];
  if (doc && Array.isArray(doc.data) && doc.data[0])
    candidates.push(doc.data[0].amount, doc.data[0].total, doc.data[0].cost);
  if (doc && typeof doc === 'object')
    candidates.push(doc.amount, doc.total, doc.cost);
  for (var i = 0; i < candidates.length; i++) {
    var node = candidates[i];
    if (!node || typeof node !== 'object')
      continue;
    var value = parseMoney(node.value);
    if (value === null)
      continue;
    var cur = String(node.currency || 'USD');
    return {
      ok: true,
      entry: {
        id: 'anthropic',
        label: 'Anthropic',
        plan: '',
        status: 'ready',
        error: '',
        fetchedAt: nowMs,
        sections: [metric('balance', formatMoney(value, cur), null, 'month to date', 0, 'low')]
      }
    };
  }
  return { ok: false, error: 'unparseable cost report' };
}

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

var PROVIDERS = {
  zai: {
    name: 'z.ai',
    monogram: 'Z',
    color: '#fff59b',
    requests: [{
      id: 'main',
      url: 'https://api.z.ai/api/monitor/usage/quota/limit',
      headers: function (key) {
        return { 'Authorization': 'Bearer ' + key, 'Accept-Language': 'en-US,en' };
      }
    }],
    parse: parseZai
  },
  deepseek: {
    name: 'DeepSeek',
    monogram: 'DS',
    color: '#4D6BFE',
    requests: [{
      id: 'main',
      url: 'https://api.deepseek.com/user/balance',
      headers: function (key) {
        return { 'Authorization': 'Bearer ' + key, 'Accept-Language': 'en-US,en' };
      }
    }],
    parse: parseDeepseek
  },
  openrouter: {
    name: 'OpenRouter',
    monogram: 'OR',
    color: '#8B5CF6',
    requests: [
      {
        id: 'credits',
        url: 'https://openrouter.ai/api/v1/credits',
        headers: function (key) {
          return { 'Authorization': 'Bearer ' + key };
        }
      },
      {
        id: 'key',
        url: 'https://openrouter.ai/api/v1/key',
        headers: function (key) {
          return { 'Authorization': 'Bearer ' + key };
        }
      }
    ],
    parse: parseOpenrouter
  },
  kimi: {
    name: 'Kimi',
    monogram: 'K',
    color: '#22D3EE',
    requests: [{
      id: 'main',
      url: 'https://api.kimi.com/coding/v1/usages',
      headers: function (key) {
        return { 'Authorization': 'Bearer ' + key, 'Accept-Language': 'en-US,en' };
      }
    }],
    parse: parseKimi
  },
  claude: {
    name: 'Claude',
    monogram: 'C',
    color: '#D97757',
    keyless: true,
    auth: 'oauth',
    // XHR cannot set User-Agent (the endpoint 429s without the CLI one), so
    // Main.qml drives these with curl via runShell — URLs live here as data.
    usageUrl: 'https://api.anthropic.com/api/oauth/usage',
    refreshUrl: 'https://platform.claude.com/v1/oauth/token',
    clientId: '9d1c250a-e61b-44d9-88ed-5944d1962f5e',
    parse: function (responses, nowMs) {
      return parseClaudeUsage(responses.main, nowMs);
    }
  },
  anthropic: {
    name: 'Anthropic',
    monogram: 'A',
    color: '#CC785C',
    requests: [{
      id: 'main',
      url: 'https://api.anthropic.com/v1/organizations/cost_report',
      headers: function (key) {
        return { 'x-api-key': key, 'anthropic-version': '2023-06-01' };
      }
    }],
    parse: function (responses, nowMs) {
      return parseAnthropicCostReport(responses.main, nowMs);
    }
  }
};
