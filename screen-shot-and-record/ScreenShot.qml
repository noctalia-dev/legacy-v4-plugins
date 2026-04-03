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
                    stopArgs.push(...buildRecordingNotifyArgs())
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

    function shellQuote(value) {
        return "'" + String(value ?? "").replace(/'/g, "'\"'\"'") + "'"
    }

    function buildShellRequireCmdFn(appName, failedTitle, missingMessage) {
        return `require_cmd() { if ! command -v "$1" >/dev/null 2>&1; then notify-send -a ${shellQuote(appName)} ${shellQuote(failedTitle)} ${shellQuote(missingMessage)}; exit 1; fi; }`
    }

    function buildFrozenCropCmd(sourceFile, cropGeometry, fallbackGeometry, outputPath, streamOutput) {
        const sourceArg = shellQuote(sourceFile)
        const cropArg = shellQuote(cropGeometry)
        const fallbackArg = shellQuote(fallbackGeometry)
        const magickOut = streamOutput ? "png:-" : shellQuote(outputPath)
        const grimOut = streamOutput ? "-" : shellQuote(outputPath)

        return `if command -v magick >/dev/null 2>&1; then magick ${sourceArg} -crop ${cropArg} +repage ${magickOut}; elif command -v convert >/dev/null 2>&1; then convert ${sourceArg} -crop ${cropArg} +repage ${magickOut}; else grim -g ${fallbackArg} ${grimOut}; fi`
    }

    function buildEditorCmd(editor, inputFile, outputFile) {
        if (editor === "satty") {
            return `satty --filename ${shellQuote(inputFile)} --output-filename ${shellQuote(outputFile)}`
        }

        return `${editor} -f ${shellQuote(inputFile)} -o ${shellQuote(outputFile)}`
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

    function shouldNormalizeRecordingResolution() {
        const outputName = String(root.screen?.name ?? "")
        const screens = Quickshell.screens ?? []

        let matched = root.screen
        for (let i = 0; i < screens.length; i++) {
            if (String(screens[i]?.name ?? "") === outputName) {
                matched = screens[i]
                break
            }
        }

        const scale = Number(matched?.scale ?? 1)
        const dpr = Number(matched?.devicePixelRatio ?? 1)
        return (Number.isFinite(scale) && scale > 1.01) || (Number.isFinite(dpr) && dpr > 1.01)
    }

    function processRegion(x, y, width, height, mode) {
        const localX = Math.round(x)
        const localY = Math.round(y)
        const globalX = Math.round(localX + root.monitorOffsetX)
        const globalY = Math.round(localY + root.monitorOffsetY)
        const globalW = Math.max(1, Math.round(width))
        const globalH = Math.max(1, Math.round(height))
        const geometry = `${globalX},${globalY} ${globalW}x${globalH}`

        var outputName = root.screen ? root.screen.name : "unknown"
        var safeOutputName = outputName.replace(/[^a-zA-Z0-9_-]/g, "_")
        var tempFile = `/tmp/screen-${safeOutputName}.png`
        var configuredSavePath = pluginApi?.pluginSettings?.savePath
                                 ?? pluginApi?.manifest?.metadata?.defaultSettings?.savePath
                                 ?? ""
        var screenshotDir = Settings.preprocessPath(configuredSavePath)
        if (!screenshotDir || screenshotDir === "") {
            screenshotDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
        }
        var timestamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm.ss")
        var sourceFile = `${screenshotDir}/screenshot_${timestamp}_${safeOutputName}_source.png`
        var outputFile = `${screenshotDir}/screenshot_${timestamp}_${safeOutputName}.png`
        const useFrozenSource = root.frozenSourceReady && root.frozenSourceFile !== ""
        const frozenSourceFile = root.frozenSourceFile
        // Frozen source is per-output, so crop in output-local coords.
        const cropGeometry = `${globalW}x${globalH}+${localX}+${localY}`

        Logger.d("ScreenShot", root.target)
        if (root.target === "screenshot") {
            const notifyApp = pluginApi?.tr("notify.app.screenshot")
            const copiedTitle = pluginApi?.tr("notify.screenshot.copiedTitle")
            const copiedBody = pluginApi?.tr("notify.screenshot.copiedBody")
            const savedTitle = pluginApi?.tr("notify.screenshot.savedTitle")

            if (mode === "copy") {
                const copyCmd = useFrozenSource
                    ? `${buildFrozenCropCmd(frozenSourceFile, cropGeometry, geometry, "", true)} | wl-copy --type image/png && rm -f '${frozenSourceFile}' && notify-send -a ${shellQuote(notifyApp)} ${shellQuote(copiedTitle)} ${shellQuote(copiedBody)}`
                    : `grim -g '${geometry}' - | wl-copy --type image/png && notify-send -a ${shellQuote(notifyApp)} ${shellQuote(copiedTitle)} ${shellQuote(copiedBody)}`
                Logger.d("ScreenShot", "[Panel] Executing copy command:", copyCmd)
                Quickshell.execDetached(["sh", "-c", copyCmd])
            } else if (mode === "edit") {
                const editor = pluginApi?.pluginSettings?.screenshotEditor
                               ?? pluginApi?.manifest?.metadata?.defaultSettings?.screenshotEditor
                               ?? "swappy"

                const keepSourceScreenshot = pluginApi?.pluginSettings?.keepSourceScreenshot
                                           ?? pluginApi?.manifest?.metadata?.defaultSettings?.keepSourceScreenshot
                                           ?? false

                const editorCmd = buildEditorCmd(editor, sourceFile, outputFile)
                const editCmd = useFrozenSource
                    ? `mkdir -p '${screenshotDir}' && ${buildFrozenCropCmd(frozenSourceFile, cropGeometry, geometry, sourceFile, false)} && rm -f '${frozenSourceFile}' && ${editorCmd} && if [ '${keepSourceScreenshot ? "true" : "false"}' != 'true' ]; then rm -f '${sourceFile}'; fi && notify-send -a ${shellQuote(notifyApp)} ${shellQuote(savedTitle)} "${outputFile}"`
                    : `mkdir -p '${screenshotDir}' && grim -g '${geometry}' '${sourceFile}' && ${editorCmd} && if [ '${keepSourceScreenshot ? "true" : "false"}' != 'true' ]; then rm -f '${sourceFile}'; fi && notify-send -a ${shellQuote(notifyApp)} ${shellQuote(savedTitle)} "${outputFile}"`
                Logger.d("ScreenShot", "[Panel] Executing edit command:", editCmd)
                Quickshell.execDetached(["sh", "-c", editCmd])
            }
        } else if (root.target === "search") {
            const searchCmd = useFrozenSource
                ? `${buildFrozenCropCmd(frozenSourceFile, cropGeometry, geometry, tempFile, false)} && rm -f '${frozenSourceFile}' && xdg-open \"https://lens.google.com/uploadbyurl?url=$(curl -sF files[]=@'${tempFile}' https://uguu.se/upload | jq -r '.files[0].url')\"`
                : `grim -g '${geometry}' '${tempFile}' && xdg-open \"https://lens.google.com/uploadbyurl?url=$(curl -sF files[]=@'${tempFile}' https://uguu.se/upload | jq -r '.files[0].url')\"`
            Logger.d("ScreenShot", "[Panel] Executing search command:", searchCmd)
            Quickshell.execDetached(["sh", "-c", searchCmd])
        } else if (root.target === "ocr") {
            const notifyApp = pluginApi?.tr("notify.app.screenshot")
            const depMissing = pluginApi?.tr("notify.dependencyMissing")
            const failedTitle = pluginApi?.tr("notify.ocr.failed")
            const doneTitle = pluginApi?.tr("notify.ocr.doneTitle")
            const doneCopied = pluginApi?.tr("notify.ocr.copiedBody")
            const doneNoText = pluginApi?.tr("notify.ocr.emptyBody")
            const ocrPreamble = buildShellRequireCmdFn(notifyApp, failedTitle, depMissing)
            const ocrCmd = useFrozenSource
                ? `${ocrPreamble}; require_cmd grim; require_cmd tesseract; require_cmd wl-copy; OCR_TEXT=""; ${buildFrozenCropCmd(frozenSourceFile, cropGeometry, geometry, tempFile, false)} && rm -f '${frozenSourceFile}'; if [ -s '${tempFile}' ]; then OCR_TEXT=$(tesseract '${tempFile}' stdout 2>/dev/null); fi; if [ -n "$OCR_TEXT" ]; then printf "%s" "$OCR_TEXT" | wl-copy; notify-send -a ${shellQuote(notifyApp)} ${shellQuote(doneTitle)} ${shellQuote(doneCopied)}; else notify-send -a ${shellQuote(notifyApp)} ${shellQuote(doneTitle)} ${shellQuote(doneNoText)}; fi`
                : `${ocrPreamble}; require_cmd grim; require_cmd tesseract; require_cmd wl-copy; OCR_TEXT=""; if grim -g '${geometry}' '${tempFile}'; then OCR_TEXT=$(tesseract '${tempFile}' stdout 2>/dev/null); fi; if [ -n "$OCR_TEXT" ]; then printf "%s" "$OCR_TEXT" | wl-copy; notify-send -a ${shellQuote(notifyApp)} ${shellQuote(doneTitle)} ${shellQuote(doneCopied)}; else notify-send -a ${shellQuote(notifyApp)} ${shellQuote(doneTitle)} ${shellQuote(doneNoText)}; fi`
            Logger.d("ScreenShot", "[Panel] Executing ocr command:", ocrCmd)
            Quickshell.execDetached(["sh", "-c", ocrCmd])
        } else if (root.target === "record" || root.target === "recordsound") {


            const scriptPath = pluginApi.pluginDir + '/record.sh'
            var configuredRecordingSavePath = pluginApi?.pluginSettings?.recordingSavePath
                                            ?? pluginApi?.manifest?.metadata?.defaultSettings?.recordingSavePath
                                            ?? ""
            var recordingDir = Settings.preprocessPath(configuredRecordingSavePath)
            if (!recordingDir || recordingDir === "") {
                recordingDir = Quickshell.env("HOME") + "/Videos"
            }

            var recordingNotificationsEnabled = pluginApi?.pluginSettings?.recordingNotifications
                                               ?? pluginApi?.manifest?.metadata?.defaultSettings?.recordingNotifications
                                               ?? true

            const region = `${globalX},${globalY} ${globalW}x${globalH}`

            const recordArgs = ["bash", scriptPath, "--region", region, "--dir", recordingDir]
            if (shouldNormalizeRecordingResolution()) {
                const targetSize = `${globalW}x${globalH}`
                recordArgs.push("--video-target-size", targetSize)
            }
            if (root.target === "recordsound") {
                recordArgs.push("--sound")
            }
            if (recordingNotificationsEnabled) {
                recordArgs.push("--notify")
            }
            recordArgs.push(...buildRecordingNotifyArgs())

            Logger.d("ScreenShot", "[Panel] Executing record command args:", recordArgs)
            const recordStarted = Quickshell.execDetached(recordArgs)
            if (pluginApi?.mainInstance) {
                // Event-driven bar state update: red only when this plugin starts recording successfully.
                pluginApi.mainInstance.recordingActive = (recordStarted !== false)
            }
        }
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
            root.processRegion(root.regionX, root.regionY, root.regionWidth, root.regionHeight, mode)
        }

        root.closeSelector()
    }

    ScreencopyView {
        anchors.fill: parent
        live: false
        captureSource: root.screen
    }

        Rectangle {
            id: darkenOverlay
            z: 1
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: root.regionX - border.width
                topMargin: root.regionY - border.width
            }
            width: root.regionWidth + border.width * 2
            height: root.regionHeight + border.width * 2
            color: "transparent"
            border.color: "#88111111"
            border.width: Math.max(root.width, root.height)
            visible: root.dragging
        }

        Rectangle {
            z: 2
            x: root.regionX
            y: root.regionY
            width: root.regionWidth
            height: root.regionHeight
            color: "transparent"
            border.color: "#cccccc"
            border.width: Math.max(1, Math.round(2 * root.uiScale))
            visible: root.dragging
        }

        Text {
            z: 3
            x: root.regionX + root.regionWidth - width - (8 * root.uiScale)
            y: root.regionY + root.regionHeight + (8 * root.uiScale)
            text: root.dragging ? `${Math.round(root.regionWidth)} x ${Math.round(root.regionHeight)}` : ""
            color: "#cccccc"
            font.pixelSize: Math.max(10, Math.round(13 * root.uiScale))
            visible: root.dragging
        }

        // 十字准星
        Rectangle {
            visible: root.mouseInside && root.enableCross
            opacity: 0.4
            z: 2
            x: root.mouseX
            anchors { top: parent.top; bottom: parent.bottom }
            width: Math.max(1, Math.round(root.uiScale))
            color: "#cccccc"
        }
        Rectangle {
            visible: root.mouseInside && root.enableCross
            opacity: 0.4
            z: 2
            y: root.mouseY
            anchors { left: parent.left; right: parent.right }
            height: Math.max(1, Math.round(root.uiScale))
            color: "#cccccc"
        }

        // 背景遮罩
        Rectangle {
            anchors.fill: parent
            color: "#88111111"
            visible: !root.dragging
            z: 0
        }



        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            z: 10

            onPositionChanged: (mouse) => {
                root.mouseX = mouse.x
                root.mouseY = mouse.y
                root.mouseInside = true
                if (root.dragging) {
                    root.draggingX = mouse.x
                    root.draggingY = mouse.y
                }
            }
            onExited: {
                root.mouseInside = false
            }
            onPressed: (mouse) => {
                root.dragStartX = mouse.x
                root.dragStartY = mouse.y
                root.draggingX = mouse.x
                root.draggingY = mouse.y
                root.dragging = true
                root.mouseButton = mouse.button
            }
            onReleased: (mouse) => {
                root.dragging = false

                root.finish()
            }
    }

    NBox {
        id: rowBackground
        color: Color.mPrimary
        radius: Style.radiusM
        width: rowLayout.implicitWidth + Style.marginL * 2
        height: rowLayout.implicitHeight + Style.marginM * 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.marginM
        z: 20

        RowLayout {
            z: 20
            id: rowLayout
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NIcon {
                icon: iconForTarget(root.target)
                color: Color.mOnPrimary
            }

            NText {
                text: labelForTarget(root.target)
                color: Color.mOnPrimary
            }

            NButton {
                z: 20
                icon: "close"
                backgroundColor: Color.mError
                textColor: Color.mOnError
                onClicked: {
                    root.closeSelector()
                }
            }
        }

        Behavior on opacity { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutQuad } }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true
                root.closeSelector()
            }
        }

        Component.onCompleted: {
            forceActiveFocus()
        }
    }

    function iconForTarget(t: string): string {
        switch (t) {
            case "screenshot": return "screenshot"
            case "ocr": return "text-recognition"
            case "search": return "photo-search"
            case "record": return "camera"
            case "recordsound": return "camera-spark"
            default: return "bug"
        }
    }

    function labelForTarget(t: string): string {
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
