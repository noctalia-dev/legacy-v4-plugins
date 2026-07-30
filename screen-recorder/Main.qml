import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Services.System
import qs.Services.Compositor

Item {
    id: root

    property var pluginApi: null

    property bool isRecording: false
    property bool isReplaying: false
    property bool isSavingReplay: false

    property string backend: ""
    property string outputPath: ""
    property var recordingStart: null
    property string recordingDuration: "0:00"

    IpcHandler {
        target: "plugin:screen-recorder"

        function toggleRecording() {
            root.toggleRecording();
        }

        function startRecording() {
            root.startRecording();
        }

        function stopRecording() {
            root.stopRecording();
        }

        function toggleReplay() {
            root.toggleReplay();
        }

        function startReplay() {
            root.startReplay();
        }

        function stopReplay() {
            root.stopReplay();
        }

        function saveReplay() {
            root.saveReplay();
        }
    }

    // General
    readonly property string directory: pluginApi?.pluginSettings?.directory || ""
    readonly property string scriptPath: pluginApi?.pluginSettings?.scriptPath || ""
    readonly property bool showCursor: pluginApi?.pluginSettings?.showCursor ?? true
    readonly property bool copyToClipboard: pluginApi?.pluginSettings?.copyToClipboard ?? false
    readonly property bool restorePortalSession: pluginApi?.pluginSettings?.restorePortalSession ?? false

    // Video
    readonly property string videoSource: pluginApi?.pluginSettings?.videoSource || "portal"
    readonly property string resolution: pluginApi?.pluginSettings?.resolution || "original"
    readonly property string frameRate: pluginApi?.pluginSettings?.frameRate || "60"
    readonly property string customFrameRate: pluginApi?.pluginSettings?.customFrameRate || "60"
    readonly property string rateControl: pluginApi?.pluginSettings?.rateControl || "qp"
    readonly property string quality: pluginApi?.pluginSettings?.quality || "very_high"
    readonly property string bitrate: pluginApi?.pluginSettings?.bitrate || "6000"
    readonly property string videoCodec: pluginApi?.pluginSettings?.videoCodec || "h264"
    readonly property string colorRange: pluginApi?.pluginSettings?.colorRange || "limited"

    // Audio
    readonly property string audioSource: pluginApi?.pluginSettings?.audioSource || "default_output"
    readonly property string audioCodec: pluginApi?.pluginSettings?.audioCodec || "opus"

    // Replay
    readonly property string replayDuration: pluginApi?.pluginSettings?.replayDuration || "30"
    readonly property string customReplayDuration: pluginApi?.pluginSettings?.customReplayDuration || "30"
    readonly property string replayStorage: pluginApi?.pluginSettings?.replayStorage || "ram"
    readonly property bool replayNotifications: pluginApi?.pluginSettings?.replayNotifications ?? true
    readonly property bool autoStartReplay: pluginApi?.pluginSettings?.autoStartReplay ?? false

    Component.onCompleted: {
        if (autoStartReplay)
            startReplay();
    }

    function handleButtonAction(action, openPanelCallback) {
        if (action === "toggle-recording")
            toggleRecording();
        else if (action === "toggle-replay")
            toggleReplay();
        else if (action === "save-replay")
            saveReplay();
        else if (action === "open-panel" && openPanelCallback)
            openPanelCallback();
    }

    function toggleRecording() {
        isRecording ? stopRecording() : startRecording();
    }

    function startRecording() {
        if (isRecording)
            return;

        isRecording = true;

        // Close any opened panel
        if ((PanelService.openedPanel !== null) && !PanelService.openedPanel.isClosing) {
            PanelService.openedPanel.close();
        }

        if (isReplaying) {
            // Portal session is already established from the replay process, no selection dialog occurs
            recordingStart = Date.now();
            updateRecordingDuration();
            Quickshell.execDetached(["sh", "-c", "pkill -SIGRTMIN -f 'gpu-screen-recorder' || pkill -SIGRTMIN -f 'com.dec05eba.gpu_screen_recorder'"]);
            return;
        }

        // For portal source the timer starts when pipewire negotiation finishes
        // (after the screen selection dialog). For all other sources start immediately.
        if (videoSource !== "portal") {
            recordingStart = Date.now();
            updateRecordingDuration();
        }

        // First, ensure xdg-desktop-portal and a compositor portal are running
        portalCheckProcess.exec({
            "command": ["sh", "-c", "pidof xdg-desktop-portal >/dev/null 2>&1 && (pidof xdg-desktop-portal-wlr >/dev/null 2>&1 || pidof xdg-desktop-portal-hyprland >/dev/null 2>&1 || pidof xdg-desktop-portal-gnome >/dev/null 2>&1 || pidof xdg-desktop-portal-kde >/dev/null 2>&1)"]
        });
    }

    function stopRecording() {
        if (!isRecording)
            return;

        if (isReplaying) {
            Quickshell.execDetached(["sh", "-c", "pkill -SIGRTMIN -f 'gpu-screen-recorder' || pkill -SIGRTMIN -f 'com.dec05eba.gpu_screen_recorder'"]);
            return;
        }

        Quickshell.execDetached(["sh", "-c", "pkill -SIGINT -f 'gpu-screen-recorder' || pkill -SIGINT -f 'com.dec05eba.gpu_screen_recorder'"]);

        // Just in case, force kill after 3 seconds
        killTimer.running = true;
    }

    function toggleReplay() {
        isReplaying ? stopReplay() : startReplay();
    }

    function startReplay() {
        if (isReplaying)
            return;

        if (isRecording) {
            ToastService.showNotice(pluginApi.tr("messages.cannot-start-replay-while-recording"));
            return;
        }

        isReplaying = true;

        if (replayNotifications)
            ToastService.showNotice(pluginApi.tr("messages.replay-started"));

        // First, ensure xdg-desktop-portal and a compositor portal are running
        portalCheckProcess.exec({
            "command": ["sh", "-c", "pidof xdg-desktop-portal >/dev/null 2>&1 && (pidof xdg-desktop-portal-wlr >/dev/null 2>&1 || pidof xdg-desktop-portal-hyprland >/dev/null 2>&1 || pidof xdg-desktop-portal-gnome >/dev/null 2>&1 || pidof xdg-desktop-portal-kde >/dev/null 2>&1)"]
        });
    }

    function stopReplay() {
        if (!isReplaying)
            return;

        if (isRecording) {
            ToastService.showNotice(pluginApi.tr("messages.cannot-stop-replay-while-recording"));
            return;
        }

        if (replayNotifications)
            ToastService.showNotice(pluginApi.tr("messages.replay-stopped"));

        Quickshell.execDetached(["sh", "-c", "pkill -SIGINT -f 'gpu-screen-recorder' || pkill -SIGINT -f 'com.dec05eba.gpu_screen_recorder'"]);

        // Just in case, force kill after 3 seconds
        killTimer.running = true;
    }

    function saveReplay() {
        if (!isReplaying) {
            ToastService.showNotice(pluginApi.tr("messages.replay-is-not-running"));
            return;
        }

        if (isSavingReplay)
            return;

        isSavingReplay = true;

        // Close any opened panel
        if ((PanelService.openedPanel !== null) && !PanelService.openedPanel.isClosing) {
            PanelService.openedPanel.close();
        }

        Quickshell.execDetached(["sh", "-c", "pkill -SIGUSR1 -f 'gpu-screen-recorder' || pkill -SIGUSR1 -f 'com.dec05eba.gpu_screen_recorder'"]);
    }

    function launchRecorder() {
        // If focused-monitor is selected, detect monitor first
        if (videoSource === "focused-monitor" && CompositorService.isHyprland) {
            var monitorDetectionScript = 'set -euo pipefail\n' + 'pos=$(hyprctl cursorpos)\n' + 'cx=${pos%,*}; cy=${pos#*,}\n' + 'mon=$(hyprctl monitors -j | jq -r --argjson cx "$cx" --argjson cy "$cy" ' + "'.[] | select(($cx>=.x) and ($cx<(.x+.width)) and ($cy>=.y) and ($cy<(.y+.height))) | .name' " + '| head -n1)\n' + '[ -n "${mon:-}" ] || { echo "MONITOR_NOT_FOUND"; exit 1; }\n' + 'use_prime=0\n' + 'for v in /sys/class/drm/card*/device/vendor; do\n' + '  [ -f "$v" ] || continue\n' + '  if grep -qi "0x10de" "$v"; then\n' + '    card="$(basename "$(dirname "$(dirname "$v")")")"\n' + '    [ -e "/sys/class/drm/${card}-${mon}" ] && use_prime=1 && break\n' + '  fi\n' + 'done\n' + 'echo "${mon}:${use_prime}"';
            monitorDetectProcess.exec({
                "command": ["sh", "-c", monitorDetectionScript]
            });
            return;
        }

        launchRecorderWithSource(videoSource, false);
    }

    function launchRecorderWithSource(source, primeRun) {
        var videoDir = Settings.preprocessPath(directory) || (Quickshell.env("HOME") + "/Videos");
        if (videoDir.endsWith("/"))
            videoDir = videoDir.slice(0, -1);

        const audioFlags = buildAudioFlags();

        var actualFrameRate = (frameRate === "custom") ? customFrameRate : frameRate;
        var qualityValue = rateControl === "cbr" ? bitrate : quality;
        var flags = [`-w ${source}`, `-f ${actualFrameRate}`, `-k ${videoCodec}`, ...audioFlags, `-bm ${rateControl}`, `-q ${qualityValue}`, `-cursor ${showCursor ? "yes" : "no"}`, `-cr ${colorRange}`];

        var resFlag = buildResolutionFlag();
        if (resFlag)
            flags.push(resFlag);

        if (source === "portal" && restorePortalSession)
            flags.push("-restore-portal-session yes");

        if (scriptPath)
            flags.push(`-sc "${scriptPath}"`);

        if (isReplaying) {
            var actualDuration = (replayDuration === "custom") ? customReplayDuration : replayDuration;
            flags.push(`-c mp4`, `-r ${actualDuration}`, `-replay-storage ${replayStorage}`, `-o "${videoDir}"`, `-ro "${videoDir}"`);
        } else {
            outputPath = videoDir + "/" + buildOutputFilename();
            flags.push(`-o "${outputPath}"`);
        }

        var primePrefix = primeRun ? "prime-run " : "";

        var command;
        if (backend === "native") {
            command = primePrefix + `gpu-screen-recorder ${flags.join(" ")}`;
        } else if (backend === "flatpak") {
            command = primePrefix + `flatpak run --command=gpu-screen-recorder --file-forwarding com.dec05eba.gpu_screen_recorder ${flags.join(" ")}`;
        } else {
            command = "echo GPU_SCREEN_RECORDER_NOT_INSTALLED";
        }

        recorderProcess.exec({
            "command": ["sh", "-c", command]
        });
    }

    function buildAudioFlags() {
        if (audioSource === "none")
            return [];
        if (audioSource === "both")
            return [`-ac ${audioCodec}`, `-a "default_output|default_input"`];
        return [`-ac ${audioCodec}`, `-a ${audioSource}`];
    }

    readonly property var codecResolutionLimits: ({
            "h264": "4096x4096"
        })

    function buildResolutionFlag() {
        if (resolution !== "original")
            return `-s ${resolution}`;

        var maxResolution = codecResolutionLimits[videoCodec];
        return maxResolution ? `-s ${maxResolution}` : "";
    }

    function buildOutputFilename() {
        const now = new Date();
        const timestamp = Qt.formatDateTime(now, "yyyy-MM-dd_HH-mm-ss");
        return `Video_${timestamp}.mp4`;
    }

    // Process to run and monitor gpu-screen-recorder
    Process {
        id: recorderProcess
        stdout: SplitParser {
            onRead: data => {
                var stdout = String(data || "").trim();
                if (stdout === "GPU_SCREEN_RECORDER_NOT_INSTALLED") {
                    ToastService.showError(pluginApi.tr("messages.not-installed"), pluginApi.tr("messages.not-installed-description"));
                } else if (isRecording && !isSavingReplay) {
                    isRecording = false;
                    recordingStart = null;
                    ToastService.showNotice(pluginApi.tr("messages.recording-saved"), stdout, "video", 3000, pluginApi.tr("messages.open-file"), () => openFile(stdout));
                    if (copyToClipboard)
                        copyFileToClipboard(stdout);
                } else if (replayNotifications && stdout.length > 0) {
                    isSavingReplay = false;
                    ToastService.showNotice(pluginApi.tr("messages.replay-saved"), stdout, "video", 3000, pluginApi.tr("messages.open-file"), () => openFile(stdout));
                    if (copyToClipboard)
                        copyFileToClipboard(stdout);
                }
            }
        }
        property string stderrAccumulator: ""
        stderr: SplitParser {
            onRead: data => {
                recorderProcess.stderrAccumulator += data + "\n";
                if (isRecording && data.includes("pipewire negotiation finished")) {
                    recordingStart = Date.now();
                    updateRecordingDuration();
                }
            }
        }
        onExited: function (exitCode, exitStatus) {
            const stderr = recorderProcess.stderrAccumulator.trim();
            const wasCancelled = stderr.includes("canceled by the user");

            if (exitCode === 0 && isRecording) {
                ToastService.showNotice(pluginApi.tr("messages.recording-saved"), outputPath, "video", 3000, pluginApi.tr("messages.open-file"), () => openFile(outputPath));
                if (copyToClipboard)
                    copyFileToClipboard(outputPath);
            } else if (!wasCancelled) {
                const filteredError = filterStderr(stderr);
                if (filteredError.length > 0) {
                    ToastService.showError(pluginApi.tr("messages.failed-start"), truncateForToast(filteredError));
                    Logger.e("ScreenRecorder", filteredError);
                } else if (exitCode !== 0) {
                    ToastService.showError(pluginApi.tr("messages.failed-start"), pluginApi.tr("messages.failed-general"));
                }
            }

            isRecording = false;
            isReplaying = false;
            isSavingReplay = false;
            recordingStart = null;
            recorderProcess.stderrAccumulator = "";
        }
    }

    // Pre-flight check for xdg-desktop-portal
    Process {
        id: portalCheckProcess
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                // Portals available, proceed to launch
                var backendDetectionScript = "if command -v gpu-screen-recorder >/dev/null 2>&1; then\n" + "    exit 0\n" + "fi\n" + "if command -v flatpak >/dev/null 2>&1 && flatpak list --app | grep -q 'com.dec05eba.gpu_screen_recorder'; then\n" + "    exit 1\n" + "fi\n" + "exit 2";
                backendCheckProcess.exec({
                    "command": ["sh", "-c", backendDetectionScript]
                });
            } else {
                isRecording = false;
                isReplaying = false;
                ToastService.showError(pluginApi.tr("messages.no-portals"), pluginApi.tr("messages.no-portals-description"));
            }
        }
    }

    Process {
        id: backendCheckProcess
        onExited: function (exitCode) {
            if (exitCode === 0) {
                backend = "native";
            } else if (exitCode === 1) {
                backend = "flatpak";
            } else {
                backend = "none";
            }

            launchRecorder();
        }
    }

    // Detect focused monitor on Hyprland
    Process {
        id: monitorDetectProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function (exitCode, exitStatus) {
            const output = String(monitorDetectProcess.stdout.text || "").trim();

            if (exitCode !== 0 || output === "MONITOR_NOT_FOUND" || !output) {
                isRecording = false;
                isReplaying = false;
                ToastService.showError(pluginApi.tr("messages.failed-start"), pluginApi.tr("messages.monitor-not-found"));
                return;
            }

            // Parse "MONITOR_NAME:USE_PRIME" format
            const parts = output.split(":");
            const monitorName = parts[0];
            const primeRun = parts.length > 1 && parts[1] === "1";

            Logger.i("ScreenRecorder", "Detected monitor: " + monitorName + (primeRun ? " (prime-run)" : ""));
            launchRecorderWithSource(monitorName, primeRun);
        }
    }

    Process {
        id: copyToClipboardProcess
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                Logger.e("ScreenRecorder", "Failed to copy file to clipboard, exit code:", exitCode);
            }
        }
    }

    Timer {
        id: killTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            if (!isRecording && !isReplaying)
                Quickshell.execDetached(["sh", "-c", "pkill -9 -f 'gpu-screen-recorder' 2>/dev/null || pkill -9 -f 'com.dec05eba.gpu_screen_recorder' 2>/dev/null || true"]);
        }
    }

    function openFile(path) {
        if (!path)
            return;
        Quickshell.execDetached(["xdg-open", path]);
    }

    function copyFileToClipboard(filePath) {
        if (!filePath)
            return;
        // Convert path to file:// URI format for copying as file reference
        const fileUri = "file://" + filePath.replace(/ /g, "%20").replace(/'/g, "%27").replace(/"/g, "%22");
        const escapedUri = fileUri.replace(/'/g, "'\\''");
        const command = "printf '%s' '" + escapedUri + "' | wl-copy --type text/uri-list";
        copyToClipboardProcess.exec({
            "command": ["sh", "-c", command]
        });
    }

    function truncateForToast(text, maxLength = 128) {
        if (text.length <= maxLength)
            return text;
        return text.substring(0, maxLength) + "…";
    }

    // Filter stderr to only include actual errors (starting with gsr error: or gsr fatal:)
    function filterStderr(text) {
        if (!text)
            return "";
        const lines = text.split("\n");
        const errorLines = lines.filter(line => {
            const lower = line.toLowerCase();
            if (lower.includes("gsr info:") || lower.includes("gsr notice:") || lower.includes("(error: none)"))
                return false;
            return lower.includes("gsr error:") || lower.includes("gsr fatal:") || lower.includes("failed to") || lower.includes("error:");
        });
        if (errorLines.length === 0)
            return "";
        return errorLines.join("\n").trim();
    }

    Timer {
        interval: 250
        running: recordingStart !== null && isRecording
        repeat: true
        triggeredOnStart: true
        onTriggered: updateRecordingDuration()
    }

    function updateRecordingDuration() {
        if (recordingStart === null)
            return;
        var elapsed = Math.floor((Date.now() - recordingStart) / 1000);
        var minutes = Math.floor(elapsed / 60);
        var seconds = elapsed % 60;
        recordingDuration = minutes + ":" + (seconds < 10 ? "0" + seconds : seconds);
    }
}
