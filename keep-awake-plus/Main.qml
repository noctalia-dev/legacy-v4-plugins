import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  // --- Live state mirrored from `system-awake status --json` ---
  property bool active: false
  property string scope: "partial"
  property string durationLabel: ""
  property var endEpoch: null  // null → unlimited; number → expiry unix seconds
  property bool thermalGuardActive: false

  // Bundled host-side backend. Resolved from the plugin's install dir so the
  // script doesn't need to be on $PATH.
  readonly property string scriptPath: (pluginApi?.pluginDir ?? "") + "/scripts/system-awake"

  // Suppress the enable/disable toast on the first status apply so a session
  // already running when the shell starts doesn't spuriously "enable" us.
  property bool _firstStatusApplied: false

  // Unix-ms timestamp of the last `start` issued by this plugin. Used to
  // suppress the transient active=false window during a reconfigure
  // (the shell's cleanup_inactive removes state.json before writing the
  // new one), which otherwise makes the widget flicker off→on.
  property real _lastStartMs: 0

  // Derived from endEpoch so the countdown ticks with the global Time singleton
  // (free clock-skew / resume handling).
  readonly property int remainingSeconds: {
    if (!active) return 0;
    if (endEpoch === null) return -1;  // unlimited sentinel
    return Math.max(0, endEpoch - Time.timestamp);
  }

  // --- Wayland idle inhibitor ---
  // 1x1 transparent layer-shell surface that hosts a real
  // zwp_idle_inhibit_manager_v1 inhibitor. Mapped iff we want the
  // compositor to treat the user as not idle:
  //   * full scope    : mapped for the entire session
  //                     (display stays on, idle daemons paused)
  //   * partial scope : briefly mapped post-expiry to re-arm idle daemons
  //                     whose on-timeout was consumed during the session
  //
  // Compositor-agnostic — every conforming idle daemon (hypridle, swayidle,
  // gnome-session-idle, …) reacts to the protocol-level resume edge.
  PanelWindow {
    id: inhibitorWindow
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    visible: (root.active && root.scope === "full") || pulseTimer.running
    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "noctalia-keep-awake-plus"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    IdleInhibitor {
      window: inhibitorWindow
      enabled: inhibitorWindow.visible
    }
  }

  Timer { id: pulseTimer; interval: 150 }

  onActiveChanged: {
    if (_firstStatusApplied) {
      if (active) {
        const label = (endEpoch === null) ? pluginApi?.tr("panel.unlimited") : durationLabel;
        const descKey = (scope === "full") ? "toast.enabled-desc-full" : "toast.enabled-desc-partial";
        const desc = pluginApi?.tr(descKey, { scope: scope, label: label });
        ToastService.showNotice(pluginApi?.tr("toast.enabled-title"), desc, "coffee");
      } else {
        ToastService.showNotice(pluginApi?.tr("toast.disabled-title"), "", "coffee-off");
      }
    }
  }

  // PluginService merges manifest's defaultSettings into pluginSettings, so
  // these are already populated when pluginApi is set.
  readonly property var cfg: pluginApi?.pluginSettings ?? ({})
  readonly property string defaultScope: cfg.defaultScope ?? "partial"
  readonly property var durations: cfg.durations ?? []
  readonly property bool includeUnlimited: cfg.includeUnlimited ?? true
  readonly property bool showRemainingText: cfg.showRemainingText ?? true
  readonly property bool activateOnLeftClick: cfg.activateOnLeftClick ?? false
  readonly property int quickExtendMinutes: cfg.quickExtendMinutes ?? 30

  // --- Pollers ---
  Process {
    id: statusProc
    running: false
    command: [root.scriptPath, "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root._applyStatus(JSON.parse(this.text.trim() || "{}"));
        } catch (e) {
          Logger.w("keep-awake-plus", "Failed to parse status:", e, "text:", this.text);
        }
      }
    }
  }

  Process {
    id: guardProc
    running: false
    command: ["systemctl", "--user", "is-active", "--quiet", "system-awake-thermal-guard.service"]
    onExited: function(exitCode) { root.thermalGuardActive = (exitCode === 0); }
  }

  function _pollStatus() { if (!statusProc.running) statusProc.running = true; }
  function pollGuard()   { if (!guardProc.running)  guardProc.running  = true; }

  Timer {
    id: statusPoller
    interval: 1000; repeat: true; running: pluginApi !== null; triggeredOnStart: true
    onTriggered: root._pollStatus()
  }

  function _applyStatus(s) {
    // Assign `active` LAST. The derived `remainingSeconds` reads
    // `active && endEpoch === null` as the unlimited sentinel, so if
    // `active` flipped true before `endEpoch` updates, the stale null
    // would briefly surface as ∞ in bindings and `onActiveChanged`.
    if (!s.active) {
      // Reconfigure race: if we just issued `start` while active, the shell
      // briefly tears state down before writing the new state. Ignore the
      // transient off window so the bar widget doesn't flicker.
      if (root.active && (Date.now() - root._lastStartMs) < 2000) return;
      // Capture pre-mutation state to decide whether to pulse the idle
      // inhibitor (re-arms idle daemons whose on-timeout was consumed).
      // Full scope's binding already produces an unmap edge when
      // `scope` clears, so only partial scope needs an explicit pulse.
      const wasActive = root.active;
      const pulse = wasActive && root.scope !== "full";
      root.scope = "";
      root.durationLabel = "";
      root.endEpoch = null;
      root.active = false;
      if (pulse && root._firstStatusApplied) pulseTimer.restart();
    } else {
      root.scope = s.scope;
      root.durationLabel = s.duration_label;
      root.endEpoch = (s.end_epoch === null || s.end_epoch === undefined) ? null : Number(s.end_epoch);
      root.active = true;
    }
    root._firstStatusApplied = true;
  }

  // --- Actions (invoked by BarWidget / Panel) ---
  // All shell invocations pass --silent; state-change toasts are fired from
  // `onActiveChanged` above so they trigger for external `system-awake`
  // callers too (CLI, keybind) without the shell also firing notify-send.

  // Mirrors the shell's format_label. Public so the panel's label-based
  // minutes match doesn't drift from what the next poll will write.
  function formatLabel(seconds) {
    if (seconds === -1) return "∞";
    if (seconds >= 3600) {
      const h = Math.floor(seconds / 3600);
      const m = Math.floor((seconds % 3600) / 60);
      if (m === 0) return h + "h";
      return h + "h" + (m < 10 ? "0" + m : m) + "m";
    }
    return Math.floor(seconds / 60) + "m";
  }

  function start(durationSeconds, pickScope) {
    // `timeout 0s` in GNU coreutils means unlimited, so reject any
    // non-positive duration except the explicit -1 "unlimited" sentinel.
    const d = durationSeconds;
    if (d !== -1 && (!Number.isFinite(d) || d < 1)) {
      Logger.w("keep-awake-plus", "Refused start with invalid duration:", d);
      return;
    }
    const durArg = (d === -1) ? "unlimited" : String(Math.floor(d));
    root._lastStartMs = Date.now();

    // Optimistic update: reflect the new state immediately so the bar
    // icon color + countdown update on click, not 100-300ms later when
    // the shell finishes writing state.json. The next poll confirms.
    root.scope = pickScope;
    root.durationLabel = formatLabel(d);
    root.endEpoch = (d === -1) ? null : Math.floor(Date.now() / 1000) + Math.floor(d);
    root.active = true;

    Quickshell.execDetached([root.scriptPath, "start", durArg, "--scope=" + pickScope, "--silent"]);
    Qt.callLater(root._pollStatus);
  }

  function off() {
    // Optimistic update so the bar widget flips to "off" immediately.
    root.scope = "";
    root.durationLabel = "";
    root.endEpoch = null;
    root.active = false;
    Quickshell.execDetached([root.scriptPath, "off", "--silent"]);
    Qt.callLater(root._pollStatus);
  }

  function extend(seconds) {
    // extend also briefly looks inactive to a status poll (shell pkills the
    // old inhibitor before spawning the new one), so reuse the same debounce.
    root._lastStartMs = Date.now();
    if (root.active && root.endEpoch !== null) {
      root.endEpoch = root.endEpoch + Math.floor(seconds);
    }
    Quickshell.execDetached([root.scriptPath, "extend", String(seconds), "--silent"]);
    const mins = Math.floor(seconds / 60);
    ToastService.showNotice(
      pluginApi?.tr("toast.extended-title"),
      pluginApi?.tr("toast.extended-desc", { minutes: mins }),
      "clock-plus");
    Qt.callLater(root._pollStatus);
  }

  function toggleLast() {
    Quickshell.execDetached([root.scriptPath, "toggle-last", "--silent"]);
    Qt.callLater(root._pollStatus);
  }

  function formatRemaining() {
    if (!active) return "";
    if (remainingSeconds === -1) return "∞";
    return Time.formatVagueHumanReadableDuration(remainingSeconds);
  }
}
