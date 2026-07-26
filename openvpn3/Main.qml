import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

QtObject {
    id: root

    property var pluginSettings: pluginApi?.pluginSettings ?? ({})

    readonly property var toast: ToastService
    readonly property bool showNotifications: pluginSettings.showNotifications ?? true
    readonly property int pollInterval: (pluginSettings.pollInterval ?? 5) * 1000

    property var pluginApi: null

    property var configList: []
    property var sessionList: []
    property var configDetails: ({})
    property var sessionStats: ({})
    property var configDump: ({})
    property var sessionLogs: []
    property bool logStreamActive: false
    readonly property int maxLogs: 100
    property real connectedCount: 0
    readonly property bool isLoading: Object.keys(root._pending).length > 0
    readonly property bool panelOpen: pluginApi?.panelOpenScreen != null

    property var _pending: ({})

    // ==================== Two-tier polling ====================
    // Light timer: configs + sessions only (keeps bar widget updated)
    property var _lightTimer: Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Heavy timer: stats + details + logs (only when panel is open)
    property var _heavyTimer: Timer {
        interval: Math.max(root.pollInterval * 3, 15000)
        running: root.panelOpen
        repeat: true
        onTriggered: root.refreshFull()
    }

    property bool _heavyRefreshPending: false

    // When panel opens, immediately do a full refresh
    onPanelOpenChanged: {
        if (panelOpen) {
            refreshFull()
            if (sessionList.length > 0 && logStreamActive) {
                _syncLogStream()
            }
        } else {
            // Panel closed: stop log stream
            if (_logProc.running) {
                _logProc.running = false
                sessionLogs = []
            }
        }
    }

    property var _configLines: []
    property var _sessionLines: []
    property var _showLines: []
    property var _dumpLines: []
    property var _statsLines: []
    property int _showIndex: -1
    property int _statsIndex: -1

    // --- Helpers ---
    function formatBytes(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        return (bytes / 1073741824).toFixed(2) + " GB"
    }

    function getSessionStats(sessionPath) {
        return sessionStats[sessionPath] || null
    }

    function getConfigDump(configPath) {
        return configDump[configPath] || null
    }

    // ==================== Configs list ====================
    property var _configProc: Process {
        command: ["openvpn3", "configs-list", "--json"]
        running: true

        stdout: SplitParser {
            onRead: (line) => { root._configLines.push(line) }
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                try {
                    const raw = JSON.parse(root._configLines.join(""))
                    const parsed = []
                    for (const path in raw) {
                        const entry = raw[path]
                        parsed.push({ path: path, name: entry.name || path })
                    }
                    root.configList = parsed
                } catch (e) {
                    root.configList = []
                }
            } else {
                root.configList = []
            }
            root._configLines = []
            root._sessionProc.running = true
        }
    }

    // ==================== Sessions list ====================
    property var _sessionProc: Process {
        command: ["openvpn3", "sessions-list"]
        running: false

        stdout: SplitParser {
            onRead: (line) => { root._sessionLines.push(line) }
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                const parsed = []
                let current = null
                for (const line of root._sessionLines) {
                    const pathMatch = line.match(/Path:\s*(.+)$/)
                    if (pathMatch) {
                        current = { sessionPath: pathMatch[1].trim(), configPath: "", name: "", status: "", isPaused: false }
                    }
                    const nameMatch = line.match(/Config name:\s*(.+)$/)
                    if (nameMatch && current) {
                        current.name = nameMatch[1].trim()
                        for (const c of root.configList) {
                            if (c.name === current.name) {
                                current.configPath = c.path
                                break
                            }
                        }
                    }
                    const statusMatch = line.match(/Status:\s*(.+)$/)
                    if (statusMatch && current) {
                        current.status = statusMatch[1].trim()
                        current.isPaused = current.status.toLowerCase().includes("paused")
                        parsed.push(current)
                        current = null
                    }
                }
                root.sessionList = parsed
            } else {
                root.sessionList = []
            }
            root._sessionLines = []
            root.connectedCount = root.sessionList.length

            // Only run heavy queries when explicitly requested
            if (root._heavyRefreshPending) {
                root._heavyRefreshPending = false
                root._queryPersistentDetails()
                root._querySessionStats()
                root._syncLogStream()
            }
        }
    }

    // ==================== Persistent details ====================
    property var _showProc: Process {
        property string targetPath: ""
        running: false

        stdout: SplitParser {
            onRead: (line) => { root._showLines.push(line) }
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                let persistent = false
                for (const line of root._showLines) {
                    if (line.includes("Persistent config:")) {
                        persistent = line.includes("Yes")
                        break
                    }
                }
                const details = Object.assign({}, root.configDetails)
                details[targetPath] = { persistent: persistent }
                root.configDetails = details
            }
            root._showLines = []
            root._showIndex++
            root._queryNextPersistent()
        }
    }

    function _queryPersistentDetails() {
        _showIndex = 0
        _queryNextPersistent()
    }

    function _queryNextPersistent() {
        if (_showIndex >= configList.length) return
        _showLines = []
        _showProc.targetPath = configList[_showIndex].path
        _showProc.command = ["openvpn3", "config-manage", "--path", _showProc.targetPath, "--show"]
        _showProc.running = true
    }

    function isConfigPersistent(configPath) {
        const d = configDetails[configPath]
        return d ? d.persistent : false
    }

    // ==================== Session Stats ====================
    property var _statsProc: Process {
        property string targetSession: ""
        running: false

        stdout: SplitParser {
            onRead: (line) => { root._statsLines.push(line) }
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                try {
                    const raw = JSON.parse(root._statsLines.join(""))
                    const stats = Object.assign({}, root.sessionStats)
                    stats[targetSession] = {
                        bytesIn: raw.BYTES_IN || 0,
                        bytesOut: raw.BYTES_OUT || 0,
                        packetsIn: raw.PACKETS_IN || 0,
                        packetsOut: raw.PACKETS_OUT || 0,
                        nReconnect: raw.N_RECONNECT || 0
                    }
                    root.sessionStats = stats
                } catch (e) {}
            }
            root._statsLines = []
            root._statsIndex++
            root._queryNextStats()
        }
    }

    function _querySessionStats() {
        _statsIndex = 0
        _queryNextStats()
    }

    function _queryNextStats() {
        if (_statsIndex >= sessionList.length) return
        _statsLines = []
        const path = sessionList[_statsIndex].sessionPath
        _statsProc.running = false
        _statsProc.targetSession = path
        _statsProc.command = ["openvpn3", "session-stats", "--json", "--path", path]
        _statsProc.running = true
    }

    // ==================== Config Dump ====================
    property var _dumpProc: Process {
        property string targetConfig: ""
        running: false

        stdout: SplitParser {
            onRead: (line) => { root._dumpLines.push(line) }
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                try {
                    const raw = JSON.parse(root._dumpLines.join(""))
                    const profile = (raw.profile && raw.profile[0]) || {}
                    const remote = (profile.remote && profile.remote[0]) || []
                    const dumps = Object.assign({}, root.configDump)
                    dumps[targetConfig] = {
                        server: remote[0] || "N/A",
                        port: remote[1] || "N/A",
                        protocol: remote[2] || "N/A",
                        cipher: (profile.cipher && profile.cipher[0]) || "N/A",
                        username: (profile.USERNAME && profile.USERNAME[0]) || "N/A",
                        device: (profile.dev && profile.dev[0]) || "N/A"
                    }
                    root.configDump = dumps
                } catch (e) {}
            }
            root._dumpLines = []
        }
    }

    function loadConfigDetails(configPath) {
        if (configDump[configPath]) return
        _dumpLines = []
        _dumpProc.targetConfig = configPath
        _dumpProc.command = ["openvpn3", "config-dump", "--json", "--path", _dumpProc.targetConfig]
        _dumpProc.running = true
    }

    // ==================== Restart ====================
    property var _restartProc: Process {
        property string targetSession: ""
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.showNotifications)
                toast.showError(pluginApi?.tr("errors.restart"))
            root._pending = {}
            root.refresh()
        }
    }

    function restartSession(sessionPath) {
        _restartProc.targetSession = sessionPath
        _restartProc.command = ["openvpn3", "session-manage", "--path", sessionPath, "--restart"]
        _restartProc.running = true
    }

    // ==================== Connect ====================
    property var _connectProc: Process {
        property string targetConfig: ""
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.showNotifications)
                toast.showError(pluginApi?.tr("errors.connect"))
            root._pending = {}
            root.refresh()
        }
    }

    // ==================== Disconnect ====================
    property var _disconnectProc: Process {
        property string targetPath: ""
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.showNotifications)
                toast.showError(pluginApi?.tr("errors.disconnect"))
            root._pending = {}
            root.refresh()
        }
    }

    // ==================== Import ====================
    property var _importProc: Process {
        property string importFilePath: ""
        property string importName: ""
        property bool importPersistent: true
        command: ["openvpn3", "config-import"]
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.showNotifications)
                toast.showError(pluginApi?.tr("errors.import"))
            root._pending = {}
            root.refresh()
        }
    }

    // ==================== Rename ====================
    property var _renameProc: Process {
        property string renameOldPath: ""
        property string renameNewName: ""
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.showNotifications)
                toast.showError(pluginApi?.tr("errors.rename"))
            root._pending = {}
            root.refresh()
        }
    }

    // ==================== Delete ====================
    property var _deleteProc: Process {
        property string targetPath: ""
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.showNotifications)
                toast.showError(pluginApi?.tr("errors.delete"))
            root._pending = {}
            root.refresh()
        }
    }

    // ==================== Log Stream ====================
    property var _logProc: Process {
        property string targetSession: ""
        running: false

        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "") return
                var logs = root.sessionLogs.slice()
                logs.unshift({ raw: line.trim() })
                if (logs.length > root.maxLogs)
                    logs = logs.slice(0, root.maxLogs)
                root.sessionLogs = logs
            }
        }
    }

    function _syncLogStream() {
        if (logStreamActive && sessionList.length > 0 && panelOpen) {
            if (_logProc.targetSession !== sessionList[0].sessionPath || !_logProc.running) {
                _logProc.running = false
                _logProc.targetSession = sessionList[0].sessionPath
                _logProc.command = ["openvpn3", "log", "--session-path", _logProc.targetSession]
                _logProc.running = true
                sessionLogs = []
            }
        } else {
            if (_logProc.running) {
                _logProc.running = false
                sessionLogs = []
            }
        }
    }

    function clearLogs() {
        sessionLogs = []
    }

    // ==================== Public functions ====================

    // Light refresh: configs + sessions only (for bar widget)
    function refresh() {
        _configProc.running = true
    }

    // Full refresh: configs + sessions + stats + details + logs (for panel)
    function refreshFull() {
        _heavyRefreshPending = true
        _configProc.running = true
    }

    function connectTo(configPath) {
        const p = Object.assign({}, _pending)
        p[configPath] = "connect"
        _pending = p
        _connectProc.targetConfig = configPath
        _connectProc.command = ["openvpn3", "session-start", "--config-path", configPath]
        _connectProc.running = true
    }

    function disconnectFrom(sessionPath) {
        const p = Object.assign({}, _pending)
        p[sessionPath] = "disconnect"
        _pending = p
        _disconnectProc.targetPath = sessionPath
        _disconnectProc.command = ["openvpn3", "session-manage", "--path", sessionPath, "--disconnect"]
        _disconnectProc.running = true
    }

    function importConfig(filePath, name, persistent) {
        const p = Object.assign({}, _pending)
        p["import"] = "import"
        _pending = p
        _importProc.importFilePath = filePath
        _importProc.importName = name
        _importProc.importPersistent = persistent
        var cmd = ["openvpn3", "config-import", "--config", filePath, "--name", name]
        if (persistent) cmd.push("--persistent")
        _importProc.command = cmd
        _importProc.running = true
    }

    function renameConfig(configPath, newName) {
        const p = Object.assign({}, _pending)
        p[configPath] = "rename"
        _pending = p
        _renameProc.renameOldPath = configPath
        _renameProc.renameNewName = newName
        _renameProc.command = ["openvpn3", "config-manage", "--path", configPath, "--rename", newName]
        _renameProc.running = true
    }

    function deleteConfig(configPath) {
        const p = Object.assign({}, _pending)
        p[configPath] = "delete"
        _pending = p
        _deleteProc.targetPath = configPath
        _deleteProc.command = ["openvpn3", "config-remove", "--path", configPath, "--force"]
        _deleteProc.running = true
    }

    function isPending(path) {
        return path in _pending
    }

    function isSessionActive(configPath) {
        for (const s of sessionList) {
            if (s.configPath === configPath) return true
        }
        return false
    }

    Component.onCompleted: {
        Logger.i("OpenVPN3", "Started")
    }
}
