import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  readonly property int refreshInterval: pluginApi?.pluginSettings?.refreshInterval ?? 5000

  property bool warpInstalled: false
  property bool warpConnected: false
  property string warpMode: ""
  property bool isRefreshing: false
  property bool isSwitchingMode: false
  property string lastToggleAction: ""

  readonly property var availableModes: [
    "warp", "doh", "warp+doh", "dot", "warp+dot", "proxy", "tunnel_only"
  ]

  Timer {
    id: updateTimer
    interval: root.refreshInterval
    running: root.warpInstalled
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: statusDelayTimer
    interval: 1500
    repeat: false
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    checkInstalled()
  }

  function checkInstalled() {
    root.isRefreshing = true
    whichProcess.running = true
  }

  function refresh() {
    if (root.isRefreshing) return
    root.isRefreshing = true
    statusProcess.running = true
    modeProcess.running = true
  }

  function setMode(mode) {
    if (root.isSwitchingMode) return
    if (root.availableModes.indexOf(mode) === -1) return
    root.isSwitchingMode = true
    modeSetProcess.command = ["warp-cli", "--accept-tos", "mode", mode]
    modeSetProcess.running = true
  }

  function connect() {
    root.lastToggleAction = "connect"
    connectProcess.running = true
  }

  function disconnect() {
    root.lastToggleAction = "disconnect"
    disconnectProcess.running = true
  }

  function toggleWarp() {
    if (root.warpConnected) {
      disconnect()
    } else {
      connect()
    }
  }

  Process {
    id: whichProcess
    command: ["which", "warp-cli"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      root.warpInstalled = (exitCode === 0)
      root.isRefreshing = false
      if (root.warpInstalled) {
        root.refresh()
        updateTimer.start()
      } else {
        Logger.w("CloudflareWarp", "warp-cli not found in PATH")
      }
    }
  }

  Process {
    id: statusProcess
    command: ["warp-cli", "--accept-tos", "status"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      root.isRefreshing = false
      var output = String(statusProcess.stdout.text || "").trim()

      if (exitCode === 0 && output) {
        if (/status update:\s*disconnected/i.test(output)) {
          root.warpConnected = false
        } else if (/status update:\s*connected/i.test(output)) {
          root.warpConnected = true
        } else {
          root.warpConnected = false
        }
      } else {
        root.warpConnected = false
        if (exitCode !== 0) {
          Logger.w("CloudflareWarp", "warp-cli status failed: " + String(statusProcess.stderr.text || "").trim())
        }
      }
    }
  }

  Process {
    id: modeProcess
    command: ["warp-cli", "--accept-tos", "--json", "settings"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      var output = String(modeProcess.stdout.text || "").trim()
      if (exitCode === 0 && output) {
        try {
          var data = JSON.parse(output)
          root.warpMode = data?.settings?.operation_mode ?? ""
        } catch (e) {
          Logger.w("CloudflareWarp", "Failed to parse warp-cli settings JSON: " + e)
          root.warpMode = ""
        }
      } else {
        Logger.w("CloudflareWarp", "warp-cli settings failed: " + String(modeProcess.stderr.text || "").trim())
      }
    }
  }

  Process {
    id: modeSetProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      root.isSwitchingMode = false
      if (exitCode === 0) {
        ToastService.showNotice(
          pluginApi?.tr("toast.title"),
          pluginApi?.tr("toast.mode-changed"),
          "cloud-lock"
        )
      } else {
        var err = String(modeSetProcess.stderr.text || "").trim()
        Logger.e("CloudflareWarp", "Mode switch failed: " + err)
        ToastService.showWarning(pluginApi?.tr("toast.title"), err || "Mode switch failed")
      }
      statusDelayTimer.start()
    }
  }

  Process {
    id: connectProcess
    command: ["warp-cli", "--accept-tos", "connect"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode === 0) {
        ToastService.showNotice(
          pluginApi?.tr("toast.title"),
          pluginApi?.tr("toast.connected"),
          "cloud-lock"
        )
      } else {
        var err = String(connectProcess.stderr.text || "").trim()
        Logger.e("CloudflareWarp", "Connect failed: " + err)
        ToastService.showWarning(pluginApi?.tr("toast.title"), err || "Connect failed")
      }
      statusDelayTimer.start()
    }
  }

  Process {
    id: disconnectProcess
    command: ["warp-cli", "--accept-tos", "disconnect"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode === 0) {
        ToastService.showNotice(
          pluginApi?.tr("toast.title"),
          pluginApi?.tr("toast.disconnected"),
          "cloud-off"
        )
      } else {
        var err = String(disconnectProcess.stderr.text || "").trim()
        Logger.e("CloudflareWarp", "Disconnect failed: " + err)
        ToastService.showWarning(pluginApi?.tr("toast.title"), err || "Disconnect failed")
      }
      statusDelayTimer.start()
    }
  }
}
