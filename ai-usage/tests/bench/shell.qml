// tests/bench/shell.qml — offline smoke harness for the plugin's QML panes:
// stubs the noctalia design system (qs.*), instantiates the real Settings,
// BarWidget, Panel AND Main (symlinked here). Verifies:
//   1) Panel tab switching (selectedId → currentId → currentEntry),
//   2) external activeProviderId change drops a stale tab selection,
//   3) BarWidget lays out N segments with non-zero width (Row regression),
//   4) crypto: real openssl roundtrip + plaintext keys migrate to envelopes.
// Run from plugin root:
//   env QT_QPA_PLATFORM=offscreen timeout 40 qs -p tests/bench
// Success = "BENCH-OK" in output (exit 124 is just the timeout kill).
import QtQuick
import QtQuick.Layouts
import "Logic.js" as Logic

Item {
  id: bench

  width: 500
  height: 900

  property var failures: []
  property bool cryptoPhase: false
  property int migrationTries: 0

  MockMain {
    id: mockMain
  }

  readonly property var mockApi: ({
    mainInstance: mockMain,
    panelOpenScreen: null,
    tr: function (key) { return key; },
    openPanel: function () {}
  })

  // Mock settings with ONE PLAINTEXT key: Main's startup migration must
  // convert it to an enc:v1 envelope (real openssl, real machine-id).
  // claude_1 is keyless — its fetch must degrade to the "not logged in"
  // error state without any key material.
  readonly property var mockSettings: ({
    providers: [
      { id: "zai_1", type: "zai", apiKey: "bench-plain-key",
        label: "", planLabel: "", validUntil: "", enabled: true },
      { id: "claude_1", type: "claude", apiKey: "",
        label: "", planLabel: "", validUntil: "", enabled: true }
    ],
    activeProviderId: "zai_1",
    refreshMinutes: 5,
    showBackground: true
  })

  readonly property var mainApi: ({
    pluginSettings: bench.mockSettings,
    saveSettings: function () {},
    pluginDir: "/tmp/opencode/bench-ai-usage",
    tr: function (key) { return key; }
  })

  Component.onCompleted: {
    // Settings: exercise both form branches.
    pane.addVisible = true;
    pane.editId = "";
    pane.editId = "zai_1";
    pane.editId = "";

    // Panel: tab-switch chain (bug 3). selectedId is what a tab click sets.
    console.log("PANEL initial currentId:", panel.currentId,
                "plan:", panel.currentEntry ? panel.currentEntry.plan : "null");
    panel.selectedId = "deepseek_1";
    if (panel.currentId !== "deepseek_1")
      failures.push("tab switch → deepseek failed, currentId=" + panel.currentId);
    if (!panel.currentEntry || panel.currentEntry.plan !== "pay-as-you-go")
      failures.push("deepseek entry not selected after switch");
    console.log("PANEL switch→deepseek currentId:", panel.currentId,
                "plan:", panel.currentEntry ? panel.currentEntry.plan : "null");
    panel.selectedId = "zai_1";
    if (panel.currentId !== "zai_1")
      failures.push("tab switch → zai failed, currentId=" + panel.currentId);
    console.log("PANEL switch→zai currentId:", panel.currentId,
                "plan:", panel.currentEntry ? panel.currentEntry.plan : "null");

    // Bar segment click while the panel is open: setActive fires externally,
    // a stale tab selection must be dropped and the content must follow.
    mockMain.setActive("deepseek_1");
    if (panel.selectedId !== "")
      failures.push("stale selectedId survived external setActive");
    if (panel.currentId !== "deepseek_1")
      failures.push("panel did not follow external setActive, currentId=" + panel.currentId);
    console.log("PANEL after external setActive currentId:", panel.currentId);

    // BarWidget: two mock segments must lay out with a sane total width
    // (the "Row will not function" regression produced zero-width rows).
    console.log("BAR segments:", bar.segments.length,
                "contentWidth:", bar.contentWidth.toFixed(1));
    if (bar.segments.length !== 2)
      failures.push("expected 2 bar segments, got " + bar.segments.length);
    if (!(bar.contentWidth > 40))
      failures.push("bar contentWidth too small: " + bar.contentWidth);

    console.log("UI asserts done, waiting for crypto phase…");
  }

  // Crypto phase starts once Main derived its passphrase (async, real
  // machine-id read + openssl children work under offscreen).
  Connections {
    target: mainService
    function onCryptoReadyChanged() {
      if (!mainService.cryptoReady || bench.cryptoPhase)
        return;
      bench.cryptoPhase = true;
      console.log("CRYPTO passphrase derived, testing roundtrip…");
      mainService.encryptSecret("bench-key-12345", function (env) {
        if (env === null || !Logic.isEncryptedSecret(env)) {
          bench.fail("encryptSecret returned no envelope: " + env);
          bench.finish();
          return;
        }
        console.log("CRYPTO envelope:", Logic.keyMask(env), env.substring(0, 24) + "…");
        if (Logic.keyMask(env) !== "•••2345")
          bench.fail("envelope hint mask wrong: " + Logic.keyMask(env));
        mainService.decryptSecret(env, function (plain) {
          if (plain !== "bench-key-12345")
            bench.fail("roundtrip mismatch: " + plain);
          else
            console.log("CRYPTO roundtrip OK");
          // A tampered BLOB must fail the integrity check (HMAC covers
          // blob+hint): flip its first base64url character.
          var parts = Logic.encryptedSecretParts(env);
          var flip = parts.blob.charAt(0) === "Q" ? "R" : "Q";
          var tampered = Logic.buildEnvelope(flip + parts.blob.substring(1), parts.hmac, parts.hint);
          mainService.decryptSecret(tampered, function (t) {
            if (t !== null)
              bench.fail("tampered envelope decrypted without integrity failure");
            else
              console.log("CRYPTO tamper detection OK");
            migrationTimer.start();
          });
        });
      });
    }
  }

  // Startup migration (async serial encrypt) should turn the plaintext key
  // into an envelope shortly after cryptoReady.
  Timer {
    id: migrationTimer
    interval: 300
    repeat: true
    onTriggered: {
      bench.migrationTries++;
      var key = bench.mockSettings.providers[0].apiKey;
      if (!Logic.isEncryptedSecret(key)) {
        if (bench.migrationTries > 40) {
          bench.fail("plaintext key not migrated after 12s, got: " + key);
          bench.finish();
        }
        return;
      }
      console.log("CRYPTO migration OK:", Logic.keyMask(key));
      migrationTimer.stop();
      // 'bench-plain-key' → last 4 chars, '-' is a valid hint character.
      if (Logic.encryptedSecretParts(key).hint !== "-key")
        bench.fail("migrated envelope hint wrong: " + Logic.encryptedSecretParts(key).hint);
      // The keyless claude provider must land in its error state (no
      // credentials file on this machine), never hang the fetch slot.
      if (bench.mockSettings.providers[1].apiKey !== "")
        bench.fail("keyless provider acquired a key?!");
      claudeTimer.start();
    }
  }

  // claude_1 fetch runs cat via runShell right after startup — expect the
  // not-logged-in error state within a few ticks.
  Timer {
    id: claudeTimer
    interval: 400
    repeat: true
    property int tries: 0
    onTriggered: {
      tries++;
      var err = mainService.errors["claude_1"];
      if (err === undefined) {
        if (tries > 25) {
          bench.fail("claude_1 fetch never settled");
          bench.finish();
        }
        return;
      }
      if (err !== "claude CLI not logged in")
        bench.fail("claude_1 error state unexpected: " + err);
      else
        console.log("CLAUDE keyless error path OK:", err);
      if (mainService.fetching["claude_1"])
        bench.fail("claude_1 fetch slot not released");

      // --- DesktopWidget + ControlCenterWidget coverage (review M-14) -----
      var activeLabel = mockMain.displayLabel(mockMain.activeProvider);
      if (desktop.valueLine === "")
        bench.fail("desktop valueLine empty with a healthy active entry");
      if (desktop.implicitHeight <= 0)
        bench.fail("desktop widget has no height");
      if (cc.tooltipText.indexOf(activeLabel) < 0)
        bench.fail("CC tooltip lost the provider label: " + cc.tooltipText);
      // error surfacing: inject an error → tooltip must show ⚠ (M-14 fix)
      var errs = {};
      errs[mockMain.activeProviderId] = "boom";
      mockMain.errors = errs;
      if (cc.tooltipText.indexOf("⚠") < 0)
        bench.fail("CC tooltip hides active errors: " + cc.tooltipText);
      mockMain.errors = ({});

      bench.finish();
    }
  }

  function fail(msg) {
    failures.push(msg);
  }

  property bool finished: false

  function finish() {
    if (finished)
      return;
    finished = true;
    migrationTimer.stop();
    claudeTimer.stop();
    if (failures.length > 0) {
      for (var i = 0; i < failures.length; i++)
        console.log("BENCH-FAIL:", failures[i]);
      Qt.exit(1);
    }
    console.log("BENCH-OK: Settings + BarWidget + Panel + Desktop + CC + Main crypto + claude keyless verified");
    Qt.exit(0);
  }

  Settings { id: pane; pluginApi: null }
  BarWidget { id: bar; pluginApi: bench.mockApi }
  Panel { id: panel; pluginApi: bench.mockApi }
  DesktopWidget { id: desktop; pluginApi: bench.mockApi }
  ControlCenterWidget { id: cc; pluginApi: bench.mockApi; screen: null }
  Main { id: mainService; pluginApi: bench.mainApi }
}
