// Main.qml v2.1 — shared data service: one poller per configured provider.
//
// State is exposed for every entry point via `pluginApi.mainInstance`:
//   providers        — migrated provider configs (array)
//   entries          — { providerId: normalized entry } (last good fetch)
//   errors           — { providerId: message } ('' when healthy)
//   fetching         — { providerId: bool }
//   activeProviderId / activeEntry — convenience for bar & CC widgets
//   cryptoReady      — passphrase derived; encrypt/decrypt usable
//
// Method surface used by the views (MockMain.qml in tests/bench mirrors it):
//   chipFor(provider) / displayLabel(provider)  — identity presentation
//   headlineSection(entry) / leftPercent(entry)  — compact-view metrics
//   severityColor(sev)                           — severity → theme color
//   setActive(id)                                 — switch active provider
//   fetchProvider(p) / loadProviders()            — data lifecycle
//   encryptSecret(plain, cb) / decryptSecret(env, cb)
//
// Each adapter may declare several HTTP requests (e.g. OpenRouter credits+key);
// they are all resolved before adapter.parse() runs.
//
// At-rest key encryption (v0.5): stored keys are `enc:v1:...` envelopes
// (see Logic.js). The passphrase is derived from machine-id + uid; openssl
// does AES-256-CBC/PBKDF2, keys travel via process pipes, never argv.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Logic.js" as Logic

Item {
  id: root

  property var pluginApi: null

  property var providers: []
  property string activeProviderId: ""
  property var entries: ({})
  property var errors: ({})
  property var fetching: ({})
  // id → claim timestamp; the reaper force-frees slots wedged past
  // staleSlotMs (worst claude chain = 2 curls × 20s + overhead).
  property var fetchClaims: ({})
  readonly property real staleSlotMs: 120000
  property real now: Date.now()

  // --- crypto state --------------------------------------------------------
  property string cryptoPass: ""
  property bool cryptoDerived: false
  readonly property bool cryptoReady: cryptoPass !== ""

  // pluginSettings is a plain var — sub-property writes emit no change
  // signal, so dependents re-read via this counter bumped on every save.
  property int settingsRevision: 0

  readonly property int refreshMs: {
    settingsRevision;
    var m = Number(pluginApi && pluginApi.pluginSettings ? pluginApi.pluginSettings.refreshMinutes : 5);
    if (!isFinite(m) || m <= 0)
      m = 5;
    return Math.max(1, Math.min(60, Math.round(m))) * 60000;
  }

  function settingsObj() {
    return pluginApi ? pluginApi.pluginSettings : null;
  }

  function saveSettings() {
    if (pluginApi && pluginApi.saveSettings)
      pluginApi.saveSettings();
    // The framework rewrite can reset permissions — re-tighten on every save.
    secureSettingsFile();
    settingsRevision++;
  }

  // ------------------------------------------------------- at-rest crypto

  // One-shot helper process: runs `sh -c <script>` with extra environment,
  // calls back with stdout (null on non-zero exit). Anything secret travels
  // through env/pipe, never through argv.
  Component {
    id: shellProcComponent
    Process {
      id: shellProc
      property var done: null
      property string collected: ""
      property int code: -1
      property bool streamDone: false
      property bool exitedDone: false
      stdinEnabled: false
      stdout: StdioCollector {
        onStreamFinished: {
          shellProc.collected = text;
          shellProc.streamDone = true;
          shellProc.tryFinish();
        }
      }
      stderr: StdioCollector {}
      onExited: function (exitCode, exitStatus) {
        shellProc.code = exitCode;
        shellProc.exitedDone = true;
        shellProc.tryFinish();
      }
      function tryFinish() {
        if (!streamDone || !exitedDone || !done)
          return;
        var cb = done;
        var out = code === 0 ? collected : null;
        done = null;
        cb(out);
        shellProc.destroy(50);
      }
    }
  }

  function runShell(script, envVars, cb) {
    var proc = shellProcComponent.createObject(root);
    proc.done = cb;
    proc.environment = envVars || ({});
    proc.command = ["sh", "-c", script];
    proc.running = true;
  }

  // Passphrase = machine-id + uid + domain salt, derived once at startup.
  // Machine-bound: a copied settings.json is useless on another machine.
  function derivePassphrase() {
    if (cryptoDerived)
      return;
    cryptoDerived = true;
    runShell(
      'printf %s "$(cat /etc/machine-id 2>/dev/null || cat /var/lib/dbus/machine-id 2>/dev/null || echo no-machine-id)|uid=$(id -u)"',
      null,
      function (out) {
        if (out === null || String(out).length === 0) {
          Logger.e("AiUsage", "crypto passphrase derivation failed");
          return;
        }
        root.cryptoPass = String(out) + "|ai-usage-v0.5";
        Logger.i("AiUsage", "crypto ready");
        secureSettingsFile();
        migrateEncryption();
        fetchAll();
      });
  }

  function secureSettingsFile() {
    var dir = pluginApi && pluginApi.pluginDir ? String(pluginApi.pluginDir) : "";
    if (dir === "")
      return;
    runShell('chmod 600 "$DF" 2>/dev/null; exit 0', { DF: dir + "/settings.json" }, function () {});
  }

  function b64StdToUrl(s) {
    return s.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  function b64UrlToStd(s) {
    var t = s.replace(/-/g, '+').replace(/_/g, '/');
    while (t.length % 4 !== 0)
      t += '=';
    return t;
  }

  function encryptSecret(plain, cb) {
    if (!cryptoReady) {
      cb(null);
      return;
    }
    runShell(
      'printf %s "$KD" | openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -a -A -pass env:PP',
      { KD: plain, PP: root.cryptoPass },
      function (b64) {
        if (b64 === null) {
          Logger.e("AiUsage", "openssl encrypt failed");
          cb(null);
          return;
        }
        var blob = b64StdToUrl(String(b64).replace(/\s+/g, ''));
        var hint = Logic.keyHintOf(plain);
        var hmac = Logic.hmacSha256Hex(root.cryptoPass, Logic.envelopeHmacMessage(blob, hint));
        cb(Logic.buildEnvelope(blob, hmac, hint));
      });
  }

  function decryptSecret(envelope, cb) {
    var parts = Logic.encryptedSecretParts(envelope);
    if (!parts) {
      cb(null);
      return;
    }
    var expect = Logic.hmacSha256Hex(root.cryptoPass, Logic.envelopeHmacMessage(parts.blob, parts.hint));
    // Non-constant-time compare: the threat model is corruption/tamper
    // detection of a local file, not a remotely-timed oracle — acceptable.
    if (expect !== parts.hmac) {
      Logger.w("AiUsage", "key envelope failed integrity check");
      cb(null);
      return;
    }
    runShell(
      'printf %s "$KD" | openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -a -A -pass env:PP',
      { KD: b64UrlToStd(parts.blob), PP: root.cryptoPass },
      function (plain) {
        cb(plain === null ? null : String(plain).replace(/[\r\n]+$/, ''));
      });
  }

  // Decrypt only at request time; plaintext lives in a fetch-local variable.
  function resolveApiKey(p, cb) {
    if (!Logic.isEncryptedSecret(p.apiKey)) {
      cb(p.apiKey);
      return;
    }
    if (!cryptoReady) {
      cb(null); // fetchAll() runs again once the passphrase is derived
      return;
    }
    decryptSecret(p.apiKey, cb);
  }

  // One-time migration: every plaintext key → encrypted envelope, then save.
  function migrateEncryption() {
    var s = settingsObj();
    if (!s)
      return;
    var work = [];
    if (typeof s.apiKey === 'string' && s.apiKey !== '' && !Logic.isEncryptedSecret(s.apiKey))
      work.push({ obj: s, field: 'apiKey' });
    if (Array.isArray(s.providers)) {
      for (var i = 0; i < s.providers.length; i++) {
        var p = s.providers[i];
        if (p && typeof p.apiKey === 'string' && p.apiKey !== '' && !Logic.isEncryptedSecret(p.apiKey))
          work.push({ obj: p, field: 'apiKey' });
      }
    }
    // Legacy v0.2 top-level apiKey duplicates zai_1's key once the provider
    // list exists — drop it so settings.json stores each key exactly once.
    var dropLegacy = Array.isArray(s.providers) && s.providers.length > 0
        && typeof s.apiKey === 'string' && Logic.isEncryptedSecret(s.apiKey);
    if (work.length === 0 && !dropLegacy) {
      Logger.i("AiUsage", "all keys already encrypted at rest");
      return;
    }
    var idx = 0;
    function step() {
      if (idx >= work.length) {
        if (dropLegacy)
          delete s.apiKey;
        saveSettings();
        Logger.i("AiUsage", "encrypted " + work.length + " key(s) at rest"
                 + (dropLegacy ? " (legacy apiKey removed)" : ""));
        return;
      }
      var item = work[idx++];
      encryptSecret(item.obj[item.field], function (env) {
        if (env !== null)
          item.obj[item.field] = env;
        else
          Logger.e("AiUsage", "encryption failed; key left as-is");
        step();
      });
    }
    step();
  }

  // Load + migrate provider list (v0.2 single key → v0.3 list), persisted once.
  function loadProviders() {
    var s = settingsObj();
    if (!s)
      return;
    var migrated = Logic.migrateSettings(s);
    var changed = !Array.isArray(s.providers) || s.activeProviderId === undefined;
    s.providers = migrated.providers;
    s.activeProviderId = migrated.activeProviderId;
    if (changed)
      saveSettings();
    root.providers = s.providers;
    root.activeProviderId = s.activeProviderId;
  }

  function providerById(id) {
    for (var i = 0; i < root.providers.length; i++) {
      if (root.providers[i].id === id)
        return root.providers[i];
    }
    return null;
  }

  function adapterFor(p) {
    return p ? Logic.PROVIDERS[p.type] : null;
  }

  // Display helpers shared by all widgets.
  function displayLabel(p) {
    if (!p)
      return "";
    if (p.label && p.label !== "")
      return p.label;
    var a = adapterFor(p);
    return a ? a.name : p.type;
  }

  function chipFor(p) {
    var a = adapterFor(p);
    return a ? { monogram: a.monogram, color: a.color, name: a.name } : { monogram: '?', color: Color.mOnSurfaceVariant, name: p ? p.type : '' };
  }

  // The single severity → theme-color mapping (views used to duplicate it).
  function severityColor(sev) {
    switch (sev) {
    case "critical":
      return Color.mError;
    case "high":
      return Color.mSecondary;
    case "mid":
      return Color.mPrimary;
    default:
      return Color.mTertiary;
    }
  }

  function setActive(id) {
    var s = settingsObj();
    if (!s || !providerById(id))
      return;
    s.activeProviderId = id;
    root.activeProviderId = id;
    saveSettings();
  }

  // The headline metric for compact views: session % for window vendors,
  // balance for money vendors. Returns the metric section or null.
  function headlineSection(entry) {
    if (!entry)
      return null;
    var s = Logic.sectionByKey(entry, 'session');
    if (s)
      return s;
    return Logic.sectionByKey(entry, 'balance');
  }

  // "46" (left) for percent metrics; NO_PERCENT (-1) for balance vendors —
  // consumers test >= 0.
  function leftPercent(entry) {
    var s = headlineSection(entry);
    if (!s || s.percent === null || s.percent === undefined)
      return -1;
    return 100 - s.percent;
  }

  readonly property var activeProvider: providerById(activeProviderId)
  readonly property var activeEntry: entries[activeProviderId] !== undefined ? entries[activeProviderId] : null
  readonly property string activeError: errors[activeProviderId] !== undefined ? errors[activeProviderId] : ""

  // ------------------------------------------------------------------ fetch

  function fetchProvider(p) {
    if (!p)
      return;
    var adapter = adapterFor(p);
    if (!adapter) {
      root.errors = Object.assign({}, root.errors, (function () { var o = {}; o[p.id] = 'unknown provider type'; return o; })());
      return;
    }
    if (root.fetching[p.id])
      return;
    // Claim the slot immediately: key resolution and claude's shell chain
    // are async.
    var f = Object.assign({}, root.fetching);
    f[p.id] = true;
    root.fetching = f;
    var claims = Object.assign({}, root.fetchClaims);
    claims[p.id] = Date.now();
    root.fetchClaims = claims;

    if (adapter.keyless) {
      fetchClaude(p, adapter);
      return;
    }

    if (p.apiKey === "") {
      releaseSlot(p.id);
      return;
    }
    // Startup race: pollTimer fires before machine-id lands. Stay quiet —
    // fetchAll() re-runs right after derivation (no spurious ⚠ flash).
    if (!cryptoReady && Logic.isEncryptedSecret(p.apiKey)) {
      releaseSlot(p.id);
      return;
    }
    resolveApiKey(p, function (key) {
      if (key === null || key === "") {
        var er0 = Object.assign({}, root.errors);
        er0[p.id] = 'key decrypt failed';
        var f0 = Object.assign({}, root.fetching);
        f0[p.id] = false;
        root.errors = er0;
        root.fetching = f0;
        Logger.w("AiUsage", p.type + " key decryption failed");
        return;
      }
      startFetch(p, adapter, key);
    });
  }

  function releaseSlot(id) {
    var f = Object.assign({}, root.fetching);
    f[id] = false;
    root.fetching = f;
    var claims = Object.assign({}, root.fetchClaims);
    if (claims[id] !== undefined) {
      delete claims[id];
      root.fetchClaims = claims;
    }
  }

  // Belt-and-braces for wedged requests (all IO has 20s timeouts, but a
  // subprocess that never exits would otherwise pin the slot forever).
  function reapStaleSlots() {
    var now = Date.now();
    var reaped = [];
    for (var id in root.fetching) {
      if (root.fetching[id] && root.fetchClaims[id] !== undefined
          && now - root.fetchClaims[id] > root.staleSlotMs)
        reaped.push(id);
    }
    if (reaped.length === 0)
      return;
    var er = Object.assign({}, root.errors);
    for (var i = 0; i < reaped.length; i++) {
      er[reaped[i]] = 'fetch timed out';
      Logger.w("AiUsage", "reaped stuck fetch slot " + reaped[i]);
    }
    root.errors = er;
    for (var j = 0; j < reaped.length; j++)
      releaseSlot(reaped[j]);
  }

  // Store a parse result (shared by the XHR path and the claude curl path).
  function storeResult(p, r) {
    var e = Object.assign({}, root.entries);
    var er = Object.assign({}, root.errors);
    if (r.ok) {
      e[p.id] = r.entry;
      er[p.id] = '';
    } else {
      er[p.id] = r.error;
      Logger.w("AiUsage", p.type + " parse failed: " + r.error);
    }
    root.entries = e;
    root.errors = er;
    releaseSlot(p.id);
  }

  // ------------------------------------------------------------- claude (oauth)

  readonly property real claudeMinIntervalMs: 300000
  // Per-provider throttle state (id → last fetch ts): two claude accounts
  // must not starve each other through a shared timestamp.
  property var claudeLastFetch: ({})

  // Claude reads the `claude` CLI credentials instead of a stored API key.
  // XHR cannot set User-Agent (the endpoint rejects requests without the
  // CLI one), so the whole chain goes through curl via runShell — secrets
  // travel in env vars, never in argv.
  function fetchClaude(p, adapter) {
    var now = Date.now();
    if (now - (root.claudeLastFetch[p.id] || 0) < root.claudeMinIntervalMs) {
      releaseSlot(p.id);
      return;
    }
    root.claudeLastFetch[p.id] = now;
    runShell('cat "$HOME/.claude/.credentials.json" 2>/dev/null', null, function (out) {
      var raw = out === null || out === undefined ? '' : String(out);
      var doc = null;
      try {
        doc = JSON.parse(raw);
      } catch (e2) {
      }
      var oauth = doc && doc.claudeAiOauth ? doc.claudeAiOauth : null;
      if (!oauth) {
        // Empty file/missing = CLI never logged in; non-empty unparsable =
        // corrupt — different remedies for the user.
        storeResult(p, { ok: false, error: raw.trim() !== '' ? 'claude credentials unreadable' : 'claude CLI not logged in' });
        return;
      }
      var creds = {
        accessToken: String(oauth.accessToken !== undefined ? oauth.accessToken : (oauth.access_token || '')),
        refreshToken: String(oauth.refreshToken !== undefined ? oauth.refreshToken : (oauth.refresh_token || '')),
        expiresAt: Number(oauth.expiresAt !== undefined ? oauth.expiresAt : (oauth.expires_at || 0)) || 0,
        subscriptionType: String(oauth.subscriptionType !== undefined ? oauth.subscriptionType : (oauth.subscription_type || '')),
        rateLimitTier: String(oauth.rateLimitTier !== undefined ? oauth.rateLimitTier : (oauth.rate_limit_tier || ''))
      };
      var withCreds = function (c) {
        claudeUsage(p, adapter, c);
      };
      if (Logic.needsClaudeRefresh(creds, Date.now()) && creds.refreshToken !== '')
        claudeRefresh(p, adapter, creds, doc, withCreds);
      else
        withCreds(creds);
    });
  }

  // Trusted-device logins have no refresh token — we never POST an empty
  // grant (the server answers 400 and may spend the token).
  function claudeRefresh(p, adapter, creds, doc, done) {
    var script = 'BODY=$(printf \'{"grant_type":"refresh_token","client_id":"%s","refresh_token":"%s"}\' "$CID" "$RT")\n'
      + 'curl -fsS --max-time 20 -X POST "$RU" '
      + '-H "anthropic-beta: oauth-2025-04-20" -H "User-Agent: claude-cli/1.0" '
      + '-H "Content-Type: application/json" --data "$BODY"';
    runShell(script, { RT: creds.refreshToken, RU: adapter.refreshUrl, CID: adapter.clientId },
             function (out) {
               var resp = null;
               try {
                 resp = JSON.parse(out);
               } catch (e2) {
               }
               if (!resp || !resp.access_token) {
                 Logger.w("AiUsage", "claude token refresh failed, trying old token");
                 done(creds);
                 return;
               }
               var next = Logic.applyClaudeRefresh(creds, resp, Date.now());
                // The server MAY rotate the refresh token — persist or the
                // user is silently logged out next time. chmod after write:
                // umask only applies at creation, the file may already exist.
                var fullDoc = Object.assign({}, doc, { claudeAiOauth: next });
                runShell('umask 077; printf \'%s\' "$CJ" > "$HOME/.claude/.credentials.json" && chmod 600 "$HOME/.claude/.credentials.json"',
                        { CJ: JSON.stringify(fullDoc) },
                        function (written) {
                          if (written === null)
                            Logger.w("AiUsage", "claude credentials write-back failed");
                          done(next);
                        });
             });
  }

  function claudeUsage(p, adapter, creds) {
    var script = 'curl -fsS --max-time 20 "$UU" '
      + '-H "Authorization: Bearer $AT" '
      + '-H "anthropic-beta: oauth-2025-04-20" '
      + '-H "User-Agent: claude-code/2.1.183" '
      + '-H "Content-Type: application/json"';
    runShell(script, { UU: adapter.usageUrl, AT: creds.accessToken }, function (out) {
      var doc = null;
      try {
        doc = JSON.parse(out);
      } catch (e2) {
      }
      if (!doc) {
        storeResult(p, { ok: false, error: 'usage request failed' });
        return;
      }
      var r = Logic.parseClaudeUsage(doc, Date.now());
      if (r.ok) {
        var plan = Logic.claudePlanLabel(creds.subscriptionType, creds.rateLimitTier);
        if (plan !== 'Unknown')
          r.entry.plan = plan;
      }
      storeResult(p, r);
    });
  }

  function startFetch(p, adapter, key) {
    var responses = {};
    var pending = adapter.requests.length;
    var finishOne = function () {
      pending--;
      if (pending > 0)
        return;
      storeResult(p, adapter.parse(responses, Date.now()));
    };
    for (var i = 0; i < adapter.requests.length; i++) {
      (function (req) {
        var xhr = new XMLHttpRequest();
        // Timeout can fire alongside readyState DONE — settle exactly once.
        var settled = false;
        var settle = function () {
          if (settled)
            return;
          settled = true;
          finishOne();
        };
        xhr.open("GET", req.url);
        xhr.timeout = 20000;
        var hdrs = req.headers(key);
        for (var k in hdrs)
          xhr.setRequestHeader(k, hdrs[k]);
        xhr.onreadystatechange = function () {
          if (xhr.readyState !== XMLHttpRequest.DONE)
            return;
          if (xhr.status === 200) {
            try {
              responses[req.id] = JSON.parse(xhr.responseText);
            } catch (e2) {
              responses[req.id] = null;
            }
          } else {
            responses[req.id] = null;
            Logger.w("AiUsage", p.type + " " + req.id + " HTTP " + xhr.status);
          }
          settle();
        };
        xhr.ontimeout = function () {
          responses[req.id] = null;
          Logger.w("AiUsage", p.type + " " + req.id + " request timeout");
          settle();
        };
        xhr.send();
      })(adapter.requests[i]);
    }
  }

  function fetchAll() {
    for (var i = 0; i < root.providers.length; i++) {
      var p = root.providers[i];
      if (p.enabled)
        fetchProvider(p);
    }
  }

  // ------------------------------------------------------------------ timers

  Timer {
    id: pollTimer
    interval: root.refreshMs
    running: root.providers.length > 0
    repeat: true
    triggeredOnStart: true
    onTriggered: root.fetchAll()
  }

  Timer {
    id: tickTimer
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.now = Date.now()
  }

  Timer {
    id: reaperTimer
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.reapStaleSlots()
  }

  Component.onCompleted: {
    if (!pluginApi)
      return;
    loadProviders();
    Logger.i("AiUsage", "service started, " + root.providers.length + " provider(s)");
    derivePassphrase();
  }

  onPluginApiChanged: {
    if (pluginApi) {
      loadProviders();
      // Late-bound api must not leave crypto permanently dead.
      derivePassphrase();
    }
  }
}
