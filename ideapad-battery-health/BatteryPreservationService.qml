import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root
    visible: false

    property var pluginApi: null
    property int currentPreservation: 0
    property bool isAvailable: false
    property bool isWritable: false
    property int desiredPreservation: 0

    property string preservationFile: ""
    readonly property string batteryDir: preservationFile !== "" ? preservationFile.replace("/extensions/ideapad_laptop/conservation_mode", "") : ""

    Component.onCompleted: {
        batteryDetector.running = true
    }

    function refresh() {
        if (preservationFileView.path !== "") {
            preservationFileView.reload()
        }
    }

    function restoreSavedPreservation() {
        if (!pluginApi?.pluginSettings)
            return
        const saved = pluginApi.pluginSettings.preservationMode
        // Skip if current preservation already matches saved value
        if (currentPreservation === saved)
            return
        if (saved != desiredPreservation && isWritable) {
            setPreservation(saved)
        }
    }

    function setPreservation(value) {
        const v = value
        if (v !== 0 && v !== 1) {
            Logger.e("BatteryPreservation", `Invalid value: ${v}. Must be exactly 0 or 1`)
            return
        }
        Logger.i("BatteryPreservation", "Set preservation mode to " + v)
        desiredPreservation = v
        preservationWriter.pendingPreservation = v
        preservationWriter.command = ["/bin/sh", "-c", `echo ${v} > ${preservationFile}`]
        preservationWriter.running = true
    }

    onIsWritableChanged: {
        if (isWritable)
            restoreSavedPreservation()
    }

    Process {
        id: batteryDetector
        command: ["sh", "-c", "for f in /sys/class/power_supply/BAT*/extensions/ideapad_laptop/conservation_mode; do [ -f \"$f\" ] && echo \"$f\" && break; done"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const detected = text.trim()
                if (detected !== "") {
                    root.preservationFile = detected
                    root.isAvailable = true
                    preservationFileView.path = detected
                    Logger.i("BatteryPreservation", "Detected conservation_mode at: " + detected)
                    writeAccessChecker.running = true
                } else {
                    Logger.w("BatteryPreservation", "No ideapad conservation_mode file found")
                }
            }
        }
    }

    Process {
        id: writeAccessChecker
        command: ["sh", "-c", `test -w ${root.preservationFile} && echo 1 || echo 0`]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.isWritable = text.trim() === "1"
            }
        }
    }

    FileView {
        id: preservationFileView
        path: ""
        printErrors: false

        onLoaded: {
            const value = parseInt(text().trim())
            // The range exposed by sysfs - typically 0 or 1 for preservation mode
            if (!isNaN(value)) {
                root.currentPreservation = value
            }
        }
    }

    Process {
        id: preservationWriter
        property int pendingPreservation: -1

        running: false

        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.refresh()
                if (pluginApi && pluginApi.pluginSettings.preservationMode != pendingPreservation) {
                    pluginApi.pluginSettings.preservationMode = pendingPreservation
                    pluginApi.saveSettings()
                }
            } else {
                Logger.w("BatteryPreservation", "Failed to write preservation, exitCode=" + exitCode)
            }
        }
    }
}
