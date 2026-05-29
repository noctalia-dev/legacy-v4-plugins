import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  // Expose service to bar widget
  property alias hermesService: hermesService

  // Path to the status check script (~ is expanded by sh)
  readonly property string scriptPath: {
    var cfg = pluginApi?.pluginSettings || {};
    var defaults = pluginApi?.manifest?.metadata?.defaultSettings || {};
    return cfg.statusScript ?? defaults.statusScript ?? "~/.config/noctalia/hermes-status-check";
  }

  QtObject {
    id: hermesService

    property string status: "idle"
    property string gatewayPid: ""
    property string cliPid: ""
    property bool cliActive: false
    property bool needsAttention: false
    property var platforms: ({})
    property string fetchState: "idle"
    property string errorMessage: ""
    property string signalEvent: ""
    property string signalTs: ""
    property var usage: ({})

    property bool hasError: {
      for (var key in platforms) {
        if (platforms[key] && platforms[key].state !== "connected") return true;
      }
      return false;
    }

    function refresh() {
      fetchState = "loading";
      // sh -c expands ~ to home directory
      statusProcess.command = ["sh", "-c", root.scriptPath];
      statusProcess.running = true;
    }

    function clearAttention() {
      needsAttention = false;
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
      if (exitCode !== 0) {
        hermesService.fetchState = "error";
        hermesService.status = "error";
        hermesService.errorMessage = "Script failed (exit " + exitCode + ")";
        return;
      }

      var response = stdout.text;
      if (!response || response.trim() === "") {
        hermesService.fetchState = "error";
        hermesService.status = "error";
        hermesService.errorMessage = "Empty response";
        return;
      }

      try {
        var data = JSON.parse(response);
        hermesService.status = data.status || "unknown";
        hermesService.gatewayPid = data.gateway_pid || "";
        hermesService.cliPid = data.cli_pid || "";
        hermesService.cliActive = data.cli_active || false;
        hermesService.needsAttention = data.needs_attention || false;
        hermesService.platforms = data.platforms || {};
        hermesService.signalEvent = data.signal_event || "";
        hermesService.signalTs = data.signal_ts || "";
        hermesService.usage = data.usage || {};
        hermesService.fetchState = "success";
        hermesService.errorMessage = "";
      } catch (e) {
        hermesService.fetchState = "error";
        hermesService.status = "error";
        hermesService.errorMessage = "JSON parse error: " + e;
      }
    }
  }

  // Clear attention process
  Process {
    id: clearAttentionProcess
    stdout: StdioCollector {}
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
      hermesService.refresh();
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
