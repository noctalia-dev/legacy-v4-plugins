import QtQuick
import Quickshell.Io
import qs.Services.UI
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  // ── Public state (accessed by other entry points via pluginApi.mainInstance) ──
  property bool daemonAvailable: false
  property var  devices:         []     // sorted array of device objects
  property var  mainDevice:      null
  property string mainDeviceId:  ""
  property bool   isRefreshing:  false

  // ── Internal ────────────────────────────────────────────────────────────────
  property var _devicesMap: ({})

  readonly property int _stateConnected:     1
  readonly property int _statePaired:        2
  readonly property int _statePairIncoming:  4
  readonly property int _statePairOutgoing:  8

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  Component.onCompleted: {
    _checkAvailability()
  }

  onPluginApiChanged: {
    setMainDevice(pluginApi?.pluginSettings?.mainDeviceId || "")
  }

  // ── IPC toggle ───────────────────────────────────────────────────────────────
  IpcHandler {
    target: "plugin:valent-connect"
    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
      }
    }
  }

  // ── Helper functions (called by other entry points via pluginApi.mainInstance) ─
  function getConnectionStateIcon(device, available) {
    if (!available)
      return "exclamation-circle"
    if (!device || !device.isReachable)
      return "device-mobile-off"
    if (device.notificationIds && device.notificationIds.length > 0)
      return "device-mobile-message"
    if (device.batteryCharging)
      return "device-mobile-charging"
    return "device-mobile"
  }

  function getConnectionStateKey(device, available) {
    if (!available)
      return "control_center.state.unavailable"
    if (!device)
      return "control_center.state.no-device"
    if (!device.isReachable)
      return "control_center.state.disconnected"
    if (!device.isPaired)
      return "control_center.state.not-paired"
    return "control_center.state.connected"
  }

  // ── Object-path escaping ─────────────────────────────────────────────────────
  function escapeObjectPath(id) {
    var result = ""
    for (var i = 0; i < id.length; i++) {
      var c = id.charCodeAt(i)
      if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39)) {
        result += id[i]
      } else {
        var hex = c.toString(16)
        if (hex.length < 2) hex = "0" + hex
        result += "_" + hex
      }
    }
    return result
  }

  function getDevicePath(deviceId) {
    return "/ca/andyholmes/Valent/Device/" + escapeObjectPath(deviceId)
  }

  // ── Service functions ────────────────────────────────────────────────────────
  function setMainDevice(deviceId) {
    mainDeviceId = deviceId || ""
    _updateMainDevice()
  }

  function refreshDevices() {
    if (!daemonAvailable) return
    isRefreshing = true
    _refreshProc.running = true
  }

  property Process _refreshProc: Process {
    command: ["bash", "-c", "gsettings set ca.andyholmes.Valent device-addresses \"['']\"; gsettings set ca.andyholmes.Valent device-addresses \"[]\""]
    onRunningChanged: {
      if (!running) {
        _discoveryDelayTimer.start()
      }
    }
  }

  property Timer _discoveryDelayTimer: Timer {
    interval: 800
    repeat: false
    onTriggered: {
      _getManagedProc.running = false
      _getManagedProc.running = true
    }
  }

  function triggerFindMyPhone(deviceId) { _activate(deviceId, "findmyphone.ring") }
  function pingDevice(deviceId)         { _activate(deviceId, "ping.ping") }
  function browseFiles(deviceId)        { _activate(deviceId, "sftp.browse") }
  function requestPairing(deviceId)     { _activate(deviceId, "pair"); Qt.callLater(refreshDevices) }
  function unpairDevice(deviceId)       { _activate(deviceId, "unpair"); Qt.callLater(refreshDevices) }

  function shareFile(deviceId, filePath) {
    var uri = filePath.indexOf("file://") === 0 ? filePath : "file://" + filePath
    var proc = _actionProcComp.createObject(root, {
      _path:   getDevicePath(deviceId),
      _action: "share.uri",
      _param:  "[<'" + uri.replace(/'/g, "'\"'\"'") + "'>]"
    })
    proc.running = true
  }

  // ── Internal helpers ─────────────────────────────────────────────────────────
  function _checkAvailability() {
    _listNamesProc.running = true
  }

  function _activate(deviceId, actionName) {
    var proc = _actionProcComp.createObject(root, {
      _path:   getDevicePath(deviceId),
      _action: actionName,
      _param:  "@av []"
    })
    proc.running = true
  }

  function _rebuildArray() {
    var arr = []
    var keys = Object.keys(_devicesMap)
    for (var i = 0; i < keys.length; i++) {
      arr.push(_devicesMap[keys[i]])
    }
    arr.sort(function(a, b) { return (a.name || "").localeCompare(b.name || "") })
    devices = arr
    _updateMainDevice()
  }

  function _updateMainDevice() {
    if (!devices || devices.length === 0) {
      mainDevice = null
      return
    }
    var found = null
    for (var i = 0; i < devices.length; i++) {
      if (devices[i].id === mainDeviceId) { found = devices[i]; break }
    }
    if (!found) {
      for (var j = 0; j < devices.length; j++) {
        if (devices[j].isReachable) { found = devices[j]; break }
      }
    }
    if (!found) found = devices[0]
    mainDevice = found
  }

  // ── Process: check if Valent is on the bus ───────────────────────────────────
  property Process _listNamesProc: Process {
    command: ["gdbus", "call", "--session",
              "--dest", "org.freedesktop.DBus",
              "--object-path", "/org/freedesktop/DBus",
              "--method", "org.freedesktop.DBus.ListNames"]
    stdout: StdioCollector {
      onStreamFinished: {
        var found = text.indexOf("ca.andyholmes.Valent") !== -1
        if (found && !root.daemonAvailable) {
          root.daemonAvailable = true
          _getManagedProc.running = true
        } else if (!found) {
          root.daemonAvailable = false
          root._devicesMap  = {}
          root.devices      = []
          root.mainDevice   = null
        }
      }
    }
  }

  // ── Process: GetManagedObjects ───────────────────────────────────────────────
  property Process _getManagedProc: Process {
    command: ["gdbus", "call", "--session",
              "--dest", "ca.andyholmes.Valent",
              "--object-path", "/ca/andyholmes/Valent",
              "--method", "org.freedesktop.DBus.ObjectManager.GetManagedObjects"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.isRefreshing = false
        var raw = text.trim()
        if (raw === "" || raw.indexOf("ca.andyholmes.Valent.Device") === -1) {
          root.daemonAvailable = false
          root._devicesMap = {}
          root.devices     = []
          root.mainDevice  = null
          return
        }

        root.daemonAvailable = true

        var re = /objectpath\s+'([^']+\/Device\/[^']+)'\s*:\s*\{'ca\.andyholmes\.Valent\.Device'\s*:\s*\{([^}]*)\}/g
        var match
        var newMap = {}

        while ((match = re.exec(raw)) !== null) {
          var propsBlock = match[2]

          var idM    = /'Id':\s*<'([^']+)'>/.exec(propsBlock)
          var nameM  = /'Name':\s*<'([^']+)'>/.exec(propsBlock)
          var stateM = /'State':\s*<uint32\s+(\d+)>/.exec(propsBlock)

          var id    = idM    ? idM[1]              : (match[1].split("/Device/")[1] || match[1])
          var name  = nameM  ? nameM[1]            : id
          var state = stateM ? parseInt(stateM[1]) : 0

          var existing = root._devicesMap[id] || {}

          newMap[id] = {
            id:                    id,
            name:                  name,
            isReachable:           (state & root._stateConnected)    !== 0,
            isPaired:              (state & root._statePaired)       !== 0,
            isPairRequested:       (state & root._statePairOutgoing) !== 0,
            isPairRequestedByPeer: (state & root._statePairIncoming) !== 0,
            verificationKey:       "",
            batteryCharge:         existing.batteryCharge   !== undefined ? existing.batteryCharge   : -1,
            batteryCharging:       existing.batteryCharging !== undefined ? existing.batteryCharging  : false,
            networkType:           existing.networkType     !== undefined ? existing.networkType      : "",
            networkStrength:       existing.networkStrength !== undefined ? existing.networkStrength  : -1,
            notificationIds:       []
          }
        }

        root._devicesMap = newMap
        root._rebuildArray()

        // Fetch battery + connectivity for connected+paired devices
        var keys = Object.keys(newMap)
        for (var i = 0; i < keys.length; i++) {
          var dev = newMap[keys[i]]
          if (dev.isPaired && dev.isReachable) {
            root._fetchBattery(keys[i])
            root._fetchConnectivity(keys[i])
          }
        }
      }
    }
  }

  // ── Battery fetch ────────────────────────────────────────────────────────────
  // Output: ((true, signature '', [<{'charging': <false>, 'percentage': <64.0>, ...}>]),)
  function _fetchBattery(deviceId) {
    var proc = _batteryProcComp.createObject(root, { _deviceId: deviceId })
    proc.running = true
  }

  property Component _batteryProcComp: Component {
    Process {
      id: battProc
      property string _deviceId: ""
      command: ["gdbus", "call", "--session",
                "--dest", "ca.andyholmes.Valent",
                "--object-path", root.getDevicePath(_deviceId),
                "--method", "org.gtk.Actions.Describe",
                "battery.state"]
      stdout: StdioCollector {
        onStreamFinished: {
          var pctM = /'percentage':\s*<([0-9.]+)>/.exec(text)
          var chgM = /'charging':\s*<(true|false)>/.exec(text)
          if (pctM && root._devicesMap[battProc._deviceId]) {
            var updated = Object.assign({}, root._devicesMap[battProc._deviceId], {
              batteryCharge:   Math.round(parseFloat(pctM[1])),
              batteryCharging: chgM ? (chgM[1] === "true") : false
            })
            var m = Object.assign({}, root._devicesMap)
            m[battProc._deviceId] = updated
            root._devicesMap = m
            root._rebuildArray()
          }
          root._rebuildArray()
          battProc.destroy()
        }
      }
    }
  }

  // ── Connectivity fetch ───────────────────────────────────────────────────────
  // Output: ((true, signature '', [<{'signal-strengths': <{'1': <{'network-type': <'LTE'>, 'signal-strength': <int64 3>}>}>}>]),)
  function _fetchConnectivity(deviceId) {
    var proc = _connProcComp.createObject(root, { _deviceId: deviceId })
    proc.running = true
  }

  property Component _connProcComp: Component {
    Process {
      id: connProc
      property string _deviceId: ""
      command: ["gdbus", "call", "--session",
                "--dest", "ca.andyholmes.Valent",
                "--object-path", root.getDevicePath(_deviceId),
                "--method", "org.gtk.Actions.Describe",
                "connectivity_report.state"]
      stdout: StdioCollector {
        onStreamFinished: {
          var typeM = /'network-type':\s*<'([^']+)'>/.exec(text)
          var sigM  = /'signal-strength':\s*<(?:int64\s+)?(\d+)>/.exec(text)
          if (root._devicesMap[connProc._deviceId]) {
            var updated = Object.assign({}, root._devicesMap[connProc._deviceId], {
              networkType:     typeM ? typeM[1]          : "",
              networkStrength: sigM  ? parseInt(sigM[1]) : -1
            })
            var m = Object.assign({}, root._devicesMap)
            m[connProc._deviceId] = updated
            root._devicesMap = m
            root._rebuildArray()
          }
          connProc.destroy()
        }
      }
    }
  }

  // ── Action fire-and-forget ───────────────────────────────────────────────────
  property Component _actionProcComp: Component {
    Process {
      id: actProc
      property string _path:   ""
      property string _action: ""
      property string _param:  "@av []"
      command: ["gdbus", "call", "--session",
                "--dest", "ca.andyholmes.Valent",
                "--object-path", _path,
                "--method", "org.gtk.Actions.Activate",
                _action, _param, "{}"]
      stdout: StdioCollector { onStreamFinished: actProc.destroy() }
      stderr: StdioCollector { onStreamFinished: actProc.destroy() }
    }
  }

  // ── Periodic refresh ─────────────────────────────────────────────────────────
  property Timer _refreshTimer: Timer {
    interval: 5000
    running:  true
    repeat:   true
    onTriggered: {
      root._checkAvailability()
    }
  }
}
