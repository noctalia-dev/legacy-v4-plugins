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
            settingsVersion++;
        }
    }

    property var settingsWatcher: pluginApi?.pluginSettings
    onSettingsWatcherChanged: {
        if (settingsWatcher) {
            settingsVersion++;
        }
    }

    property int settingsVersion: 0

    property int refreshInterval: _computeRefreshInterval()
    property bool compactMode: _computeCompactMode()
    property bool showIpAddress: _computeShowIpAddress()
    property bool showPing: _computeShowPing()

    function _computeRefreshInterval() {
        return pluginApi?.pluginSettings?.refreshInterval ?? 5000;
    }
    function _computeCompactMode() {
        return pluginApi?.pluginSettings?.compactMode ?? false;
    }
    function _computeShowIpAddress() {
        return pluginApi?.pluginSettings?.showIpAddress ?? true;
    }
    function _computeShowPing() {
        return pluginApi?.pluginSettings?.showPing ?? false;
    }

    onSettingsVersionChanged: {
        refreshInterval = _computeRefreshInterval();
        compactMode = _computeCompactMode();
        showIpAddress = _computeShowIpAddress();
        showPing = _computeShowPing();
        updateTimer.interval = refreshInterval;
    }

    property bool netbirdInstalled: false
    property bool netbirdRunning: false
    property string netbirdIp: ""
    property string netbirdFqdn: ""
    property string netbirdStatus: ""
    property int peerCount: 0
    property int peerConnected: 0
    property bool isRefreshing: false
    property string lastToggleAction: ""
    property var peerList: []
    property bool managementConnected: false
    property bool signalConnected: false

    property var peerPings: ({})
    property var pingQueue: []
    property string currentPingIp: ""

    property string detectedTerminal: ""
    property bool terminalDetected: detectedTerminal !== ""
    property var terminalCandidates: ["ghostty", "alacritty", "kitty", "foot", "wezterm", "konsole", "gnome-terminal", "xfce4-terminal", "xterm"]
    property int terminalCheckIndex: 0

    function parseIp(ip) {
        if (!ip)
            return "";
        var idx = ip.indexOf("/");
        if (idx > 0)
            return ip.substring(0, idx);
        return ip;
    }

    Process {
        id: whichProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: function (exitCode, exitStatus) {
            root.netbirdInstalled = (exitCode === 0);
            root.isRefreshing = false;
            updateNetbirdStatus();
        }
    }

    Process {
        id: terminalDetectProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                root.detectedTerminal = root.terminalCandidates[root.terminalCheckIndex];
                Logger.i("NetBird", "Auto-detected terminal: " + root.detectedTerminal);
            } else {
                root.terminalCheckIndex++;
                if (root.terminalCheckIndex < root.terminalCandidates.length) {
                    terminalDetectProcess.command = ["which", root.terminalCandidates[root.terminalCheckIndex]];
                    terminalDetectProcess.running = true;
                } else {
                    Logger.w("NetBird", "No terminal emulator found");
                }
            }
        }
    }

    function detectTerminal() {
        root.terminalCheckIndex = 0;
        root.detectedTerminal = "";
        if (root.terminalCandidates.length > 0) {
            terminalDetectProcess.command = ["which", root.terminalCandidates[0]];
            terminalDetectProcess.running = true;
        }
    }

    Process {
        id: statusProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: function (exitCode, exitStatus) {
            root.isRefreshing = false;
            var stdout = String(statusProcess.stdout.text || "").trim();
            var stderr = String(statusProcess.stderr.text || "").trim();

            if (exitCode === 0 && stdout && stdout.length > 0) {
                try {
                    var data = JSON.parse(stdout);

                    root.managementConnected = data.management?.connected ?? false;
                    root.signalConnected = data.signal?.connected ?? false;

                    root.netbirdRunning = root.managementConnected;

                    if (root.netbirdRunning) {
                        root.netbirdIp = parseIp(data.netbirdIp || "");
                        root.netbirdFqdn = data.fqdn || "";
                        root.netbirdStatus = "Connected";

                        var peers = [];
                        if (data.peers && data.peers.details) {
                            for (var i = 0; i < data.peers.details.length; i++) {
                                var peer = data.peers.details[i];
                                peers.push({
                                    "fqdn": peer.fqdn || "",
                                    "netbirdIp": parseIp(peer.netbirdIp || ""),
                                    "status": peer.status || "Disconnected",
                                    "connectionType": peer.connectionType || "",
                                    "lastStatusUpdate": peer.lastStatusUpdate || "",
                                    "latency": peer.latency || 0,
                                    "transferReceived": peer.transferReceived || 0,
                                    "transferSent": peer.transferSent || 0,
                                    "networks": peer.networks || [],
                                    "quantumResistance": peer.quantumResistance || false
                                });
                            }
                        }
                        root.peerList = peers;
                        root.peerCount = data.peers?.total ?? peers.length;
                        root.peerConnected = data.peers?.connected ?? 0;

                        if (root.showPing) {
                            root.startPingQueue();
                        }
                    } else {
                        root.netbirdIp = "";
                        root.netbirdFqdn = "";
                        root.netbirdStatus = "Disconnected";
                        root.peerCount = 0;
                        root.peerConnected = 0;
                        root.peerList = [];
                    }
                } catch (e) {
                    Logger.e("NetBird", "Failed to parse status: " + e);
                    root.netbirdRunning = false;
                    root.netbirdStatus = "Error";
                    root.peerList = [];
                }
            } else {
                root.netbirdRunning = false;
                root.netbirdStatus = "Disconnected";
                root.netbirdIp = "";
                root.netbirdFqdn = "";
                root.peerCount = 0;
                root.peerConnected = 0;
                root.peerList = [];
            }
        }
    }

    Process {
        id: toggleProcess
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                var message = root.lastToggleAction === "connect" ? pluginApi?.tr("toast.connected") || "NetBird connected" : pluginApi?.tr("toast.disconnected") || "NetBird disconnected";
                ToastService.showNotice(pluginApi?.tr("toast.title") || "NetBird", message, "network");
            }

            statusDelayTimer.start();
        }
    }

    Process {
        id: pingProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: function (exitCode, exitStatus) {
            var stdout = String(pingProcess.stdout.text || "").trim();
            var ip = root.currentPingIp;

            if (exitCode === 0 && stdout.length > 0) {
                var match = stdout.match(/\/([\d.]+)\//);
                if (match) {
                    var latency = parseFloat(match[1]);
                    var newPings = Object.assign({}, root.peerPings);
                    newPings[ip] = latency.toFixed(1);
                    root.peerPings = newPings;
                }
            } else {
                var newPings2 = Object.assign({}, root.peerPings);
                newPings2[ip] = "timeout";
                root.peerPings = newPings2;
            }

            root.processNextPing();
        }
    }

    function startPingQueue() {
        var queue = [];
        for (var i = 0; i < root.peerList.length; i++) {
            if (root.peerList[i].status === "Connected" && root.peerList[i].netbirdIp) {
                queue.push(root.peerList[i].netbirdIp);
            }
        }
        root.pingQueue = queue;
        root.processNextPing();
    }

    function processNextPing() {
        if (root.pingQueue.length === 0) {
            root.currentPingIp = "";
            return;
        }
        var ip = root.pingQueue[0];
        root.pingQueue = root.pingQueue.slice(1);
        root.currentPingIp = ip;
        pingProcess.command = ["ping", "-c", "1", "-W", "2", ip];
        pingProcess.running = true;
    }

    Timer {
        id: statusDelayTimer
        interval: 500
        repeat: false
        onTriggered: {
            root.isRefreshing = false;
            updateNetbirdStatus();
        }
    }

    function checkNetbirdInstalled() {
        root.isRefreshing = true;
        whichProcess.command = ["which", "netbird"];
        whichProcess.running = true;
    }

    function updateNetbirdStatus() {
        if (!root.netbirdInstalled) {
            root.netbirdRunning = false;
            root.netbirdIp = "";
            root.netbirdStatus = "Not installed";
            root.peerCount = 0;
            return;
        }

        root.isRefreshing = true;
        statusProcess.command = ["netbird", "status", "--json"];
        statusProcess.running = true;
    }

    function toggleNetbird() {
        if (!root.netbirdInstalled)
            return;
        root.isRefreshing = true;
        if (root.netbirdRunning) {
            root.lastToggleAction = "disconnect";
            toggleProcess.command = ["netbird", "down"];
        } else {
            root.lastToggleAction = "connect";
            toggleProcess.command = ["netbird", "up"];
        }
        toggleProcess.running = true;
    }

    Timer {
        id: updateTimer
        interval: refreshInterval
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (root.netbirdInstalled === false) {
                checkNetbirdInstalled();
            } else {
                updateNetbirdStatus();
            }
        }
    }

    Component.onCompleted: {
        checkNetbirdInstalled();
        detectTerminal();
    }

    IpcHandler {
        target: "plugin:netbird"

        function toggle() {
            toggleNetbird();
        }

        function status() {
            return {
                "installed": root.netbirdInstalled,
                "running": root.netbirdRunning,
                "ip": root.netbirdIp,
                "fqdn": root.netbirdFqdn,
                "status": root.netbirdStatus,
                "peers": root.peerCount,
                "peersConnected": root.peerConnected
            };
        }

        function refresh() {
            updateNetbirdStatus();
        }
    }
}
