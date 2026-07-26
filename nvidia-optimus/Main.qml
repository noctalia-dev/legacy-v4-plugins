import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Headless logic + polling for the NVIDIA Optimus plugin.
// The background poll runs the bundled `scripts/gpu-stat` in SYSFS-ONLY mode, so it
// never wakes — or holds awake — a sleeping dGPU. Detailed nvidia-smi stats are
// polled by the Panel only while it is open.
Item {
  id: root

  property var pluginApi: null

  // Bundled helper scripts, resolved relative to this plugin's directory and run via
  // bash (so no execute bit is required after a plain `git clone`).
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
  readonly property string statCmd: root.pluginDir + "scripts/gpu-stat"
  readonly property string toggleCmd: root.pluginDir + "scripts/gpu-toggle"

  property var stats: ({
      "runtime": "unknown",
      "mode": "battery",
      "pending": "battery",
      "external": "none"
    })

  readonly property string runtime: (stats && stats.runtime) ? stats.runtime : "unknown"
  readonly property string mode: (stats && stats.mode) ? stats.mode : "battery"       // live
  readonly property string pending: (stats && stats.pending) ? stats.pending : mode     // next login
  readonly property bool present: runtime !== "absent"
  readonly property bool active: runtime === "active"
  readonly property bool external: !!(stats && stats.external && stats.external !== "none")
  readonly property bool needsRestart: pending !== mode
  property bool busy: false

  function refresh() {
    if (statProc.running)
      return;
    statProc.command = ["bash", root.statCmd];
    statProc.running = true;
  }

  function setMode(m) {
    busy = true;
    ctlProc.command = ["bash", root.toggleCmd, m];
    ctlProc.running = true;
    refresh();
  }

  function toggle() {
    if (busy)
      return;
    setMode(pending === "hdmi" ? "battery" : "hdmi");
  }

  function apply() {
    applyProc.running = true; // restarts the Hyprland session to pick up the env change
  }

  // qs -c noctalia-shell ipc call plugin:nvidia-optimus toggle   (open panel)
  // qs -c noctalia-shell ipc call plugin:nvidia-optimus mode     (flip Battery/HDMI)
  IpcHandler {
    target: "plugin:nvidia-optimus"

    function toggle(): void {
      if (root.pluginApi)
        root.pluginApi.withCurrentScreen(screen => root.pluginApi.togglePanel(screen));
    }

    function mode(): void {
      root.toggle();
    }
  }

  Process {
    id: statProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.stats = JSON.parse(this.text);
        } catch (e) {
          Logger.w("NvidiaOptimus", "Failed to parse gpu-stat output");
        }
      }
    }
  }

  Process {
    id: ctlProc
    onExited: function (code) {
      root.busy = false;
      root.refresh();
    }
  }

  Process {
    id: applyProc
    command: ["hyprctl", "dispatch", "exit"]
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
