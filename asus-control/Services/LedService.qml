import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    // --- State ---
    property string brightness: ""
    property int brightnessIndex: -1

    readonly property list<string> levels: ["off", "low", "med", "high"]
    readonly property list<string> levelLabels: ["Off", "Low", "Medium", "High"]

    signal brightnessChanged()

    Process {
        id: getProc
        command: ["asusctl", "leds", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var text = text.trim();
                var marker = "Current keyboard led brightness: ";
                var idx = text.indexOf(marker);
                if (idx >= 0) {
                    var level = text.substring(idx + marker.length).trim().toLowerCase();
                    root.brightness = level;
                    root.brightnessIndex = root.levels.indexOf(level);
                } else {
                    root.brightness = "";
                    root.brightnessIndex = -1;
                }
                root.brightnessChanged();
            }
        }
    }

    property Process setProc: Process {
        id: setProc
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.refresh();
            } else {
                Logger.e("AsusctlLed", "Failed to set brightness, exitCode=" + exitCode);
            }
        }
    }

    function refresh() {
        if (getProc.running) return;
        getProc.running = true;
    }

    function setBrightness(level) {
        if (setProc.running) return;
        setProc.command = ["asusctl", "leds", "set", level];
        setProc.running = true;
        Logger.i("AsusctlLed", "Setting brightness to " + level);
    }

    function nextBrightness() {
        if (setProc.running) return;
        setProc.command = ["asusctl", "leds", "next"];
        setProc.running = true;
    }

    function prevBrightness() {
        if (setProc.running) return;
        setProc.command = ["asusctl", "leds", "prev"];
        setProc.running = true;
    }

    Component.onCompleted: refresh()
}
