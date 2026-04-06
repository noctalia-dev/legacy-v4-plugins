import QtQuick
import Quickshell
import qs.Commons

QtObject {
    id: common

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

    function buildRecordingNotifyArgs(pluginApi) {
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

    function shouldNormalizeRecordingResolution(host) {
        const outputName = String(host.screen?.name ?? "")
        const screens = Quickshell.screens ?? []

        let matched = host.screen
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

    function processRegion(host, x, y, width, height, mode) {
        const pluginApi = host.pluginApi

        const scale = Number(host.screen?.scale ?? 1)
        const dpr = Number(host.screen?.devicePixelRatio ?? 1)
        const factor = (Number.isFinite(scale) && scale > 0.01) ? scale : ((Number.isFinite(dpr) && dpr > 0.01) ? dpr : 1)

        const globalX = Math.round(x + host.monitorOffsetX)
        const globalY = Math.round(y + host.monitorOffsetY)
        const globalW = Math.max(1, Math.round(width))
        const globalH = Math.max(1, Math.round(height))

        const scaledGlobalX = Math.round(globalX * factor)
        const scaledGlobalY = Math.round(globalY * factor)
        const scaledGlobalW = Math.max(1, Math.round(globalW * factor))
        const scaledGlobalH = Math.max(1, Math.round(globalH * factor))
        const geometry = `${scaledGlobalX},${scaledGlobalY} ${scaledGlobalW}x${scaledGlobalH}`

        const scaledLocalX = Math.round(x * factor)
        const scaledLocalY = Math.round(y * factor)
        const scaledLocalW = Math.max(1, Math.round(width * factor))
        const scaledLocalH = Math.max(1, Math.round(height * factor))
        const cropGeometry = `${scaledLocalW}x${scaledLocalH}+${scaledLocalX}+${scaledLocalY}`

        var outputName = host.screen ? host.screen.name : "unknown"
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
        const useFrozenSource = host.frozenSourceReady && host.frozenSourceFile !== ""
        const frozenSourceFile = host.frozenSourceFile

        Logger.d("ScreenShot", host.target)
        if (host.target === "screenshot") {
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
        } else if (host.target === "search") {
            const searchCmd = useFrozenSource
                ? `${buildFrozenCropCmd(frozenSourceFile, cropGeometry, geometry, tempFile, false)} && rm -f '${frozenSourceFile}' && xdg-open \"https://lens.google.com/uploadbyurl?url=$(curl -sF files[]=@'${tempFile}' https://uguu.se/upload | jq -r '.files[0].url')\"`
                : `grim -g '${geometry}' '${tempFile}' && xdg-open \"https://lens.google.com/uploadbyurl?url=$(curl -sF files[]=@'${tempFile}' https://uguu.se/upload | jq -r '.files[0].url')\"`
            Logger.d("ScreenShot", "[Panel] Executing search command:", searchCmd)
            Quickshell.execDetached(["sh", "-c", searchCmd])
        } else if (host.target === "ocr") {
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
        } else if (host.target === "record" || host.target === "recordsound") {
            const scriptPath = pluginApi.pluginDir + "/record.sh"
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
            if (shouldNormalizeRecordingResolution(host)) {
                const targetSize = `${globalW}x${globalH}`
                recordArgs.push("--video-target-size", targetSize)
            }
            if (host.target === "recordsound") {
                recordArgs.push("--sound")
            }
            if (recordingNotificationsEnabled) {
                recordArgs.push("--notify")
            }
            recordArgs.push(...buildRecordingNotifyArgs(pluginApi))

            Logger.d("ScreenShot", "[Panel] Executing record command args:", recordArgs)
            const recordStarted = Quickshell.execDetached(recordArgs)
            if (pluginApi?.mainInstance) {
                pluginApi.mainInstance.recordingActive = (recordStarted !== false)
            }
        }
    }
}
