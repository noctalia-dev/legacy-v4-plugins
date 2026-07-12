import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    // --- State ---
    property string activeProfile: ""
    property string acProfile: ""
    property string batteryProfile: ""
    property list<string> availableProfiles: []

    signal profilesChanged()
    signal activeProfileChanged()

    Process {
        id: listProc
        command: ["asusctl", "profile", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var profiles = [];
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim();
                    if (p.length > 0)
                        profiles.push(p);
                }
                root.availableProfiles = profiles;
                root.profilesChanged();
            }
        }
    }

    Process {
        id: getProc
        command: ["asusctl", "profile", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("Active profile:") === 0) {
                        root.activeProfile = line.substring("Active profile:".length).trim();
                    } else if (line.indexOf("AC profile") === 0) {
                        root.acProfile = line.substring("AC profile".length).trim();
                    } else if (line.indexOf("Battery profile") === 0) {
                        root.batteryProfile = line.substring("Battery profile".length).trim();
                    }
                }
                root.activeProfileChanged();
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
                Logger.e("AsusctlProfile", "Failed to set profile, exitCode=" + exitCode);
            }
        }
    }

    function refresh() {
        if (listProc.running || getProc.running) return;
        listProc.running = true;
        getProc.running = true;
    }

    function setProfile(name) {
        if (setProc.running) return;
        setProc.command = ["asusctl", "profile", "set", name];
        setProc.running = true;
        Logger.i("AsusctlProfile", "Setting profile to " + name);
    }

    function setAcProfile(name) {
        if (setProc.running) return;
        setProc.command = ["asusctl", "profile", "set", "--ac", name];
        setProc.running = true;
        Logger.i("AsusctlProfile", "Setting AC profile to " + name);
    }

    function setBatteryProfile(name) {
        if (setProc.running) return;
        setProc.command = ["asusctl", "profile", "set", "--battery", name];
        setProc.running = true;
        Logger.i("AsusctlProfile", "Setting battery profile to " + name);
    }

    Component.onCompleted: refresh()
}
