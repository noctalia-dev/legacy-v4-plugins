import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Power

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
    property string activeProfile: ""
    property string acProfile: ""
    property string batteryProfile: ""
    property var availableProfiles: []
    property bool _syncingProfile: false

    Process {
        id: profileListProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var profiles = [];
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim();
                    if (p.length > 0) profiles.push(p);
                }
                root.availableProfiles = profiles;
            }
        }
    }

    Process {
        id: profileGetProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("Active profile:") === 0)
                        root.activeProfile = line.substring("Active profile:".length).trim();
                    else if (line.indexOf("AC profile") === 0)
                        root.acProfile = line.substring("AC profile".length).trim();
                    else if (line.indexOf("Battery profile") === 0)
                        root.batteryProfile = line.substring("Battery profile".length).trim();
                }
            }
        }
    }

    Process {
        id: profileSetProc
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) root._refreshProfile();
            else Logger.e("AsusctlProfile", "Failed to set profile");
        }
    }

    function _refreshProfile() {
        if (profileListProc.running || profileGetProc.running) return;
        profileListProc.command = [asusctlBin, "profile", "list"];
        profileGetProc.command = [asusctlBin, "profile", "get"];
        profileListProc.running = true;
        profileGetProc.running = true;
    }

    function _setProfile(name) {
        if (profileSetProc.running) return;
        profileSetProc.command = [asusctlBin, "profile", "set", name];
        profileSetProc.running = true;
        root._syncAsusToNoctalia(name);
    }

    // --- Noctalia ↔ asusctl profile sync ---

    property var _noctaliaToAsusMap: ({
        "performance": "Performance",
        "balanced": "Balanced",
        "powersaver": "Quiet"
    })

    function _asusToNoctaliaKey(asusName) {
        var lower = asusName.toLowerCase();
        if (lower.indexOf("performance") >= 0 || lower.indexOf("turbo") >= 0 || lower.indexOf("boost") >= 0)
            return "performance";
        if (lower.indexOf("quiet") >= 0 || lower.indexOf("silent") >= 0 || lower.indexOf("powersaver") >= 0)
            return "powersaver";
        return "balanced";
    }

    function _syncAsusToNoctalia(asusName) {
        if (!pluginApi?.pluginSettings?.syncPowerProfiles) return;
        if (root._syncingProfile) return;
        root._syncingProfile = true;
        var noctaliaKey = root._asusToNoctaliaKey(asusName);
        var map = root._noctaliaToAsusMap;
        var idx = -1;
        if (noctaliaKey === "performance") idx = 2;
        else if (noctaliaKey === "powersaver") idx = 0;
        else idx = 1;
        PowerProfileService.setProfile(idx);
        Logger.i("AsusctlSync", "ASUS profile '" + asusName + "' → Noctalia " + noctaliaKey);
        root._syncingProfile = false;
    }

    function _syncNoctaliaToAsus() {
        if (!pluginApi?.pluginSettings?.syncPowerProfiles) return;
        if (root._syncingProfile) return;
        root._syncingProfile = true;
        var noctaliaKey = PowerProfileService.getIcon();
        var map = root._noctaliaToAsusMap;
        var asusTarget = map[noctaliaKey] || "Balanced";
        // Check if the target profile exists in available profiles
        var found = false;
        for (var i = 0; i < root.availableProfiles.length; i++) {
            if (root.availableProfiles[i].toLowerCase() === asusTarget.toLowerCase()) {
                asusTarget = root.availableProfiles[i];
                found = true;
                break;
            }
        }
        if (!found) {
            // Try fuzzy match
            for (var j = 0; j < root.availableProfiles.length; j++) {
                if (root.availableProfiles[j].toLowerCase().indexOf(noctaliaKey) >= 0) {
                    asusTarget = root.availableProfiles[j];
                    found = true;
                    break;
                }
            }
        }
        if (found) {
            Logger.i("AsusctlSync", "Noctalia " + noctaliaKey + " → ASUS profile '" + asusTarget + "'");
            root._setProfileRaw(asusTarget);
        } else {
            Logger.w("AsusctlSync", "No profile matches Noctalia '" + noctaliaKey + "'");
        }
        root._syncingProfile = false;
    }

    function _setProfileRaw(name) {
        if (profileSetProc.running) return;
        profileSetProc.command = [asusctlBin, "profile", "set", name];
        profileSetProc.running = true;
    }

    Connections {
        target: PowerProfileService
        function onProfileChanged() {
            root._syncNoctaliaToAsus();
        }
    }

    // ============================================================
    // Aura color sync (theme settle)
    // ============================================================
    property bool _themeSettled: true

    Timer {
        id: themeSettleTimer
        interval: 300
        onTriggered: {
            root._themeSettled = true;
            root._applyAuraColorSync();
        }
    }

    Connections {
        target: Color
        function onIsTransitioningChanged() {
            if (!pluginApi?.pluginSettings?.syncAuraColor) return;
            if (Color.isTransitioning) {
                root._themeSettled = false;
                themeSettleTimer.restart();
            } else if (root._themeSettled) {
                root._applyAuraColorSync();
            }
        }
    }

    function _applyAuraColorSync() {
        if (!root.isAvailable) return;
        if (!pluginApi?.pluginSettings?.syncAuraColor) return;
        var source = pluginApi?.pluginSettings?.auraColorSource ?? "primary";
        var resolved = Color.resolveColorKey(source);
        if (!resolved) return;
        var hex = resolved.toString();
        if (hex && hex.charAt(0) === "#") hex = hex.substring(1);
        root._auraSetEffect("static", "#" + hex, "");
        Logger.i("AsusctlAuraSync", "Theme color '" + source + "' → aura #" + hex);
    }

    // ============================================================
    // LED Service
    // ============================================================
    property string ledBrightness: ""
    property int ledBrightnessIndex: -1
    property var ledLevels: ["off", "low", "med", "high"]
    property var ledLevelLabels: ["Off", "Low", "Medium", "High"]

    Process {
        id: ledGetProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                var marker = "Current keyboard led brightness: ";
                var idx = t.indexOf(marker);
                if (idx >= 0) {
                    var level = t.substring(idx + marker.length).trim().toLowerCase();
                    root.ledBrightness = level;
                    root.ledBrightnessIndex = root.ledLevels.indexOf(level);
                } else {
                    root.ledBrightness = "";
                    root.ledBrightnessIndex = -1;
                }
            }
        }
    }

    Process {
        id: ledSetProc
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) { ledGetProc.command = [asusctlBin, "leds", "get"]; ledGetProc.running = true; }
            else Logger.e("AsusctlLed", "Failed to set brightness");
        }
    }

    function _refreshLed() {
        if (!ledGetProc.running) { ledGetProc.command = [asusctlBin, "leds", "get"]; ledGetProc.running = true; }
    }

    function _setLedBrightness(level) {
        if (ledSetProc.running) return;
        ledSetProc.command = [asusctlBin, "leds", "set", level];
        ledSetProc.running = true;
    }

    // ============================================================
    // Battery Service
    // ============================================================
    property int chargeLimit: -1

    Process {
        id: batInfoProc
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
                        root.chargeLimit = val;
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
                root.chargeLimit = pendingLimit;
                Logger.i("AsusctlBattery", "Charge limit set to " + pendingLimit + "%");
            } else {
                Logger.e("AsusctlBattery", "Failed to set charge limit");
                batInfoProc.command = [asusctlBin, "battery", "info"];
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

    function _refreshBattery() {
        if (!batInfoProc.running) { batInfoProc.command = [asusctlBin, "battery", "info"]; batInfoProc.running = true; }
    }

    function _setBatteryLimit(percent) {
        if (batSetProc.running) return;
        var v = Math.round(Math.max(20, Math.min(100, percent)));
        batSetProc.pendingLimit = v;
        batSetProc.command = [asusctlBin, "battery", "limit", v.toString()];
        batSetProc.running = true;
    }

    function _triggerOneshot() {
        if (batOneshotProc.running) return;
        batOneshotProc.command = [asusctlBin, "battery", "oneshot"];
        batOneshotProc.running = true;
    }

    // ============================================================
    // Fan Curve Service
    // ============================================================
    property var fanStates: ({})
    property var availableFanTypes: []

    Process {
        id: fanEnabledProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: { root._parseFanEnabled(text); }
        }
    }

    Process {
        id: fanDataProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: { root._parseFanCurveData(text); }
        }
    }

    Process {
        id: fanSetProc
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) root._refreshFan();
            else Logger.e("AsusctlFanCurve", "Failed to set fan curve");
        }
    }

    Process {
        id: fanEnableProc
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) { fanEnabledProc.command = [asusctlBin, "fan-curve", "--get-enabled"]; fanEnabledProc.running = true; }
            else Logger.e("AsusctlFanCurve", "Failed to toggle fan curve");
        }
    }

    Process {
        id: fanDefaultProc
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) root._refreshFan();
            else Logger.e("AsusctlFanCurve", "Failed to reset to default");
        }
    }

    function _refreshFan() {
        if (!fanEnabledProc.running) { fanEnabledProc.command = [asusctlBin, "fan-curve", "--get-enabled"]; fanEnabledProc.running = true; }
        var profile = root.activeProfile || "Balanced";
        if (!fanDataProc.running) { fanDataProc.command = [asusctlBin, "fan-curve", "--mod-profile", profile]; fanDataProc.running = true; }
    }

    function _setFanEnabled(profile, fan, enabled) {
        if (fanEnableProc.running) return;
        fanEnableProc.command = [asusctlBin, "fan-curve", "--enable-fan-curve", enabled ? "true" : "false", "--mod-profile", profile, "--fan", fan];
        fanEnableProc.running = true;
    }

    function _resetFanToDefault(profile) {
        if (fanDefaultProc.running) return;
        fanDefaultProc.command = [asusctlBin, "fan-curve", "--default", "--mod-profile", profile];
        fanDefaultProc.running = true;
    }

    function _parseFanEnabled(text) {
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
        root.availableFanTypes = fans;
        root.fanStates = states;
    }

    function _parseFanCurveData(text) {
        var lines = text.trim().split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            var fanMatch = line.match(/fan:\s*(\w+)/);
            var pwmMatch = line.match(/pwm:\s*\(([^)]+)\)/);
            var tempMatch = line.match(/temp:\s*\(([^)]+)\)/);
            if (fanMatch && pwmMatch && tempMatch) {
                var pwms = pwmMatch[1].split(",").map(function(s) { return parseInt(s.trim()); });
                var temps = tempMatch[1].split(",").map(function(s) { return parseInt(s.trim()); });
                var points = [];
                for (var j = 0; j < Math.min(pwms.length, temps.length); j++)
                    points.push({ temp: temps[j], pwm: pwms[j] });
            }
        }
    }

    // ============================================================
    // Aura Service
    // ============================================================
    property var auraAvailableZones: []
    property var auraZoneStates: ({})
    property var auraKnownZones: ["keyboard", "logo", "lightbar", "lid", "rear-glow", "ally"]
    property var _auraProbeQueue: []
    property bool _auraProbing: false

    Process {
        id: auraProbeProc
        running: false
        property string targetZone: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.indexOf("--awake") >= 0) {
                    var zones = root.auraAvailableZones.slice();
                    if (zones.indexOf(auraProbeProc.targetZone) < 0) {
                        zones.push(auraProbeProc.targetZone);
                        root.auraAvailableZones = zones;
                    }
                    root._auraReadZoneState(auraProbeProc.targetZone);
                }
            }
        }
    }

    Process {
        id: auraReadProc
        running: false
        property string targetZone: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var zone = auraReadProc.targetZone;
                var states = root.auraZoneStates[zone] || { boot: false, awake: false, sleep: false, shutdown: false };
                var lines = text.trim().split("\n");
                for (var k = 0; k < lines.length; k++) {
                    var l = lines[k].trim().toLowerCase();
                    if (l.indexOf("awake:") >= 0) states.awake = l.indexOf("true") >= 0;
                    else if (l.indexOf("sleep:") >= 0) states.sleep = l.indexOf("true") >= 0;
                    else if (l.indexOf("boot:") >= 0) states.boot = l.indexOf("true") >= 0;
                    else if (l.indexOf("shutdown:") >= 0) states.shutdown = l.indexOf("true") >= 0;
                }
                var newStates = JSON.parse(JSON.stringify(root.auraZoneStates));
                newStates[zone] = states;
                root.auraZoneStates = newStates;
            }
        }
    }

    Process {
        id: auraSetPowerProc
        running: false
        property string targetZone: ""
        onExited: function(exitCode) {
            if (exitCode === 0) root._auraReadZoneState(targetZone);
            else Logger.e("AsusctlAura", "Failed to set power for " + targetZone);
        }
    }

    Process {
        id: auraSetEffectProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    Logger.e("AsusctlAura", "stderr: " + text.trim());
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) Logger.e("AsusctlAura", "Failed to set effect (exitCode=" + exitCode + ")");
        }
    }

    Process {
        id: auraModeProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    Logger.e("AsusctlAura", "mode stderr: " + text.trim());
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) Logger.e("AsusctlAura", "Failed to switch mode (exitCode=" + exitCode + ")");
        }
    }

    Connections {
        target: auraProbeProc
        function onExited() {
            if (root._auraProbing) Qt.callLater(root._auraProbeNext);
        }
    }

    function _auraProbeZones() {
        root.auraAvailableZones = [];
        root.auraZoneStates = {};
        root._auraProbeQueue = root.auraKnownZones.slice();
        root._auraProbing = true;
        root._auraProbeNext();
    }

    function _auraProbeNext() {
        if (root._auraProbeQueue.length === 0) { root._auraProbing = false; return; }
        auraProbeProc.targetZone = root._auraProbeQueue.shift();
        auraProbeProc.command = [asusctlBin, "aura", "power", auraProbeProc.targetZone, "--help"];
        auraProbeProc.running = true;
    }

    function _auraReadZoneState(zone) {
        auraReadProc.targetZone = zone;
        auraReadProc.command = [asusctlBin, "aura", "power", zone];
        if (!auraReadProc.running) auraReadProc.running = true;
    }

    function _auraSetZonePower(zone, boot, awake, sleep, shutdown) {
        if (auraSetPowerProc.running) return;
        var args = [asusctlBin, "aura", "power", zone];
        if (boot) args.push("--boot");
        if (awake) args.push("--awake");
        if (sleep) args.push("--sleep");
        if (shutdown) args.push("--shutdown");
        auraSetPowerProc.targetZone = zone;
        auraSetPowerProc.command = args;
        auraSetPowerProc.running = true;
    }

    function _auraSetEffect(effectName, colour, zone) {
        if (auraSetEffectProc.running) return;
        var hex = colour;
        if (hex && hex.charAt(0) === "#") hex = hex.substring(1);
        var args = [asusctlBin, "aura", "effect", effectName];
        if (hex && hex.length > 0) { args.push("-c"); args.push(hex); }
        if (zone && zone.length > 0) { args.push("--zone"); args.push(zone); }
        auraSetEffectProc.command = args;
        auraSetEffectProc.running = true;
    }

    function _auraNextEffect() {
        if (auraModeProc.running) return;
        auraModeProc.command = [asusctlBin, "aura", "effect", "--next-mode"];
        auraModeProc.running = true;
    }

    function _auraPrevEffect() {
        if (auraModeProc.running) return;
        auraModeProc.command = [asusctlBin, "aura", "effect", "--prev-mode"];
        auraModeProc.running = true;
    }

    // ============================================================
    // Binary discovery
    // ============================================================
    Process {
        id: findProc
        running: false
        command: ["sh", "-c", "asusctl info 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (t.length === 0) return;
                var lines = t.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("asusctl v") === 0)
                        root.asusctlVersion = line.substring("asusctl ".length).trim();
                    else if (line.indexOf("Product family:") >= 0)
                        root.productFamily = line.substring(line.indexOf(":") + 1).trim();
                    else if (line.indexOf("Board name:") >= 0)
                        root.boardName = line.substring(line.indexOf(":") + 1).trim();
                }
                root.asusctlBin = "asusctl";
                root.isAvailable = true;
                Logger.i("AsusctlControl", "asusctl " + root.asusctlVersion + " (" + root.productFamily + ")");
                root.refreshAll();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    Logger.w("AsusctlControl", "stderr: " + text.trim());
            }
        }
        onExited: function(exitCode) {
            Logger.i("AsusctlControl", "findProc exited, code=" + exitCode + ", available=" + root.isAvailable);
            if (exitCode !== 0 && !root.isAvailable) {
                Logger.w("AsusctlControl", "asusctl not found (exitCode=" + exitCode + ")");
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
        if (!root.isAvailable) return;
        root._refreshProfile();
        root._refreshLed();
        root._refreshBattery();
        root._refreshFan();
        root._auraProbeZones();
    }

    // ============================================================
    // Service accessors for Panel.qml compatibility
    // ============================================================
    readonly property var profileService: ({
        activeProfile: root.activeProfile,
        acProfile: root.acProfile,
        batteryProfile: root.batteryProfile,
        availableProfiles: root.availableProfiles,
        setProfile: function(name) { root._setProfile(name); },
        refresh: function() { root._refreshProfile(); }
    })

    readonly property var ledService: ({
        brightness: root.ledBrightness,
        brightnessIndex: root.ledBrightnessIndex,
        levels: root.ledLevels,
        levelLabels: root.ledLevelLabels,
        setBrightness: function(level) { root._setLedBrightness(level); },
        refresh: function() { root._refreshLed(); }
    })

    readonly property var batteryService: ({
        chargeLimit: root.chargeLimit,
        setLimit: function(percent) { root._setBatteryLimit(percent); },
        triggerOneshot: function() { root._triggerOneshot(); },
        refresh: function() { root._refreshBattery(); }
    })

    readonly property var fanCurveService: ({
        fanStates: root.fanStates,
        availableFanTypes: root.availableFanTypes,
        setFanEnabled: function(profile, fan, enabled) { root._setFanEnabled(profile, fan, enabled); },
        resetToDefault: function(profile) { root._resetFanToDefault(profile); },
        refresh: function() { root._refreshFan(); }
    })

    readonly property var auraService: ({
        availableZones: root.auraAvailableZones,
        zoneStates: root.auraZoneStates,
        setZonePower: function(zone, boot, awake, sleep, shutdown) { root._auraSetZonePower(zone, boot, awake, sleep, shutdown); },
        setEffect: function(effectName, colour, zone) { root._auraSetEffect(effectName, colour, zone); },
        nextEffect: function() { root._auraNextEffect(); },
        prevEffect: function() { root._auraPrevEffect(); },
        probeZones: function() { root._auraProbeZones(); }
    })

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
            if (root.isAvailable && name) root._setProfile(name);
        }

        function setLedBrightness(level: string) {
            if (root.isAvailable && level) root._setLedBrightness(level);
        }

        function setBatteryLimit(percent: string) {
            if (root.isAvailable && percent) root._setBatteryLimit(parseInt(percent));
        }

        function refresh() {
            root.refreshAll();
        }
    }

    Component.onCompleted: {
        findProc.running = true;
    }
}
