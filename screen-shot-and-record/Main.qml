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

    function shellQuote(value) {
        return "'" + String(value ?? "").replace(/'/g, "'\"'\"'") + "'"
    }

    function buildShellRequireCmdFn(appName, failedTitle, missingMessage) {
        return `require_cmd() { if ! command -v "$1" >/dev/null 2>&1; then notify-send -a ${shellQuote(appName)} ${shellQuote(failedTitle)} ${shellQuote(missingMessage)}; exit 1; fi; }`
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

    function buildRecordingNotifyShellArgs() {
        const args = buildRecordingNotifyArgs()
        let shellArgs = ""
        for (let i = 0; i < args.length; i += 2) {
            shellArgs += ` ${shellQuote(args[i])} ${shellQuote(args[i + 1])}`
        }
        return shellArgs
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
            const notifyApp = pluginApi?.tr("notify.app.screenshot")
            const depMissing = pluginApi?.tr("notify.dependencyMissing")
            const failedTitle = pluginApi?.tr("notify.screenshot.failed")
            const savedTitle = pluginApi?.tr("notify.screenshot.savedTitle")
            const copiedTitle = pluginApi?.tr("notify.screenshot.copiedTitle")
            const copiedBody = pluginApi?.tr("notify.screenshot.copiedBody")

            const screenshotPreamble = buildShellRequireCmdFn(notifyApp, failedTitle, depMissing)
            const cmd = `${screenshotPreamble}; require_cmd slurp; require_cmd grim; REGION="$(slurp)"; [[ -n "$REGION" ]] || exit 0; mkdir -p "$1"; grim -s 1 "$2"; read -r RX RY RW RH <<<"$(printf '%s' "$REGION" | awk -F'[, x]+' '{printf "%d %d %d %d", $1, $2, $3, $4}')"; CROP="$(printf '%sx%s+%s+%s' "$RW" "$RH" "$RX" "$RY")"; if command -v "$4" >/dev/null 2>&1; then if command -v magick >/dev/null 2>&1; then magick "$2" -crop "$CROP" +repage "$6"; elif command -v convert >/dev/null 2>&1; then convert "$2" -crop "$CROP" +repage "$6"; else grim -g "$REGION" "$6"; fi && if [ "$4" = "satty" ]; then satty --filename "$6" --output-filename "$3"; else "$4" -f "$6" -o "$3"; fi && if [ "$5" != "true" ]; then rm -f "$2" "$6"; fi && notify-send -a ${shellQuote(notifyApp)} ${shellQuote(savedTitle)} "$3"; else require_cmd wl-copy; if command -v magick >/dev/null 2>&1; then magick "$2" -crop "$CROP" +repage png:- | wl-copy --type image/png; elif command -v convert >/dev/null 2>&1; then convert "$2" -crop "$CROP" +repage png:- | wl-copy --type image/png; else grim -g "$REGION" - | wl-copy --type image/png; fi && notify-send -a ${shellQuote(notifyApp)} ${shellQuote(copiedTitle)} ${shellQuote(copiedBody)}; fi`
            const regionFile = `${screenshotDir}/screenshot_${timestamp}_niri_region.png`
            Quickshell.execDetached(["bash", "-c", cmd, "bash", screenshotDir, sourceFile, outputFile, editor, keepSourceScreenshot ? "true" : "false", regionFile])
            return true
        }

        if (target === "search") {
            const tempFile = `/tmp/screen-niri-${Date.now()}.png`
            const notifyApp = pluginApi?.tr("notify.app.screenshot")
            const depMissing = pluginApi?.tr("notify.dependencyMissing")
            const failedTitle = pluginApi?.tr("notify.search.failed")
            const searchPreamble = buildShellRequireCmdFn(notifyApp, failedTitle, depMissing)
            const cmd = `${searchPreamble}; require_cmd slurp; require_cmd grim; REGION="$(slurp)"; [[ -n "$REGION" ]] || exit 0; grim -g "$REGION" '${tempFile}' && xdg-open "https://lens.google.com/uploadbyurl?url=$(curl -sF files[]=@'${tempFile}' https://uguu.se/upload | jq -r '.files[0].url')"`
            Quickshell.execDetached(["bash", "-c", cmd])
            return true
        }

        if (target === "ocr") {
            const tempFile = `/tmp/screen-niri-ocr-${Date.now()}.png`
            const notifyApp = pluginApi?.tr("notify.app.screenshot")
            const depMissing = pluginApi?.tr("notify.dependencyMissing")
            const failedTitle = pluginApi?.tr("notify.ocr.failed")
            const doneTitle = pluginApi?.tr("notify.ocr.doneTitle")
            const doneCopied = pluginApi?.tr("notify.ocr.copiedBody")
            const doneNoText = pluginApi?.tr("notify.ocr.emptyBody")
            const ocrPreamble = buildShellRequireCmdFn(notifyApp, failedTitle, depMissing)
            const cmd = `${ocrPreamble}; require_cmd slurp; require_cmd grim; require_cmd tesseract; require_cmd wl-copy; REGION="$(slurp)"; [[ -n "$REGION" ]] || exit 0; OCR_TEXT=""; if grim -g "$REGION" '${tempFile}'; then OCR_TEXT=$(tesseract '${tempFile}' stdout 2>/dev/null); fi; if [ -n "$OCR_TEXT" ]; then printf "%s" "$OCR_TEXT" | wl-copy; notify-send -a ${shellQuote(notifyApp)} ${shellQuote(doneTitle)} ${shellQuote(doneCopied)}; else notify-send -a ${shellQuote(notifyApp)} ${shellQuote(doneTitle)} ${shellQuote(doneNoText)}; fi`
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
            const notifyTextArgs = buildRecordingNotifyShellArgs()
            const notifyApp = pluginApi?.tr("notify.app.recorder")
            const depMissing = pluginApi?.tr("notify.dependencyMissing")
            const failedTitle = pluginApi?.tr("notify.recording.failed")
            const recordPreamble = buildShellRequireCmdFn(notifyApp, failedTitle, depMissing)
            const cmd = `${recordPreamble}; require_cmd slurp; require_cmd wf-recorder; REGION="$(slurp)"; [[ -n "$REGION" ]] || exit 0; bash "$2" --region "$REGION" --dir "$1"${soundArg}${notifyArg}${notifyTextArgs}`
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
