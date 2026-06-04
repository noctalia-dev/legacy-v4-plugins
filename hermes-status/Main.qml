import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  // Expose service to bar widget
  property alias hermesService: hermesService
  // Expose process model for Panel/BarWidget
  property alias processModel: processListModel

  // Path to the status check script (~ expanded to home directory)
  readonly property string scriptPath: {
    var cfg = pluginApi?.pluginSettings || {};
    var defaults = pluginApi?.manifest?.metadata?.defaultSettings || {};
    var raw = cfg.statusScript ?? defaults.statusScript ?? "~/.cache/noctalia/plugins/hermes-status/hermes-status-check";
    return expandHome(raw);
  }

  // Shared ListModel for process list (lives at Item level, not inside QtObject)
  ListModel {
    id: processListModel
  }

  QtObject {
    id: hermesService

    property string status: "idle"
    property string gatewayPid: ""
    property string cliPid: ""
    property bool cliActive: false
    property int activeCliCount: 0
    property bool needsAttention: false
    property var platforms: ({})
    property string fetchState: "idle"
    property string errorMessage: ""
    property string signalEvent: ""
    property string signalTs: ""
    property var usage: ({})
    property var processes: ([])
    property ListModel processModel: processListModel
    // Pending refresh: set when a refresh is requested while one is in-flight,
    // so the UI does not miss status transitions during rapid hook updates.
    property bool pendingRefresh: false

    property bool hasError: {
      for (var key in platforms) {
        if (platforms[key] && platforms[key].state !== "connected") return true;
      }
      return false;
    }

    function refresh(force) {
      // If a fetch is already in-flight, mark pending so onExited will re-trigger.
      // force=true bypasses the stuck guard (used by IPC manual refresh).
      if (fetchState === "loading" || statusProcess.running) {
        if (force) {
          // Force-reset stuck state: kill the old process and start fresh.
          statusProcess.running = false;
          fetchState = "idle";
          pendingRefresh = false;
        } else {
          pendingRefresh = true;
          return;
        }
      }
      fetchState = "loading";
      // sh -c allows shell features in custom statusScript settings (env vars, wrappers, args)
      statusProcess.command = ["sh", "-c", root.scriptPath];
      statusProcess.running = true;
      fetchWatchdog.restart();
    }

    function clearAttention() {
      // Clear the flag only after the rm process succeeds.
      clearAttentionProcess.command = ["rm", "-f", Quickshell.env("HOME") + "/.hermes/needs_attention"];
      clearAttentionProcess.running = true;
    }
  }

  function expandHome(path) {
    if (!path) return path;
    if (path === "~") return Quickshell.env("HOME") || path;
    if (path.indexOf("~/") === 0) return (Quickshell.env("HOME") || "") + path.slice(1);
    return path;
  }

  readonly property string signalFilePath: {
    var cfg = pluginApi?.pluginSettings || {};
    var defaults = pluginApi?.manifest?.metadata?.defaultSettings || {};
    return expandHome(cfg.signalFile ?? defaults.signalFile ?? "~/.hermes/status_signal");
  }

  // Watch the hook signal file for near-instant UI refresh.  The timer below is
  // still kept as a low-frequency safety net for process/gateway changes that do
  // not rewrite status_signal.
  FileView {
    id: signalFileView
    path: root.signalFilePath
    printErrors: false
    watchChanges: true

    onFileChanged: {
      reload();
      refreshDebounce.restart();
    }

    onLoaded: refreshDebounce.restart()
    onLoadFailed: refreshDebounce.restart()
  }

  Timer {
    id: refreshDebounce
    interval: 100
    repeat: false
    onTriggered: hermesService.refresh()
  }

  // Status check process
  Process {
    id: statusProcess
    stdout: StdioCollector {}

    onExited: function(exitCode) {
      fetchWatchdog.stop();
      if (exitCode !== 0) {
        hermesService.fetchState = "error";
        hermesService.status = "error";
        hermesService.errorMessage = "Script failed (exit " + exitCode + ")";
        if (hermesService.pendingRefresh) {
          hermesService.pendingRefresh = false;
          hermesService.refresh();
        }
        return;
      }

      var response = stdout.text;
      if (!response || response.trim() === "") {
        hermesService.fetchState = "error";
        hermesService.status = "error";
        hermesService.errorMessage = "Empty response";
        if (hermesService.pendingRefresh) {
          hermesService.pendingRefresh = false;
          hermesService.refresh();
        }
        return;
      }

      try {
        var data = JSON.parse(response);
        hermesService.status = data.status || "unknown";
        hermesService.gatewayPid = data.gateway_pid || "";
        hermesService.cliPid = data.cli_pid || "";
        hermesService.cliActive = data.cli_active || false;
        hermesService.activeCliCount = data.active_cli_count || 0;
        hermesService.needsAttention = data.needs_attention || false;
        hermesService.platforms = data.platforms || {};
        hermesService.signalEvent = data.signal_event || "";
        hermesService.signalTs = data.signal_ts || "";
        hermesService.usage = data.usage || {};
        hermesService.processes = data.processes || [];
        hermesService.fetchState = "success";
        hermesService.errorMessage = "";

        // Update ListModel for QML Repeaters
        processListModel.clear();
        var procs = data.processes || [];
        for (var i = 0; i < procs.length; i++) {
          var p = procs[i];
          processListModel.append({
            "pid": p.pid || "",
            "source": p.source || "unknown",
            "sessionId": p.session_id || "",
            "state": p.state || "idle",
            "event": p.event || "",
            "ts": p.ts || "",
            "signalAge": p.signal_age !== undefined ? p.signal_age : -1,
            "platform": p.platform || "",
            "alive": p.alive !== false
          });
        }
      } catch (e) {
        hermesService.fetchState = "error";
        hermesService.status = "error";
        hermesService.errorMessage = "JSON parse error: " + e;
      }

      // If another refresh was requested while we were loading, re-trigger now.
      if (hermesService.pendingRefresh) {
        hermesService.pendingRefresh = false;
        hermesService.refresh();
      }
    }
  }

  // Clear attention process
  Process {
    id: clearAttentionProcess
    stdout: StdioCollector {}
    onExited: function(exitCode) {
      if (exitCode === 0) {
        hermesService.needsAttention = false;
      }
    }
  }

  // Watchdog: if fetchState stays "loading" for >15s, force-reset.
  // Handles cases where onExited doesn't fire (process crash, QML bug).
  Timer {
    id: fetchWatchdog
    interval: 15000
    repeat: false
    onTriggered: {
      if (hermesService.fetchState === "loading") {
        statusProcess.running = false;
        hermesService.fetchState = "idle";
        hermesService.pendingRefresh = false;
      }
    }
  }

  // Poll timer
  Timer {
    id: pollTimer
    repeat: true
    running: true
    triggeredOnStart: true
    interval: {
      var cfg = pluginApi?.pluginSettings || {};
      var defaults = pluginApi?.manifest?.metadata?.defaultSettings || {};
      var secs = cfg.pollInterval ?? defaults.pollInterval ?? 10;
      return secs * 1000;
    }
    onTriggered: hermesService.refresh()
  }

  IpcHandler {
    target: "plugin:hermes-status"
    function refresh() {
      hermesService.refresh(true);  // force: bypass stuck guard
    }
    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(function(screen) {
          pluginApi.togglePanel(screen);
        });
      }
    }
  }
}
