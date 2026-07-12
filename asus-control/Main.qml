import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    // --- Availability ---
    property bool isAvailable: false
    property string asusctlBin: ""
    property string asusctlVersion: ""
    property string productFamily: ""
    property string boardName: ""

    // ============================================================
    // Profile Service
    // ============================================================
    readonly property QtObject profileService: QtObject {
        id: profileService
        property string activeProfile: ""
        property string acProfile: ""
        property string batteryProfile: ""
        property var availableProfiles: []

        property string bin: root.asusctlBin

        Process {
            id: profileListProc
            command: [profileService.bin, "profile", "list"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var lines = text.trim().split("\n");
                    var profiles = [];
                    for (var i = 0; i < lines.length; i++) {
                        var p = lines[i].trim();
                        if (p.length > 0) profiles.push(p);
                    }
                    profileService.availableProfiles = profiles;
                }
            }
        }

        Process {
            id: profileGetProc
            command: [profileService.bin, "profile", "get"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var lines = text.trim().split("\n");
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim();
                        if (line.indexOf("Active profile:") === 0)
                            profileService.activeProfile = line.substring("Active profile:".length).trim();
                        else if (line.indexOf("AC profile") === 0)
                            profileService.acProfile = line.substring("AC profile".length).trim();
                        else if (line.indexOf("Battery profile") === 0)
                            profileService.batteryProfile = line.substring("Battery profile".length).trim();
                    }
                }
            }
        }

        Process {
            id: profileSetProc
            running: false
            onExited: function(exitCode) {
                if (exitCode === 0) profileService.refresh();
                else Logger.e("AsusctlProfile", "Failed to set profile");
            }
        }

        function refresh() {
            if (profileListProc.running || profileGetProc.running) return;
            profileListProc.running = true;
            profileGetProc.running = true;
        }

        function setProfile(name) {
            if (profileSetProc.running) return;
            profileSetProc.command = [bin, "profile", "set", name];
            profileSetProc.running = true;
        }

        Component.onCompleted: refresh()
    }

    // ============================================================
    // LED Service
    // ============================================================
    readonly property QtObject ledService: QtObject {
        id: ledService
        property string brightness: ""
        property int brightnessIndex: -1
        property var levels: ["off", "low", "med", "high"]
        property var levelLabels: ["Off", "Low", "Medium", "High"]

        property string bin: root.asusctlBin

        Process {
            id: ledGetProc
            command: [ledService.bin, "leds", "get"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var t = text.trim();
                    var marker = "Current keyboard led brightness: ";
                    var idx = t.indexOf(marker);
                    if (idx >= 0) {
                        var level = t.substring(idx + marker.length).trim().toLowerCase();
                        ledService.brightness = level;
                        ledService.brightnessIndex = ledService.levels.indexOf(level);
                    } else {
                        ledService.brightness = "";
                        ledService.brightnessIndex = -1;
                    }
                }
            }
        }

        Process {
            id: ledSetProc
            running: false
            onExited: function(exitCode) {
                if (exitCode === 0) ledGetProc.running = true;
                else Logger.e("AsusctlLed", "Failed to set brightness");
            }
        }

        function refresh() {
            if (!ledGetProc.running) ledGetProc.running = true;
        }

        function setBrightness(level) {
            if (ledSetProc.running) return;
            ledSetProc.command = [bin, "leds", "set", level];
            ledSetProc.running = true;
        }

        Component.onCompleted: refresh()
    }

    // ============================================================
    // Battery Service
    // ============================================================
    readonly property QtObject batteryService: QtObject {
        id: batteryService
        property int chargeLimit: -1

        property string bin: root.asusctlBin

        Process {
            id: batInfoProc
            command: [batteryService.bin, "battery", "info"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var t = text.trim();
                    var marker = "Current battery charge limit: ";
                    var idx = t.indexOf(marker);
                    if (idx >= 0) {
                        var valStr = t.substring(idx + marker.length).trim().replace("%", "");
                        var val = parseInt(valStr);
                        if (!isNaN(val) && val >= 0 && val <= 100)
                            batteryService.chargeLimit = val;
                    }
                }
            }
        }

        Process {
            id: batSetProc
            running: false
            property int pendingLimit: -1
            onExited: function(exitCode) {
                if (exitCode === 0) {
                    batteryService.chargeLimit = pendingLimit;
                    Logger.i("AsusctlBattery", "Charge limit set to " + pendingLimit + "%");
                } else {
                    Logger.e("AsusctlBattery", "Failed to set charge limit");
                    batInfoProc.running = true;
                }
            }
        }

        Process {
            id: batOneshotProc
            running: false
            onExited: function(exitCode) {
                if (exitCode !== 0) Logger.e("AsusctlBattery", "Failed to trigger one-shot charge");
            }
        }

        function refresh() {
            if (!batInfoProc.running) batInfoProc.running = true;
        }

        function setLimit(percent) {
            if (batSetProc.running) return;
            var v = Math.round(Math.max(20, Math.min(100, percent)));
            batSetProc.pendingLimit = v;
            batSetProc.command = [bin, "battery", "limit", v.toString()];
            batSetProc.running = true;
        }

        function triggerOneshot() {
            if (batOneshotProc.running) return;
            batOneshotProc.command = [bin, "battery", "oneshot"];
            batOneshotProc.running = true;
        }

        Component.onCompleted: refresh()
    }

    // ============================================================
    // Fan Curve Service
    // ============================================================
    readonly property QtObject fanCurveService: QtObject {
        id: fanCurveService
        property var fanStates: ({})
        property var availableFanTypes: []

        property string bin: root.asusctlBin

        Process {
            id: fanEnabledProc
            command: [fanCurveService.bin, "fan-curve", "--get-enabled"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: { fanCurveService._parseEnabled(text); }
            }
        }

        Process {
            id: fanDataProc
            property string profileName: ""
            command: [fanCurveService.bin, "fan-curve", "--mod-profile", profileName]
            running: false
            stdout: StdioCollector {
                onStreamFinished: { fanCurveService._parseCurveData(text); }
            }
        }

        Process {
            id: fanSetProc
            running: false
            onExited: function(exitCode) {
                if (exitCode === 0) fanCurveService.refresh();
                else Logger.e("AsusctlFanCurve", "Failed to set fan curve");
            }
        }

        Process {
            id: fanEnableProc
            running: false
            onExited: function(exitCode) {
                if (exitCode === 0) fanEnabledProc.running = true;
                else Logger.e("AsusctlFanCurve", "Failed to toggle fan curve");
            }
        }

        Process {
            id: fanDefaultProc
            running: false
            onExited: function(exitCode) {
                if (exitCode === 0) fanCurveService.refresh();
                else Logger.e("AsusctlFanCurve", "Failed to reset to default");
            }
        }

        function refresh() {
            if (!fanEnabledProc.running) fanEnabledProc.running = true;
            var profile = root.profileService?.activeProfile || "Balanced";
            fanDataProc.profileName = profile;
            if (!fanDataProc.running) fanDataProc.running = true;
        }

        function setFanEnabled(profile, fan, enabled) {
            if (fanEnableProc.running) return;
            fanEnableProc.command = [bin, "fan-curve", "--enable-fan-curve", enabled ? "true" : "false", "--mod-profile", profile, "--fan", fan];
            fanEnableProc.running = true;
        }

        function resetToDefault(profile) {
            if (fanDefaultProc.running) return;
            fanDefaultProc.command = [bin, "fan-curve", "--default", "--mod-profile", profile];
            fanDefaultProc.running = true;
        }

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
                var dataPoints = [];
                var dataIdx = rest.indexOf(",");
                if (dataIdx >= 0) {
                    var dataStr = rest.substring(dataIdx + 1).trim();
                    var pairs = dataStr.split(",");
                    for (var j = 0; j < pairs.length; j++) {
                        var m = pairs[j].trim().match(/(\d+)c:(\d+)%?/);
                        if (m) dataPoints.push({ temp: parseInt(m[1]), pwm: parseInt(m[2]) });
                    }
                }
                states[fanName] = { enabled: enabled, data: dataPoints };
            }
            fanCurveService.availableFanTypes = fans;
            fanCurveService.fanStates = states;
        }

        function _parseCurveData(text) {
            var lines = text.trim().split("\n");
            var currentFan = "";
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                var fanMatch = line.match(/fan:\s*(\w+)/);
                if (fanMatch) { currentFan = fanMatch[1]; continue; }
                var pwmMatch = line.match(/pwm:\s*\(([^)]+)\)/);
                var tempMatch = line.match(/temp:\s*\(([^)]+)\)/);
                if (pwmMatch && tempMatch) {
                    var pwms = pwmMatch[1].split(",").map(function(s) { return parseInt(s.trim()); });
                    var temps = tempMatch[1].split(",").map(function(s) { return parseInt(s.trim()); });
                    var points = [];
                    for (var j = 0; j < Math.min(pwms.length, temps.length); j++)
                        points.push({ temp: temps[j], pwm: pwms[j] });
                }
            }
        }

        Component.onCompleted: refresh()
    }

    // ============================================================
    // Aura Service
    // ============================================================
    readonly property QtObject auraService: QtObject {
        id: auraService
        property var availableZones: []
        property var zoneStates: ({})
        property var knownZones: ["keyboard", "logo", "lightbar", "lid", "rear-glow", "ally"]

        property string bin: root.asusctlBin
        property var _probeQueue: []
        property bool _probing: false

        Process {
            id: auraProbeProc
            running: false
            property string targetZone: ""
            command: [auraService.bin, "aura", "power", targetZone, "--help"]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.indexOf("--awake") >= 0) {
                        var zones = auraService.availableZones.slice();
                        if (zones.indexOf(auraProbeProc.targetZone) < 0) {
                            zones.push(auraProbeProc.targetZone);
                            auraService.availableZones = zones;
                        }
                        auraService._readZoneState(auraProbeProc.targetZone);
                    }
                }
            }
        }

        Process {
            id: auraReadProc
            running: false
            property string targetZone: ""
            command: [auraService.bin, "aura", "power", targetZone]
            stdout: StdioCollector {
                onStreamFinished: {
                    var zone = auraReadProc.targetZone;
                    var states = auraService.zoneStates[zone] || { boot: false, awake: false, sleep: false, shutdown: false };
                    var lines = text.trim().split("\n");
                    for (var k = 0; k < lines.length; k++) {
                        var l = lines[k].trim().toLowerCase();
                        if (l.indexOf("awake:") >= 0) states.awake = l.indexOf("true") >= 0;
                        else if (l.indexOf("sleep:") >= 0) states.sleep = l.indexOf("true") >= 0;
                        else if (l.indexOf("boot:") >= 0) states.boot = l.indexOf("true") >= 0;
                        else if (l.indexOf("shutdown:") >= 0) states.shutdown = l.indexOf("true") >= 0;
                    }
                    var newStates = JSON.parse(JSON.stringify(auraService.zoneStates));
                    newStates[zone] = states;
                    auraService.zoneStates = newStates;
                }
            }
        }

        Process {
            id: auraSetPowerProc
            running: false
            property string targetZone: ""
            onExited: function(exitCode) {
                if (exitCode === 0) auraService._readZoneState(targetZone);
                else Logger.e("AsusctlAura", "Failed to set power for " + targetZone);
            }
        }

        Process {
            id: auraSetEffectProc
            running: false
            onExited: function(exitCode) {
                if (exitCode !== 0) Logger.e("AsusctlAura", "Failed to set effect");
            }
        }

        Connections {
            target: auraProbeProc
            function onExited() {
                if (auraService._probing) Qt.callLater(auraService._probeNext);
            }
        }

        function probeZones() {
            availableZones = [];
            zoneStates = {};
            _probeQueue = knownZones.slice();
            _probing = true;
            _probeNext();
        }

        function _probeNext() {
            if (_probeQueue.length === 0) { _probing = false; return; }
            auraProbeProc.targetZone = _probeQueue.shift();
            auraProbeProc.running = true;
        }

        function _readZoneState(zone) {
            auraReadProc.targetZone = zone;
            if (!auraReadProc.running) auraReadProc.running = true;
        }

        function setZonePower(zone, boot, awake, sleep, shutdown) {
            if (auraSetPowerProc.running) return;
            var args = [bin, "aura", "power", zone];
            if (boot) args.push("--boot");
            if (awake) args.push("--awake");
            if (sleep) args.push("--sleep");
            if (shutdown) args.push("--shutdown");
            auraSetPowerProc.targetZone = zone;
            auraSetPowerProc.command = args;
            auraSetPowerProc.running = true;
        }

        function setEffect(effectName, colour, zone) {
            if (auraSetEffectProc.running) return;
            var args = [bin, "aura", "effect", effectName];
            if (colour && colour.length > 0) { args.push("-c"); args.push(colour); }
            if (zone && zone.length > 0) { args.push("--zone"); args.push(zone); }
            auraSetEffectProc.command = args;
            auraSetEffectProc.running = true;
        }

        function nextEffect() {
            if (auraSetEffectProc.running) return;
            auraSetEffectProc.command = [bin, "aura", "effect", "--next-mode"];
            auraSetEffectProc.running = true;
        }

        function prevEffect() {
            if (auraSetEffectProc.running) return;
            auraSetEffectProc.command = [bin, "aura", "effect", "--prev-mode"];
            auraSetEffectProc.running = true;
        }

        Component.onCompleted: probeZones()
    }

    // ============================================================
    // Binary discovery
    // ============================================================
    Process {
        id: findProc
        command: ["sh", "-c", "command -v asusctl || which asusctl || echo /usr/bin/asusctl"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var path = text.trim();
                if (path.length > 0) {
                    root.asusctlBin = path;
                    Logger.i("AsusctlControl", "asusctl binary: " + path);
                }
            }
        }
        onExited: function(exitCode) {
            if (root.asusctlBin.length > 0) {
                checkProc.running = true;
            } else {
                Logger.w("AsusctlControl", "asusctl not found in PATH");
            }
        }
    }

    Process {
        id: checkProc
        command: [root.asusctlBin, "info"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("asusctl v") === 0)
                        root.asusctlVersion = line.substring("asusctl ".length).trim();
                    else if (line.indexOf("Product family:") >= 0)
                        root.productFamily = line.substring(line.indexOf(":") + 1).trim();
                    else if (line.indexOf("Board name:") >= 0)
                        root.boardName = line.substring(line.indexOf(":") + 1).trim();
                }
            }
        }
        onExited: function(exitCode) {
            root.isAvailable = (exitCode === 0);
            if (root.isAvailable) {
                Logger.i("AsusctlControl", "asusctl " + root.asusctlVersion + " (" + root.productFamily + ")");
                root.refreshAll();
            } else {
                Logger.w("AsusctlControl", "asusctl info failed, exitCode=" + exitCode);
            }
        }
    }

    // ============================================================
    // Polling
    // ============================================================
    Timer {
        id: pollingTimer
        interval: pluginApi?.pluginSettings?.pollingIntervalMs ?? 5000
        running: root.isAvailable && (pluginApi?.pluginSettings?.pollingEnabled ?? false)
        repeat: true
        onTriggered: root.refreshAll()
    }

    function refreshAll() {
        profileService.refresh();
        ledService.refresh();
        batteryService.refresh();
        fanCurveService.refresh();
    }

    // ============================================================
    // IPC
    // ============================================================
    IpcHandler {
        target: "plugin:asus-control"

        function toggle() {
            if (pluginApi) {
                pluginApi.withCurrentScreen(screen => {
                    pluginApi.togglePanel(screen);
                });
            }
        }

        function setProfile(name: string) {
            if (root.isAvailable && name) root.profileService.setProfile(name);
        }

        function setLedBrightness(level: string) {
            if (root.isAvailable && level) root.ledService.setBrightness(level);
        }

        function setBatteryLimit(percent: string) {
            if (root.isAvailable && percent) root.batteryService.setLimit(parseInt(percent));
        }

        function refresh() {
            root.refreshAll();
        }
    }

    Component.onCompleted: {
        findProc.running = true;
    }
}
