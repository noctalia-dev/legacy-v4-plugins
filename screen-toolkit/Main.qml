import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.Compositor
Item {
    id: root
    property var pluginApi: null
    property bool isRecording: false
    property bool isConverting: false
    property bool isDone: false
    property int regionX: 0
    property int regionY: 0
    property int regionW: 400
    property int regionH: 300
    property int uiX: 0
    property int uiY: 0
    property var _primaryScreen: null
    property int _elapsed: 0
    property int _frameToken: 0
    property string format: "gif"
    property bool audioOutput: false
    property bool audioInput: false
    property bool includeCursor: false
    property string _recorderBin: "wl-screenrec"
    property bool _previewBusy: false
    property real _maskW: 0
    property real _maskH: 0
    property bool isRunning: false
    property string activeTool: ""
    property string pendingLangStr: "eng"
    property string pendingRecordFormat: "gif"
    property bool pendingRecordAudioOut: false
    property bool pendingRecordAudioIn: false
    property bool pendingRecordCursor: false
    property string pendingTool: ""
    onIsRunningChanged:  _syncState()
    onActiveToolChanged: _syncState()
    function _syncState() {
        if (!pluginApi) return
        pluginApi.pluginSettings.stateIsRunning     = root.isRunning
        pluginApi.pluginSettings.stateActiveTool    = root.activeTool
        pluginApi.pluginSettings.stateMirrorVisible = mirrorOverlay?.isVisible ?? false
        pluginApi.saveSettings()
    }
    readonly property string selectedOcrLang: pluginApi?.pluginSettings?.selectedOcrLang || "eng"
    readonly property bool   isNiri:          CompositorService.isNiri
    readonly property bool   isHyprland:      CompositorService.isHyprland
    function expandPath(p) {
        if (!p || p.trim() === "") return ""
        if (p.startsWith("~/")) return Quickshell.env("HOME") + "/" + p.substring(2)
        return p
    }
    function formatFilename(stem) {
        if (!stem || stem.trim() === "") return ""
        var now = new Date()
        var s = stem
            .replace(/%Y/g, Qt.formatDateTime(now, "yyyy"))
            .replace(/%m/g, Qt.formatDateTime(now, "MM"))
            .replace(/%d/g, Qt.formatDateTime(now, "dd"))
            .replace(/%H/g, Qt.formatDateTime(now, "HH"))
            .replace(/%M/g, Qt.formatDateTime(now, "mm"))
            .replace(/%S/g, Qt.formatDateTime(now, "ss"))
            .replace(/[\/\\\n\r\0]/g, "_")
            .trim()
        return s
    }
    function screenshotDir() {
        var custom = pluginApi?.pluginSettings?.screenshotPath ?? ""
        if (custom.trim() !== "") return expandPath(custom.trim())
        return Quickshell.env("HOME") + "/Pictures/Screenshots"
    }
    function videoDir() {
        var custom = pluginApi?.pluginSettings?.videoPath ?? ""
        if (custom.trim() !== "") return expandPath(custom.trim())
        return Quickshell.env("HOME") + "/Videos"
    }
    function buildFilename(prefix) {
        var fmt = pluginApi?.pluginSettings?.filenameFormat ?? ""
        if (fmt.trim() !== "") {
            var stem = formatFilename(fmt.trim())
            if (stem !== "") return stem
        }
        var now = new Date()
        return prefix + "-"
            + Qt.formatDateTime(now, "yyyy-MM-dd")
            + "_"
            + Qt.formatDateTime(now, "HH-mm-ss")
    }
    property int _regionX:        0
    property int _regionY:        0
    property int _regionW:        0
    property int _regionH:        0
    property var _regionScreen:   null
    property bool _capsDetected:  false
    property var _detectedLangs:  []
    Component.onCompleted: {
        root.isRunning  = false
        root.activeTool = ""
        if (!_capsDetected) {
            detectCapabilities()
            _capsDetected = true
        }
    }
    onPluginApiChanged: {
        if (pluginApi) {
            pluginApi.pluginSettings.stateIsRunning     = false
            pluginApi.pluginSettings.stateActiveTool    = ""
            pluginApi.pluginSettings.detectedCompositor =
                root.isHyprland ? "hyprland" :
                root.isNiri     ? "niri"     : "other"
            pluginApi.saveSettings()
        }
    }
    function _grimRegionCmd(outFile) {
        if (!root._regionScreen)
            Logger.w("ScreenToolkit", "_grimRegionCmd: _regionScreen is null")
        var scale = Math.max(0.1, root._regionScreen?.devicePixelRatio ?? 1.0)
        var sx    = root._regionScreen?.x ?? 0
        var sy    = root._regionScreen?.y ?? 0
        var gx = sx + Math.round(root._regionX / scale)
        var gy = sy + Math.round(root._regionY / scale)
        var gw = Math.round(root._regionW / scale)
        var gh = Math.round(root._regionH / scale)
        return "grim -g \"" + gx + "," + gy + " " + gw + "x" + gh + "\" " + outFile + " 2>/dev/null"
    }
    function _runSlurpTool(tool) {
        if (root.isRunning) return
        root.pendingTool = tool
        root.isRunning   = true
        closeThenLaunch(launchRegionSelector)
    }
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
            var output = colorPickerProc.stdout.text.trim()
            var parts  = output.split(/\s+/)
            if (parts.length < 3) {
                root.activeTool = ""
                ToastService.showError(pluginApi.tr("messages.picker-cancelled"))
                return
            }
            var r = Math.max(0, Math.min(255, parseInt(parts[0])))
            var g = Math.max(0, Math.min(255, parseInt(parts[1])))
            var b = Math.max(0, Math.min(255, parseInt(parts[2])))
            var hex = "#" + ((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1).toUpperCase()
            var rgb = "rgb(" + r + ", " + g + ", " + b + ")"
            var rn  = r / 255, gn = g / 255, bn = b / 255
            var max = Math.max(rn, gn, bn)
            var min = Math.min(rn, gn, bn)
            var d   = max - min
            var h = 0
            var s = max === 0 ? 0 : d / max
            var v = max
            if (d !== 0) {
                if      (max === rn) h = ((gn - bn) / d + (gn < bn ? 6 : 0)) % 6
                else if (max === gn) h = (bn - rn) / d + 2
                else                 h = (rn - gn) / d + 4
                h = Math.round(h * 60)
            }
            var hsv = "hsv(" + h + ", " + Math.round(s * 100) + "%, " + Math.round(v * 100) + "%)"
            var l   = (max + min) / 2
            var sl  = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1))
            var hsl = "hsl(" + h + ", " + Math.round(sl * 100) + "%, " + Math.round(l * 100) + "%)"
            if (pluginApi) {
                pluginApi.pluginSettings.resultHex        = hex
                pluginApi.pluginSettings.resultRgb        = rgb
                pluginApi.pluginSettings.resultHsv        = hsv
                pluginApi.pluginSettings.resultHsl        = hsl
                pluginApi.pluginSettings.colorCapturePath = "/tmp/screen-toolkit-colorpicker.png"
                pluginApi.pluginSettings.colorCacheBust   = Date.now()
                var history = pluginApi.pluginSettings.colorHistory || []
                history = [hex].concat(history.filter(c => c !== hex)).slice(0, 8)
                pluginApi.pluginSettings.colorHistory = history
                pluginApi.saveSettings()
                root.copyToClipboard(hex)
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
                    pluginApi.pluginSettings.ocrResult       = text
                    pluginApi.pluginSettings.ocrCapturePath  = "/tmp/screen-toolkit-ocr.png"
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
                    pluginApi.pluginSettings.qrResult      = result
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
            root.isRunning  = false
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
                var region = annotateRegionState._pendingRegion
                annotateOverlay.parseAndShow(region, "/tmp/screen-toolkit-annotate.png", annotateRegionState._pendingScreen)
                annotateRegionState._pendingRegion = ""
                annotateRegionState._pendingScreen = null
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
            if (pluginApi) pluginApi.withCurrentScreen(s => pluginApi.closePanel(s))
            annotateOverlay.parseAndShow(regionStr, "/tmp/screen-toolkit-annotate.png", screen)
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
                var colors = raw.split("\n")
                    .map(function(c) { return c.trim() })
                    .filter(function(c) { return /^#[0-9a-fA-F]{6}$/.test(c) })
                    .filter(function(c, i, arr) { return arr.indexOf(c) === i })
                    .slice(0, 8)
                if (colors.length > 0 && pluginApi) {
                    pluginApi.pluginSettings.paletteColors   = colors
                    pluginApi.pluginSettings.stateActiveTool = "palette"
                    pluginApi.saveSettings()
                    root.activeTool = "palette"
                    pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
                } else {
                    root.activeTool = ""
                    ToastService.showError(pluginApi.tr("messages.palette-failed"))
                }
            } else {
                root.activeTool = ""
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
                pluginApi.pluginSettings.translateResult = result !== ""
                    ? result : pluginApi.tr("messages.translate-failed")
                pluginApi.saveSettings()
            }
        }
    }
    Process { id: clipProc }
    RegionSelector {
        id: regionSelector
        onRegionSelected: (x, y, w, h, screen) => {
            root._regionX      = x; root._regionY = y
            root._regionW      = w; root._regionH = h
            root._regionScreen = screen
            _dispatchPendingTool()
        }
        onCancelled: {
            root.isRunning  = false
            root.activeTool = ""
        }
    }
    Annotate { id: annotateOverlay; mainInstance: root }
    Measure  { id: measureOverlay;  mainInstance: root }
    Pin      { id: pinOverlay;      pluginApi: root.pluginApi }
    Record   { id: recordOverlay;   pluginApi: root.pluginApi }
    Mirror   { id: mirrorOverlay;   pluginApi: root.pluginApi }
    readonly property bool mirrorVisible: mirrorOverlay.isVisible
    onMirrorVisibleChanged: _syncState()
    Timer {
        id: launchColorPicker
        interval: 220; repeat: false
        onTriggered: {
            var file = "/tmp/screen-toolkit-colorpicker.png"
            var cmd = "COORDS=$(slurp -p 2>/dev/null) || exit 1; " +
                      "X=${COORDS%%,*}; REST=${COORDS#*,}; Y=${REST%% *}; " +
                      "GX=$((X > 5 ? X - 5 : 0)); GY=$((Y > 5 ? Y - 5 : 0)); " +
                      "grim -g \"${GX},${GY} 11x11\" " + shellEscape(file) + " 2>/dev/null || exit 1; " +
                      "magick " + shellEscape(file) + " -alpha off " +
                      "-format '%[fx:int(255*u.p{5,5}.r)] %[fx:int(255*u.p{5,5}.g)] %[fx:int(255*u.p{5,5}.b)]' " +
                      "info:- 2>/dev/null"
            colorPickerProc.exec({ command: ["bash", "-c", cmd] })
        }
    }
    Timer {
        id: launchOcr
        interval: 50; repeat: false
        onTriggered: {
            var file = "/tmp/screen-toolkit-ocr.png"
            var tmp  = "/tmp/screen-toolkit-ocr-work-" + Date.now() + ".pnm"
            var lang = root.pendingLangStr || "eng"
            var scale    = root._regionScreen?.devicePixelRatio ?? 1.0
            var physW    = Math.round(root._regionW / scale)
            var physH    = Math.round(root._regionH / scale)
            var area     = physW * physH
            var upscale  = physH < 30 ? "-resize 400%" : (area < 50000 || physW < 200) ? "-resize 200%" : ""
            var aspectRatio = physW / Math.max(physH, 1)
            var psm      = aspectRatio > 8 ? "7" : area < 60000 ? "6" : physH < 40 ? "7" : "3"
            var cmd =
                _grimRegionCmd(file) + " && " +
                "magick " + shellEscape(file) + " " + upscale + " " +
                "-colorspace Gray -normalize -contrast-stretch 2%x1% -sharpen 0x1.5 +repage " +
                shellEscape(tmp) + " && " +
                "if [ $(magick " + shellEscape(tmp) + " -format '%[fx:mean]' info:) < 0.4 ]; then " +
                "  magick " + shellEscape(tmp) + " -negate " + shellEscape(tmp) + "; " +
                "fi && " +
                "TEXT=$(tesseract " + shellEscape(tmp) + " stdout -l " + shellEscape(lang) + " --psm " + psm + " --oem 1 2>/dev/null) && " +
                "if [ $(printf '%s' \"$TEXT\" | tr -d '[:space:]' | wc -c) -lt 4 ]; then " +
                "  TEXT2=$(magick " + shellEscape(tmp) + " -threshold 85% stdout | " +
                "          tesseract - stdout -l " + shellEscape(lang) + " --psm " + psm + " --oem 1 2>/dev/null); " +
                "  if [ $(printf '%s' \"$TEXT2\" | tr -d '[:space:]' | wc -c) -gt $(printf '%s' \"$TEXT\" | tr -d '[:space:]' | wc -c) ]; then " +
                "    TEXT=\"$TEXT2\"; fi; " +
                "fi && " +
                "printf '%s' \"$TEXT\"; rm -f " + shellEscape(tmp)
            ocrProc.exec({ command: ["bash", "-c", cmd] })
        }
    }
    Timer {
        id: launchQr
        interval: 50; repeat: false
        onTriggered: {
            var file = "/tmp/screen-toolkit-qr.png"
            qrProc.exec({ command: ["bash", "-c",
                _grimRegionCmd(file) + "; zbarimg -q --raw " + file + " 2>/dev/null"
            ]})
        }
    }
    Timer {
        id: launchLens
        interval: 50; repeat: false
        onTriggered: {
            var file = "/tmp/screen-toolkit-lens.png"
            var cmd =
                _grimRegionCmd(file) + " || { notify-send -u critical 'Screen Toolkit' 'Capture failed'; exit 1; }; " +
                "notify-send 'Screen Toolkit' 'Uploading to Lens...' 2>/dev/null; " +
                "RESP=$(curl -sS --connect-timeout 5 --max-time 30 -F 'files[]=@" + file + "' 'https://uguu.se/upload' 2>/dev/null); " +
                "URL=$(echo \"$RESP\" | jq -r '.files[0].url // empty' 2>/dev/null); " +
                "rm -f " + file + "; " +
                "if [ -n \"$URL\" ] && [ \"$URL\" != \"null\" ]; then " +
                "  xdg-open \"https://lens.google.com/uploadbyurl?url=$URL\" >/dev/null 2>&1; exit 0; " +
                "else notify-send -u critical 'Screen Toolkit' 'Upload failed or timed out'; exit 1; fi"
            lensProc.exec({ command: ["bash", "-c", cmd] })
        }
    }
    Timer {
        id: launchAnnotate
        interval: 50; repeat: false
        onTriggered: {
            var scale     = root._regionScreen?.devicePixelRatio ?? 1.0
            var regionStr = Math.round(root._regionX / scale) + "," +
                            Math.round(root._regionY / scale) + " " +
                            Math.round(root._regionW / scale) + "x" +
                            Math.round(root._regionH / scale)
            annotateRegionState._pendingRegion = regionStr
            annotateRegionState._pendingScreen = root._regionScreen
            annotateProc.exec({ command: ["bash", "-c", _grimRegionCmd("/tmp/screen-toolkit-annotate.png")] })
        }
    }
    Timer {
        id: launchAnnotateActiveWindow
        interval: 360; repeat: false
        property var targetScreen: null
        onTriggered: {
            var cmd =
                "WIN=$(hyprctl activewindow -j 2>/dev/null) || exit 1; " +
                "GEOM=$(printf '%s' \"$WIN\" | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"' 2>/dev/null); " +
                "[ -z \"$GEOM\" ] && exit 1; " +
                "grim -g \"$GEOM\" /tmp/screen-toolkit-annotate.png 2>/dev/null || exit 1; " +
                "printf '%s' \"$GEOM\""
            annotateWinProc.exec({ command: ["bash", "-c", cmd] })
        }
    }
    Timer {
        id: launchAnnotateFullscreen
        interval: 380; repeat: false
        property var targetScreen: null
        onTriggered: {
            var name = targetScreen?.name ?? ""
            var cmd  = name !== ""
                ? "grim -o " + shellEscape(name) + " /tmp/screen-toolkit-annotate.png 2>/dev/null"
                : "grim /tmp/screen-toolkit-annotate.png 2>/dev/null"
            annotateProc.exec({ command: ["bash", "-c", cmd] })
        }
    }
    Timer {
        id: launchPin
        interval: 50; repeat: false
        onTriggered: {
            var scale = Math.max(0.1, root._regionScreen?.devicePixelRatio ?? 1.0)
            var sx    = root._regionScreen?.x ?? 0
            var sy    = root._regionScreen?.y ?? 0
            var gx = sx + Math.round(root._regionX / scale)
            var gy = sy + Math.round(root._regionY / scale)
            var gw = Math.round(root._regionW / scale)
            var gh = Math.round(root._regionH / scale)
            var cmd = "FILE=/tmp/screen-toolkit-pin-$(date +%s%3N).png"
                    + "; grim -s 2 -g \"" + gx + "," + gy + " " + gw + "x" + gh + "\" \"$FILE\" 2>/dev/null || exit 1"
                    + "; echo \"$FILE|" + gw + "x" + gh + "\""
            pinGrimProc.exec({ command: ["bash", "-c", cmd] })
        }
    }
    Timer {
        id: launchPinFile
        interval: 200; repeat: false
        onTriggered: {
            pinFileProc.exec({ command: [
                "bash", "-c",
                "if command -v zenity >/dev/null 2>&1; then " +
                "zenity --file-selection --title='Pin image' --file-filter='Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp' 2>/dev/null; " +
                "elif command -v kdialog >/dev/null 2>&1; then " +
                "kdialog --getopenfilename '' 'Images (*.png *.jpg *.jpeg *.webp *.gif *.bmp)' 2>/dev/null; fi"
            ]})
        }
    }
    Timer {
        id: launchPalette
        interval: 50; repeat: false
        onTriggered: {
            var file = "/tmp/screen-toolkit-palette.png"
            var cmd  = _grimRegionCmd(file) + " && " +
                       "magick " + shellEscape(file) +
                       " -alpha off +dither -colors 8 -unique-colors txt:- 2>/dev/null" +
                       " | grep -v '^#' | grep -oP '#[0-9a-fA-F]{6}' | head -8"
            paletteProc.exec({ command: ["bash", "-c", cmd] })
        }
    }
    Timer {
        id: launchRecord
        interval: 50; repeat: false
        onTriggered: {
            var scale  = root._regionScreen?.devicePixelRatio ?? 1.0
            var sx     = root._regionScreen?.x ?? 0
            var sy     = root._regionScreen?.y ?? 0
            var region = (sx + Math.round(root._regionX / scale)) + "," +
                         (sy + Math.round(root._regionY / scale)) + " " +
                         Math.round(root._regionW / scale) + "x" +
                         Math.round(root._regionH / scale)
            var localX = Math.round(root._regionX / scale)
            var localY = Math.round(root._regionY / scale)
            root.isRunning  = false
            root.activeTool = "record"
            recordOverlay.startRecording(
                region, root.pendingRecordFormat,
                root.pendingRecordAudioOut, root.pendingRecordAudioIn,
                root.pendingRecordCursor, localX, localY,
                root._regionScreen
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
        clipProc.exec({ command: ["bash", "-c", "printf '%s' " + shellEscape(text) + " | wl-copy 2>/dev/null"] })
    }
    function shellEscape(str) { return "'" + str.replace(/'/g, "'\\''") + "'" }
    function closeThenLaunch(timer) {
        if (!pluginApi) { timer.start(); return }
        pluginApi.withCurrentScreen(screen => {
            if (timer === launchRegionSelector) launchRegionSelector.targetScreen = screen
            pluginApi.closePanel(screen)
            timer.start()
        })
    }
    function runTranslate(text, targetLang) {
        if (!text || text === "" || translateProc.isTranslating) return
        translateProc.isTranslating = true
        if (pluginApi) { pluginApi.pluginSettings.translateResult = ""; pluginApi.saveSettings() }
        translateProc.exec({ command: ["bash", "-c", "trans -brief -to " + targetLang + " " + shellEscape(text)] })
    }
    function runColorPicker() {
        if (root.isRunning) return
        root.isRunning  = true
        root.activeTool = ""
        if (pluginApi) {
            pluginApi.pluginSettings.resultHex        = ""
            pluginApi.pluginSettings.resultRgb        = ""
            pluginApi.pluginSettings.resultHsv        = ""
            pluginApi.pluginSettings.resultHsl        = ""
            pluginApi.pluginSettings.colorCapturePath = ""
            pluginApi.pluginSettings.colorCacheBust   = 0
            pluginApi.saveSettings()
        }
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
            launchAnnotateActiveWindow.targetScreen = screen
            launchAnnotateActiveWindow.start()
        })
    }
    function runPalette() {
        if (root.isRunning) return
        if (pluginApi) { pluginApi.pluginSettings.paletteColors = []; pluginApi.saveSettings() }
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
    function runMeasure() {
        if (root.isRunning) return
        root.activeTool = "measure"
        if (pluginApi) pluginApi.withCurrentScreen(screen => pluginApi.closePanel(screen))
        measureOverlay.show()
    }
    function runRecord(format, audioOut, audioIn, cursor) {
        if (root.isRunning || recordOverlay.isRecording || recordOverlay.isConverting) return
        root.pendingRecordFormat   = format   || "gif"
        root.pendingRecordAudioOut = audioOut === true
        root.pendingRecordAudioIn  = audioIn  === true
        root.pendingRecordCursor   = cursor   === true
        _runSlurpTool("record")
    }
    function runMirror() {
        if (pluginApi) pluginApi.withCurrentScreen(screen => mirrorOverlay.toggle(screen))
        else mirrorOverlay.toggle()
    }
    function detectCapabilities() {
        root._detectedLangs = []
        detectLangsProc.exec({ command:     ["bash", "-c", "tesseract --list-langs 2>/dev/null | tail -n +2"] })
        detectTransProc.exec({ command:     ["bash", "-c", "which trans 2>/dev/null"] })
        detectRecorderProc.exec({ command:  ["bash", "-c", "which wl-screenrec 2>/dev/null || which wf-recorder 2>/dev/null"] })
    }
    function annotateScreenshotCmd(overlayTmpFile) {
        var dir   = root.screenshotDir()
        var fname = root.buildFilename("annotate") + ".png"
        var dest  = dir + "/" + fname
        return "mkdir -p " + shellEscape(dir) + " && " +
               "magick /tmp/screen-toolkit-annotate.png " + shellEscape(overlayTmpFile) + " " +
               "-composite " + shellEscape(dest) + " && " +
               "rm -f " + shellEscape(overlayTmpFile) + " && " +
               "echo " + shellEscape(dest)
    }
    function annotateScreenshotZoomCmd(imgPath) {
        var dir   = root.screenshotDir()
        var fname = root.buildFilename("annotate") + ".png"
        var dest  = dir + "/" + fname
        return "mkdir -p " + shellEscape(dir) + " && " +
               "cp " + shellEscape(imgPath) + " " + shellEscape(dest) + " && " +
               "echo " + shellEscape(dest)
    }
    IpcHandler {
        target: "plugin:screen-toolkit"
        function toggle()             { if (pluginApi) pluginApi.withCurrentScreen(screen => pluginApi.togglePanel(screen)) }
        function mirror()             { root.runMirror() }
        function measure()            { root.runMeasure() }
        function colorPicker()        { root.runColorPicker() }
        function annotate()           { root.runAnnotate() }
        function annotateFullscreen() { root.runAnnotateFullscreen() }
        function annotateWindow()     { root.runAnnotateActiveWindow() }
        function pin()                { root.runPin() }
        function pinImage()           { root.runPinFromFile() }
        function ocr()                { root.runOcr(root.selectedOcrLang) }
        function qr()                 { root.runQr() }
        function palette()            { root.runPalette() }
        function lens()               { root.runLens() }
        function record()             { root.runRecord("gif") }
        function recordMp4()          { root.runRecord("mp4") }
        function recordStop()         { if (recordOverlay.isRecording) recordOverlay.stopRecording() }
    }
}

