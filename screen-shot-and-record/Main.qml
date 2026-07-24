import QtQuick
import Quickshell.Io
import qs.Services.UI
import QtQml.Models
import Quickshell
import qs.Commons
import qs.Services.Compositor

Item {
    id: root
    property var pluginApi: null
    property bool active: false
    property bool recordingActive: false
    property string target: ""
    property string recordingCheckTarget: ""

    Component.onCompleted: {
        Logger.d("ScreenShot", "[Main] Component.onCompleted compositor=sway:",
                 CompositorService.isSway, "hyprland:", CompositorService.isHyprland,
                 "niri:", CompositorService.isNiri,
                 "selectorSource=", root.selectorSource,
                 "screens count=", Quickshell.screens?.length)
    }

    Component.onDestruction: {
        Logger.d("ScreenShot", "[Main] Component.onDestruction")
    }

    Process {
        id: recordingCheckProc
        command: ["pidof", "wf-recorder"]
        running: false
        onExited: (exitCode) => {
            const requestedTarget = root.recordingCheckTarget
            root.recordingCheckTarget = ""

            Logger.d("ScreenShot", "[Main] recordingCheckProc onExited code=", exitCode,
                     "requestedTarget=", requestedTarget)

            if (requestedTarget === "") {
                return
            }

            if (exitCode === 0) {
                Logger.d("ScreenShot", "[Main] recordingCheckProc: wf-recorder is running, stopping")
                root.stopRecording()
                return
            }

            Logger.d("ScreenShot", "[Main] recordingCheckProc: wf-recorder not running, opening selector for", requestedTarget)
            root.openSelector(requestedTarget)
        }
    }

    function stopRecording() {
        Logger.d("ScreenShot", "[Main] stopRecording() pluginDir=", pluginApi?.pluginDir,
                 "recordingActive=", root.recordingActive)

        if (!pluginApi?.pluginDir) {
            Logger.w("ScreenShot", "[Main] stopRecording: no pluginDir")
            return
        }

        const recordingNotificationsEnabled = pluginApi?.pluginSettings?.recordingNotifications
                                           ?? pluginApi?.manifest?.metadata?.defaultSettings?.recordingNotifications
                                           ?? true

        recordingActive = false
        const stopArgs = ["bash", pluginApi.pluginDir + "/record.sh"]
        if (recordingNotificationsEnabled) {
            stopArgs.push("--notify")
        }
        stopArgs.push(...buildRecordingNotifyArgs())
        Logger.d("ScreenShot", "[Main] stopRecording: executing", stopArgs)
        Quickshell.execDetached(stopArgs)
    }

    function buildRecordingNotifyArgs() {
        return [
            "--notify-app", pluginApi?.tr("notify.app.recorder"),
            "--notify-cancelled-title", pluginApi?.tr("notify.recording.cancelledTitle"),
            "--notify-no-region-body", pluginApi?.tr("notify.recording.noRegionBody"),
            "--notify-no-dir-body", pluginApi?.tr("notify.recording.noDirBody"),
            "--notify-stopped-title", pluginApi?.tr("notify.recording.stoppedTitle"),
            "--notify-stopped-body", pluginApi?.tr("notify.recording.stoppedBody"),
            "--notify-starting-title", pluginApi?.tr("notify.recording.startingTitle")
        ]
    }

    readonly property string selectorSource: CompositorService.isSway ? "ScreenShotSway.qml"
                                           : CompositorService.isHyprland ? "ScreenShotHypr.qml"
                                           : CompositorService.isNiri ? "ScreenShotNiri.qml"
                                           : "ScreenShot.qml"
    Instantiator {
        id: selectorInstantiator
        active: root.active
        model: Quickshell.screens
        delegate: Loader {
            required property int index
            source: root.selectorSource
            onLoaded: {
                item.pluginApi = root.pluginApi
                item.screen = Quickshell.screens[index]
                item.target = root.target
                item.closed.connect(() => root.close())
                item.startCapture()
            }
        }
    }

    function openSelector(target) {
        if (root.active) return

        root.target = target
        active = true
    }

    function open(target) {
        Logger.d("ScreenShot", "[Main] open(" + target + ") recordingCheckTarget=",
                 root.recordingCheckTarget, "active=", root.active)

        if (target === "record" || target === "recordsound") {
            if (root.recordingCheckTarget !== "") {
                return
            }

            root.recordingCheckTarget = target
            recordingCheckProc.running = true
            return
        }

        root.openSelector(target)
    }

    function close() {
        if (!root.active) return

        active = false
        root.target = ""
    }

    IpcHandler {
        target: "plugin:screen-shot-and-record"
        function screenshot() {
            open("screenshot")
        }

        function search() {
            open("search")
        }

        function ocr() {
            open("ocr")
        }

        function record() {
            open("record")
        }

        function recordsound() {
            open("recordsound")
        }

        function stoprecord() {
            root.stopRecording()
        }
    }
}
