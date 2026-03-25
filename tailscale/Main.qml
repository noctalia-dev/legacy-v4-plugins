import QtQuick
import Quickshell
import qs.Commons
import Quickshell.Io
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  onPluginApiChanged: {
    if (pluginApi) {
      settingsVersion++
    }
  }

  // Watch for settings changes (when pluginSettings object is replaced)
  property var settingsWatcher: pluginApi?.pluginSettings
  onSettingsWatcherChanged: {
    if (settingsWatcher) {
      settingsVersion++
    }
  }

  property int settingsVersion: 0

  property int refreshInterval: _computeRefreshInterval()
  property bool compactMode: _computeCompactMode()
  property bool showIpAddress: _computeShowIpAddress()
  property bool showPeerCount: _computeShowPeerCount()

  function _computeRefreshInterval() { return pluginApi?.pluginSettings?.refreshInterval ?? 5000; }
  function _computeCompactMode() { return pluginApi?.pluginSettings?.compactMode ?? false; }
  function _computeShowIpAddress() { return pluginApi?.pluginSettings?.showIpAddress ?? true; }
  function _computeShowPeerCount() { return pluginApi?.pluginSettings?.showPeerCount ?? true; }

  onSettingsVersionChanged: {
    refreshInterval = _computeRefreshInterval()
    compactMode = _computeCompactMode()
    showIpAddress = _computeShowIpAddress()
    showPeerCount = _computeShowPeerCount()
    updateTimer.interval = refreshInterval
  }

  property bool tailscaleInstalled: false
  property bool tailscaleRunning: false
  property string tailscaleIp: ""
  property string tailscaleStatus: ""
  property int peerCount: 0
  property bool isRefreshing: false
  property string lastToggleAction: ""
  property var _realPeerList: []
  property var exitNodeStatus: null

  // Dev/testing: override the peer list with a short mock to reproduce few-device layouts.
  // Toggle via: qs -c noctalia-shell ipc call plugin:tailscale setMockPeers
  property bool useMockData: false
  readonly property var mockPeerList: [
    { "HostName": "mock-linux-box", "DNSName": "mock-linux-box.tail1234.ts.net.", "TailscaleIPs": ["100.64.0.1"], "Online": true,  "OS": "linux", "Tags": [] },
    { "HostName": "mock-mac",       "DNSName": "mock-mac.tail1234.ts.net.",       "TailscaleIPs": ["100.64.0.2"], "Online": true,  "OS": "macos", "Tags": [] },
    { "HostName": "mock-win-pc",    "DNSName": "mock-win-pc.tail1234.ts.net.",    "TailscaleIPs": ["100.64.0.3"], "Online": false, "OS": "windows", "Tags": [] }
  ]

  readonly property var peerList: useMockData ? mockPeerList : _realPeerList

  // Helper to filter IPv4 addresses from Tailscale (100.x.x.x range)
  function filterIPv4(ips) {
    if (!ips || !ips.length) return []
    return ips.filter(ip => ip.startsWith("100."))
  }

  Process {
    id: whichProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode, exitStatus) {
      root.tailscaleInstalled = (exitCode === 0)
      root.isRefreshing = false
      updateTailscaleStatus()
    }
  }

  Process {
    id: statusProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode, exitStatus) {
      root.isRefreshing = false
      var stdout = String(statusProcess.stdout.text || "").trim()
      var stderr = String(statusProcess.stderr.text || "").trim()

      if (exitCode === 0 && stdout && stdout.length > 0) {
        try {
          var data = JSON.parse(stdout)
          root.tailscaleRunning = data.BackendState === "Running"

          if (root.tailscaleRunning && data.Self && data.Self.TailscaleIPs && data.Self.TailscaleIPs.length > 0) {
            root.tailscaleIp = filterIPv4(data.Self.TailscaleIPs)[0] || data.Self.TailscaleIPs[0]
            root.tailscaleStatus = "Connected"

            var peers = []
            if (data.Peer) {
              for (var peerId in data.Peer) {
                var peer = data.Peer[peerId]
                var ipv4s = filterIPv4(peer.TailscaleIPs)
                peers.push({
                  "HostName": peer.HostName,
                  "DNSName": peer.DNSName,
                  "TailscaleIPs": ipv4s,
                  "Online": peer.Online,
                  "OS": peer.OS,
                  "Tags": peer.Tags || []
                })
              }
            }
            root._realPeerList = peers
            root.peerCount = peers.length

            // Extract exit node status if present
            if (data.ExitNodeStatus) {
              root.exitNodeStatus = {
                "ID": data.ExitNodeStatus.ID || "",
                "Online": data.ExitNodeStatus.Online || false,
                "TailscaleIPs": data.ExitNodeStatus.TailscaleIPs || []
              }
            } else {
              root.exitNodeStatus = null
            }
          } else {
            root.tailscaleIp = ""
            root.tailscaleStatus = root.tailscaleRunning ? "Connected" : "Disconnected"
            root.peerCount = 0
            root._realPeerList = []
            root.exitNodeStatus = null
          }
        } catch (e) {
          Logger.e("Tailscale", "Failed to parse status: " + e)
          root.tailscaleRunning = false
          root.tailscaleStatus = "Error"
          root._realPeerList = []
        }
      } else {
        root.tailscaleRunning = false
        root.tailscaleStatus = "Disconnected"
        root.tailscaleIp = ""
        root.peerCount = 0
        root._realPeerList = []
      }
    }
  }

  Process {
    id: toggleProcess
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        var message = root.lastToggleAction === "connect" ?
          pluginApi?.tr("toast.connected") :
          pluginApi?.tr("toast.disconnected")
        ToastService.showNotice(
          pluginApi?.tr("toast.title"),
          message,
          "network"
        )
      }

      statusDelayTimer.start()
    }
  }

  Timer {
    id: statusDelayTimer
    interval: 500
    repeat: false
    onTriggered: {
      root.isRefreshing = false
      updateTailscaleStatus()
    }
  }

  function checkTailscaleInstalled() {
    root.isRefreshing = true
    whichProcess.command = ["which", "tailscale"]
    whichProcess.running = true
  }

  function updateTailscaleStatus() {
    if (!root.tailscaleInstalled) {
      root.tailscaleRunning = false
      root.tailscaleIp = ""
      root.tailscaleStatus = "Not installed"
      root.peerCount = 0
      return
    }

    root.isRefreshing = true
    statusProcess.command = ["tailscale", "status", "--json"]
    statusProcess.running = true
  }

  function toggleTailscale() {
    if (!root.tailscaleInstalled) return

    root.isRefreshing = true
    if (root.tailscaleRunning) {
      root.lastToggleAction = "disconnect"
      toggleProcess.command = ["tailscale", "down"]
    } else {
      root.lastToggleAction = "connect"
      toggleProcess.command = ["tailscale", "up"]
    }
    toggleProcess.running = true
  }

  Timer {
    id: updateTimer
    interval: refreshInterval
    repeat: true
    running: true
    triggeredOnStart: true

    onTriggered: {
      if (root.tailscaleInstalled === false) {
        checkTailscaleInstalled()
      } else {
        updateTailscaleStatus()
      }
    }
  }

  Component.onCompleted: {
    checkTailscaleInstalled()
  }

  IpcHandler {
    target: "plugin:tailscale"

    function toggle() {
      toggleTailscale()
    }

    function status() {
      return {
        "installed": root.tailscaleInstalled,
        "running": root.tailscaleRunning,
        "ip": root.tailscaleIp,
        "status": root.tailscaleStatus,
        "peers": root.peerCount
      }
    }

    function refresh() {
      updateTailscaleStatus()
    }

    // Dev/testing: toggle mock peer list to reproduce few-device layouts.
    // Usage: qs -c noctalia-shell ipc call plugin:tailscale setMockPeers
    function setMockPeers() {
      root.useMockData = !root.useMockData
      Logger.d("Tailscale", "Mock peer data " + (root.useMockData ? "enabled" : "disabled"))
    }
  }
}
