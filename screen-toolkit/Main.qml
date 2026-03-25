import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    property bool isRunning: false
    property string activeTool: ""
    property string pendingLangStr: "eng"
    property string pendingRecordFormat: "gif"
    property bool pendingRecordAudioOut: false
    property bool pendingRecordAudioIn: false
    property string pendingTool: ""

    // ── Sync state to pluginSettings so Panel can read without mainInstance ──
    onIsRunningChanged:   _syncState()
    onActiveToolChanged:  _syncState()

    function _syncState() {
        if (!pluginApi) return
        pluginApi.pluginSettings.stateIsRunning   = root.isRunning
        pluginApi.pluginSettings.stateActiveTool  = root.activeTool
        pluginApi.pluginSettings.stateMirrorVisible = root.mirrorVisible
        pluginApi.saveSettings()
    }

    // ── Settings shortcuts ────────────────────────────────────
    readonly property string selectedOcrLang: pluginApi?.pluginSettings?.selectedOcrLang || "eng"

    // ── Region selector state (replaces slurp) ────────────────
    // Stores the confirmed region from RegionSelector for dispatch to tools.
    property int _regionX: 0
    property int _regionY: 0
    property int _regionW: 0
    property int _regionH: 0
    property var _regionScreen: null

    // ── Capability detection ──────────────────────────────────
    property bool _capsDetected: false
    property var _detectedLangs: []

    Component.onCompleted: {
        // Reset any stale running state from previous sessions
        root.isRunning = false
        root.activeTool = ""
        if (!_capsDetected) {
            _capsDetected = true
            detectCapabilities()
        }
    }

    onPluginApiChanged: {
        if (pluginApi) {
            // Clear stale state that may have persisted across restarts
            pluginApi.pluginSettings.stateIsRunning  = false
            pluginApi.pluginSettings.stateActiveTool = ""
            pluginApi.saveSettings()
        }
    }

    // ── Bash helpers ──────────────────────────────────────────
    // Builds a grim command. RegionSelector emits screen-local physical pixels;
    // grim -g expects global logical coordinates (same space as slurp output).
    // We divide by devicePixelRatio and add the screen's global offset.

    function _grimRegionCmd(outFile) {
        var scale = root._regionScreen?.devicePixelRatio ?? 1.0
        var sx    = root._regionScreen?.x ?? 0
        var sy    = root._regionScreen?.y ?? 0
        var gx = sx + Math.round(root._regionX / scale)
        var gy = sy + Math.round(root._regionY / scale)
        var gw = Math.round(root._regionW / scale)
        var gh = Math.round(root._regionH / scale)
        return "grim -g \"" + gx + "," + gy + " " + gw + "x" + gh + "\" " +
               outFile + " 2>/dev/null"
    }

    // ── Generic region-tool launcher ─────────────────────────
    // Shows the QML region selector overlay. Panel.qml / IPC API unchanged.
    function _runSlurpTool(tool) {
        if (root.isRunning) return
        root.pendingTool = tool
        root.isRunning = true
        closeThenLaunch(launchRegionSelector)
    }

    // ── Processes ─────────────────────────────────────────────

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
        }
    }

    Process {
        id: colorPickerProc
        stdout: StdioCollector {}
        onExited: (code) => {
            root.isRunning = false
            if (code !== 0 || colorPickerProc.stdout.text.trim() === "") {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.picker-cancelled"))
                return
            }
            var line  = colorPickerProc.stdout.text.trim()
            var parts = line.split("|")
            var hex   = parts[0]
            var capturePath = parts.length > 1 ? parts[1] : ""
            if (hex.length !== 7 || hex.charAt(0) !== "#") {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.picker-cancelled"))
                return
            }
            var r = parseInt(hex.slice(1, 3), 16)
            var g = parseInt(hex.slice(3, 5), 16)
            var b = parseInt(hex.slice(5, 7), 16)
            var rgb = "rgb(" + r + ", " + g + ", " + b + ")"
            var rn = r/255, gn = g/255, bn = b/255
            var max = Math.max(rn,gn,bn), min = Math.min(rn,gn,bn)
            var d = max - min, hh = 0
            var sv = (max === 0) ? 0 : d / max
            var vv = max
            if (d !== 0) {
                if      (max === rn) hh = ((gn-bn)/d + 6) % 6
                else if (max === gn) hh = (bn-rn)/d + 2
                else                 hh = (rn-gn)/d + 4
                hh = Math.round(hh * 60)
            }
            var hsv = "hsv(" + hh + ", " + Math.round(sv*100) + "%, " + Math.round(vv*100) + "%)"
            var l  = (max + min) / 2
            var sl = (d === 0) ? 0 : d / (1 - Math.abs(2*l - 1))
            var hsl = "hsl(" + hh + ", " + Math.round(sl*100) + "%, " + Math.round(l*100) + "%)"
            if (pluginApi) {
                pluginApi.pluginSettings.resultHex = hex
                pluginApi.pluginSettings.resultRgb = rgb
                pluginApi.pluginSettings.resultHsv = hsv
                pluginApi.pluginSettings.resultHsl = hsl
                pluginApi.pluginSettings.colorCapturePath = capturePath
                var history = pluginApi.pluginSettings.colorHistory || []
                history = [hex].concat(history.filter(c => c !== hex)).slice(0, 8)
                pluginApi.pluginSettings.colorHistory = history
                pluginApi.saveSettings()
            }
            root.activeTool = "colorpicker"
            if (pluginApi) {
                pluginApi.pluginSettings.stateActiveTool = "colorpicker"
                pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
            }
        }
    }

    Process {
        id: ocrProc
        stdout: StdioCollector {}
        onExited: {
            root.isRunning = false
            var text = ocrProc.stdout.text.trim()
            if (text !== "") {
                if (pluginApi) {
                    pluginApi.pluginSettings.ocrResult = text
                    pluginApi.pluginSettings.ocrCapturePath = "/tmp/screen-toolkit-ocr.png"
                    pluginApi.pluginSettings.translateResult = ""
                    pluginApi.saveSettings()
                }
                root.activeTool = "ocr"
                if (pluginApi) {
                    pluginApi.pluginSettings.stateActiveTool = "ocr"
                    pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
                }
            } else {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.no-text"))
            }
        }
    }

    Process {
        id: qrProc
        stdout: StdioCollector {}
        onExited: {
            root.isRunning = false
            var result = qrProc.stdout.text.trim()
            if (result !== "") {
                if (pluginApi) {
                    pluginApi.pluginSettings.qrResult = result
                    pluginApi.pluginSettings.qrCapturePath = "/tmp/screen-toolkit-qr.png"
                    pluginApi.saveSettings()
                }
                root.activeTool = "qr"
                if (pluginApi) {
                    pluginApi.pluginSettings.stateActiveTool = "qr"
                    pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
                }
            } else {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.no-qr"))
            }
        }
    }

    Process {
        id: lensProc
        onExited: (code) => {
            root.isRunning = false
            root.activeTool = ""
            if (code !== 0) ToastService.showError(pluginApi.tr("messages.lens-failed"))
        }
    }

    Process {
        id: annotateProc
        onExited: (code) => {
            root.isRunning = false
            if (code === 0) {
                root.activeTool = ""
                if (pluginApi) pluginApi.withCurrentScreen(screen => pluginApi.closePanel(screen))
                var region = annotateRegionProc._pendingRegion
                Logger.i("ScreenToolkit", "annotate done, region=" + region)
                annotateOverlay.parseAndShow(region, "/tmp/screen-toolkit-annotate.png")
                annotateRegionProc._pendingRegion = ""
            } else {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.capture-failed"))
            }
        }
    }

    // annotateRegionProc is kept as a namespace to store the pending region string
    // so annotateProc.onExited can pass it to annotateOverlay.parseAndShow.
    QtObject {
        id: annotateRegionProc
        property string _pendingRegion: ""
    }

    Process {
        id: pinGrimProc
        stdout: StdioCollector {}
        onExited: (code) => {
            root.isRunning = false
            var output = pinGrimProc.stdout.text.trim()
            Logger.i("ScreenToolkit", "pinGrimProc exited: code=" + code + " output=" + output)
            if (code === 0 && output !== "") {
                var parts = output.split("|")
                Logger.i("ScreenToolkit", "pin parts=" + JSON.stringify(parts))
                if (parts.length === 2) {
                    var imgPath = parts[0]
                    var wh = parts[1].split("x")
                    var pw = parseInt(wh[0]) || 400
                    var ph = parseInt(wh[1]) || 300
                    Logger.i("ScreenToolkit", "addPin: " + imgPath + " " + pw + "x" + ph)
                    pinOverlay.addPin(imgPath, pw, ph)
                    ToastService.showNotice(pluginApi.tr("messages.pinned"))
                }
            } else if (code !== 0) {
                ToastService.showError(pluginApi.tr("messages.capture-failed"))
            }
        }
    }

    Process {
        id: paletteProc
        stdout: StdioCollector {}
        onExited: (code) => {
            root.isRunning = false
            var raw = paletteProc.stdout.text.trim()
            if (code === 0 && raw !== "") {
                var colors = raw.split("\n").filter(function(c) { return c.match(/^#[0-9a-fA-F]{6}$/) }).slice(0, 8)
                Logger.i("ScreenToolkit", "palette colors: " + JSON.stringify(colors))
                if (colors.length > 0 && pluginApi) {
                    pluginApi.pluginSettings.paletteColors = colors
                    pluginApi.saveSettings()
                    root.activeTool = "palette"
                    pluginApi.pluginSettings.stateActiveTool = "palette"
                    pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
                }
            } else {
                ToastService.showError(pluginApi.tr("messages.palette-failed"))
            }
        }
    }

    Process {
        id: translateProc
        property bool isTranslating: false
        stdout: StdioCollector {}
        onExited: {
            translateProc.isTranslating = false
            var result = translateProc.stdout.text.trim()
            if (pluginApi) {
                pluginApi.pluginSettings.translateResult = (result !== "")
                    ? result
                    : pluginApi.tr("messages.translate-failed")
                pluginApi.saveSettings()
            }
        }
    }

    Process { id: clipProc }

    // ── Overlays ──────────────────────────────────────────────

    // QML region selector — replaces slurp entirely.
    // Instant (no process spawn), GPU-rendered (ScreencopyView + GLSL shader),
    // spring-animated selection box, works on all monitors.
    RegionSelector {
        id: regionSelector

        onRegionSelected: (x, y, w, h, screen) => {
            Logger.i("ScreenToolkit", "RegionSelector: region=" + x + "," + y + " " + w + "x" + h)
            root._regionX = x
            root._regionY = y
            root._regionW = w
            root._regionH = h
            root._regionScreen = screen
            _dispatchPendingTool()
        }

        onCancelled: {
            Logger.i("ScreenToolkit", "RegionSelector: cancelled")
            root.isRunning = false
            root.activeTool = ""
        }
    }

    Annotate {
        id: annotateOverlay
        mainInstance: root
    }


    Measure {
        id: measureOverlay
        mainInstance: root
    }

    Pin {
        id: pinOverlay
        pluginApi: root.pluginApi
    }

    Record {
        id: recordOverlay
        pluginApi: root.pluginApi
    }

    Mirror {
        id: mirrorOverlay
        pluginApi: root.pluginApi
    }

    readonly property bool mirrorVisible: mirrorOverlay.isVisible
    onMirrorVisibleChanged: _syncState()

    // ── Timers ────────────────────────────────────────────────

    // Colorpicker uses slurp -p — it speaks Wayland natively so coordinates
    // are always correct regardless of compositor (Hyprland, Niri, Sway...).
    // slurp also provides its own live crosshair preview for free.
    Timer {
        id: launchColorPicker
        interval: 150; repeat: false
        onTriggered: {
            colorPickerProc.exec({
                command: [
                    "bash", "-c",
                    "COORDS=$(slurp -p 2>/dev/null) || exit 1; " +
                    "X=$(echo \"$COORDS\" | cut -d',' -f1); " +
                    "Y=$(echo \"$COORDS\" | cut -d',' -f2 | cut -d' ' -f1); " +
                    "GX=$((X-5)); GY=$((Y-5)); " +
                    "FILE=/tmp/screen-toolkit-colorpicker.png; " +
                    "grim -g \"${GX},${GY} 11x11\" \"$FILE\" 2>/dev/null || exit 1; " +
                    "HEX=$(magick \"$FILE\" -alpha off -format '#%[hex:p{5,5}]' info:- 2>/dev/null); " +
                    "[ -n \"$HEX\" ] && printf '%s|%s' \"$HEX\" \"$FILE\" || exit 1"
                ]
            })
        }
    }

    // ── Tool launch timers ────────────────────────────────────
    // Each fires immediately after RegionSelector confirms a region.
    // No polling needed — region coords are already in root._regionX/Y/W/H.

    Timer {
        id: launchOcr
        interval: 50; repeat: false
        onTriggered: {
            ocrProc.exec({
                command: [
                    "bash", "-c",
                    _grimRegionCmd("/tmp/screen-toolkit-ocr.png") + "; " +
                    "cat /tmp/screen-toolkit-ocr.png | tesseract - - -l " + root.pendingLangStr + " 2>/dev/null"
                ]
            })
        }
    }

    Timer {
        id: launchQr
        interval: 50; repeat: false
        onTriggered: {
            qrProc.exec({
                command: [
                    "bash", "-c",
                    _grimRegionCmd("/tmp/screen-toolkit-qr.png") + "; " +
                    "zbarimg -q --raw /tmp/screen-toolkit-qr.png 2>/dev/null"
                ]
            })
        }
    }

    Timer {
        id: launchLens
        interval: 50; repeat: false
        onTriggered: {
            lensProc.exec({
                command: [
                    "bash", "-c",
                    _grimRegionCmd("/tmp/screen-toolkit-lens.png") + " && " +
                    "notify-send 'Screen Toolkit' 'Uploading to Lens...' 2>/dev/null; " +
                    "URL=$(curl -sS -F 'file=@/tmp/screen-toolkit-lens.png' 'https://0x0.st' 2>/dev/null); " +
                    "rm -f /tmp/screen-toolkit-lens.png; " +
                    "if [ -n \"$URL\" ]; then xdg-open \"https://lens.google.com/uploadbyurl?url=$URL\" 2>/dev/null; else exit 1; fi"
                ]
            })
        }
    }

    Timer {
        id: launchAnnotate
        interval: 50; repeat: false
        onTriggered: {
            // parseAndShow positions the overlay in screen-local logical pixels
            var scale = root._regionScreen?.devicePixelRatio ?? 1.0
            var regionStr = Math.round(root._regionX / scale) + "," +
                            Math.round(root._regionY / scale) + " " +
                            Math.round(root._regionW / scale) + "x" +
                            Math.round(root._regionH / scale)
            annotateRegionProc._pendingRegion = regionStr
            annotateProc.exec({
                command: [
                    "bash", "-c",
                    _grimRegionCmd("/tmp/screen-toolkit-annotate.png")
                ]
            })
        }
    }

    Timer {
        id: launchPin
        interval: 50; repeat: false
        onTriggered: {
            pinGrimProc.exec({
                command: [
                    "bash", "-c",
                    (function() {
                        var scale = root._regionScreen?.devicePixelRatio ?? 1.0
                        var sx = root._regionScreen?.x ?? 0
                        var sy = root._regionScreen?.y ?? 0
                        var gx = sx + Math.round(root._regionX / scale)
                        var gy = sy + Math.round(root._regionY / scale)
                        var gw = Math.round(root._regionW / scale)
                        var gh = Math.round(root._regionH / scale)
                        return "FILE=/tmp/screen-toolkit-pin-$(date +%s%3N).png; " +
                               "grim -s 2 -g \"" + gx + "," + gy + " " + gw + "x" + gh + "\" \"$FILE\" 2>/dev/null || exit 1; " +
                               "echo \"$FILE|" + gw + "x" + gh + "\""
                    })()
                ]
            })
        }
    }

    Timer {
        id: launchPalette
        interval: 50; repeat: false
        onTriggered: {
            paletteProc.exec({
                command: [
                    "bash", "-c",
                    _grimRegionCmd("/tmp/screen-toolkit-palette.png") + "; " +
                    "magick /tmp/screen-toolkit-palette.png -alpha off +dither -colors 8 -unique-colors txt:- 2>/dev/null " +
                    "| grep -v '^#' | grep -oP '#[0-9a-fA-F]{6}' | head -8"
                ]
            })
        }
    }

    Timer {
        id: launchRecord
        interval: 50; repeat: false
        onTriggered: {
            var scale = root._regionScreen?.devicePixelRatio ?? 1.0
            var sx = root._regionScreen?.x ?? 0
            var sy = root._regionScreen?.y ?? 0
            var region = (sx + Math.round(root._regionX / scale)) + "," +
                         (sy + Math.round(root._regionY / scale)) + " " +
                         Math.round(root._regionW / scale) + "x" +
                         Math.round(root._regionH / scale)
            root.isRunning = false
            root.activeTool = "record"
            recordOverlay.startRecording(region, root.pendingRecordFormat, root.pendingRecordAudioOut, root.pendingRecordAudioIn)
        }
    }

    // Shows the RegionSelector after the panel closes
    Timer {
        id: launchRegionSelector
        interval: 150; repeat: false
        property var targetScreen: null
        onTriggered: {
            regionSelector.show(targetScreen)
        }
    }

    // ── Internal helpers ──────────────────────────────────────

    // Dispatches to the correct tool timer after region is confirmed.
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
        clipProc.exec({
            command: ["bash", "-c", "printf '%s' " + shellEscape(text) + " | wl-copy 2>/dev/null"]
        })
    }

    function shellEscape(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'"
    }

    function closeThenLaunch(timer) {
        if (!pluginApi) { timer.start(); return }
        pluginApi.withCurrentScreen(screen => {
            if (timer === launchRegionSelector)
                launchRegionSelector.targetScreen = screen
            pluginApi.closePanel(screen)
            timer.start()
        })
    }

    function runTranslate(text, targetLang) {
        if (!text || text === "" || translateProc.isTranslating) return
        translateProc.isTranslating = true
        if (pluginApi) {
            pluginApi.pluginSettings.translateResult = ""
            pluginApi.saveSettings()
        }
        translateProc.exec({
            command: ["bash", "-c", "trans -brief -to " + targetLang + " " + shellEscape(text)]
        })
    }

    // ── Public tool runners ───────────────────────────────────
    // These keep the same names/signatures as before so Panel.qml and
    // the IpcHandler below need zero changes.

    function runColorPicker() {
        if (root.isRunning) return
        root.isRunning = true
        root.activeTool = ""
        if (pluginApi) {
            pluginApi.pluginSettings.resultHex = ""
            pluginApi.pluginSettings.resultRgb = ""
            pluginApi.pluginSettings.resultHsv = ""
            pluginApi.pluginSettings.resultHsl = ""
            pluginApi.pluginSettings.colorCapturePath = ""
            pluginApi.saveSettings()
        }
        // slurp -p handles its own UI — no RegionSelector needed
        closeThenLaunch(launchColorPicker)
    }

    function runOcr(langStr) {
        if (root.isRunning) return
        root.pendingLangStr = (langStr && langStr !== "") ? langStr : "eng"
        _runSlurpTool("ocr")
    }

    function runQr()      { _runSlurpTool("qr")       }
    function runLens()    { _runSlurpTool("lens")      }
    function runAnnotate(){ _runSlurpTool("annotate")  }
    function runPalette() {
        if (root.isRunning) return
        if (pluginApi) {
            pluginApi.pluginSettings.paletteColors = []
            pluginApi.saveSettings()
        }
        _runSlurpTool("palette")
    }
    function runPin()     { _runSlurpTool("pin")       }

    function runMeasure() {
        if (root.isRunning) return
        root.activeTool = "measure"
        if (pluginApi) pluginApi.withCurrentScreen(screen => pluginApi.closePanel(screen))
        measureOverlay.show()
    }

    function runRecord(format, audioOut, audioIn) {
        if (root.isRunning || recordOverlay.isRecording || recordOverlay.isConverting) return
        root.pendingRecordFormat   = format   || "gif"
        root.pendingRecordAudioOut = audioOut === true
        root.pendingRecordAudioIn  = audioIn  === true
        _runSlurpTool("record")
    }

    function runMirror() {
        mirrorOverlay.toggle()
    }

    function detectCapabilities() {
        root._detectedLangs = []
        detectLangsProc.exec({
            command: ["bash", "-c", "tesseract --list-langs 2>/dev/null | tail -n +2"]
        })
        detectTransProc.exec({
            command: ["bash", "-c", "which trans 2>/dev/null"]
        })
    }

    // ── IPC ───────────────────────────────────────────────────

    IpcHandler {
        target: "plugin:screen-toolkit"
        function colorPicker()  { root.runColorPicker() }
        function ocr()          { root.runOcr(root.selectedOcrLang) }
        function qr()           { root.runQr() }
        function lens()         { root.runLens() }
        function annotate()     { root.runAnnotate() }
        function measure()      { root.runMeasure() }
        function pin()          { root.runPin() }
        function palette()      { root.runPalette() }
        function record()       { root.runRecord("gif") }
        function mirror()       { root.runMirror() }
        function toggle() {
            if (!pluginApi) return
            pluginApi.withCurrentScreen(screen => pluginApi.togglePanel(screen))
        }
    }
}
