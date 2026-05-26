import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

QtObject {
    id: root
    property var pluginApi: null

    property bool dockerAvailable: false
    property int runningCount: 0

    property var _dockerListCountProc: Process {
        command: ["docker", "ps", "-q"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                root.runningCount = output === "" ? 0 : output.split('\n').length;
            }
        }
    }

    property var _dockerCheckProc: Process {
        running: false
        command: ["docker", "--version"]
        onExited: (code, status) => {
            const res = (code === 0);
            if (root.dockerAvailable != res) {
                root.dockerAvailable = res
                root.refresh()
            }
        }
    }

    property var _pollTimer: Timer {
        interval: pluginApi?.pluginSettings?.refreshInterval || 5000
        running: true
        repeat: true
        onTriggered: {
            root.refresh()
        }
    }

    function refresh() {
        if (!root.dockerAvailable) {
            root._dockerCheckProc.running = true;

            return
        }

        root._dockerListCountProc.running = true
    }

    Component.onCompleted: {
        root._dockerCheckProc.running = true
        Logger.i("MiniDocker", "Started")
    }
}
