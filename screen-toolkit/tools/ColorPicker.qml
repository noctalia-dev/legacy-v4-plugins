import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.UI

Item {
    id: root
    property var    pluginApi:  null
    property string scriptsDir: ""

    property string resultHex:        ""
    property string resultRgb:        ""
    property string resultHsv:        ""
    property string resultHsl:        ""
    property string colorCapturePath: ""
    property int    colorCacheBust:   0
    property var    colorHistory:     []

    signal done()
    signal failed()

    function run() {
        colorPickerProc.exec({ command: [
            root.scriptsDir + "color-picker.sh",
            "/tmp/screen-toolkit-colorpicker.png"
        ]})
    }

    function clearResults() {
        root.resultHex        = ""
        root.resultRgb        = ""
        root.resultHsv        = ""
        root.resultHsl        = ""
        root.colorCapturePath = ""
        root.colorCacheBust   = 0
    }

    function loadState(s) {
        if ((s.resultHex ?? "") === "") return
        root.resultHex        = s.resultHex        ?? ""
        root.resultRgb        = s.resultRgb        ?? ""
        root.resultHsv        = s.resultHsv        ?? ""
        root.resultHsl        = s.resultHsl        ?? ""
        root.colorCapturePath = s.colorCapturePath ?? ""
        root.colorCacheBust   = s.colorCacheBust   ?? 0
    }

    Process {
        id: colorPickerProc
        stdout: StdioCollector {}
        onExited: (code) => {
            var output = colorPickerProc.stdout.text.trim()
            if (code !== 0 || output === "") { root.failed(); return }

            var parts = output.split(/\s+/)
            if (parts.length < 3) { root.failed(); return }

            var r = Math.max(0, Math.min(255, parseInt(parts[0])))
            var g = Math.max(0, Math.min(255, parseInt(parts[1])))
            var b = Math.max(0, Math.min(255, parseInt(parts[2])))

            var hex = "#" + ((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1).toUpperCase()
            var rgb = "rgb(" + r + ", " + g + ", " + b + ")"

            var rn  = r / 255, gn = g / 255, bn = b / 255
            var max = Math.max(rn, gn, bn)
            var min = Math.min(rn, gn, bn)
            var d   = max - min
            var h   = 0
            var sat = max === 0 ? 0 : d / max
            var val = max
            if (d !== 0) {
                if      (max === rn) h = ((gn - bn) / d + (gn < bn ? 6 : 0)) % 6
                else if (max === gn) h = (bn - rn) / d + 2
                else                 h = (rn - gn) / d + 4
                h = Math.round(h * 60)
            }
            var hsv = "hsv(" + h + ", " + Math.round(sat * 100) + "%, " + Math.round(val * 100) + "%)"
            var l   = (max + min) / 2
            var sl  = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1))
            var hsl = "hsl(" + h + ", " + Math.round(sl * 100) + "%, " + Math.round(l * 100) + "%)"

            root.resultHex        = hex
            root.resultRgb        = rgb
            root.resultHsv        = hsv
            root.resultHsl        = hsl
            root.colorCapturePath = "/tmp/screen-toolkit-colorpicker.png"
            root.colorCacheBust   = Date.now()

            if (root.pluginApi) {
                var settings = root.pluginApi.pluginSettings
                settings.resultHex        = hex
                settings.resultRgb        = rgb
                settings.resultHsv        = hsv
                settings.resultHsl        = hsl
                settings.colorCapturePath = "/tmp/screen-toolkit-colorpicker.png"
                settings.colorCacheBust   = Date.now()
                var history = (settings.colorHistory || [])
                history = [hex].concat(history.filter(c => c !== hex)).slice(0, 8)
                settings.colorHistory = history
                root.pluginApi.saveSettings()
                root.colorHistory = history
            }

            root.done()
        }
    }
}
