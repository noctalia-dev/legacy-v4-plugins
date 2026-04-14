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
    { "HostName": "mock-linux-box",          "DNSName": "mock-linux-box.tail1234.ts.net.",          "TailscaleIPs": ["100.64.0.1"], "Online": true,  "OS": "linux",   "Tags": [], "ExitNodeOption": true,  "ExitNode": false },
    { "HostName": "mock-mac",                "DNSName": "mock-mac.tail1234.ts.net.",                "TailscaleIPs": ["100.64.0.2"], "Online": true,  "OS": "macos",   "Tags": [], "ExitNodeOption": false, "ExitNode": false },
    { "HostName": "mock-win-pc",             "DNSName": "mock-win-pc.tail1234.ts.net.",             "TailscaleIPs": ["100.64.0.3"], "Online": false, "OS": "windows", "Tags": [], "ExitNodeOption": false, "ExitNode": false },
    { "HostName": "google-pixel-9-pro-xl",   "DNSName": "google-pixel-9-pro-xl.tail1234.ts.net.",   "TailscaleIPs": ["100.64.0.4"], "Online": true,  "OS": "android", "Tags": [], "ExitNodeOption": false, "ExitNode": false }
  ]

  readonly property var peerList: useMockData ? mockPeerList : _realPeerList

  // Helper to filter IPv4 addresses from Tailscale (100.x.x.x range)
  function filterIPv4(ips) {
    if (!ips || !ips.length) return []
    return ips.filter(ip => ip.startsWith("100."))
  }

  // Some devices (e.g. Android) report "localhost" as their HostName.
  // In that case, derive a meaningful name from the first label of DNSName.
  function resolveHostName(hostName, dnsName) {
    if (hostName && hostName.toLowerCase() !== "localhost") return hostName
    if (!dnsName) return hostName
    var label = dnsName.split(".")[0]
    return label || hostName
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
                  "HostName": resolveHostName(peer.HostName, peer.DNSName),
                  "DNSName": peer.DNSName,
                  "TailscaleIPs": ipv4s,
                  "Online": peer.Online,
                  "OS": peer.OS,
                  "Tags": peer.Tags || [],
                  "ExitNodeOption": peer.ExitNodeOption || false,
                  "ExitNode": peer.ExitNode || false
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

  Process {
    id: exitNodeProcess
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        var message = root.lastExitNodeAction === "set" ?
          pluginApi?.tr("toast.exit-node-enabled") :
          pluginApi?.tr("toast.exit-node-disabled")
        ToastService.showNotice(
          pluginApi?.tr("toast.title"),
          message,
          "globe"
        )
      }
      statusDelayTimer.start()
    }
  }

  property string lastExitNodeAction: ""

  // ─── Taildrop state ──────────────────────────────────────────────────────

  // Possible values: "idle", "receiving", "sending", "error"
  property string taildropState: "idle"
  property string taildropMessage: ""

  readonly property string _homeDir: Quickshell.env("HOME") ?? ""

  function _expandPath(path) {
    if (!path) return path
    if (path.startsWith("~/")) return _homeDir + path.substring(1)
    return path
  }

  readonly property bool taildropEnabled:
    pluginApi?.pluginSettings?.taildropEnabled ??
    pluginApi?.manifest?.metadata?.defaultSettings?.taildropEnabled ??
    true

  readonly property string taildropDownloadDir:
    _expandPath(
      pluginApi?.pluginSettings?.taildropDownloadDir ||
      pluginApi?.manifest?.metadata?.defaultSettings?.taildropDownloadDir ||
      "~/Downloads"
    )

  // "operator" = no priv-esc (requires `sudo tailscale set --operator $USER`)
  // "pkexec"   = use pkexec to run as root
  readonly property string taildropReceiveMode:
    pluginApi?.pluginSettings?.taildropReceiveMode ||
    pluginApi?.manifest?.metadata?.defaultSettings?.taildropReceiveMode ||
    "operator"

  // Snapshot of filenames in download dir taken just before receive starts
  property var _preScanFiles: []

  Process {
    id: preScanProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode === 0) {
        var raw = String(preScanProcess.stdout.text || "").trim()
        root._preScanFiles = raw.length > 0 ? raw.split("\n") : []
      } else {
        root._preScanFiles = []
      }
      Logger.d("Tailscale", "Pre-scan: " + root._preScanFiles.length + " files")
      // Now start the actual receive
      var dir = root.taildropDownloadDir
      if (root.taildropReceiveMode === "pkexec") {
        taildropReceiveProcess.command = ["pkexec", "tailscale", "file", "get", dir]
      } else {
        taildropReceiveProcess.command = ["tailscale", "file", "get", dir]
      }
      taildropReceiveProcess.running = true
    }
  }

  Process {
    id: postScanProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      var newFiles = []
      if (exitCode === 0) {
        var raw = String(postScanProcess.stdout.text || "").trim()
        var postFiles = raw.length > 0 ? raw.split("\n") : []
        var preSet = {}
        for (var i = 0; i < root._preScanFiles.length; i++) {
          preSet[root._preScanFiles[i]] = true
        }
        for (var j = 0; j < postFiles.length; j++) {
          if (!preSet[postFiles[j]]) {
            newFiles.push(postFiles[j])
          }
        }
      }
      Logger.i("Tailscale", "Taildrop received " + newFiles.length + " new file(s)")
      if (newFiles.length > 0) {
        ToastService.showNotice(
          pluginApi?.tr("toast.title"),
          newFiles.join("\n"),
          "file-download"
        )
      } else {
        ToastService.showWarning(
          pluginApi?.tr("toast.title"),
          pluginApi?.tr("taildrop.toast.no-files")
        )
      }
    }
  }

  Process {
    id: taildropReceiveProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onStarted: {
      root.taildropState = "receiving"
      root.taildropMessage = ""
      Logger.i("Tailscale", "Taildrop receive started in: " + root.taildropDownloadDir)
    }

    onExited: function(exitCode, exitStatus) {
      var stderr = String(taildropReceiveProcess.stderr.text || "").trim()
      var stdout = String(taildropReceiveProcess.stdout.text || "").trim()
      var allOutput = (stderr + "\n" + stdout).trim()
      if (exitCode === 0) {
        root.taildropState = "idle"
        root.taildropMessage = ""
        // Scan post-receive to diff new files
        postScanProcess.command = ["ls", "-1", root.taildropDownloadDir]
        postScanProcess.running = true
        Logger.i("Tailscale", "Taildrop receive completed, running post-scan")
      } else {
        root.taildropState = "error"
        var isDuplicateFile = allOutput.indexOf("file exists") !== -1
          || allOutput.indexOf("refusing to overwrite") !== -1
          || /moved 0\/\d+ files/.test(allOutput)
        root.taildropMessage = isDuplicateFile
          ? pluginApi?.tr("taildrop.error.file-exists")
          : allOutput || pluginApi?.tr("taildrop.error.unknown")
        ToastService.showError(
          pluginApi?.tr("toast.title"),
          root.taildropMessage,
          "file-x"
        )
        Logger.e("Tailscale", "Taildrop receive failed (exit " + exitCode + "): " + allOutput)
      }
    }
  }

  Process {
    id: taildropSendProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onStarted: {
      root.taildropState = "sending"
      root.taildropMessage = ""
      Logger.i("Tailscale", "Taildrop send started")
    }

    onExited: function(exitCode, exitStatus) {
      var stderr = String(taildropSendProcess.stderr.text || "").trim()
      if (exitCode === 0) {
        root.taildropState = "idle"
        root.taildropMessage = ""
        ToastService.showNotice(
          pluginApi?.tr("toast.title"),
          pluginApi?.tr("taildrop.toast.sent"),
          "file-upload"
        )
        Logger.i("Tailscale", "Taildrop send completed successfully")
      } else {
        root.taildropState = "error"
        root.taildropMessage = stderr || pluginApi?.tr("taildrop.error.unknown")
        ToastService.showError(
          pluginApi?.tr("toast.title"),
          root.taildropMessage,
          "file-x"
        )
        Logger.e("Tailscale", "Taildrop send failed (exit " + exitCode + "): " + root.taildropMessage)
      }
    }
  }

  function startTaildropReceive() {
    if (!root.tailscaleInstalled || !root.tailscaleRunning) {
      Logger.w("Tailscale", "Cannot start receive: tailscale not running")
      return
    }
    if (!root.taildropEnabled) {
      Logger.w("Tailscale", "Taildrop is disabled in settings")
      return
    }
    if (root.taildropState === "receiving") {
      Logger.w("Tailscale", "Already receiving")
      return
    }
    // Pre-scan the download dir; the scan's onExited launches the actual receive
    preScanProcess.command = ["ls", "-1", root.taildropDownloadDir]
    preScanProcess.running = true
  }

  // files: array of local file paths, peerTarget: "hostname:" or "ip:"
  function sendFilesViaTaildrop(files, peerTarget) {
    if (!root.tailscaleInstalled || !root.tailscaleRunning) {
      Logger.w("Tailscale", "Cannot send: tailscale not running")
      return
    }
    if (!root.taildropEnabled) {
      Logger.w("Tailscale", "Taildrop is disabled in settings")
      return
    }
    if (!files || files.length === 0) {
      Logger.w("Tailscale", "No files to send")
      return
    }
    if (root.taildropState === "sending") {
      Logger.w("Tailscale", "Already sending files")
      return
    }
    var cmd = ["tailscale", "file", "cp"]
    for (var i = 0; i < files.length; i++) {
      cmd.push(files[i])
    }
    cmd.push(peerTarget)
    taildropSendProcess.command = cmd
    taildropSendProcess.running = true
  }

  function setExitNode(ip) {
    if (!root.tailscaleInstalled || !root.tailscaleRunning) return
    root.lastExitNodeAction = "set"
    exitNodeProcess.command = ["tailscale", "set", "--exit-node=" + ip]
    exitNodeProcess.running = true
  }

  function clearExitNode() {
    if (!root.tailscaleInstalled || !root.tailscaleRunning) return
    root.lastExitNodeAction = "clear"
    exitNodeProcess.command = ["tailscale", "set", "--exit-node="]
    exitNodeProcess.running = true
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

		function togglePanel() {
			pluginApi.withCurrentScreen(screen => {
				pluginApi.togglePanel(screen);
			});
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

    // Taildrop IPC: qs ipc call plugin:tailscale receive
    function receive() {
      startTaildropReceive()
    }

    // Dev/testing: toggle mock peer list to reproduce few-device layouts.
    // Usage: qs -c noctalia-shell ipc call plugin:tailscale setMockPeers
    function setMockPeers() {
      root.useMockData = !root.useMockData
      Logger.d("Tailscale", "Mock peer data " + (root.useMockData ? "enabled" : "disabled"))
    }
  }
}
