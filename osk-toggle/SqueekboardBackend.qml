import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var pluginApi: null

    property bool keyboardActive: false
    property bool gsettingsOk: false
    property bool squeekboardOk: false
    property bool available: gsettingsOk && squeekboardOk

    readonly property string unavailableTooltipKey: !gsettingsOk ? "tooltip.noGsettings" : "tooltip.noSqueekboard"

    // --- Initial state check ---
    Process {
        id: stateChecker
        command: ["gsettings", "get", "org.gnome.desktop.a11y.applications", "screen-keyboard-enabled"]
        stdout: SplitParser {
            onRead: data => {
                root.keyboardActive = data.trim() === "true"
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.gsettingsOk = exitCode === 0
        }
        Component.onCompleted: running = true
    }

    // --- Squeekboard availability: initial check ---
    Process {
        id: squeekboardChecker
        command: ["busctl", "--user", "call",
                  "org.freedesktop.DBus", "/org/freedesktop/DBus",
                  "org.freedesktop.DBus", "GetNameOwner",
                  "s", "sm.puri.OSK0"]
        onExited: (exitCode, exitStatus) => {
            root.squeekboardOk = exitCode === 0
        }
        Component.onCompleted: running = true
    }

    // --- Squeekboard availability: live D-Bus monitor ---
    // Watches all NameOwnerChanged signals and filters for sm.puri.OSK0 in QML.
    // Avoids the arg0= match rule which is not universally supported.
    Process {
        id: squeekboardMonitor
        command: ["dbus-monitor", "--session",
                  "type='signal',sender='org.freedesktop.DBus',member='NameOwnerChanged'"]
        running: true
        stdout: SplitParser {
            property int argCount: 0
            property bool isOurService: false
            onRead: data => {
                const trimmed = data.trim()
                if (trimmed.startsWith("signal ")) {
                    argCount = 0
                    isOurService = false
                } else if (trimmed.startsWith("string ")) {
                    argCount++
                    if (argCount === 1) {
                        isOurService = trimmed === 'string "sm.puri.OSK0"'
                    } else if (argCount === 3 && isOurService) {
                        const nowRunning = trimmed !== 'string ""'
                        root.squeekboardOk = nowRunning
                        if (!nowRunning && root.keyboardActive) {
                            root.keyboardActive = false
                        } else if (nowRunning) {
                            stateChecker.running = true
                        }
                    }
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            squeekboardMonitor.running = true
        }
    }

    // --- Live state monitor ---
    Process {
        id: stateMonitor
        command: ["dconf", "watch", "/org/gnome/desktop/a11y/applications/screen-keyboard-enabled"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed === "true" || trimmed === "false") {
                    root.keyboardActive = trimmed === "true"
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            stateChecker.running = true
            stateMonitor.running = true
        }
    }

    Process {
        id: toggleProcess
    }

    Component.onDestruction: {
        stateMonitor.running = false
        squeekboardMonitor.running = false
    }

    function recheckState() {
        squeekboardChecker.running = true
        stateChecker.running = true
    }

    function toggleKeyboard() {
        toggleProcess.command = ["gsettings", "set", "org.gnome.desktop.a11y.applications",
                                 "screen-keyboard-enabled", root.keyboardActive ? "false" : "true"]
        toggleProcess.running = true
    }
}
