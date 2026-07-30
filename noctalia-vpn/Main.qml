import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

/*
  Owns the dbus-bridge.py child process and exposes backend state as properties
  for BarWidget.qml / Panel.qml to bind to. All mutating actions funnel through
  callBackend(method, args, onResult). Signals from the backend (StatusChanged,
  TrafficUpdate, etc.) arrive through bridgeProc.stdout as JSON events.

  Lifecycle: bridge launches at plugin start; if the daemon isn't yet on the
  bus, the bridge spawns it. On bridge exit we restart with a small backoff.
*/
Item {
    id: root

    property var pluginApi: null

    // ── Connection state ────────────────────────────────────────────────────
    property bool bridgeReady: false
    property string bridgeStatus: "starting"  // starting | ready | error

    // ── Backend state (mirrors GetStatus + GetHealth + GetTrafficStats) ─────
    property bool running: false
    property string activeServerId: ""
    property string mode: "rules"          // rules | global
    property string proxyMode: "system"    // system | tun
    property int transportPort: 11080
    property int muxPort: 11081
    property string statusLevel: "ok"      // ok | degraded | failed | error
    property string statusReason: ""
    property string statusMessage: ""

    property int healthLatencyMs: -1
    property int healthJitterMs: -1
    property real healthDownMbps: -1
    property real healthUpMbps: -1
    property string healthSpeedTakenAt: ""
    property string healthLastCheck: ""
    property int healthConsecutiveFailures: 0
    property string healthStatus: "ok"

    property int trafficSent: 0
    property int trafficRecv: 0
    property int trafficUptime: 0
    property int trafficConnections: 0

    // ── User preferences (mirrored from backend settings via GetSettings) ───
    property bool showPingInBar: true
    property bool showTrafficInBar: false

    // ── Data lists ──────────────────────────────────────────────────────────
    property var servers: []           // list of server dicts
    property var rules: []             // list of routing rules
    property var presets: []           // [{key, name, flag, description, enabled}]
    property var subscriptions: []     // list of subscription dicts
    property var logs: []              // last N log lines (strings)
    property var killSwitch: ({ enabled: false, active: false })

    // ── Pending requests ────────────────────────────────────────────────────
    property int nextRequestId: 1
    property var pending: ({})          // id → onResult callback

    // ── Activity transient (used by Panel for an in-flight indicator) ───────
    property int inFlight: 0
    property bool busy: inFlight > 0

    readonly property string pluginDir: {
        if (pluginApi && pluginApi.pluginDir) {
            return pluginApi.pluginDir.toString().replace(/^file:\/\//, "")
        }
        return Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
    }

    readonly property string bridgePath: pluginDir + "/dbus-bridge.py"
    readonly property string venvPython: "/home/ubn/dev/noctalia-vpn-plugin/.venv/bin/python3"

    // ── Bridge process ─────────────────────────────────────────────────────
    Process {
        id: bridgeProc
        command: [root.venvPython, root.bridgePath]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => root.handleBridgeLine(data)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data && data.length > 0) {
                    Logger.w("noctalia-vpn", "bridge stderr: " + data)
                }
            }
        }
    }

    Connections {
        target: bridgeProc
        function onRunningChanged() {
            if (!bridgeProc.running) {
                root.bridgeReady = false
                root.bridgeStatus = "starting"
                root.running = false
                bridgeRestartTimer.start()
            }
        }
    }

    Timer {
        id: bridgeRestartTimer
        interval: 1500
        repeat: false
        onTriggered: { if (!bridgeProc.running) bridgeProc.running = true }
    }

    // ── Refresh polling (periodic GetStatus + GetHealth) ───────────────────
    Timer {
        id: refreshTimer
        interval: 2000
        repeat: true
        running: root.bridgeReady
        onTriggered: root.refreshAll()
    }

    // ── Line handler ───────────────────────────────────────────────────────
    function handleBridgeLine(line) {
        const t = (line || "").trim()
        if (!t) return
        let obj = null
        try { obj = JSON.parse(t) } catch (e) {
            Logger.w("noctalia-vpn", "bad bridge line: " + t)
            return
        }

        if (obj.event !== undefined) {
            handleEvent(obj.event, obj.data)
        } else if (obj.id !== undefined) {
            const cb = root.pending[obj.id]
            if (cb) {
                try {
                    cb(obj.error || null, obj.result === undefined ? null : obj.result)
                } catch (e) {
                    Logger.w("noctalia-vpn", "callback threw: " + e)
                }
                delete root.pending[obj.id]
            }
            if (root.inFlight > 0) root.inFlight = root.inFlight - 1
        }
    }

    function handleEvent(event, data) {
        switch (event) {
        case "ready":
            root.bridgeReady = true
            root.bridgeStatus = "ready"
            refreshAll()
            refreshServers()
            refreshRules()
            refreshSubscriptions()
            refreshKillSwitch()
            refreshSettings()
            refreshPresets()
            break
        case "error":
            root.bridgeStatus = "error"
            if (typeof ToastService !== "undefined") {
                ToastService.showWarning("VPN bridge: " + (data && data.message || "error"))
            }
            break
        case "exit":
            root.bridgeReady = false
            root.bridgeStatus = "starting"
            break
        case "StatusChanged":
            applyStatus(data || {})
            break
        case "ServerListChanged":
            refreshServers()
            break
        case "LogMessage":
            if (data && data.message) {
                const arr = root.logs.slice()
                arr.push(data.message)
                if (arr.length > 200) arr.splice(0, arr.length - 200)
                root.logs = arr
            }
            break
        case "TrafficUpdate":
            applyTraffic(data || {})
            break
        }
    }

    // ── State application helpers ──────────────────────────────────────────
    function applyStatus(s) {
        root.running         = s.running === true
        root.activeServerId  = s.activeServerId || root.activeServerId
        root.mode            = s.mode || root.mode
        root.proxyMode       = s.proxyMode || root.proxyMode
        if (s.transportPort !== undefined) root.transportPort = s.transportPort
        if (s.muxPort !== undefined && s.muxPort !== null) root.muxPort = s.muxPort
        root.statusLevel     = s.status || "ok"
        root.statusReason    = s.reason || ""
        root.statusMessage   = s.message || ""
    }

    function applyTraffic(t) {
        root.trafficSent        = t.bytes_sent || 0
        root.trafficRecv        = t.bytes_received || 0
        root.trafficUptime      = t.uptime_seconds || 0
        root.trafficConnections = t.connection_count || 0
    }

    // ── Public callBackend (used by everywhere) ────────────────────────────
    function callBackend(method, args, onResult) {
        if (!bridgeReady) {
            if (onResult) onResult("bridge not ready", null)
            return -1
        }
        const id = root.nextRequestId
        root.nextRequestId = id + 1
        root.pending[id] = onResult || null
        root.inFlight = root.inFlight + 1
        const payload = JSON.stringify({ id: id, method: method, args: args || [] }) + "\n"
        try {
            bridgeProc.write(payload)
        } catch (e) {
            Logger.w("noctalia-vpn", "bridge write failed: " + e)
            delete root.pending[id]
            if (root.inFlight > 0) root.inFlight = root.inFlight - 1
        }
        return id
    }

    // ── Pollers ────────────────────────────────────────────────────────────
    function refreshAll() {
        callBackend("GetStatus", [], function(err, res) { if (!err) applyStatus(res || {}) })
        callBackend("GetHealth", [], function(err, res) {
            if (err || !res) return
            root.healthLatencyMs           = res.latency_ms !== undefined ? res.latency_ms : -1
            root.healthJitterMs            = res.jitter_ms !== undefined ? res.jitter_ms : -1
            root.healthDownMbps            = res.down_mbps !== undefined ? res.down_mbps : -1
            root.healthUpMbps              = res.up_mbps !== undefined ? res.up_mbps : -1
            root.healthSpeedTakenAt        = res.speed_taken_at || ""
            root.healthLastCheck           = res.last_check || ""
            root.healthConsecutiveFailures = res.consecutive_failures || 0
            root.healthStatus              = res.status || "ok"
        })
        if (root.running) {
            callBackend("GetTrafficStats", [], function(err, res) { if (!err) applyTraffic(res || {}) })
        }
    }

    function refreshServers() {
        callBackend("GetServers", [], function(err, res) {
            if (!err && Array.isArray(res)) root.servers = res
        })
    }

    function refreshRules() {
        callBackend("GetRoutingRules", [], function(err, res) {
            if (!err && Array.isArray(res)) root.rules = res
        })
    }

    function refreshSubscriptions() {
        callBackend("GetSubscriptions", [], function(err, res) {
            if (!err && Array.isArray(res)) root.subscriptions = res
        })
    }

    function refreshKillSwitch() {
        callBackend("GetKillSwitchStatus", [], function(err, res) {
            if (!err && res) root.killSwitch = res
        })
    }

    function refreshSettings() {
        callBackend("GetSettings", [], function(err, res) {
            if (err || !res) return
            if (res.showPingInBar !== undefined)    root.showPingInBar    = res.showPingInBar === true
            if (res.showTrafficInBar !== undefined) root.showTrafficInBar = res.showTrafficInBar === true
        })
    }

    function updateBackendSettings(patch) {
        callBackend("UpdateSettings", [patch], function(err, res) {
            if (err || !res) { if (err) toastWarn(err); return }
            if (res.showPingInBar !== undefined)    root.showPingInBar    = res.showPingInBar === true
            if (res.showTrafficInBar !== undefined) root.showTrafficInBar = res.showTrafficInBar === true
        })
    }

    function setShowPingInBar(on) {
        root.showPingInBar = !!on
        updateBackendSettings({ showPingInBar: !!on })
    }

    function setShowTrafficInBar(on) {
        root.showTrafficInBar = !!on
        updateBackendSettings({ showTrafficInBar: !!on })
    }

    // ── Convenience actions used by Panel/Bar ──────────────────────────────
    function startProxy(serverId, mode, proxyMode) {
        callBackend("StartProxy",
                    [serverId, mode || root.mode, proxyMode || root.proxyMode],
                    function(err, res) {
            if (err) toastWarn(err)
            else if (res !== true) toastWarn(root.statusMessage || "Failed to start proxy")
        })
    }

    function stopProxy() {
        callBackend("StopProxy", [], function(err) { if (err) toastWarn(err) })
    }

    function toggleProxy() {
        if (root.running) {
            stopProxy()
        } else if (root.activeServerId) {
            startProxy(root.activeServerId, root.mode, root.proxyMode)
        } else if (root.servers && root.servers.length > 0) {
            root.activeServerId = root.servers[0].id
            startProxy(root.activeServerId, root.mode, root.proxyMode)
        } else {
            toastWarn("No servers configured")
        }
    }

    function setMode(m) {
        if (m === root.mode) return
        root.mode = m
        callBackend("SetMode", [m], function(err) { if (err) toastWarn(err) })
    }

    function setProxyMode(pm) {
        if (pm === root.proxyMode) return
        if (pm === "tun" && typeof ToastService !== "undefined") {
            ToastService.showNotice("VPN mode requires administrator privileges")
        }
        root.proxyMode = pm
        callBackend("SetProxyMode", [pm], function(err) { if (err) toastWarn(err) })
    }

    function selectServer(id) {
        root.activeServerId = id
        callBackend("SwitchServer", [id], function(err) { if (err) toastWarn(err) })
    }

    function pingServer(id, onDone) {
        callBackend("PingServer", [id], function(err, res) {
            if (onDone) onDone(err ? -1 : (res || -1))
        })
    }

    function runSpeedTest(onDone) {
        callBackend("RunSpeedTest", [], function(err, res) {
            if (!err && res) {
                if (res.down_mbps !== undefined) root.healthDownMbps  = res.down_mbps
                if (res.up_mbps   !== undefined) root.healthUpMbps    = res.up_mbps
                if (res.ping_ms   !== undefined) root.healthLatencyMs = res.ping_ms
                if (res.jitter_ms !== undefined) root.healthJitterMs  = res.jitter_ms
            }
            if (onDone) onDone(err, res)
        })
    }

    function addServer(payload, onDone) {
        callBackend("AddServer", [payload], function(err, res) {
            if (err) toastWarn(err)
            else refreshServers()
            if (onDone) onDone(err, res)
        })
    }

    function updateServer(payload, onDone) {
        callBackend("UpdateServer", [payload], function(err, res) {
            if (err) toastWarn(err)
            else refreshServers()
            if (onDone) onDone(err, res)
        })
    }

    function removeServer(id) {
        callBackend("RemoveServer", [id], function(err) {
            if (err) toastWarn(err)
            else refreshServers()
        })
    }

    function addRule(rule, onDone) {
        callBackend("AddRoutingRule", [rule], function(err, res) {
            if (err) toastWarn(err)
            else refreshRules()
            if (onDone) onDone(err, res)
        })
    }

    function removeRule(id) {
        callBackend("RemoveRoutingRule", [id], function(err) {
            if (err) toastWarn(err)
            else refreshRules()
        })
    }

    function refreshPresets() {
        callBackend("GetPresets", [], function(err, res) {
            if (!err && Array.isArray(res)) root.presets = res
        })
    }

    function togglePreset(key, enabled) {
        // optimistic UI: flip the local flag immediately so the toggle reacts
        let next = []
        for (var i = 0; i < root.presets.length; ++i) {
            let p = root.presets[i]
            if (p.key === key) {
                next.push(Object.assign({}, p, { enabled: !!enabled }))
            } else {
                next.push(p)
            }
        }
        root.presets = next
        callBackend("TogglePreset", [key, !!enabled], function(err, res) {
            if (err || res !== true) {
                if (err) toastWarn(err)
                refreshPresets()  // rollback / resync
            }
        })
    }

    function setKillSwitch(enabled) {
        callBackend("SetKillSwitch", [enabled], function(err, res) {
            if (err) toastWarn(err)
            refreshKillSwitch()
            if (!err && res !== true) {
                toastWarn("Kill switch install failed (needs root or polkit agent)")
            }
        })
    }

    function addSubscription(url, name, onDone) {
        callBackend("AddSubscription", [url, name || ""], function(err, ok) {
            if (err) toastWarn(err)
            else refreshSubscriptions()
            if (onDone) onDone(err, ok)
        })
    }

    function updateSubscription(url, onDone) {
        callBackend("UpdateSubscription", [url], function(err, count) {
            if (err) toastWarn(err)
            else {
                refreshSubscriptions()
                refreshServers()
                if (typeof ToastService !== "undefined") {
                    ToastService.showNotice("Imported " + (count || 0) + " new servers")
                }
            }
            if (onDone) onDone(err, count)
        })
    }

    function removeSubscription(url) {
        callBackend("RemoveSubscription", [url], function(err) {
            if (err) toastWarn(err)
            else refreshSubscriptions()
        })
    }

    // ── Utilities ──────────────────────────────────────────────────────────
    function serverById(id) {
        const list = root.servers || []
        for (let i = 0; i < list.length; ++i) if (list[i].id === id) return list[i]
        return null
    }

    function activeServer() { return serverById(root.activeServerId) }

    function toastWarn(text) {
        if (typeof ToastService !== "undefined") ToastService.showWarning(String(text))
        else Logger.w("noctalia-vpn", "" + text)
    }

    function formatBytes(n) {
        if (!n || n < 1024) return (n || 0) + " B"
        const u = ["KiB","MiB","GiB","TiB"]
        let i = -1
        do { n /= 1024.0; ++i } while (n >= 1024 && i < u.length - 1)
        return n.toFixed(n < 10 ? 2 : 1) + " " + u[i]
    }

    function formatDuration(sec) {
        sec = Math.max(0, sec | 0)
        if (sec < 60) return sec + "s"
        if (sec < 3600) return (sec / 60 | 0) + "m " + (sec % 60) + "s"
        const h = sec / 3600 | 0
        const m = (sec % 3600) / 60 | 0
        return h + "h " + m + "m"
    }

    function pingColor(ms) {
        if (ms === undefined || ms === null || ms < 0) return Color.mOnSurfaceVariant
        if (ms < 60)  return Color.mTertiary  // green-ish
        if (ms < 150) return Color.mSecondary // mid
        return Color.mError
    }

    // ── IPC for noctalia ctl ──────────────────────────────────────────────
    IpcHandler {
        target: "plugin:noctalia-vpn"

        function toggle(): void              { root.toggleProxy() }
        function setMode(m: string): void    { root.setMode(m) }
        function setProxyMode(m: string): void { root.setProxyMode(m) }
        function status(): string {
            return JSON.stringify({
                running:    root.running,
                mode:       root.mode,
                proxyMode:  root.proxyMode,
                server:     root.activeServer() ? root.activeServer().name : "",
                latencyMs:  root.healthLatencyMs
            })
        }
    }
}
