import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    property string currentProfile: ""
    property var profiles: []
    property bool available: false
    property bool busy: false

    Component.onCompleted: {
        refresh();
    }

    function getProfileIcon(profile) {
        switch (profile) {
        case "power-saver":
            return "leaf";
        case "balanced":
            return "bolt";
        case "performance":
            return "rocket";
        default:
            return "cpu";
        }
    }

    function getProfileLabel(profile) {
        var key = "profile." + profile;
        var translated = pluginApi?.tr(key);
        if (translated && translated !== key) {
            return translated;
        }
        // Fallback: capitalize and replace hyphens
        return profile.replace(/-/g, " ").replace(/\b\w/g, c => c.toUpperCase());
    }

    function refresh() {
        if (busy) return;
        busy = true;
        listProcess.running = true;
    }

    function setProfile(profile) {
        if (busy) return;
        busy = true;
        setProcess.command = ["powerprofilesctl", "set", profile];
        setProcess.running = true;
    }

    // Parse `powerprofilesctl list` output.
    // Profile name lines look like: "* performance:" or "  balanced:"
    // Metadata lines look like: "    Degraded:   yes"
    function parseListOutput(text) {
        var lines = text.split("\n");
        var profileList = [];
        var current = "";
        var entry = null;

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];

            var profileMatch = line.match(/^(\*)?\s*([\w-]+):$/);
            if (profileMatch) {
                entry = { name: profileMatch[2], degraded: false };
                profileList.push(entry);
                if (profileMatch[1] === "*") {
                    current = entry.name;
                }
                continue;
            }

            if (entry) {
                var degradedMatch = line.match(/^\s+Degraded:\s+(.+)$/);
                if (degradedMatch) {
                    entry.degraded = degradedMatch[1].trim() !== "no";
                }
            }
        }

        return { profiles: profileList, current: current };
    }

    Process {
        id: listProcess
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                Logger.e("PowerProfile", "powerprofilesctl list failed with exit code " + exitCode);
                root.available = false;
                root.busy = false;
                return;
            }

            var result = root.parseListOutput(listProcess.stdout.text.trim());
            root.profiles = result.profiles;
            root.currentProfile = result.current;
            root.available = result.profiles.length > 0;
            root.busy = false;
        }
    }

    Process {
        id: setProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                Logger.e("PowerProfile", "Failed to set profile, exit code: " + exitCode);
            }
            root.busy = false;
            root.refresh();
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }
}
