import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var pluginApi: null

    property int leftCount: 0
    property int rightCount: 0
    property real ratioStart: 0
    property real ratioWidth: 1

    Process {
        id: niriRibbonScript
        command: ["python3", Quickshell.env("HOME") + "/projects/noctalia-niri-ribbon/niri_ribbon.py"]
        running: true
        
        stdout: SplitParser {
            onRead: line => {
                const parts = line.trim().split("|");
                if (parts.length === 4) {
                    root.leftCount = parseInt(parts[0]);
                    root.rightCount = parseInt(parts[1]);
                    root.ratioStart = parseFloat(parts[2]);
                    root.ratioWidth = parseFloat(parts[3]);
                }
            }
        }
    }
}
