import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var pluginApi: null
    property bool recordingActive: false

    readonly property string scriptPath: pluginApi?.pluginDir ? pluginApi.pluginDir + "/screencast-gif.sh" : ""
    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function trigger() {
        if (!scriptPath) return
        const fps = cfg.fps ?? defaults.fps ?? 20
        const maxSecs = cfg.maxRecordingSeconds ?? defaults.maxRecordingSeconds ?? 120
        const outDir = cfg.outputDir ?? defaults.outputDir ?? "~/Screenshots"
        const env = "FPS=" + fps + " MAX_SECS=" + maxSecs + " OUTDIR=" + shellQuote(outDir)
        Quickshell.execDetached(["sh", "-c", env + " " + shellQuote(scriptPath)])
    }

    Process {
        id: checker
        running: false
        command: ["sh", "-c", "[ -f /tmp/screencast-gif.pid ] && kill -0 \"$(awk '{print $1}' /tmp/screencast-gif.pid 2>/dev/null)\" 2>/dev/null && printf 1 || printf 0"]
        stdout: StdioCollector {
            onStreamFinished: root.recordingActive = (text === "1")
        }
        onExited: checker.running = false
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: checker.running = true
    }

    IpcHandler {
        target: "plugin:screencast-gif"
        function toggle() { root.trigger() }
    }
}
