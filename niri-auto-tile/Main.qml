import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var pluginApi: null
    property bool running: false
    property string status: "stopped"
    property bool pendingRestart: false

    readonly property bool enabled: pluginApi?.pluginSettings?.enabled ?? true
    readonly property int maxVisible: pluginApi?.pluginSettings?.maxVisible ?? 4
    readonly property bool perWorkspace: pluginApi?.pluginSettings?.perWorkspace ?? false
    readonly property bool onlyAtMax: pluginApi?.pluginSettings?.onlyAtMax ?? true
    readonly property var workspaceMaxVisible: pluginApi?.pluginSettings?.workspaceMaxVisible ?? ({})
    readonly property int debounceMs: pluginApi?.pluginSettings?.debounceMs ?? 300
    readonly property int maxEventsPerSecond: pluginApi?.pluginSettings?.maxEventsPerSecond ?? 20

    readonly property string scriptPath: (pluginApi?.pluginDir ?? "") + "/auto-tile.py"
    readonly property string configFilePath: (pluginApi?.pluginDir ?? "/tmp") + "/runtime-config.json"

    // Serialize workspace config as JSON string for CLI
    function workspaceConfigJson() {
        const cfg = workspaceMaxVisible;
        if (!cfg || typeof cfg !== "object") return "{}";
        return JSON.stringify(cfg);
    }

    onEnabledChanged: {
        if (enabled) {
            startDaemon();
        } else {
            pendingRestart = false;
            stopDaemon();
        }
    }

    onMaxVisibleChanged: {
        if (running) hotReloadConfig();
    }

    onPerWorkspaceChanged: {
        if (running) hotReloadConfig();
    }

    onOnlyAtMaxChanged: {
        if (running) hotReloadConfig();
    }

    Component.onCompleted: {
        if (enabled) startDaemon();
    }

    Component.onDestruction: {
        pendingRestart = false;
        stopDaemon();
    }

    function startDaemon() {
        if (running) return;
        daemonProcess.running = true;
    }

    function stopDaemon() {
        if (!running) return;
        daemonProcess.signal(15); // SIGTERM
    }

    function restartDaemon() {
        pendingRestart = true;
        stopDaemon();
    }

    function hotReloadConfig() {
        // Build command with current values, then write config + send SIGUSR1
        const config = JSON.stringify({
            maxVisible: maxVisible,
            onlyAtMax: onlyAtMax,
            perWorkspace: perWorkspace,
            workspaceMaxVisible: workspaceMaxVisible
        });
        configWriter.command = [
            "bash", "-c",
            "echo '" + config + "' > " + configFilePath
        ];
        configWriter.running = true;
    }

    function setMaxVisible(count) {
        if (count < 1 || count > 8) return;
        if (!pluginApi?.pluginSettings) return;
        pluginApi.pluginSettings.maxVisible = count;
        pluginApi.saveSettings();
    }

    function setWorkspaceMaxVisible(wsId, count) {
        if (count < 1 || count > 8) return;
        if (!pluginApi?.pluginSettings) return;
        let cfg = pluginApi.pluginSettings.workspaceMaxVisible;
        if (!cfg || typeof cfg !== "object") cfg = {};
        // Create new object (immutable pattern)
        const updated = Object.assign({}, cfg);
        updated[String(wsId)] = count;
        pluginApi.pluginSettings.workspaceMaxVisible = updated;
        pluginApi.saveSettings();
        if (running) hotReloadConfig();
    }

    function setPerWorkspace(value) {
        if (!pluginApi?.pluginSettings) return;
        pluginApi.pluginSettings.perWorkspace = value;
        pluginApi.saveSettings();
    }

    function setOnlyAtMax(value) {
        if (!pluginApi?.pluginSettings) return;
        pluginApi.pluginSettings.onlyAtMax = value;
        pluginApi.saveSettings();
    }

    function getMaxVisibleForWorkspace(wsId) {
        if (perWorkspace) {
            const cfg = workspaceMaxVisible;
            if (cfg && typeof cfg === "object" && String(wsId) in cfg) {
                return cfg[String(wsId)];
            }
        }
        return maxVisible;
    }

    readonly property Process configWriter: Process {
        running: false

        onExited: {
            // Config file written, now send SIGUSR1 to daemon
            if (root.running) {
                root.daemonProcess.signal(10); // SIGUSR1
            }
        }
    }

    readonly property Process daemonProcess: Process {
        command: {
            const args = [
                "python3", root.scriptPath,
                "--max-visible", String(root.maxVisible),
                "--debounce", String(root.debounceMs / 1000.0),
                "--max-events", String(root.maxEventsPerSecond),
                "--config-file", root.configFilePath
            ];
            if (root.onlyAtMax) {
                args.push("--only-at-max");
            }
            if (root.perWorkspace) {
                args.push("--per-workspace");
                args.push("--workspace-config");
                args.push(root.workspaceConfigJson());
            }
            return args;
        }

        running: false

        onStarted: {
            root.running = true;
            root.status = "running";
        }

        onExited: (exitCode, exitStatus) => {
            root.running = false;

            if (root.pendingRestart) {
                root.pendingRestart = false;
                root.status = "starting";
                root.startDaemon();
                return;
            }

            if (exitCode === 0 || exitStatus === Process.CrashExit) {
                root.status = "stopped";
            } else {
                root.status = "error";
                if (root.enabled) {
                    restartTimer.start();
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim();
                if (msg) {
                    Logger.w("[auto-tile]", msg);
                }
            }
        }
    }

    readonly property Timer restartTimer: Timer {
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.enabled && !root.running) {
                root.startDaemon();
            }
        }
    }

    IpcHandler {
        target: "plugin:niri-auto-tile"

        function toggle() {
            const newState = !root.enabled;
            if (pluginApi?.pluginSettings) {
                pluginApi.pluginSettings.enabled = newState;
                pluginApi.saveSettings();
            }
        }

        function setColumns(count: int) {
            root.setMaxVisible(count);
        }

        function status() {
            return {
                running: root.running,
                enabled: root.enabled,
                status: root.status,
                maxVisible: root.maxVisible,
                perWorkspace: root.perWorkspace
            };
        }
    }
}
