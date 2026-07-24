import QtQuick
import Quickshell
import qs.Commons

QtObject {
    id: common

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

        const rawScale = matched?.scale
        const scale = (rawScale !== null && rawScale !== undefined) ? Number(rawScale) : NaN
        const dpr = Number(matched?.devicePixelRatio ?? 1)
        const result = (Number.isFinite(scale) && scale > 1.01) || (Number.isFinite(dpr) && dpr > 1.01)
        return result
    }

    function processRegion(host, x, y, width, height, mode) {
        const pluginApi = host.pluginApi

        if (!pluginApi) return

        const rawScale = host.screen?.scale
        const scale = (rawScale !== null && rawScale !== undefined) ? Number(rawScale) : NaN
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

        const scriptPath = pluginApi.pluginDir + "/capture.sh"

        const pngCompressionLevel = pluginApi?.pluginSettings?.pngCompressionLevel
                                    ?? pluginApi?.manifest?.metadata?.defaultSettings?.pngCompressionLevel
                                    ?? 1

        const notificationsEnabled = pluginApi?.pluginSettings?.notificationsEnabled
                                     ?? pluginApi?.manifest?.metadata?.defaultSettings?.notificationsEnabled
                                     ?? true

        if (host.target === "screenshot") {
            const args = ["bash", scriptPath, "--action", "screenshot", "--geometry", geometry, "--crop-geometry", cropGeometry, "--png-compression-level", String(pngCompressionLevel)]

            if (useFrozenSource) {
                args.push("--frozen-source", frozenSourceFile)
            }

            if (!notificationsEnabled) {
                args.push("--no-notify")
            }

            if (mode === "copy") {
                args.push("--mode", "copy",
                    "--copied-title", pluginApi?.tr("notify.screenshot.copiedTitle"),
                    "--copied-body", pluginApi?.tr("notify.screenshot.copiedBody"))
            } else if (mode === "edit") {
                const editor = pluginApi?.pluginSettings?.screenshotEditor
                               ?? pluginApi?.manifest?.metadata?.defaultSettings?.screenshotEditor
                               ?? "swappy"
                const keepSourceScreenshot = pluginApi?.pluginSettings?.keepSourceScreenshot
                                            ?? pluginApi?.manifest?.metadata?.defaultSettings?.keepSourceScreenshot
                                            ?? false

                args.push("--mode", "edit", "--editor", editor,
                    "--source", sourceFile, "--output", outputFile,
                    "--saved-title", pluginApi?.tr("notify.screenshot.savedTitle"))

                if (keepSourceScreenshot) {
                    args.push("--keep-source")
                }
            }

            args.push("--notify-app", pluginApi?.tr("notify.app.screenshot"))
            Quickshell.execDetached(args)

        } else if (host.target === "search") {
            const args = ["bash", scriptPath, "--action", "search", "--geometry", geometry, "--crop-geometry", cropGeometry, "--png-compression-level", String(pngCompressionLevel)]

            if (useFrozenSource) {
                args.push("--frozen-source", frozenSourceFile)
            }

            Quickshell.execDetached(args)

        } else if (host.target === "ocr") {
            const args = ["bash", scriptPath, "--action", "ocr", "--geometry", geometry, "--crop-geometry", cropGeometry, "--png-compression-level", String(pngCompressionLevel)]

            if (useFrozenSource) {
                args.push("--frozen-source", frozenSourceFile)
            }

            if (!notificationsEnabled) {
                args.push("--no-notify")
            }

            args.push("--notify-app", pluginApi?.tr("notify.app.screenshot"),
                "--ocr-done-title", pluginApi?.tr("notify.ocr.doneTitle"),
                "--ocr-copied-body", pluginApi?.tr("notify.ocr.copiedBody"),
                "--ocr-empty-body", pluginApi?.tr("notify.ocr.emptyBody"),
                "--dep-missing", pluginApi?.tr("notify.dependencyMissing"),
                "--ocr-failed", pluginApi?.tr("notify.ocr.failed"))

            Quickshell.execDetached(args)

        } else if (host.target === "record" || host.target === "recordsound") {
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

            const recordArgs = ["bash", pluginApi.pluginDir + "/record.sh", "--region", region, "--dir", recordingDir]
            if (shouldNormalizeRecordingResolution(host)) {
                const targetSize = `${globalW}x${globalH}`
                recordArgs.push("--video-target-size", targetSize)
            }
            if (host.target === "recordsound") {
                recordArgs.push("--sound")
            }
            if (recordingNotificationsEnabled && notificationsEnabled) {
                recordArgs.push("--notify")
            }
            recordArgs.push(...buildRecordingNotifyArgs(pluginApi))

            const recordStarted = Quickshell.execDetached(recordArgs)
            if (pluginApi?.mainInstance) {
                pluginApi.mainInstance.recordingActive = (recordStarted !== false)
            }
        }
    }
}
