import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    // --- Dynamic fan list ---
    property list<string> fanNames: []
    // fan name -> { enabled: bool, data: [{temp, pwm}] }
    property var fanStates: ({})

    // Current profile's fan curves
    property list<var> cpuCurve: []
    property list<var> gpuCurve: []
    property list<string> availableFanTypes: []

    signal fanCurvesChanged()

    property string bin: pluginApi?.mainInstance?.asusctlBin || "asusctl"

    Process {
        id: enabledProc
        command: [root.bin, "fan-curve", "--get-enabled"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root._parseEnabled(text);
            }
        }
    }

    Process {
        id: curveDataProc
        property string profileName: ""
        command: [root.bin, "fan-curve", "--mod-profile", profileName]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root._parseCurveData(text, curveDataProc.profileName);
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
                Logger.e("AsusctlFanCurve", "Failed to set fan curve, exitCode=" + exitCode);
            }
        }
    }

    property Process enableProc: Process {
        id: enableProc
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.refreshEnabled();
            } else {
                Logger.e("AsusctlFanCurve", "Failed to toggle fan curve");
            }
        }
    }

    property Process defaultProc: Process {
        id: defaultProc
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.refresh();
            } else {
                Logger.e("AsusctlFanCurve", "Failed to reset fan curve to default");
            }
        }
    }

    function refresh() {
        refreshEnabled();
        var profile = pluginApi?.mainInstance?.profileService?.activeProfile || "Balanced";
        curveDataProc.profileName = profile;
        curveDataProc.running = true;
    }

    function refreshEnabled() {
        if (enabledProc.running) return;
        enabledProc.running = true;
    }

    function setFanCurve(profile, fan, dataStr) {
        if (setProc.running) return;
        setProc.command = [root.bin, "fan-curve", "--mod-profile", profile, "--fan", fan, "--data", dataStr];
        setProc.running = true;
        Logger.i("AsusctlFanCurve", "Setting " + fan + " curve for " + profile);
    }

    function setFanEnabled(profile, fan, enabled) {
        if (enableProc.running) return;
        enableProc.command = [root.bin, "fan-curve", "--enable-fan-curve", enabled ? "true" : "false", "--mod-profile", profile, "--fan", fan];
        enableProc.running = true;
        Logger.i("AsusctlFanCurve", (enabled ? "Enabling" : "Disabling") + " " + fan + " curve for " + profile);
    }

    function setAllFanCurves(profile, enabled) {
        if (enableProc.running) return;
        enableProc.command = [root.bin, "fan-curve", "--enable-fan-curves", enabled ? "true" : "false", "--mod-profile", profile];
        enableProc.running = true;
    }

    function resetToDefault(profile) {
        if (defaultProc.running) return;
        defaultProc.command = [root.bin, "fan-curve", "--default", "--mod-profile", profile];
        defaultProc.running = true;
        Logger.i("AsusctlFanCurve", "Resetting fan curves to default for " + profile);
    }

    // Parse "CPU: enabled: false, 30c:20%,55c:30%,..."
    function _parseEnabled(text) {
        var lines = text.trim().split("\n");
        var states = {};
        var fans = [];
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.length === 0) continue;

            var colonIdx = line.indexOf(":");
            if (colonIdx < 0) continue;

            var fanName = line.substring(0, colonIdx).trim();
            fans.push(fanName);

            var rest = line.substring(colonIdx + 1).trim();
            var enabledMatch = rest.match(/enabled:\s*(true|false)/);
            var enabled = enabledMatch ? enabledMatch[1] === "true" : false;

            // Parse curve data after the comma
            var dataPoints = [];
            var dataIdx = rest.indexOf(",");
            if (dataIdx >= 0) {
                var dataStr = rest.substring(dataIdx + 1).trim();
                var pairs = dataStr.split(",");
                for (var j = 0; j < pairs.length; j++) {
                    var pair = pairs[j].trim();
                    var m = pair.match(/(\d+)c:(\d+)%?/);
                    if (m) {
                        dataPoints.push({ temp: parseInt(m[1]), pwm: parseInt(m[2]) });
                    }
                }
            }

            states[fanName] = { enabled: enabled, data: dataPoints };
        }

        root.availableFanTypes = fans;
        root.fanStates = states;
        root.fanCurvesChanged();
    }

    // Parse the structured curve data output
    function _parseCurveData(text, profile) {
        var cpuPoints = [];
        var gpuPoints = [];

        var lines = text.trim().split("\n");
        var currentFan = "";

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();

            var fanMatch = line.match(/fan:\s*(\w+)/);
            if (fanMatch) {
                currentFan = fanMatch[1];
                continue;
            }

            var pwmMatch = line.match(/pwm:\s*\(([^)]+)\)/);
            var tempMatch = line.match(/temp:\s*\(([^)]+)\)/);

            if (pwmMatch && tempMatch) {
                var pwms = pwmMatch[1].split(",").map(function(s) { return parseInt(s.trim()); });
                var temps = tempMatch[1].split(",").map(function(s) { return parseInt(s.trim()); });
                var points = [];
                for (var j = 0; j < Math.min(pwms.length, temps.length); j++) {
                    points.push({ temp: temps[j], pwm: pwms[j] });
                }
                if (currentFan === "CPU") cpuPoints = points;
                else if (currentFan === "GPU") gpuPoints = points;
            }
        }

        root.cpuCurve = cpuPoints;
        root.gpuCurve = gpuPoints;
        root.fanCurvesChanged();
    }

    Component.onCompleted: refresh()
}
