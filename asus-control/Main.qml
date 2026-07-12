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

    // --- Services ---
    property var profileService: ProfileService {
        id: profileService
        pluginApi: root.pluginApi
    }

    property var ledService: LedService {
        id: ledService
        pluginApi: root.pluginApi
    }

    property var batteryService: BatteryService {
        id: batteryService
        pluginApi: root.pluginApi
    }

    property var fanCurveService: FanCurveService {
        id: fanCurveService
        pluginApi: root.pluginApi
    }

    property var auraService: AuraService {
        id: auraService
        pluginApi: root.pluginApi
    }

    // --- Step 1: Find asusctl binary ---
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

    // --- Step 2: Check asusctl info ---
    Process {
        id: checkProc
        command: [root.asusctlBin, "info"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("asusctl v") === 0) {
                        root.asusctlVersion = line.substring("asusctl ".length).trim();
                    } else if (line.indexOf("Product family:") >= 0) {
                        root.productFamily = line.substring(line.indexOf(":") + 1).trim();
                    } else if (line.indexOf("Board name:") >= 0) {
                        root.boardName = line.substring(line.indexOf(":") + 1).trim();
                    }
                }
            }
        }
        onExited: function(exitCode) {
            root.isAvailable = (exitCode === 0);
            if (root.isAvailable) {
                Logger.i("AsusctlControl", "asusctl found: " + root.asusctlVersion + " (" + root.productFamily + ")");
                root.refreshAll();
            } else {
                Logger.w("AsusctlControl", "asusctl info failed, exitCode=" + exitCode);
            }
        }
    }

    // --- Polling ---
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
        // Aura zones are probed once on init, no need to poll frequently
    }

    function checkAvailability() {
        findProc.running = true;
    }

    // --- IPC ---
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
            if (root.isAvailable && name) {
                root.profileService.setProfile(name);
            }
        }

        function setLedBrightness(level: string) {
            if (root.isAvailable && level) {
                root.ledService.setBrightness(level);
            }
        }

        function setBatteryLimit(percent: string) {
            if (root.isAvailable && percent) {
                root.batteryService.setLimit(parseInt(percent));
            }
        }

        function refresh() {
            root.refreshAll();
        }
    }

    Component.onCompleted: {
        checkAvailability();
    }
}
