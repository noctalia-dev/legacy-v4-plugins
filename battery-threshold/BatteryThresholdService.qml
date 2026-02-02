import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root
    visible: false

    property var pluginApi: null
    property int currentThreshold: 0
    property bool isAvailable: false
    property bool isWritable: false
    property int batteryMinThresh: 40
    property int batteryMaxThresh: 100

    readonly property string thresholdFile: "/sys/class/power_supply/BAT0/charge_control_end_threshold"

    Component.onCompleted: {
        batteryChecker.running = true
    }

    function refresh() {
        if (thresholdFileView.path !== "") {
            thresholdFileView.reload()
        }
    }

    function restoreSavedThreshold() {
        if (!pluginApi?.pluginSettings)
            return
        const saved = pluginApi.pluginSettings.chargeThreshold
        // Skip if current threshold already matches saved value
        if (currentThreshold === saved)
            return
        if (saved >= batteryMinThresh && saved <= batteryMaxThresh && isWritable) {
            setThreshold(saved)
        }
    }

    function setThreshold(value) {
        const v = Math.round(value)
        Logger.i("BatteryThreshold", "Restored charge threshold to " + v + "%")

        thresholdWriter.pendingThreshold = v
        thresholdWriter.command = ["/bin/bash", "-c", `echo ${v} > ${thresholdFile}`]
        thresholdWriter.running = true
    }

    onIsWritableChanged: {
        if (isWritable)
            restoreSavedThreshold()
    }

    Process {
        id: batteryChecker
        command: ["test", "-f", root.thresholdFile]
        running: false

        onExited: function (exitCode) {
            if (exitCode === 0) {
                root.isAvailable = true
                thresholdFileView.path = root.thresholdFile
                writeAccessChecker.running = true
            }
        }
    }

    Process {
        id: writeAccessChecker
        command: ["/bin/bash", "-c", `test -w ${root.thresholdFile} && echo 1 || echo 0`]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.isWritable = text.trim() === "1"
            }
        }
    }

    FileView {
        id: thresholdFileView
        path: ""
        printErrors: false

        onLoaded: {
            const value = parseInt(text().trim())
            // The range exposed by sysfs
            if (!isNaN(value) && value >= 0 && value <= 100) {
                root.currentThreshold = value
            }
        }
    }

    Process {
        id: thresholdWriter
        property int pendingThreshold: -1

        running: false

        onExited: function(exitCode) {
            if (exitCode === 0) {
                service.refresh()
                if (pluginApi && pluginApi.pluginSettings.chargeThreshold != pendingThreshold) {
                    pluginApi.pluginSettings.chargeThreshold = pendingThreshold
                    pluginApi.saveSettings()
                }
            } else {
                Logger.w("BatteryThreshold", "Failed to write threshold, exitCode=" + exitCode)
            }
        }
    }
}
