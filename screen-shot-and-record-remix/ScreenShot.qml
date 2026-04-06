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

    // Track if mouse is currently on this screen
    property bool mouseOnThisScreen: false

    readonly property real monitorOffsetX: Number(root.screen?.x ?? 0)
    readonly property real monitorOffsetY: Number(root.screen?.y ?? 0)
    property string frozenSourceFile: ""
    property bool frozenSourceReady: false

    Process {
        id: checkRecordingProc
        command: ["pidof", "wf-recorder"]
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                if (root.target === "record" || root.target === "recordsound"){
                    // Stop flow: if recorder is already running, stop it immediately.
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
            }
        }
    }

    Process {
        id: freezeCaptureProc
        running: false
        onExited: (exitCode) => {
            root.frozenSourceReady = (exitCode === 0)
            if (!root.frozenSourceReady) {
                Logger.w("ScreenShot", "[RegionSelector] Frozen source capture failed; falling back to live region capture")
            }
        }
    }

    function startCapture() {
        const isRecordingTarget = (root.target === "record" || root.target === "recordsound")
        if (isRecordingTarget) {
            checkRecordingProc.running = true
        } else if (typeof root.onNonRecordingStart === "function") {
            root.onNonRecordingStart()
        }

        if (root.target === "screenshot" || root.target === "search" || root.target === "ocr") {
            const outputName = root.screen ? root.screen.name : "unknown"
            const safeOutputName = outputName.replace(/[^a-zA-Z0-9_-]/g, "_")
            root.frozenSourceFile = `/tmp/screen-${safeOutputName}-${Date.now()}-frozen.png`
            root.frozenSourceReady = false
            // Capture only the current output at scale 1 so crop coordinates stay
            // in output-local logical pixels, which is correct for all resolutions.
            freezeCaptureProc.command = ["sh", "-c", "command -v grim >/dev/null 2>&1 && grim -s 1 -o \"$2\" \"$1\" && test -s \"$1\"", "sh", root.frozenSourceFile, outputName]
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

        // Avoid destroying the selector while Qt is still dispatching pointer/hover events.
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

        if (root.regionWidth > 0 && root.regionHeight > 0) {
            captureCommon.processRegion(root, root.regionX, root.regionY, root.regionWidth, root.regionHeight, mode)
        } else if (typeof root.resolveFallbackRegion === "function") {
            const fallback = root.resolveFallbackRegion()
            if (fallback && fallback.width > 0 && fallback.height > 0) {
                captureCommon.processRegion(root, fallback.x, fallback.y, fallback.width, fallback.height, mode)
            }
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
