import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Background logic for the Battery for Wireless Devices plugin.
//
// Polls scripts/scan.py on a timer, parses its normalized JSON, and exposes the
// live device list. The bar widget and settings UI both read `devices` from
// this instance via pluginApi.mainInstance.
Item {
    id: root

    // Injected by PluginService.
    property var pluginApi: null

    // Live, normalized device list: [{ id, name, type, battery, charging, source }].
    // Replaced wholesale on each successful scan so QML bindings re-fire.
    property var devices: []

    // True while a scan is in flight (used by the settings UI's refresh button).
    property bool scanning: false

    // Absolute path to the scan script. pluginDir is a plain filesystem path.
    readonly property string scriptPath: (pluginApi ? pluginApi.pluginDir : "") + "/scripts/scan.py"

    readonly property int refreshInterval: {
        var s = pluginApi && pluginApi.pluginSettings ? pluginApi.pluginSettings.refreshInterval : undefined
        return (typeof s === "number" && s > 0) ? s : 60
    }

    function refresh() {
        if (!pluginApi || scanner.running)
            return
        root.scanning = true
        scanner.running = true
    }

    Component.onCompleted: refresh()

    Process {
        id: scanner
        command: ["python3", root.scriptPath]

        property string _buffer: ""

        // scan.py prints the JSON array on a single line; accumulate in case
        // the stream is delivered in multiple chunks.
        stdout: SplitParser {
            onRead: data => scanner._buffer += data
        }

        onExited: (exitCode, exitStatus) => {
            root.scanning = false
            var text = _buffer.trim()
            _buffer = ""
            if (exitCode !== 0) {
                Logger.w("DeviceBattery", "scan.py exited with code", exitCode)
                return
            }
            try {
                root.devices = JSON.parse(text)
            } catch (e) {
                Logger.e("DeviceBattery", "Failed to parse scan output:", e, "raw:", text)
            }
        }
    }

    // Periodic polling. Re-binds automatically when refreshInterval changes.
    Timer {
        interval: root.refreshInterval * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // `qs -c noctalia-shell ipc call plugin:battery-wireless-devices refresh`
    IpcHandler {
        target: "plugin:battery-wireless-devices"

        function refresh(): string {
            root.refresh()
            return "Device battery scan triggered"
        }
    }
}
