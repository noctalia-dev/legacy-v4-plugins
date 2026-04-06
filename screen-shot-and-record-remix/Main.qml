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

    Process {
        id: recordingCheckProc
        command: ["pidof", "wf-recorder"]
        running: false
        onExited: (exitCode) => {
            const requestedTarget = root.recordingCheckTarget
            root.recordingCheckTarget = ""

            if (requestedTarget === "") {
                return
            }

            if (exitCode === 0) {
                root.stopRecording()
                return
            }

            root.openSelector(requestedTarget)
        }
    }

    function stopRecording() {
        if (!pluginApi?.pluginDir) {
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

    function openSelector(target) {
        if (active) {
            return
        }

     //   if (CompositorService.isNiri) {
     //       // Show a notification that Niri is not supported (i18n only)
     //       pluginApi?.mainInstance?.showToast?.(pluginApi?.tr("screenshot.niriNotSupported"));
    //        Logger.w("ScreenShot", "Niri is not supported for screenshots.");
    //        return;
    //    }

        root.target = target
        active = true
    }

    // 存储当前所有屏幕
    property var screens: Quickshell.screens
    readonly property string selectorSource: CompositorService.isSway ? "ScreenShotSway.qml"
                                           : CompositorService.isHyprland ? "ScreenShotHypr.qml"
                                           : "ScreenShot.qml"

    // 使用 Instantiator 管理选择框
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
                Logger.d("ScreenShot", (root.target))
                item.target = root.target
                item.closed.connect(() => root.close())
                item.startCapture()
            }
        }
        onObjectAdded: (index, object) => Logger.d("ScreenShot", ("Selector added for screen", index))
        onObjectRemoved: (index, object) => Logger.d("ScreenShot", ("Selector removed for screen", index))
    }

    function open(target) {
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
