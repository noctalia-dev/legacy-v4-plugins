import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    // --- Dynamic zone detection ---
    property list<string> availableZones: []
    // zone name -> { boot: bool, awake: bool, sleep: bool, shutdown: bool }
    property var zoneStates: ({})

    readonly property list<string> availableEffects: [
        "static", "breathe", "rainbow-cycle", "rainbow-wave",
        "stars", "rain", "highlight", "laser", "ripple", "pulse", "comet", "flash"
    ]

    readonly property list<string> knownZones: ["keyboard", "logo", "lightbar", "lid", "rear-glow", "ally"]

    signal zonesChanged()

    // One probe process, reused for each zone
    Process {
        id: probeProc
        running: false
        property string targetZone: ""
        command: ["asusctl", "aura", "power", targetZone, "--help"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.indexOf("--awake") >= 0) {
                    var zones = root.availableZones.slice();
                    if (zones.indexOf(probeProc.targetZone) < 0) {
                        zones.push(probeProc.targetZone);
                        root.availableZones = zones;
                    }
                    root._readZoneState(probeProc.targetZone);
                }
            }
        }
    }

    // Read process for zone state
    Process {
        id: readProc
        running: false
        property string targetZone: ""
        command: ["asusctl", "aura", "power", targetZone]
        stdout: StdioCollector {
            onStreamFinished: {
                var zone = readProc.targetZone;
                var states = root.zoneStates[zone] || { boot: false, awake: false, sleep: false, shutdown: false };
                var lines = text.trim().split("\n");
                for (var k = 0; k < lines.length; k++) {
                    var l = lines[k].trim().toLowerCase();
                    if (l.indexOf("awake:") >= 0) states.awake = l.indexOf("true") >= 0;
                    else if (l.indexOf("sleep:") >= 0) states.sleep = l.indexOf("true") >= 0;
                    else if (l.indexOf("boot:") >= 0) states.boot = l.indexOf("true") >= 0;
                    else if (l.indexOf("shutdown:") >= 0) states.shutdown = l.indexOf("true") >= 0;
                }
                var newStates = JSON.parse(JSON.stringify(root.zoneStates));
                newStates[zone] = states;
                root.zoneStates = newStates;
                root.zonesChanged();
            }
        }
    }

    // --- Set power process ---
    Process {
        id: setPowerProc
        running: false
        property string targetZone: ""
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root._readZoneState(targetZone);
            } else {
                Logger.e("AsusctlAura", "Failed to set power state for " + targetZone);
            }
        }
    }

    // --- Set effect process ---
    Process {
        id: setEffectProc
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                Logger.e("AsusctlAura", "Failed to set aura effect");
            }
        }
    }

    // Queue-based zone probing
    property list<string> _probeQueue: []
    property bool _probing: false

    function probeZones() {
        root.availableZones = [];
        root.zoneStates = {};
        _probeQueue = knownZones.slice();
        _probing = true;
        _probeNext();
    }

    function _probeNext() {
        if (_probeQueue.length === 0) {
            _probing = false;
            return;
        }
        var zone = _probeQueue.shift();
        probeProc.targetZone = zone;
        probeProc.running = true;
    }

    // Chain probe completion to next zone
    Connections {
        target: probeProc
        function onExited() {
            if (_probing) {
                Qt.callLater(root._probeNext);
            }
        }
    }

    function _readZoneState(zone) {
        readProc.targetZone = zone;
        if (!readProc.running) {
            readProc.running = true;
        }
    }

    function refreshZones() {
        for (var i = 0; i < root.availableZones.length; i++) {
            root._readZoneState(root.availableZones[i]);
        }
    }

    function setZonePower(zone, boot, awake, sleep, shutdown) {
        if (setPowerProc.running) return;
        var args = ["asusctl", "aura", "power", zone];
        if (boot) args.push("--boot");
        if (awake) args.push("--awake");
        if (sleep) args.push("--sleep");
        if (shutdown) args.push("--shutdown");

        setPowerProc.targetZone = zone;
        setPowerProc.command = args;
        setPowerProc.running = true;
        Logger.i("AsusctlAura", "Setting " + zone + " power");
    }

    function setEffect(effectName, colour, zone) {
        if (setEffectProc.running) return;
        var args = ["asusctl", "aura", "effect", effectName];
        if (colour && colour.length > 0) {
            args.push("-c");
            args.push(colour);
        }
        if (zone && zone.length > 0) {
            args.push("--zone");
            args.push(zone);
        }
        setEffectProc.command = args;
        setEffectProc.running = true;
        Logger.i("AsusctlAura", "Setting effect to " + effectName);
    }

    function nextEffect() {
        if (setEffectProc.running) return;
        setEffectProc.command = ["asusctl", "aura", "effect", "--next-mode"];
        setEffectProc.running = true;
    }

    function prevEffect() {
        if (setEffectProc.running) return;
        setEffectProc.command = ["asusctl", "aura", "effect", "--prev-mode"];
        setEffectProc.running = true;
    }

    Component.onCompleted: probeZones()
}
