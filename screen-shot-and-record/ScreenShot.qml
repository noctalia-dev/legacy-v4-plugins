import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Widgets
import QtQuick.Layouts

PanelWindow {
    id: root
    property var pluginApi: null
    visible: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "noctalia-shell:regionSelector"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    property var target: ""
    property bool enableCross: pluginApi?.pluginSettings?.enableCross
                               ?? pluginApi?.manifest?.metadata?.defaultSettings?.enableCross
                               ?? true

    property bool mouseOnThisScreen: false

    readonly property real monitorOffsetX: Number(root.screen?.x ?? 0)
    readonly property real monitorOffsetY: Number(root.screen?.y ?? 0)
    property string frozenSourceFile: ""
    property bool frozenSourceReady: false

    Component.onDestruction: {
        freezeCaptureProc.running = false
        checkRecordingProc.running = false
    }

    Process {
        id: checkRecordingProc
        command: ["pidof", "wf-recorder"]
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                if (root.target === "record" || root.target === "recordsound"){
                    if (pluginApi?.mainInstance) {
                        pluginApi.mainInstance.recordingActive = false
                    }
                    const stopRecordingNotificationsEnabled = pluginApi?.pluginSettings?.recordingNotifications
                                                          ?? pluginApi?.manifest?.metadata?.defaultSettings?.recordingNotifications
                                                          ?? true
                    const stopArgs = ["bash", pluginApi.pluginDir + "/record.sh"]
                    if (stopRecordingNotificationsEnabled) {
                        stopArgs.push("--notify")
                    }
                    stopArgs.push(...captureCommon.buildRecordingNotifyArgs(pluginApi))
                    Logger.d("ScreenShot", "[Panel] Executing stop command args:", stopArgs)
                    Quickshell.execDetached(stopArgs)
                    root.closeSelector()
                }
            } else if (root.target === "record" || root.target === "recordsound") {
                const outputName = root.screen ? root.screen.name : "unknown"
                const safeOutputName = outputName.replace(/[^a-zA-Z0-9_-]/g, "_")
                root.frozenSourceFile = `/tmp/screen-${safeOutputName}-frozen.ppm`
                freezeCaptureProc.command = ["grim", "-t", "ppm", "-o", outputName, root.frozenSourceFile]
                freezeCaptureProc.running = true
            }
        }
    }

    Process {
        id: freezeCaptureProc
        running: false
        onExited: (exitCode) => {
            root.frozenSourceReady = (exitCode === 0)
            Logger.d("ScreenShot", "[RegionSelector] freezeCaptureProc exited with code", exitCode,
                     "frozenSourceFile=", root.frozenSourceFile)
            if (!root.frozenSourceReady) {
                Logger.w("ScreenShot", "[RegionSelector] Frozen source capture failed; falling back to live region capture")
            }
        }
    }

    function startCapture() {
        root.frozenSourceReady = false
        root.mouseX = 0
        root.mouseY = 0
        root.mouseInside = false
        root.dragging = false

        const outputName = root.screen ? root.screen.name : "unknown"
        const safeOutputName = outputName.replace(/[^a-zA-Z0-9_-]/g, "_")
        root.frozenSourceFile = `/tmp/screen-${safeOutputName}-frozen.ppm`

        const isRecordingTarget = (root.target === "record" || root.target === "recordsound")
        if (isRecordingTarget) {
            checkRecordingProc.running = true
        } else if (typeof root.onNonRecordingStart === "function") {
            root.onNonRecordingStart()
        }

        if (!isRecordingTarget) {
            freezeCaptureProc.command = ["grim", "-t", "ppm", "-o", outputName, root.frozenSourceFile]
            freezeCaptureProc.running = true
        }
    }

    property real mouseX: 0
    property real mouseY: 0
    property bool mouseInside: false

    property real dragStartX: 0
    property real dragStartY: 0
    property real draggingX: 0
    property real draggingY: 0
    property bool dragging: false
    property var mouseButton: null

    property real regionX: Math.min(dragStartX, draggingX)
    property real regionY: Math.min(dragStartY, draggingY)
    property real regionWidth: Math.abs(draggingX - dragStartX)
    property real regionHeight: Math.abs(draggingY - dragStartY)
    readonly property real uiScale: Style.uiScaleRatio
    property var targetMeta: root
    property var onNonRecordingStart: null
    property var resolveFallbackRegion: null

    ScreenShotCaptureCommon {
        id: captureCommon
    }

    function closeSelector() {
        if (!root.visible) {
            return
        }

        Qt.callLater(() => {
            if (!root.visible) {
                return
            }
            root.visible = false
            root.closed()
        })
    }

    function finish() {
        const mode = (root.mouseButton === Qt.RightButton) ? "edit" : "copy"
        Logger.d("ScreenShot", "[RegionSelector] finish() mode=", mode,
                 "regionWidth=", root.regionWidth, "regionHeight=", root.regionHeight,
                 "dragStartX=", root.dragStartX, "dragStartY=", root.dragStartY,
                 "draggingX=", root.draggingX, "draggingY=", root.draggingY,
                 "frozenSourceReady=", root.frozenSourceReady,
                 "frozenSourceFile=", root.frozenSourceFile)
        if (root.regionWidth > 0 && root.regionHeight > 0) {
            captureCommon.processRegion(root, root.regionX, root.regionY, root.regionWidth, root.regionHeight, mode)
        } else if (typeof root.resolveFallbackRegion === "function") {
            const fallback = root.resolveFallbackRegion()
            if (fallback && fallback.width > 0 && fallback.height > 0) {
                captureCommon.processRegion(root, fallback.x, fallback.y, fallback.width, fallback.height, mode)
            } else {
                Logger.w("ScreenShot", "[RegionSelector] finish: fallback region invalid or empty",
                         fallback ? JSON.stringify(fallback) : "null")
            }
        } else {
            Logger.w("ScreenShot", "[RegionSelector] finish: no region and no resolveFallbackRegion, nothing to capture")
        }

        root.closeSelector()
    }

    ScreenShotOverlayCommon {
        host: root
    }

    function iconForTarget(t) {
        switch (t) {
            case "screenshot": return "screenshot"
            case "ocr": return "text-recognition"
            case "search": return "photo-search"
            case "record": return "camera"
            case "recordsound": return "camera-spark"
            default: return "bug"
        }
    }

    function labelForTarget(pluginApi, t) {
        switch (t) {
            case "screenshot": return pluginApi?.tr("panel.target.screenshot")
            case "ocr": return pluginApi?.tr("panel.target.ocr")
            case "search": return pluginApi?.tr("panel.target.search")
            case "record": return pluginApi?.tr("panel.target.record")
            case "recordsound": return pluginApi?.tr("panel.target.recordsound")
            default: return pluginApi?.tr("panel.target.bug")
        }
    }

}
