import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property QtObject pluginApi: null
    readonly property string pluginId: pluginApi?.pluginId

    property var outputs: ({})
    property bool available: false

    readonly property Process niriMsg: Process {
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") return;
                try {
                    root.outputs = JSON.parse(text);
                    root.available = true;
                } catch (e) {
                    root.available = false;
                    console.error("Failed to parse niri outputs:", e);
                }
            }
        }
    }

    Component.onCompleted: refresh()

    function refresh() {
        niriMsg.running = true;
    }

    function setScale(outputName, scale) {
        runCommand(["niri", "msg", "output", outputName, "scale", scale.toString()]);
    }

    function setMode(outputName, width, height, refreshRate) {
        const rate = (refreshRate / 1000).toFixed(3);
        runCommand(["niri", "msg", "output", outputName, "mode", `${width}x${height}@${rate}`]);
    }

    function setTransform(outputName, transform) {
        runCommand(["niri", "msg", "output", outputName, "transform", transform]);
    }

    function setPosition(outputName, x, y) {
        runCommand(["niri", "msg", "output", outputName, "position", "set", x.toString(), y.toString()]);
    }

    function toggleOutput(outputName, on) {
        runCommand(["niri", "msg", "output", outputName, on ? "on" : "off"]);
    }

    function runCommand(cmd) {
        const component = Qt.createComponent("CommandRunner.qml");
        if (component.status !== Component.Ready) {
             if (component.status === Component.Error) {
                console.error("Error loading CommandRunner.qml:", component.errorString());
            }
            return;
        }

        const runner = component.createObject(root, { "command": cmd });
        if (runner) {
            runner.exited.connect(() => root.refresh());
        }
    }
}
