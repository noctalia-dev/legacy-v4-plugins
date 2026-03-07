import QtQuick
import Quickshell.Io
import qs.Services.UI
import qs.Services.Compositor
import QtQml.Models
import Quickshell
import qs.Commons

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

            if (CompositorService.isNiri) {
                root.runNiriTarget(requestedTarget)
                return
            }

            root.openSelector(requestedTarget)
        }
    }

    function stopRecording() {
        if (!pluginApi?.pluginDir) {
            return
        }

        recordingActive = false
        Quickshell.execDetached(["bash", pluginApi.pluginDir + "/record.sh"])
    }

    function runNiriTarget(target) {
        if (!CompositorService.isNiri) {
            return false
        }

        if (target === "screenshot") {
            const editor = pluginApi?.pluginSettings?.screenshotEditor
                          ?? pluginApi?.manifest?.metadata?.defaultSettings?.screenshotEditor
                          ?? "swappy"

            const keepSourceScreenshot = pluginApi?.pluginSettings?.keepSourceScreenshot
                                       ?? pluginApi?.manifest?.metadata?.defaultSettings?.keepSourceScreenshot
                                       ?? false

            var configuredSavePath = pluginApi?.pluginSettings?.savePath
                                    ?? pluginApi?.manifest?.metadata?.defaultSettings?.savePath
                                    ?? ""
            var screenshotDir = Settings.preprocessPath(configuredSavePath)
            if (!screenshotDir || screenshotDir === "") {
                screenshotDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
            }

            const timestamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm.ss")
            const sourceFile = `${screenshotDir}/screenshot_${timestamp}_niri_source.png`
            const outputFile = `${screenshotDir}/screenshot_${timestamp}_niri.png`

            const cmd = `if ! command -v slurp >/dev/null 2>&1; then notify-send -a "Screenshot" "Screenshot failed" "slurp is not installed"; exit 1; fi; if ! command -v grim >/dev/null 2>&1; then notify-send -a "Screenshot" "Screenshot failed" "grim is not installed"; exit 1; fi; REGION="$(slurp)"; [[ -n "$REGION" ]] || exit 0; mkdir -p "$1"; if command -v "$4" >/dev/null 2>&1; then grim -g "$REGION" "$2" && "$4" -f "$2" -o "$3" && if [ "$5" != "true" ]; then rm -f "$2"; fi && notify-send -a "Screenshot" "Screenshot saved" "$3"; else if ! command -v wl-copy >/dev/null 2>&1; then notify-send -a "Screenshot" "Screenshot failed" "Editor '$4' and wl-copy are not installed"; exit 1; fi; grim -g "$REGION" - | wl-copy --type image/png && notify-send -a "Screenshot" "Screenshot copied" "Editor '$4' not found; copied to clipboard"; fi`
            Quickshell.execDetached(["bash", "-c", cmd, "bash", screenshotDir, sourceFile, outputFile, editor, keepSourceScreenshot ? "true" : "false"])
            return true
        }

        if (target === "search") {
            const tempFile = `/tmp/screen-niri-${Date.now()}.png`
            const cmd = `if ! command -v slurp >/dev/null 2>&1; then notify-send -a "Screenshot" "Search failed" "slurp is not installed"; exit 1; fi; if ! command -v grim >/dev/null 2>&1; then notify-send -a "Screenshot" "Search failed" "grim is not installed"; exit 1; fi; REGION="$(slurp)"; [[ -n "$REGION" ]] || exit 0; grim -g "$REGION" '${tempFile}' && xdg-open "https://lens.google.com/uploadbyurl?url=$(curl -sF files[]=@'${tempFile}' https://uguu.se/upload | jq -r '.files[0].url')"`
            Quickshell.execDetached(["bash", "-c", cmd])
            return true
        }

        if (target === "ocr") {
            const tempFile = `/tmp/screen-niri-ocr-${Date.now()}.png`
            const cmd = `if ! command -v slurp >/dev/null 2>&1; then notify-send -a "Screenshot" "OCR failed" "slurp is not installed"; exit 1; fi; if ! command -v grim >/dev/null 2>&1; then notify-send -a "Screenshot" "OCR failed" "grim is not installed"; exit 1; fi; if ! command -v tesseract >/dev/null 2>&1; then notify-send -a "Screenshot" "OCR failed" "tesseract is not installed"; exit 1; fi; if ! command -v wl-copy >/dev/null 2>&1; then notify-send -a "Screenshot" "OCR failed" "wl-copy is not installed"; exit 1; fi; REGION="$(slurp)"; [[ -n "$REGION" ]] || exit 0; OCR_TEXT=""; if grim -g "$REGION" '${tempFile}'; then OCR_TEXT=$(tesseract '${tempFile}' stdout 2>/dev/null); fi; if [ -n "$OCR_TEXT" ]; then printf "%s" "$OCR_TEXT" | wl-copy; notify-send -a "Screenshot" "OCR complete" "Recognized text copied to clipboard"; else notify-send -a "Screenshot" "OCR complete" "No text detected in selection"; fi`
            Quickshell.execDetached(["bash", "-c", cmd])
            return true
        }

        if (target === "record" || target === "recordsound") {
            if (!pluginApi?.pluginDir) {
                return false
            }

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

            const scriptPath = pluginApi.pluginDir + "/record.sh"
            const soundArg = (target === "recordsound") ? " --sound" : ""
            const notifyArg = recordingNotificationsEnabled ? " --notify" : ""
            const cmd = `if ! command -v slurp >/dev/null 2>&1; then notify-send -a "Recorder" "Recording failed" "slurp is not installed"; exit 1; fi; if ! command -v wf-recorder >/dev/null 2>&1; then notify-send -a "Recorder" "Recording failed" "wf-recorder is not installed"; exit 1; fi; REGION="$(slurp)"; [[ -n "$REGION" ]] || exit 0; bash "$2" --region "$REGION" --dir "$1"${soundArg}${notifyArg}`
            const recordStarted = Quickshell.execDetached(["bash", "-c", cmd, "bash", recordingDir, scriptPath])
            recordingActive = (recordStarted !== false)
            return true
        }

        return false
    }

    function openSelector(target) {
        if (active) {
            return
        }

        root.target = target
        active = true
    }

    // 存储当前所有屏幕
    property var screens: Quickshell.screens

    // 使用 Instantiator 管理选择框
    Instantiator {
        id: selectorInstantiator
        active: root.active
        model: Quickshell.screens
        delegate: Loader {
            required property int index
            source: "ScreenShot.qml"
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

        if (CompositorService.isNiri) {
            root.runNiriTarget(target)
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
