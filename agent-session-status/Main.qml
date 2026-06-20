import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string bindAddress: cfg.bindAddress ?? defaults.bindAddress ?? "127.0.0.1"
  readonly property int port: Number(cfg.port ?? defaults.port ?? 55854)
  readonly property string token: cfg.token ?? defaults.token ?? ""
  readonly property int pollIntervalSec: Math.max(1, Number(cfg.pollIntervalSec ?? defaults.pollIntervalSec ?? 2))
  readonly property string serverUrl: "http://" + bindAddress + ":" + port
  readonly property string scriptPath: (pluginApi?.pluginDir || "") + "/server.py"

  property bool serviceRunning: false
  property bool serviceStarting: false
  property string serviceError: ""
  property int runningCount: 0
  property var agents: []
  property int lastUpdatedAt: 0

  Component.onCompleted: {
    Logger.i("AgentSessionStatus", "Plugin loaded")
    restartService()
  }

  Component.onDestruction: {
    stopService()
  }

  Timer {
    id: pollTimer
    interval: root.pollIntervalSec * 1000
    repeat: true
    running: root.serviceRunning
    onTriggered: root.refresh()
  }

  Timer {
    id: restartDelay
    interval: 300
    repeat: false
    onTriggered: root.startService()
  }

  IpcHandler {
    target: "plugin:agent-session-status"

    function refresh() {
      root.refreshAndPrune()
    }

    function restart() {
      root.restartService()
    }

    function toggle() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => {
          root.pluginApi.togglePanel(screen)
        })
      }
    }
  }

  Process {
    id: serviceProcess
    stdout: StdioCollector {
      onStreamFinished: {
        var out = (text || "").trim()
        if (out) Logger.i("AgentSessionStatus", out)
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        var err = (text || "").trim()
        if (err) {
          root.serviceError = err
          Logger.w("AgentSessionStatus", err)
        }
      }
    }
    onStarted: {
      root.serviceStarting = true
      root.serviceError = ""
      pollTimer.restart()
      Qt.callLater(root.refresh)
    }
    onExited: (exitCode, exitStatus) => {
      root.serviceRunning = false
      root.serviceStarting = false
      pollTimer.stop()
      if (exitCode !== 0) {
        root.serviceError = pluginApi?.tr("service.exited", { code: exitCode })
      }
    }
  }

  function startService() {
    if (!pluginApi || serviceProcess.running) return
    if (!root.token || root.token.trim() === "") {
      root.serviceError = pluginApi?.tr("service.missingToken")
      root.serviceRunning = false
      return
    }

    serviceProcess.command = [
      "python3",
      root.scriptPath,
      "--host",
      root.bindAddress,
      "--port",
      root.port.toString(),
      "--token",
      root.token
    ]
    serviceProcess.running = true
  }

  function stopService() {
    if (serviceProcess.running) {
      serviceProcess.signal(15)
      serviceProcess.running = false
    }
    pollTimer.stop()
    serviceRunning = false
  }

  function restartService() {
    stopService()
    runningCount = 0
    agents = []
    lastUpdatedAt = 0
    restartDelay.restart()
  }

  function applySnapshot(payload) {
    root.runningCount = Number(payload.runningCount ?? 0)
    root.agents = payload.agents ?? []
    root.lastUpdatedAt = Number(payload.updatedAt ?? 0)
    root.serviceRunning = true
    root.serviceStarting = false
    root.serviceError = ""
  }

  function refresh() {
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (xhr.status !== 200) {
        root.serviceError = pluginApi?.tr("service.refreshFailed", { status: xhr.status })
        return
      }
      try {
        var payload = JSON.parse(xhr.responseText)
        root.applySnapshot(payload)
      } catch (e) {
        root.serviceError = pluginApi?.tr("service.badResponse")
      }
    }
    xhr.onerror = function() {
      root.serviceError = pluginApi?.tr("service.unreachable")
    }
    xhr.open("GET", root.serverUrl + "/sessions")
    xhr.send()
  }

  function refreshAndPrune() {
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (xhr.status !== 200) {
        root.serviceError = pluginApi?.tr("service.refreshFailed", { status: xhr.status })
        return
      }
      try {
        var payload = JSON.parse(xhr.responseText)
        root.applySnapshot(payload.snapshot ?? payload)
      } catch (e) {
        root.serviceError = pluginApi?.tr("service.badResponse")
      }
    }
    xhr.onerror = function() {
      root.serviceError = pluginApi?.tr("service.unreachable")
    }
    xhr.open("POST", root.serverUrl + "/sessions/prune-inactive")
    xhr.setRequestHeader("Authorization", "Bearer " + root.token)
    xhr.send()
  }
}
