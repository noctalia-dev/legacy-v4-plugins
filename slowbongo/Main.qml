import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Media
import qs.Services.UI

Item {
    id: root

    // === EXTERNAL API ===
    property var pluginApi: null

    // === CORE STATE ===
    property int catState: 0  // 0 = idle (both paws up), 1 = left slap, 2 = right slap, 3 = both slap
    property bool leftWasLast: false  // Track which paw slapped last to alternate
    property bool paused: false
    property bool waiting: false
    property bool blinking: false
    property int pendingCatState: 0  // State to transition to after reset delay

    // === INSTANCE IDENTIFICATION ===
    readonly property string spectrumInstanceId: "plugin:slowbongo:" + Date.now() + Math.random()

    // === INPUT DEVICES (from settings) ===
    readonly property var inputDevices: {
        const saved = pluginApi?.pluginSettings?.inputDevices;
        if (saved && saved.length > 0) return saved;
        return [];
    }

    onPluginApiChanged: {
        if (pluginApi) {
            SpectrumService.registerComponent(spectrumInstanceId);
            Logger.i("SlowBongo", "Registered with SpectrumService for audio detection");
        }
    }

    Component.onDestruction: SpectrumService.unregisterComponent(spectrumInstanceId)

    // === IPC CONTROL ===
    IpcHandler {
        target: "plugin:slowbongo"

        function pause() {
            root.paused = true
        }

        function resume() {
            root.paused = false
        }

        function toggle() {
            root.paused = !root.paused
        }
    }

    // === SETTINGS ===
    readonly property int idleTimeout: pluginApi?.pluginSettings?.idleTimeout ?? 250
    readonly property int waitingTimeout: pluginApi?.pluginSettings?.waitingTimeout ?? 5000
    readonly property string catColor: pluginApi?.pluginSettings?.catColor ?? "default"
    readonly property real catSize: pluginApi?.pluginSettings?.catSize ?? 1.0
    readonly property real catOffsetY: pluginApi?.pluginSettings?.catOffsetY ?? 0.0
    readonly property bool raveMode: pluginApi?.pluginSettings?.raveMode ?? false
    readonly property bool tappyMode: pluginApi?.pluginSettings?.tappyMode ?? false
    readonly property bool useMprisFilter: pluginApi?.pluginSettings?.useMprisFilter ?? false

    // === AUDIO REACTIVE STATE ===
    readonly property bool anyMusicPlaying: !SpectrumService.isIdle
    property int rainbowIndex: 0
    readonly property var rainbowColors: ['#aa0000', '#b65c02', '#bb9c14', '#00a100', '#01019b', '#37005c', '#6a0196']
    property real audioIntensity: 0
    property real smoothedIntensity: 0
    property real previousIntensity: 0
    property real bassIntensity: 0
    readonly property real beatThreshold: 0.07
    readonly property real bigBeatThreshold: 0.67
    readonly property real beatDeltaThreshold: 0.014  // Minimum sudden increase to count as beat
    property bool isFlashing: false

    // === COMPUTED MODE FLAGS ===
    readonly property bool mprisAllowed: !useMprisFilter || MediaService.isPlaying
    readonly property bool useTappyMode: tappyMode && anyMusicPlaying && mprisAllowed
    readonly property string currentRainbowColor: rainbowColors[rainbowIndex]
    readonly property bool useRaveColors: raveMode && anyMusicPlaying && mprisAllowed
    readonly property bool showRainbowColor: useRaveColors && isFlashing

    // === AUDIO REACTIVE CONNECTIONS ===
    Connections {
        target: SpectrumService
        function onValuesChanged() {
            if (root.paused) return;
            if (!root.useRaveColors && !root.useTappyMode) return;

            if (!SpectrumService.values || SpectrumService.values.length === 0) {
                root.audioIntensity = 0;
                return;
            }

            const subBassCount = Math.min(4, SpectrumService.values.length);
            const bassCount = Math.min(8, SpectrumService.values.length);
            const midCount = Math.min(16, SpectrumService.values.length);

            let subBassSum = 0;
            for (let i = 0; i < subBassCount; i++) {
                subBassSum += SpectrumService.values[i] || 0;
            }

            let bassSum = 0;
            for (let i = 0; i < bassCount; i++) {
                bassSum += SpectrumService.values[i] || 0;
            }

            let midSum = 0;
            for (let i = 8; i < midCount; i++) {
                midSum += SpectrumService.values[i] || 0;
            }

            const subBassAvg = subBassSum / subBassCount;
            const bassAvg = bassSum / bassCount;
            const midAvg = midSum / Math.max(1, midCount - 8);

            root.bassIntensity = subBassAvg;
            root.audioIntensity = (bassAvg * 0.8) + (midAvg * 0.6);

            const alpha = 0.75;
            root.previousIntensity = root.smoothedIntensity;
            root.smoothedIntensity = alpha * root.audioIntensity + (1 - alpha) * root.smoothedIntensity;

            const intensityDelta = root.smoothedIntensity - root.previousIntensity;
            const isBeat = (intensityDelta > root.beatDeltaThreshold && root.smoothedIntensity > root.beatThreshold * 0.5)
                        || (root.smoothedIntensity > root.beatThreshold && intensityDelta > 0);

            if (isBeat && !beatCooldownTimer.running) {
                if (root.useRaveColors) {
                    root.rainbowIndex = (root.rainbowIndex + 1) % root.rainbowColors.length;
                    root.isFlashing = true;
                    flashTimer.restart();
                }

                if (root.useTappyMode) {
                    root.musicEvent(root.bassIntensity > root.bigBeatThreshold);
                }

                beatCooldownTimer.restart();
            }
        }
    }

    // === TIMERS ===
    Timer {
        id: beatCooldownTimer
        interval: 70
        repeat: false
    }

    Timer {
        id: flashTimer
        interval: 100
        repeat: false
        onTriggered: root.isFlashing = false
    }

    Timer {
        id: stateResetTimer
        interval: 40
        repeat: false
        onTriggered: root.catState = root.pendingCatState
    }

    // === MUSIC HANDLER ===
    function musicEvent(isBigHit = false) {
        if (root.paused) return;
        root.waiting = false;

        let targetState;
        if (isBigHit) {
            targetState = 3;
        } else {
            root.leftWasLast = !root.leftWasLast;
            targetState = root.leftWasLast ? 1 : 2;
        }

        const needsReset = root.catState !== 0 && ((isBigHit && root.catState !== 3) || (!isBigHit && root.catState === 3));

        if (needsReset) {
            root.catState = 0;
            root.pendingCatState = targetState;
            stateResetTimer.restart();
        } else {
            root.catState = targetState;
        }

        idleTimer.restart();
        waitingTimer.restart();
    }

    // === KEY PRESS HANDLER ===
    function onKeyPress(isBigHit = false) {
        if (root.paused) return;
        root.waiting = false;

        let targetState;
        if (isBigHit) {
            targetState = 3;
        } else {
            if (root.catState !== 0){
                targetState = 3;
            } else {
                root.leftWasLast = !root.leftWasLast;
                targetState = root.leftWasLast ? 1 : 2;
            }
        }

        root.catState = targetState;
        waitingTimer.restart();
    }

    function onKeyRelease(isBigHit = false) {
        if (root.paused) return;
        root.waiting = false;

        let targetState;
        if (isBigHit) {
            targetState = 0;
        } else {
            if (root.catState === 3){
                targetState = root.leftWasLast ? 1 : 2;
            } else {
                targetState = 0;
            }
        }

        root.catState = targetState;
        waitingTimer.restart();
    }

    function onKeyRepeat(isBigHit = false){
        if (root.paused) return;
        root.waiting = false;

        let targetState;
        if (root.catState !== 0) {
            targetState = root.catState;
        } else {
            if (isBigHit){
                targetState = 3;
            } else {
                targetState = root.leftWasLast ? 1 : 2;
            }
        }

        root.catState = targetState;
        waitingTimer.restart();
    }

    // === STATE CHANGE HANDLERS ===
    onPausedChanged: {
        if (root.paused) {
            idleTimer.stop();
            waitingTimer.stop();
            root.waiting = false;
            root.blinking = false;
            root.catState = 0;
        } else {
            waitingTimer.restart();
        }
    }

    onWaitingChanged: {
        if (root.waiting) {
            root.blinking = false;
        }
    }

    // === IDLE & WAITING TIMERS ===
    Timer {
        id: idleTimer
        interval: root.idleTimeout
        repeat: false
        onTriggered: root.catState = 0
    }

    Timer {
        id: waitingTimer
        interval: root.waitingTimeout
        repeat: false
        onTriggered: root.waiting = true
    }

    // === BLINK ANIMATION ===
    Timer {
        id: blinkIntervalTimer
        interval: 6000 + Math.random() * 8000
        repeat: true
        running: !root.paused && !root.waiting
        onTriggered: {
            interval = 6000 + Math.random() * 8000;
            if (Math.random() < 0.5) {
                root.blinking = true;
                blinkDurationTimer.start();
            } else {
                root.blinkFlutterCount = 0;
                root.blinking = true;
                flutterTimer.start();
            }
        }
    }

    property int blinkFlutterCount: 0

    Timer {
        id: blinkDurationTimer
        interval: 450
        repeat: false
        onTriggered: root.blinking = false
    }

    Timer {
        id: flutterTimer
        interval: 120
        repeat: false
        onTriggered: {
            root.blinkFlutterCount++;
            root.blinking = !root.blinking;
            if (root.blinkFlutterCount < 4) {
                flutterTimer.start();
            } else {
                root.blinking = false;
            }
        }
    }

    // === INPUT DEVICE MONITORING ===
    Repeater {
        model: root.inputDevices

        Item {
            id: deviceMonitor
            required property string modelData

            property int retryCount: 0
            property bool hasNotified: false
            readonly property var retryIntervals: [30000, 90000, 300000] // 30s, 1:30, 5min

            Process {
                id: evtestProc
                command: ["evtest", deviceMonitor.modelData]
                running: true

                stdout: SplitParser {
                    onRead: data => {
                        if (data.includes("EV_KEY")) {
                            // Detect spacebar/enter for double slap (both paws)
                            const isBigHit = data.includes("KEY_SPACE") || data.includes("KEY_ENTER");
                            // Key pressed
                            // Ignore BTN_TOOL_ events to avoid double events with touchpads
                            if (data.includes("value 1") && !data.includes("BTN_TOOL_")){
                                root.onKeyPress(isBigHit);
                            // Key released
                            } else if (data.includes("value 0")) {
                                root.onKeyRelease(isBigHit);
                            // Key repeat
                            } else if (data.includes("value 2")) {
                                root.onKeyRepeat(isBigHit);
                            }
                        }
                    }
                }

                stderr: StdioCollector {}

                onRunningChanged: {
                    if (running) {
                        deviceMonitor.retryCount = 0;
                        deviceMonitor.hasNotified = false;
                    }
                }

                onExited: exitCode => {
                    Logger.w("Slow Bongo", "evtest (" + deviceMonitor.modelData + ") exited with code " + exitCode);

                    if (exitCode !== 0) {
                        deviceMonitor.retryCount++;

                        if (!deviceMonitor.hasNotified) {
                            ToastService.showWarning(
                                root.pluginApi?.tr("toast.evtest-error") ?? "SlowBongo",
                                root.pluginApi?.tr("toast.device-disconnected") ?? ("Device disconnected: " + deviceMonitor.modelData)
                            );
                            deviceMonitor.hasNotified = true;
                        }

                        if (deviceMonitor.retryCount <= deviceMonitor.retryIntervals.length) {
                            const interval = deviceMonitor.retryIntervals[deviceMonitor.retryCount - 1];
                            Logger.i("Slow Bongo", "Will retry in " + Math.floor(interval / 1000) + "s (attempt " + deviceMonitor.retryCount + "/" + deviceMonitor.retryIntervals.length + ")");
                            restartTimer.interval = interval;
                            restartTimer.start();
                        } else {
                            Logger.w("Slow Bongo", "Max retries reached for device: " + deviceMonitor.modelData + ". Giving up.");
                            ToastService.showInfo(
                                root.pluginApi?.tr("toast.device-gave-up") ?? "SlowBongo",
                                root.pluginApi?.tr("toast.device-gave-up-desc") ?? ("Stopped trying to reconnect to: " + deviceMonitor.modelData)
                            );
                        }
                    } else {
                        restartTimer.interval = deviceMonitor.retryIntervals[0];
                        restartTimer.start();
                    }
                }
            }

            Timer {
                id: restartTimer
                repeat: false
                onTriggered: deviceCheckProc.running = true
            }

            Process {
                id: deviceCheckProc
                command: ["test", "-e", deviceMonitor.modelData]
                running: false

                onExited: exitCode => {
                    if (exitCode === 0) {
                        Logger.i("Slow Bongo", "Device detected, restarting monitoring: " + deviceMonitor.modelData);
                        evtestProc.running = true;
                    } else if (deviceMonitor.retryCount < deviceMonitor.retryIntervals.length) {
                        deviceMonitor.retryCount++;;
                        const interval = deviceMonitor.retryIntervals[deviceMonitor.retryCount - 1];
                        Logger.i("Slow Bongo", "Device " + deviceMonitor.modelData + " not found, will retry in " + Math.floor(interval / 1000) + "s (attempt " + deviceMonitor.retryCount + "/" + deviceMonitor.retryIntervals.length + ")");
                        restartTimer.interval = interval;
                        restartTimer.start();
                    } else {
                        Logger.w("Slow Bongo", "Max retries reached for device: " + deviceMonitor.modelData + ". Giving up.");
                    }
                }
            }
        }
    }
}
