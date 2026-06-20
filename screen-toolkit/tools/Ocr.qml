import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.UI

Item {
    id: root

    property var    pluginApi:       null
    property string scriptsDir:      ""
    property string ocrResult:       ""
    property string ocrCapturePath:  ""
    property string translateResult: ""
    property bool   isTranslating:   false
    property string _stdoutBuf:      ""

    signal done()
    signal failed(string messageKey, string messageArg)

    function run(grimX, grimY, grimW, grimH, langStr) {
        _stdoutBuf = ""
        var area        = grimW * grimH
        var upscale     = grimH < 30 ? "-resize 400%" : (area < 50000 || grimW < 200) ? "-resize 200%" : ""
        var aspectRatio = grimW / Math.max(grimH, 1)
        var psm         = aspectRatio > 8 ? "7" : area < 60000 ? "6" : grimH < 40 ? "7" : "3"
        ocrProc.command = [
            root.scriptsDir + "ocr.sh",
            String(grimX), String(grimY), String(grimW), String(grimH),
            langStr || "eng",
            upscale,
            psm
        ]
        ocrProc.running = true
    }

    function runTranslate(text, targetLang) {
        if (!text || text === "" || root.isTranslating) return
        root.isTranslating   = true
        root.translateResult = ""
        translateProc.exec({ command: ["bash", "-c",
            "trans -brief -to " + targetLang + " '" + text.replace(/'/g, "'\\''") + "'"
        ]})
    }

    function clearResults() {
        root.ocrResult       = ""
        root.ocrCapturePath  = ""
        root.translateResult = ""
    }

    function loadState(s) {
        if ((s.ocrResult ?? "") === "") return
        root.ocrResult      = s.ocrResult
        root.ocrCapturePath = s.ocrCapturePath ?? ""
    }

    Process {
        id: ocrProc

        stdout: SplitParser {
            onRead: line => { root._stdoutBuf += line + "\n" }
        }

        onExited: code => {
            switch (code) {
                case 0:
                    var text = root._stdoutBuf.trim()
                    if (text === "") {
                        root.failed("messages.ocr-no-text", "")
                        return
                    }
                    root.ocrResult       = text
                    root.ocrCapturePath  = "/tmp/screen-toolkit-ocr.png"
                    root.translateResult = ""
                    if (root.pluginApi) {
                        root.pluginApi.pluginSettings.ocrResult       = text
                        root.pluginApi.pluginSettings.ocrCapturePath  = "/tmp/screen-toolkit-ocr.png"
                        root.pluginApi.pluginSettings.translateResult = ""
                        root.pluginApi.saveSettings()
                    }
                    root.done()
                    break
                case 1:
                    root.failed("messages.ocr-missing-dep", root._stdoutBuf.trim())
                    break
                case 2:
                    root.failed("messages.ocr-bad-args", "")
                    break
                case 3:
                    root.failed("messages.ocr-capture-failed", "")
                    break
                case 4:
                    root.failed("messages.ocr-process-failed", "")
                    break
                default:
                    root.failed("messages.ocr-unknown-error", String(code))
                    break
            }
        }
    }

    Process {
        id: translateProc
        stdout: StdioCollector {}
        onExited: {
            root.isTranslating   = false
            var result           = translateProc.stdout.text.trim()
            root.translateResult = result !== ""
                ? result : root.pluginApi?.tr("messages.translate-failed")
        }
    }
}
