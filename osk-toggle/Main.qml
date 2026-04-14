import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var pluginApi: null

    // Reads the user's backend preference: "auto", "squeekboard", or "wvkbd".
    // "auto" checks whether Squeekboard's D-Bus name is owned at startup and
    // falls back to wvkbd if it is not.
    readonly property string backendSetting: pluginApi?.pluginSettings?.backend ?? "auto"

    // Set once detection/selection is complete; drives the Loader below.
    property string resolvedBackend: ""

    readonly property var _backend: backendLoader.item

    // Unified API consumed by BarWidget and Settings
    property bool keyboardActive: _backend?.keyboardActive ?? false
    property bool available: _backend?.available ?? false
    readonly property string unavailableTooltipKey: _backend?.unavailableTooltipKey ?? "tooltip.detecting"

    onBackendSettingChanged: _resolveBackend()
    Component.onCompleted: _resolveBackend()

    // --- Auto-detection: check if Squeekboard's D-Bus name is owned ---
    Process {
        id: autoDetect
        command: ["busctl", "--user", "call",
                  "org.freedesktop.DBus", "/org/freedesktop/DBus",
                  "org.freedesktop.DBus", "GetNameOwner",
                  "s", "sm.puri.OSK0"]
        onExited: (exitCode, exitStatus) => {
            root.resolvedBackend = exitCode === 0 ? "squeekboard" : "wvkbd"
        }
    }

    Loader {
        id: backendLoader
        source: {
            if (root.resolvedBackend === "squeekboard") return "SqueekboardBackend.qml"
            if (root.resolvedBackend === "wvkbd") return "WvkbdBackend.qml"
            return ""
        }
        onLoaded: {
            if (item) item.pluginApi = root.pluginApi
        }
    }

    // Keep pluginApi in sync with the backend (wvkbd reads wvkbdBin from it)
    onPluginApiChanged: {
        if (backendLoader.item) backendLoader.item.pluginApi = pluginApi
    }

    function _resolveBackend() {
        if (backendSetting === "auto") {
            resolvedBackend = ""
            autoDetect.running = true
        } else {
            resolvedBackend = backendSetting
        }
    }

    function recheckState() {
        _backend?.recheckState()
    }

    function toggleKeyboard() {
        _backend?.toggleKeyboard()
    }
}
