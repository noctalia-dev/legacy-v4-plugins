import QtQuick
import Quickshell.Io

Item {
    id: root

    property var pluginApi: null

    // Connection state
    property string vpnStatus: "unknown"   // "connected" | "disconnected" | "unknown"
    property string serverName: ""
    property string serverLocation: ""
    property string protocol: ""
    property int    serverLoad: -1
    property bool   isLoading: true        // true until first poll result
    property bool   isActing: false        // true while connect/disconnect/config runs
    property string lastError: ""

    // Config state
    property string killSwitch: "unknown"  // "off" | "standard" | "unknown"

    readonly property int pollInterval: pluginApi?.pluginSettings?.pollInterval ?? 5000

    // ── Status polling ────────────────────────────────────────────────────────

    function refresh() {
        if (!statusProc.running) statusProc.running = true;
        if (!configProc.running) configProc.running = true;
    }

    StdioCollector {
        id: statusOut
        onStreamFinished: {
            root.isLoading = false;
            const text = this.text.trim();
            const statusMatch = text.match(/Status:\s*(\S+)/i);
            if (!statusMatch) { root.vpnStatus = "unknown"; return; }

            if (statusMatch[1].toLowerCase() === "connected") {
                root.vpnStatus = "connected";
                const serverMatch = text.match(/Server:\s*(\S+)\s+in\s+(.+)/i);
                if (serverMatch) {
                    root.serverName     = serverMatch[1];
                    root.serverLocation = serverMatch[2].trim();
                }
                const protoMatch = text.match(/Protocol:\s*(\S+)/i);
                root.protocol = protoMatch ? protoMatch[1] : "";
                const loadMatch = text.match(/Load:\s*(\d+)/i);
                root.serverLoad = loadMatch ? parseInt(loadMatch[1]) : -1;
            } else {
                root.vpnStatus = "disconnected";
                root.serverName = root.serverLocation = root.protocol = "";
                root.serverLoad = -1;
            }
        }
    }

    Process {
        id: statusProc
        command: ["protonvpn", "status"]
        running: false
        stdout: statusOut
        onExited: (code) => {
            root.isLoading = false;
            if (code !== 0 && root.vpnStatus !== "connected")
                root.vpnStatus = "disconnected";
        }
    }

    StdioCollector {
        id: configOut
        onStreamFinished: {
            const ksMatch = this.text.match(/kill-switch\s+(\S+)/i);
            root.killSwitch = ksMatch ? ksMatch[1].toLowerCase() : "unknown";
        }
    }

    Process {
        id: configProc
        command: ["protonvpn", "config", "list"]
        running: false
        stdout: configOut
    }

    Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    StdioCollector { id: actionOut }
    StdioCollector { id: actionErr }

    Process {
        id: actionProc
        running: false
        stdout: actionOut
        stderr: actionErr
        onExited: (code) => {
            root.isActing = false;
            root.lastError = code !== 0 ? actionErr.text.trim() : "";
            root.refresh();
        }
    }

    function _run(cmd) {
        if (root.isActing) return;
        root.isActing = true;
        root.lastError = "";
        actionProc.command = cmd;
        actionProc.running = true;
    }

    function connectFastest()    { _run(["protonvpn", "connect"]);                          }
    function connectSecureCore() { _run(["protonvpn", "connect", "--securecore"]);          }
    function connectP2P()        { _run(["protonvpn", "connect", "--p2p"]);                 }
    function disconnect()        { _run(["protonvpn", "disconnect"]);                       }

    function setKillSwitch(value) {
        // value: "off" | "standard"
        _run(["protonvpn", "config", "set", "kill-switch", value]);
    }
}
