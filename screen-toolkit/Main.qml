import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.Compositor
import "overlays"
import "widgets"
import "utils/utils.js" as U
import "tools"
Item {
    id: root
    property var pluginApi: null
    readonly property string _scriptsDir: Qt.resolvedUrl("scripts/").toString().replace("file://", "")
    readonly property string _home: Quickshell.env("HOME")
    property bool   isRunning:              false
    property string activeTool:             ""
    property string pendingLangStr:         "eng"
    property string pendingRecordFormat:    "gif"
    property bool   pendingRecordAudioOut:  false
    property bool   pendingRecordAudioIn:   false
    property bool   pendingRecordCursor:    false
    property string pendingTool:            ""
    property var    installedLangs:         []
    property bool   transAvailable:         false
    property string detectedRecorder:       ""
    readonly property string detectedCompositor: CompositorService.isHyprland ? "hyprland"
                                                 : CompositorService.isNiri   ? "niri" : "other"
    readonly property bool isNiri:     CompositorService.isNiri
    readonly property bool isHyprland: CompositorService.isHyprland
    readonly property string resultHex:        colorPickerOverlay.resultHex
    readonly property string resultRgb:        colorPickerOverlay.resultRgb
    readonly property string resultHsv:        colorPickerOverlay.resultHsv
    readonly property string resultHsl:        colorPickerOverlay.resultHsl
    readonly property string colorCapturePath: colorPickerOverlay.colorCapturePath
    readonly property int    colorCacheBust:   colorPickerOverlay.colorCacheBust
    readonly property var    colorHistory:     colorPickerOverlay.colorHistory
    readonly property string ocrResult:        ocrOverlay.ocrResult
    readonly property string ocrCapturePath:   ocrOverlay.ocrCapturePath
    readonly property string translateResult:  ocrOverlay.translateResult
    readonly property string qrResult:         qrOverlay.qrResult
    readonly property string qrCapturePath:    qrOverlay.qrCapturePath
    readonly property var    paletteColors:    paletteOverlay.paletteColors
    readonly property string recordState:  recordOverlay?.recordState  ?? ""
    readonly property string recordFormat: recordOverlay?.format       ?? "gif"
    readonly property string recordPath:   recordOverlay?.gifPath      ?? ""
    readonly property bool   mirrorVisible: mirrorOverlay.isVisible
    readonly property bool   hasPins:       pinOverlay.hasPins
    readonly property var mainInstance: pluginApi?.mainInstance ?? null
    property int    _regionX:      0
    property int    _regionY:      0
    property int    _regionW:      0
    property int    _regionH:      0
    property var    _regionScreen: null
    property bool   _capsDetected:   false
    property bool   _sessionChecked: false
    property var    _detectedLangs:  []
    property string _grimGeometry: ""
    property int    _grimX:        0
    property int    _grimY:        0
    property int    _grimW:        0
    property int    _grimH:        0
    property int    _grimLocalX:   0
    property int    _grimLocalY:   0
    Component.onCompleted: {
        root.isRunning  = false
        root.activeTool = ""
        Logger.i("ScreenToolkit", "Scripts dir: " + root._scriptsDir)
        if (!_capsDetected) {
            detectCapabilities()
            _capsDetected = true
        }
    }
    onPluginApiChanged: {
        if (pluginApi) {
            if (!root._sessionChecked) {
                root._sessionChecked = true
                _checkSession()
            }
        }
    }
    Process {
        id: sessionCheckProc
        stdout: StdioCollector {}
        onExited: {
            var isNewBoot = sessionCheckProc.stdout.text.trim() === "new"
            if (isNewBoot) _clearStaleResults()
            else           _restoreSavedState()
        }
    }
    function _checkSession() {
        sessionCheckProc.exec({ command: ["bash", "-c",
            "[ -f /tmp/screen-toolkit-session ] && echo 'exists' || echo 'new'; " +
            "touch /tmp/screen-toolkit-session"
        ]})
    }
    function _clearStaleResults() {
        if (!pluginApi) return
        var s = pluginApi.pluginSettings
        s.resultHex        = ""; s.resultRgb        = ""
        s.resultHsv        = ""; s.resultHsl        = ""
        s.colorCapturePath = ""; s.colorCacheBust   = 0
        s.ocrResult        = ""; s.ocrCapturePath   = ""
        s.qrResult         = ""; s.qrCapturePath    = ""
        s.paletteColors    = ""; s.translateResult  = ""
        pluginApi.saveSettings()
        colorPickerOverlay.clearResults()
        ocrOverlay.clearResults()
        qrOverlay.clearResults()
        paletteOverlay.clearResults()
        colorPickerOverlay.colorHistory = pluginApi.pluginSettings.colorHistory || []
    }
    function clearColorResult() {
    colorPickerOverlay.clearResults()
    if (pluginApi) {
        pluginApi.pluginSettings.resultHex        = ""
        pluginApi.pluginSettings.resultRgb        = ""
        pluginApi.pluginSettings.resultHsv        = ""
        pluginApi.pluginSettings.resultHsl        = ""
        pluginApi.pluginSettings.colorCapturePath = ""
        pluginApi.pluginSettings.colorCacheBust   = 0
        pluginApi.saveSettings()
    }
}
function clearColorHistory() {
    colorPickerOverlay.colorHistory = []
    if (pluginApi) { pluginApi.pluginSettings.colorHistory = []; pluginApi.saveSettings() }
}
function clearOcrResult() {
    ocrOverlay.clearResults()
    if (pluginApi) {
        pluginApi.pluginSettings.ocrResult      = ""
        pluginApi.pluginSettings.ocrCapturePath = ""
        pluginApi.saveSettings()
    }
}
function clearQrResult() {
    qrOverlay.clearResults()
    if (pluginApi) {
        pluginApi.pluginSettings.qrResult      = ""
        pluginApi.pluginSettings.qrCapturePath = ""
        pluginApi.saveSettings()
    }
}
function clearPaletteResult() {
    paletteOverlay.clearResults()
    if (pluginApi) { pluginApi.pluginSettings.paletteColors = []; pluginApi.saveSettings() }
}
    function _restoreSavedState() {
        if (!pluginApi) return
        var s = pluginApi.pluginSettings
        colorPickerOverlay.loadState(s)
        ocrOverlay.loadState(s)
        qrOverlay.loadState(s)
        paletteOverlay.loadState(s)
        colorPickerOverlay.colorHistory = s.colorHistory || []
    }
    Connections {
        target: recordOverlay
        function onRecordStateChanged() {
            if (!pluginApi) return
            var skipConfirm = pluginApi.pluginSettings?.recordSkipConfirmation ?? false
            var toClipboard = pluginApi.pluginSettings?.recordCopyToClipboard  ?? false
            if (recordOverlay.recordState === "converting" && !skipConfirm && !toClipboard) {
                var screen = recordOverlay._primaryScreen
                if (screen) pluginApi.openPanel(screen)
                else pluginApi.withCurrentScreen(sc => pluginApi.openPanel(sc))
            }
        }
        function onDismissed() {
            if (root.activeTool === "record") root.activeTool = ""
        }
    }
    Connections {
        target: colorPickerOverlay
        function onDone() {
            root.isRunning  = false
            root.activeTool = "colorpicker"
            pluginApi?.withCurrentScreen(screen => pluginApi.openPanel(screen))
        }
        function onFailed() {
            root.isRunning  = false
            root.activeTool = ""
            ToastService.showError(pluginApi?.tr("messages.picker-cancelled"))
        }
    }
    Connections {
        target: ocrOverlay
        function onDone() {
            root.isRunning  = false
            root.activeTool = "ocr"
            pluginApi?.withCurrentScreen(screen => pluginApi.openPanel(screen))
        }
        function onFailed(messageKey, messageArg) {
            root.isRunning  = false
            root.activeTool = ""
            var template = pluginApi?.tr(messageKey)
            var msg = messageArg !== "" ? template.replace("{dep}", messageArg) : template
            ToastService.showError(msg)
        }
    }
    Connections {
        target: qrOverlay
        function onDone() {
            root.isRunning  = false
            root.activeTool = "qr"
            pluginApi?.withCurrentScreen(screen => pluginApi.openPanel(screen))
        }
        function onFailed() {
            root.isRunning  = false
            root.activeTool = ""
            ToastService.showError(pluginApi?.tr("messages.no-qr"))
        }
    }
    Connections {
        target: lensOverlay
        function onDone() {
            root.isRunning  = false
            root.activeTool = ""
        }
        function onFailed(messageKey, messageArg) {
            root.isRunning  = false
            root.activeTool = ""
            var template = pluginApi?.tr(messageKey)
            var msg = messageArg !== "" ? template.replace("{dep}", messageArg) : template
            ToastService.showError(msg)
        }
    }
    Connections {
        target: paletteOverlay
        function onDone() {
            root.isRunning  = false
            root.activeTool = "palette"
            pluginApi?.withCurrentScreen(screen => pluginApi.openPanel(screen))
        }
        function onFailed() {
            root.isRunning  = false
            root.activeTool = ""
            ToastService.showError(pluginApi?.tr("messages.palette-failed"))
        }
    }
    RegionSelector {
        id: regionSelector
        pluginApi: root.pluginApi
        onRegionSelected: (x, y, w, h, screen) => {
            root._regionX      = x; root._regionY = y
            root._regionW      = w; root._regionH = h
            root._regionScreen = screen
            var scale          = screen?.devicePixelRatio ?? 1.0
            var sx             = screen?.x ?? 0
            var sy             = screen?.y ?? 0
            root._grimX        = sx + Math.round(x / scale)
            root._grimY        = sy + Math.round(y / scale)
            root._grimW        = Math.round(w / scale)
            root._grimH        = Math.round(h / scale)
            root._grimLocalX   = Math.round(x / scale)
            root._grimLocalY   = Math.round(y / scale)
            root._grimGeometry = root._grimX + "," + root._grimY + " " + root._grimW + "x" + root._grimH
            _dispatchPendingTool()
        }
        onCancelled: {
            root.isRunning  = false
            root.activeTool = ""
        }
    }
    Annotate      { id: annotateOverlay;      mainInstance: root }
    Measure       { id: measureOverlay;       mainInstance: root }
    Pin           { id: pinOverlay;           pluginApi: root.pluginApi }
    Record        { id: recordOverlay;        pluginApi: root.pluginApi }
    Mirror { id: mirrorOverlay; pluginApi: root.pluginApi; scriptsDir: root._scriptsDir }
    ColorPicker   { id: colorPickerOverlay;   pluginApi: root.pluginApi; scriptsDir: root._scriptsDir }
    Ocr           { id: ocrOverlay;           pluginApi: root.pluginApi; scriptsDir: root._scriptsDir }
    Qr            { id: qrOverlay;            pluginApi: root.pluginApi; scriptsDir: root._scriptsDir }
    Lens          { id: lensOverlay;          pluginApi: root.pluginApi; scriptsDir: root._scriptsDir }
    Palette       { id: paletteOverlay;       pluginApi: root.pluginApi; scriptsDir: root._scriptsDir }
    Process {
        id: detectLangsProc
        stdout: StdioCollector {}
        onExited: {
            var lines = detectLangsProc.stdout.text.trim().split("\n")
            root._detectedLangs = []
            for (var i = 0; i < lines.length; i++) {
                var lang = lines[i].trim()
                if (lang === "" || lang === "osd" || lang === "equ") continue
                if (!root._detectedLangs.includes(lang))
                    root._detectedLangs.push(lang)
            }
            if (pluginApi && root._detectedLangs.length > 0) {
                pluginApi.pluginSettings.installedLangs = root._detectedLangs.slice()
                pluginApi.saveSettings()
            }
            if (root._detectedLangs.length > 0)
                root.installedLangs = root._detectedLangs.slice()
        }
    }
    Process {
        id: detectTransProc
        stdout: StdioCollector {}
        onExited: {
            var path = detectTransProc.stdout.text.trim()
            if (pluginApi) {
                pluginApi.pluginSettings.transAvailable = path !== "" && path.startsWith("/")
                pluginApi.saveSettings()
            }
            root.transAvailable = path !== "" && path.startsWith("/")
        }
    }
    Process {
        id: detectRecorderProc
        stdout: StdioCollector {}
        onExited: {
            var path = detectRecorderProc.stdout.text.trim()
            if (pluginApi) {
                pluginApi.pluginSettings.detectedRecorder =
                    path.endsWith("wl-screenrec") ? "wl-screenrec" :
                    path.endsWith("wf-recorder")  ? "wf-recorder"  : ""
                pluginApi.saveSettings()
            }
            root.detectedRecorder =
                path.endsWith("wl-screenrec") ? "wl-screenrec" :
                path.endsWith("wf-recorder")  ? "wf-recorder"  : ""
        }
    }
    Process {
        id: annotateProc
        onExited: (code) => {
            root.isRunning = false
            if (code === 0) {
                root.activeTool = ""
                var region = annotateRegionState._pendingRegion
                var screen = annotateRegionState._pendingScreen
                annotateRegionState._pendingRegion = ""
                annotateRegionState._pendingScreen = null
                if (pluginApi) {
                    pluginApi.withCurrentScreen(s => {
                        pluginApi.closePanel(s)
                        annotateOverlay.parseAndShow(region, "/tmp/screen-toolkit-annotate.png", screen)
                    })
                } else {
                    annotateOverlay.parseAndShow(region, "/tmp/screen-toolkit-annotate.png", screen)
                }
            } else {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.capture-failed"))
            }
        }
    }
    QtObject {
        id: annotateRegionState
        property string _pendingRegion: ""
        property var    _pendingScreen: null
    }
    Process {
        id: annotateWinProc
        stdout: StdioCollector {}
        onExited: (code) => {
            root.isRunning = false
            var geomStr = annotateWinProc.stdout.text.trim()
            if (code !== 0 || geomStr === "") {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.capture-failed"))
                return
            }
            var parts = geomStr.split(" ")
            if (parts.length < 2) { root.activeTool = ""; return }
            var xy = parts[0].split(",")
            var wh = parts[1].split("x")
            var gx = parseInt(xy[0]) || 0
            var gy = parseInt(xy[1]) || 0
            var gw = parseInt(wh[0]) || 400
            var gh = parseInt(wh[1]) || 300
            var screen    = root._findScreenForPoint(gx, gy)
            var regionStr = (gx - (screen?.x ?? 0)) + "," + (gy - (screen?.y ?? 0)) + " " + gw + "x" + gh
            root.activeTool = ""
            if (pluginApi) {
                pluginApi.withCurrentScreen(s => {
                    pluginApi.closePanel(s)
                    annotateOverlay.parseAndShow(regionStr, "/tmp/screen-toolkit-annotate.png", screen)
                })
            } else {
                annotateOverlay.parseAndShow(regionStr, "/tmp/screen-toolkit-annotate.png", screen)
            }
        }
    }
    Process {
        id: pinGrimProc
        stdout: StdioCollector {}
        onExited: (code) => {
            root.isRunning = false
            var output = pinGrimProc.stdout.text.trim()
            if (code === 0 && output !== "") {
                var parts = output.split("|")
                if (parts.length === 2) {
                    var imgPath = parts[0]
                    var wh  = parts[1].split("x")
                    var pw  = parseInt(wh[0]) || 400
                    var ph  = parseInt(wh[1]) || 300
                    pinOverlay.addPin(imgPath, pw, ph, root._regionScreen)
                    ToastService.showNotice(pluginApi.tr("messages.pinned"))
                }
            } else if (code !== 0) {
                ToastService.showError(pluginApi.tr("messages.capture-failed"))
            }
        }
    }
    Process {
        id: pinFileProc
        stdout: StdioCollector {}
        onExited: (code) => {
            var path = pinFileProc.stdout.text.trim()
            if (code === 0 && path !== "") {
                pinOverlay.addPin(path, 600, 400, root._regionScreen)
                ToastService.showNotice(pluginApi.tr("messages.pinned"))
            } else if (code === 2) {
                ToastService.showError(pluginApi.tr("messages.no-file-picker"))
            }
        }
    }
    Process { id: clipProc }
    Timer {
        id: launchColorPicker
        interval: 220; repeat: false
        onTriggered: colorPickerOverlay.run()
    }
    Timer {
        id: launchOcr
        interval: 50; repeat: false
        onTriggered: ocrOverlay.run(root._grimX, root._grimY, root._grimW, root._grimH, root.pendingLangStr)
    }
    Timer {
        id: launchQr
        interval: 50; repeat: false
        onTriggered: qrOverlay.run(root._grimGeometry)
    }
    Timer {
        id: launchLens
        interval: 50; repeat: false
        onTriggered: lensOverlay.run(root._grimX, root._grimY, root._grimW, root._grimH)
    }
    Timer {
        id: launchAnnotate
        interval: 50; repeat: false
        onTriggered: {
            var regionStr = root._grimLocalX + "," + root._grimLocalY + " " + root._grimW + "x" + root._grimH
            annotateRegionState._pendingRegion = regionStr
            annotateRegionState._pendingScreen = root._regionScreen
            annotateProc.exec({ command: ["bash", "-c",
                "grim -g \"" + root._grimGeometry + "\" /tmp/screen-toolkit-annotate.png 2>/dev/null"
            ]})
        }
    }
    Timer {
        id: launchAnnotateActiveWindow
        interval: 360; repeat: false
        onTriggered: {
            annotateWinProc.exec({ command: [root._scriptsDir + "capture.sh", "annotate-window"] })
        }
    }
    Timer {
        id: launchAnnotateFullscreen
        interval: 380; repeat: false
        property var targetScreen: null
        onTriggered: {
            var name = targetScreen?.name ?? ""
            annotateProc.exec({ command: name !== ""
                ? ["grim", "-o", name, "/tmp/screen-toolkit-annotate.png"]
                : ["grim", "/tmp/screen-toolkit-annotate.png"]
            })
        }
    }
    Timer {
        id: launchPin
        interval: 50; repeat: false
        onTriggered: {
            pinGrimProc.exec({ command: [root._scriptsDir + "capture.sh", "pin", root._grimGeometry] })
        }
    }
    Timer {
        id: launchPinFile
        interval: 200; repeat: false
        onTriggered: {
            pinFileProc.exec({ command: [root._scriptsDir + "pick-file.sh"] })
        }
    }
    Timer {
        id: launchPalette
        interval: 50; repeat: false
        onTriggered: paletteOverlay.run(root._grimGeometry)
    }
    Timer {
        id: launchRecord
        interval: 50; repeat: false
        onTriggered: {
            root.isRunning  = false
            root.activeTool = "record"
            recordOverlay.startRecording(
                root._grimGeometry, root.pendingRecordFormat,
                root.pendingRecordAudioOut, root.pendingRecordAudioIn,
                root.pendingRecordCursor, root._grimLocalX, root._grimLocalY,
                root._regionScreen
            )
        }
    }
    Timer {
        id: launchRecordFullscreen
        interval: 50; repeat: false
        property var targetScreen: null
        onTriggered: {
            var screen = targetScreen ?? Quickshell.screens[0] ?? null
            if (!screen) return
            var scale  = screen.devicePixelRatio ?? 1.0
            var region = screen.x + "," + screen.y + " " +
                         Math.round(screen.width * scale) + "x" +
                         Math.round(screen.height * scale)
            root.isRunning  = false
            root.activeTool = "record"
            recordOverlay.startRecording(
                region, root.pendingRecordFormat,
                root.pendingRecordAudioOut, root.pendingRecordAudioIn,
                root.pendingRecordCursor, 0, 0, screen
            )
        }
    }
    Timer {
        id: launchRegionSelector
        interval: 220; repeat: false
        property var targetScreen: null
        onTriggered: regionSelector.show(targetScreen)
    }
    function _dispatchPendingTool() {
        switch (root.pendingTool) {
            case "ocr":      launchOcr.start();      break
            case "qr":       launchQr.start();       break
            case "lens":     launchLens.start();     break
            case "annotate": launchAnnotate.start(); break
            case "pin":      launchPin.start();      break
            case "palette":  launchPalette.start();  break
            case "record":   launchRecord.start();   break
            default:
                Logger.w("ScreenToolkit", "unknown pendingTool: " + root.pendingTool)
                root.isRunning = false
        }
    }
    function copyToClipboard(text) {
        if (!text || text === "") return
        clipProc.exec({ command: ["bash", "-c",
            "printf '%s' " + U.shellEscape(text) + " | wl-copy 2>/dev/null"] })
    }
    function closeThenLaunch(timer) {
        if (!pluginApi) { timer.start(); return }
        pluginApi.withCurrentScreen(screen => {
            if (timer === launchRegionSelector) launchRegionSelector.targetScreen = screen
            pluginApi.closePanel(screen)
            timer.start()
        })
    }
    function runTranslate(text, targetLang) {
        ocrOverlay.runTranslate(text, targetLang)
    }
    function runColorPicker() {
        if (root.isRunning) return
        root.isRunning  = true
        root.activeTool = ""
        colorPickerOverlay.clearResults()
        closeThenLaunch(launchColorPicker)
    }
    function runOcr(langStr) {
        if (root.isRunning) return
        root.pendingLangStr = (langStr && langStr !== "") ? langStr : "eng"
        _runSlurpTool("ocr")
    }
    function runQr()       { _runSlurpTool("qr")      }
    function runLens()     { _runSlurpTool("lens")     }
    function runAnnotate() { _runSlurpTool("annotate") }
    function _findScreenForPoint(gx, gy) {
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height)
                return s
        }
        return root._regionScreen ?? (screens.length > 0 ? screens[0] : null)
    }
    function runAnnotateFullscreen() {
        if (root.isRunning) return
        root.isRunning = true
        if (!pluginApi) { launchAnnotateFullscreen.start(); return }
        pluginApi.withCurrentScreen(screen => {
            pluginApi.closePanel(screen)
            root._regionScreen = screen
            root._regionX = 0; root._regionY = 0
            root._regionW = Math.round(screen.width  * (screen.devicePixelRatio ?? 1.0))
            root._regionH = Math.round(screen.height * (screen.devicePixelRatio ?? 1.0))
            annotateRegionState._pendingRegion = "0,0 " + screen.width + "x" + screen.height
            annotateRegionState._pendingScreen = screen
            launchAnnotateFullscreen.targetScreen = screen
            launchAnnotateFullscreen.start()
        })
    }
    function runAnnotateActiveWindow() {
        if (root.isRunning) return
        root.isRunning = true
        if (!pluginApi) { launchAnnotateActiveWindow.start(); return }
        pluginApi.withCurrentScreen(screen => {
            pluginApi.closePanel(screen)
            root._regionScreen = screen
            launchAnnotateActiveWindow.start()
        })
    }
    function runPalette() {
        if (root.isRunning) return
        _runSlurpTool("palette")
    }
    function runPin() { _runSlurpTool("pin") }
    function runPinFromFile() {
        if (!pluginApi) { launchPinFile.start(); return }
        pluginApi.withCurrentScreen(screen => {
            pluginApi.closePanel(screen)
            launchPinFile.start()
        })
    }
    function pinFile(path, screen) {
        if (!path || path === "") return
        pinOverlay.addPin(path, 600, 400, screen)
    }
    function runMeasure() {
        if (root.isRunning) return
        root.activeTool = "measure"
        if (pluginApi) pluginApi.withCurrentScreen(screen => pluginApi.closePanel(screen))
        measureOverlay.show()
    }
    function runRecordStop()    { recordOverlay.stopRecording() }
    function runRecordSave()    { recordOverlay._saveToFile() }
    function runRecordDiscard() { recordOverlay.dismiss() }
    function runRecord(format, audioOut, audioIn, cursor) {
        if (root.isRunning || recordOverlay.isRecording || recordOverlay.isConverting) return
        root.pendingRecordFormat   = format   || "gif"
        root.pendingRecordAudioOut = audioOut === true
        root.pendingRecordAudioIn  = audioIn  === true
        root.pendingRecordCursor   = cursor   === true
        _runSlurpTool("record")
    }
    function runRecordFullscreen(format, audioOut, audioIn, cursor) {
        if (root.isRunning || recordOverlay.isRecording || recordOverlay.isConverting) return
        root.pendingRecordFormat   = format   || "gif"
        root.pendingRecordAudioOut = audioOut === true
        root.pendingRecordAudioIn  = audioIn  === true
        root.pendingRecordCursor   = cursor   === true
        if (!pluginApi) { launchRecordFullscreen.start(); return }
        pluginApi.withCurrentScreen(screen => {
            root.isRunning  = true
            root.activeTool = "record"
            pluginApi.closePanel(screen)
            launchRecordFullscreen.targetScreen = screen
            launchRecordFullscreen.start()
        })
    }
    function runMirror() {
        if (pluginApi) {
            pluginApi.withCurrentScreen(screen => {
                pluginApi.closePanel(screen)
                if (!mirrorOverlay.isVisible) mirrorOverlay.show(screen)
            })
        } else {
            if (!mirrorOverlay.isVisible) mirrorOverlay.show()
        }
    }
    function runMirrorClose() { mirrorOverlay.hide() }
    function _runSlurpTool(tool) {
        if (root.isRunning) return
        root.pendingTool = tool
        root.isRunning   = true
        closeThenLaunch(launchRegionSelector)
    }
    function detectCapabilities() {
        root._detectedLangs = []
        detectLangsProc.exec({ command:    ["bash", "-c", "tesseract --list-langs 2>/dev/null | tail -n +2"] })
        detectTransProc.exec({ command:    ["bash", "-c", "which trans 2>/dev/null"] })
        detectRecorderProc.exec({ command: ["bash", "-c", "which wl-screenrec 2>/dev/null || which wf-recorder 2>/dev/null"] })
    }
    function annotateScreenshotCmd(overlayTmpFile) {
        var dir   = U.screenshotDir(root._home, pluginApi?.pluginSettings?.screenshotPath)
        var fname = U.buildFilename("annotate", ".png", pluginApi?.pluginSettings?.filenameFormat)
        var dest  = dir + "/" + fname
        return "mkdir -p " + U.shellEscape(dir) + " && " +
               "magick /tmp/screen-toolkit-annotate.png " + U.shellEscape(overlayTmpFile) +
               " -composite " + U.shellEscape(dest) + " && " +
               "rm -f " + U.shellEscape(overlayTmpFile) + " && " +
               "echo " + U.shellEscape(dest)
    }
    function annotateScreenshotZoomCmd(imgPath) {
        var dir   = U.screenshotDir(root._home, pluginApi?.pluginSettings?.screenshotPath)
        var fname = U.buildFilename("annotate", ".png", pluginApi?.pluginSettings?.filenameFormat)
        var dest  = dir + "/" + fname
        return "mkdir -p " + U.shellEscape(dir) + " && " +
               "cp " + U.shellEscape(imgPath) + " " + U.shellEscape(dest) + " && " +
               "echo " + U.shellEscape(dest)
    }
    IpcHandler {
        target: "plugin:screen-toolkit"
        function toggle()              { if (pluginApi) pluginApi.withCurrentScreen(screen => pluginApi.togglePanel(screen)) }
        function mirror()              { root.runMirror() }
        function measure()             { root.runMeasure() }
        function colorPicker()         { root.runColorPicker() }
        function annotate()            { root.runAnnotate() }
        function annotateFullscreen()  { root.runAnnotateFullscreen() }
        function annotateWindow()      { if (root.isHyprland) root.runAnnotateActiveWindow() }
        function pin()                 { root.runPin() }
        function pinImage()            { root.runPinFromFile() }
        function ocr()                 { root.runOcr(pluginApi?.pluginSettings?.selectedOcrLang || "eng") }
        function qr()                  { root.runQr() }
        function palette()             { root.runPalette() }
        function lens()                { root.runLens() }
        function record()              { root.runRecord("gif") }
        function recordMp4()           { root.runRecord("mp4") }
        function recordFullscreen()    { root.runRecordFullscreen("gif") }
        function recordFullscreenMp4() { root.runRecordFullscreen("mp4") }
        function recordStop()          { if (recordOverlay.isRecording) recordOverlay.stopRecording() }
    }
}


