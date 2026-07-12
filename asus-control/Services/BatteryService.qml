import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    // --- State ---
    property int chargeLimit: -1

    signal chargeLimitChanged()

    property string bin: pluginApi?.mainInstance?.asusctlBin || "asusctl"

    Process {
        id: infoProc
        command: [root.bin, "battery", "info"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var text = text.trim();
                var marker = "Current battery charge limit: ";
                var idx = text.indexOf(marker);
                if (idx >= 0) {
                    var valStr = text.substring(idx + marker.length).trim().replace("%", "");
                    var val = parseInt(valStr);
                    if (!isNaN(val) && val >= 0 && val <= 100) {
                        root.chargeLimit = val;
                    }
                }
                root.chargeLimitChanged();
            }
        }
    }

    property Process setProc: Process {
        id: setProc
        running: false
        property int pendingLimit: -1
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.chargeLimit = pendingLimit;
                root.chargeLimitChanged();
                Logger.i("AsusctlBattery", "Charge limit set to " + pendingLimit + "%");
            } else {
                Logger.e("AsusctlBattery", "Failed to set charge limit, exitCode=" + exitCode);
                root.refresh();
            }
        }
    }

    property Process oneshotProc: Process {
        id: oneshotProc
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                Logger.i("AsusctlBattery", "One-shot charge triggered");
            } else {
                Logger.e("AsusctlBattery", "Failed to trigger one-shot charge");
            }
        }
    }

    function refresh() {
        if (infoProc.running) return;
        infoProc.running = true;
    }

    function setLimit(percent) {
        if (setProc.running) return;
        var v = Math.round(Math.max(20, Math.min(100, percent)));
        setProc.pendingLimit = v;
        setProc.command = [root.bin, "battery", "limit", v.toString()];
        setProc.running = true;
    }

    function triggerOneshot() {
        if (oneshotProc.running) return;
        oneshotProc.command = [root.bin, "battery", "oneshot"];
        oneshotProc.running = true;
    }

    Component.onCompleted: refresh()
}
