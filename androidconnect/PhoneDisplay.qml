import Qt5Compat.GraphicalEffects
import QtMultimedia
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons

Rectangle {
    id: phoneRoot

    property bool showStatusOverlay: false
    property string statusTitle: ""
    property string statusSubtitle: ""
    property bool busy: false
    property bool mirrorFeedEnabled: false
    property bool showHomeIndicator: true
    property bool interactiveScreen: false
    property string mirrorDeviceIdMatch: ""
    property string mirrorDeviceDescriptionMatch: ""
    property int mirrorContentWidth: 0
    property int mirrorContentHeight: 0
    property string mirrorFeedError: ""
    property bool mediaDevicesReloadPending: false
    property int mediaDevicesReloadDelayMs: 80
    property bool mirrorFeedAttachDelayActive: false
    property bool nativeProbeReady: false
    property bool nativeProbePending: false
    property bool nativeCameraRebindPending: false
    property bool nativeZeroRectObserved: false
    property bool nativeZeroRectRecoveryScheduled: false
    property int nativeProbeRetryCount: 0
    property double nativeAttachStartedAtMs: 0
    property int nativeAttachRecoveryAttempts: 0
    property double mirrorFeedLastFrameAtMs: 0
    property bool mirrorFeedFrameLive: false
    property int mirrorFeedFrameCount: 0
    property bool mirrorFirstFrameLogged: false
    property double scrcpyStartedAtMs: 0
    property bool lastObservedFrameLive: false
    property var debugLogQueue: []
    property string debugAppendLine: ""
    readonly property string debugLogPath: "/tmp/androidconnect-preview-debug.log"
    readonly property real deviceArtWidth: 597
    readonly property real deviceArtHeight: 1241
    readonly property rect deviceArtCropRect: Qt.rect(586, 27, 597, 1241)
    readonly property real screenInsetLeftRatio: 25 / deviceArtWidth
    readonly property real screenInsetRightRatio: 34 / deviceArtWidth
    readonly property real screenInsetTopRatio: 26 / deviceArtHeight
    readonly property real screenInsetBottomRatio: 25 / deviceArtHeight
    readonly property real scaleFactor: Math.min(width / deviceArtWidth, height / deviceArtHeight)
    readonly property real frameShadowRadius: 34 * phoneRoot.scaleFactor
    readonly property real statusCardRadius: 14 * phoneRoot.scaleFactor
    readonly property real statusCardMargin: 10 * phoneRoot.scaleFactor
    readonly property real statusCardSpacing: 6 * phoneRoot.scaleFactor
    readonly property real contentAspectRatio: {
        if (mirrorContentWidth > 0 && mirrorContentHeight > 0)
            return mirrorContentWidth / mirrorContentHeight;

        return screen.width / Math.max(1, screen.height);
    }
    readonly property real videoFrameWidth: Math.min(screen.width, screen.height * contentAspectRatio)
    readonly property real videoFrameHeight: Math.min(screen.height, screen.width / Math.max(0.001, contentAspectRatio))
    readonly property real videoFrameLocalX: phoneRect.x + screen.x + videoFrame.x
    readonly property real videoFrameLocalY: phoneRect.y + screen.y + videoFrame.y
    readonly property real videoFrameGlobalX: phoneRoot.mapToGlobal(videoFrameLocalX, videoFrameLocalY).x
    readonly property real videoFrameGlobalY: phoneRoot.mapToGlobal(videoFrameLocalX, videoFrameLocalY).y
    readonly property real videoFrameGlobalWidth: videoFrame.width
    readonly property real videoFrameGlobalHeight: videoFrame.height
    readonly property real screenRadius: 44.3 * phoneRoot.scaleFactor
    readonly property real videoFrameRadius: 52 * phoneRoot.scaleFactor
    readonly property color frameShadowColor: Qt.alpha(Color.mOutline, 0.26)
    readonly property color screenIdleBaseColor: Qt.alpha(Color.mSurface, 0.94)
    readonly property color screenIdleTopColor: Qt.alpha(Color.mSurfaceVariant, 0.96)
    readonly property color screenIdleMidColor: Qt.alpha(Color.mSurface, 0.92)
    readonly property color screenIdleBottomColor: Qt.alpha(Color.mPrimaryContainer, 0.52)
    readonly property color overlayFadeTopColor: Qt.alpha(Color.mSurface, 0.08)
    readonly property color overlayFadeMidColor: Qt.alpha(Color.mSurface, 0.32)
    readonly property color overlayFadeBottomColor: Qt.alpha(Color.mSurface, 0.58)
    readonly property color overlayCardColor: Qt.alpha(Color.mSurfaceVariant, 0.9)
    readonly property color overlayCardBorderColor: Qt.alpha(Color.mOutline, 0.34)
    readonly property color overlayTitleColor: Color.mOnSurface
    readonly property color overlaySubtitleColor: Color.mOnSurfaceVariant
    readonly property color homeIndicatorColor: Qt.alpha(Color.mOnSurface, 0.66)
    readonly property string normalizedIdMatch: (mirrorDeviceIdMatch || "").trim().toLowerCase()
    readonly property string normalizedDescriptionMatch: (mirrorDeviceDescriptionMatch || "").trim().toLowerCase()
    readonly property string trimmedMirrorDevicePath: String(mirrorDeviceIdMatch || "").trim()
    readonly property var mediaDevicesRef: mediaDevicesLoader.item
    readonly property var mediaVideoInputs: (mediaDevicesRef && mediaDevicesRef.videoInputs) ? mediaDevicesRef.videoInputs : []
    readonly property string availableVideoInputsSummary: videoInputsSummary(mediaVideoInputs)
    readonly property var selectedVideoInput: {
        const inputs = mediaVideoInputs || [];
        return findMatchingVideoInput(inputs, normalizedDescriptionMatch, "description", true)
            || findMatchingVideoInput(inputs, normalizedIdMatch, "id", true)
            || findMatchingVideoInput(inputs, normalizedDescriptionMatch, "description", false)
            || findMatchingVideoInput(inputs, normalizedIdMatch, "id", false)
            || (normalizedDescriptionMatch !== "" ? findScrcpyVideoInput(inputs) : undefined)
            || defaultVideoInput(inputs);
    }
    readonly property string selectedVideoInputSummary: videoInputSummary(selectedVideoInput)
    readonly property bool mirrorFeedAvailable: hasVideoInput(selectedVideoInput)
    readonly property bool shouldActivateMirrorCamera: mirrorFeedEnabled
        && mirrorFeedAvailable
        && nativeProbeReady
        && !nativeCameraRebindPending
        && !mirrorFeedAttachDelayActive
    readonly property bool mirrorFeedHasRenderedFrame: mirrorFeedFrameCount > 0
    readonly property bool mirrorFeedHasSourceRect: {
        const rect = mirrorVideoOutput ? mirrorVideoOutput.sourceRect : null;
        return Boolean(rect) && Number(rect.width || 0) > 0 && Number(rect.height || 0) > 0;
    }
    readonly property bool mirrorDisplayVisible: shouldActivateMirrorCamera
        && mirrorFeedError === ""
        && (mirrorFeedFrameLive || mirrorFeedHasRenderedFrame || mirrorFeedHasSourceRect)
    readonly property string activeSourceRectSummary: {
        const rect = mirrorVideoOutput ? mirrorVideoOutput.sourceRect : null;
        const width = rect ? Math.round(Number(rect.width || 0)) : 0;
        const height = rect ? Math.round(Number(rect.height || 0)) : 0;
        return width > 0 && height > 0 ? (width + "x" + height) : "0x0";
    }

    signal clicked()
    signal tapRequested(real x, real y)
    signal swipeRequested(real x1, real y1, real x2, real y2, int durationMs)
    signal scrollRequested(real x, real y, real deltaX, real deltaY)
    signal textRequested(string text)
    signal keyRequested(int keyCode)
    signal homeRequested()
    signal recentsRequested()

    function hasVideoInput(input) {
        return input !== undefined && input !== null && !input.isNull;
    }

    function videoInputSummary(input) {
        if (!hasVideoInput(input))
            return "none";

        const description = String(input.description || "").trim();
        const id = String(input.id || "").trim();
        if (description !== "" && id !== "")
            return description + " [" + id + "]";

        return description !== "" ? description : id;
    }

    function videoInputsSummary(inputs) {
        const list = inputs || [];
        if (!list.length)
            return "none";

        const parts = [];
        for (let i = 0; i < list.length; ++i)
            parts.push(videoInputSummary(list[i]));

        return parts.join(", ");
    }

    function findMatchingVideoInput(inputs, needle, fieldName, exact) {
        if (needle === "")
            return undefined;

        for (let i = 0; i < inputs.length; ++i) {
            const device = inputs[i];
            const fieldValue = normalizeText(device ? device[fieldName] : "");
            if ((exact && fieldValue === needle) || (!exact && fieldValue.indexOf(needle) !== -1))
                return device;
        }

        return undefined;
    }

    function findScrcpyVideoInput(inputs) {
        for (let i = 0; i < inputs.length; ++i) {
            const device = inputs[i];
            const description = normalizeText(device ? device.description : "");
            const id = normalizeText(device ? device.id : "");
            if (description.indexOf("scrcpy") !== -1 || id.indexOf("scrcpy") !== -1 || description.indexOf("loopback") !== -1)
                return device;
        }

        return undefined;
    }

    function defaultVideoInput(inputs) {
        if (normalizedIdMatch !== "" || normalizedDescriptionMatch !== "")
            return undefined;

        if (inputs.length === 1)
            return inputs[0];

        const defaultInput = mediaDevicesRef ? mediaDevicesRef.defaultVideoInput : null;
        return hasVideoInput(defaultInput) ? defaultInput : undefined;
    }

    function normalizeText(value) {
        return String(value || "").trim().toLowerCase();
    }

    function shellQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\"'\"'") + "'";
    }

    function msSinceScrcpy() {
        const startedAt = Number(scrcpyStartedAtMs || 0);
        if (startedAt <= 0)
            return -1;

        return Math.max(0, Math.round(Date.now() - startedAt));
    }

    function msSinceAttach() {
        const attachedAt = Number(nativeAttachStartedAtMs || 0);
        if (attachedAt <= 0)
            return -1;

        return Math.max(0, Math.round(Date.now() - attachedAt));
    }

    function timingSuffix() {
        return " tSinceScrcpy=" + msSinceScrcpy() + " tSinceAttach=" + msSinceAttach();
    }

    function debugLog(message) {
        const timestamp = new Date().toISOString();
        const line = timestamp + " " + String(message || "");
        Logger.i("AndroidConnectPreview", line);
        const queue = Array.isArray(debugLogQueue) ? debugLogQueue.slice() : [];
        queue.push(line);
        debugLogQueue = queue;
        flushDebugLogQueue();
    }

    function flushDebugLogQueue() {
        if (debugAppendProc.running)
            return;

        const queue = Array.isArray(debugLogQueue) ? debugLogQueue.slice() : [];
        if (queue.length === 0)
            return;

        debugAppendLine = String(queue.shift() || "");
        debugLogQueue = queue;
        debugAppendProc.running = true;
    }

    function normalizeMirrorError(message) {
        const text = String(message || "").trim();
        if (text.indexOf("Device or resource busy") !== -1 || text.indexOf("Camera is in use") !== -1)
            return "Loopback device is busy. Recreate v4l2loopback with exclusive_caps=0 so scrcpy can write and the panel can read it.";

        return text;
    }

    function noteMirrorFrameDelivered() {
        mirrorFeedLastFrameAtMs = Date.now();
        mirrorFeedFrameLive = true;
        mirrorFeedFrameCount += 1;
        if (!mirrorFirstFrameLogged) {
            mirrorFirstFrameLogged = true;
            nativeZeroRectObserved = activeSourceRectSummary === "0x0";
            debugLog("first frame sourceRect=" + activeSourceRectSummary + timingSuffix());
            if (nativeZeroRectObserved
                    && shouldActivateMirrorCamera
                    && !nativeZeroRectRecoveryScheduled
                    && nativeAttachRecoveryAttempts === 0) {
                nativeZeroRectRecoveryScheduled = true;
                nativeZeroRectRecoveryTimer.restart();
            }
        }
    }

    function beginNativeAttachWindow(reason) {
        if (!mirrorFeedEnabled)
            return;

        nativeAttachStartedAtMs = Date.now();
        mirrorFeedAttachDelayActive = true;
        mirrorFeedAttachDelayTimer.restart();
        debugLog("attach begin reason=" + String(reason || "unspecified")
            + " selectedInput=" + selectedVideoInputSummary
            + timingSuffix());
    }

    function scheduleNativeCameraRebind(reason) {
        if (!mirrorFeedEnabled || !mirrorFeedAvailable || nativeCameraRebindPending)
            return;

        nativeCameraRebindPending = true;
        nativeZeroRectRecoveryScheduled = false;
        resetMirrorState();
        debugLog("rebind reason=" + String(reason || "unspecified") + timingSuffix());
        nativeCameraRebindTimer.restart();
    }

    function resetMirrorState() {
        mirrorFeedError = "";
        mirrorFeedLastFrameAtMs = 0;
        mirrorFeedFrameLive = false;
        mirrorFeedFrameCount = 0;
        mirrorFirstFrameLogged = false;
        nativeZeroRectObserved = false;
    }

    function reloadMediaDevices(delayMs) {
        if (mediaDevicesReloadPending)
            return;

        mediaDevicesReloadDelayMs = Math.max(80, Math.round(Number(delayMs || 0)) || 80);
        mediaDevicesReloadPending = true;
        mediaDevicesLoader.active = false;
        mediaDevicesReloadCommitTimer.interval = mediaDevicesReloadDelayMs;
        mediaDevicesReloadCommitTimer.restart();
    }

    function probeNativeLoopback() {
        if (!mirrorFeedEnabled)
            return;

        nativeProbePending = true;
        nativeProbeRetryCount = 0;
        nativeAttachRecoveryAttempts = 0;
        nativeAttachStartedAtMs = 0;
        resetMirrorState();
        reloadMediaDevices(80);
        nativeProbeRetryTimer.interval = 120;
        nativeProbeRetryTimer.restart();
    }

    height: parent ? parent.height : 235
    width: parent ? parent.width : (height / deviceArtHeight) * deviceArtWidth
    radius: 0
    color: "transparent"
    border.width: 0
    border.color: "transparent"
    clip: false

    Component.onCompleted: {
        debugResetProc.running = true;
    }

    onMirrorFeedEnabledChanged: {
        mediaDevicesReloadPending = false;
        mediaDevicesReloadDelayMs = 80;
        mediaDevicesLoader.active = false;
        nativeProbeReady = false;
        nativeProbePending = false;
        nativeCameraRebindPending = false;
        nativeZeroRectObserved = false;
        nativeZeroRectRecoveryScheduled = false;
        nativeProbeRetryCount = 0;
        nativeAttachStartedAtMs = 0;
        nativeAttachRecoveryAttempts = 0;
        mirrorFeedAttachDelayActive = mirrorFeedEnabled;
        lastObservedFrameLive = false;
        resetMirrorState();
        debugLog("mirrorFeedEnabled=" + mirrorFeedEnabled
            + " devicePath=" + trimmedMirrorDevicePath
            + timingSuffix());
        if (mirrorFeedEnabled) {
            mirrorFeedAttachDelayTimer.restart();
        } else {
            mirrorFeedAttachDelayTimer.stop();
        }
    }

    onSelectedVideoInputSummaryChanged: {
        if (mirrorFeedEnabled)
            debugLog("selectedInput=" + selectedVideoInputSummary
                + " available=" + mirrorFeedAvailable
                + timingSuffix());
    }

    onMirrorFeedAvailableChanged: {
        if (!mirrorFeedEnabled)
            return;

        resetMirrorState();
        if (mirrorFeedAvailable) {
            if (nativeProbePending || !nativeProbeReady) {
                nativeProbePending = false;
                nativeProbeReady = true;
                nativeProbeRetryCount = 0;
                beginNativeAttachWindow("video-input-ready");
            }
            return;
        }

        nativeProbeReady = false;
        if (nativeProbePending && nativeProbeRetryCount < 6) {
            nativeProbeRetryCount += 1;
            nativeProbeRetryTimer.interval = nativeProbeRetryCount <= 2 ? 100 : 180;
            nativeProbeRetryTimer.restart();
        }
    }

    onMirrorFeedErrorChanged: {
        if (mirrorFeedEnabled && String(mirrorFeedError || "").trim() !== "")
            debugLog("mirrorFeedError=" + String(mirrorFeedError || "") + timingSuffix());
    }

    onMirrorFeedFrameLiveChanged: {
        if (lastObservedFrameLive && !mirrorFeedFrameLive) {
            const lastDelta = mirrorFeedLastFrameAtMs > 0
                ? Math.round(Date.now() - mirrorFeedLastFrameAtMs)
                : -1;
            debugLog("frameLive=false count=" + mirrorFeedFrameCount
                + " dt=" + lastDelta
                + timingSuffix());
        }
        lastObservedFrameLive = mirrorFeedFrameLive;
    }

    Loader {
        id: mediaDevicesLoader

        active: false
        sourceComponent: mediaDevicesComponent
    }

    Component {
        id: mediaDevicesComponent

        MediaDevices {
        }
    }

    Timer {
        id: mediaDevicesReloadCommitTimer

        interval: 80
        repeat: false
        onTriggered: {
            mediaDevicesLoader.active = true;
            phoneRoot.mediaDevicesReloadPending = false;
        }
    }

    Timer {
        id: mirrorFeedAttachDelayTimer

        interval: 100
        repeat: false
        onTriggered: {
            phoneRoot.mirrorFeedAttachDelayActive = false;
        }
    }

    Timer {
        id: nativeCameraRebindTimer

        interval: 200
        repeat: false
        onTriggered: {
            phoneRoot.nativeCameraRebindPending = false;
            if (!phoneRoot.mirrorFeedEnabled || !phoneRoot.mirrorFeedAvailable)
                return;

            phoneRoot.beginNativeAttachWindow("camera-rebind");
        }
    }

    Timer {
        id: nativeZeroRectRecoveryTimer

        interval: 200
        repeat: false
        onTriggered: {
            if (!phoneRoot.shouldActivateMirrorCamera
                    || !phoneRoot.nativeZeroRectObserved
                    || phoneRoot.mirrorFeedHasSourceRect
                    || phoneRoot.nativeAttachRecoveryAttempts > 0) {
                phoneRoot.nativeZeroRectRecoveryScheduled = false;
                return;
            }

            phoneRoot.nativeAttachRecoveryAttempts = 1;
            phoneRoot.scheduleNativeCameraRebind("zero-source-rect");
        }
    }

    Timer {
        id: mediaDevicesRetryTimer

        interval: 1200
        repeat: true
        running: phoneRoot.mirrorFeedEnabled
            && (phoneRoot.nativeProbePending || phoneRoot.nativeProbeReady)
            && !phoneRoot.mirrorFeedAvailable
            && !phoneRoot.mediaDevicesReloadPending
        onTriggered: {
            phoneRoot.reloadMediaDevices(120);
        }
    }

    Timer {
        id: nativeProbeRetryTimer

        interval: 120
        repeat: false
        onTriggered: {
            if (!phoneRoot.mirrorFeedEnabled
                    || !phoneRoot.nativeProbePending
                    || phoneRoot.mirrorFeedAvailable
                    || phoneRoot.mediaDevicesReloadPending)
                return;

            phoneRoot.reloadMediaDevices(phoneRoot.nativeProbeRetryCount <= 2 ? 100 : 180);
        }
    }

    Timer {
        id: mirrorFeedFrameWatchdog

        interval: 450
        repeat: true
        running: phoneRoot.mirrorFeedEnabled
        onTriggered: {
            if (!phoneRoot.shouldActivateMirrorCamera) {
                phoneRoot.mirrorFeedFrameLive = false;
                return;
            }

            const lastFrameAt = Number(phoneRoot.mirrorFeedLastFrameAtMs || 0);
            phoneRoot.mirrorFeedFrameLive = lastFrameAt > 0 && (Date.now() - lastFrameAt) <= 1200;
        }
    }

    Timer {
        id: nativeAttachRecoveryTimer

        interval: 700
        repeat: true
        running: phoneRoot.mirrorFeedEnabled
        onTriggered: {
            if (!phoneRoot.shouldActivateMirrorCamera
                    || phoneRoot.mirrorFeedError !== ""
                    || phoneRoot.mirrorFeedHasSourceRect
                    || phoneRoot.nativeAttachStartedAtMs <= 0)
                return;

            const attachAgeMs = Date.now() - phoneRoot.nativeAttachStartedAtMs;
            const recoveryDelayMs = phoneRoot.nativeZeroRectObserved ? 900 : 1400;
            if (attachAgeMs < recoveryDelayMs || phoneRoot.nativeAttachRecoveryAttempts >= 2)
                return;

            phoneRoot.nativeAttachRecoveryAttempts += 1;
            phoneRoot.debugLog("attach recovery attempt=" + phoneRoot.nativeAttachRecoveryAttempts
                + " sourceRect=" + phoneRoot.activeSourceRectSummary
                + " attachAgeMs=" + Math.round(attachAgeMs)
                + phoneRoot.timingSuffix());

            if (phoneRoot.nativeAttachRecoveryAttempts === 1) {
                phoneRoot.scheduleNativeCameraRebind("stalled-first-frame");
                return;
            }

            phoneRoot.nativeProbePending = true;
            phoneRoot.nativeProbeRetryCount = 0;
            phoneRoot.beginNativeAttachWindow("stalled-first-frame");
            phoneRoot.reloadMediaDevices(120);
            nativeProbeRetryTimer.interval = 120;
            nativeProbeRetryTimer.restart();
        }
    }

    CaptureSession {
        id: mirrorCaptureSession

        camera: phoneRoot.shouldActivateMirrorCamera ? mirrorCamera : null
        videoOutput: phoneRoot.shouldActivateMirrorCamera ? mirrorVideoOutput.videoSink : null
    }

    Camera {
        id: mirrorCamera

        active: phoneRoot.shouldActivateMirrorCamera
        onActiveChanged: {
            phoneRoot.debugLog("camera active=" + active + phoneRoot.timingSuffix());
            if (active) {
                phoneRoot.resetMirrorState();
            } else {
                phoneRoot.mirrorFeedFrameLive = false;
            }
        }
        onCameraDeviceChanged: {
            phoneRoot.resetMirrorState();
        }
        onErrorOccurred: (error, errorString) => {
            phoneRoot.mirrorFeedFrameLive = false;
            phoneRoot.mirrorFeedError = phoneRoot.normalizeMirrorError(errorString !== "" ? errorString : ("camera error " + error));
            phoneRoot.debugLog("camera error code=" + error
                + " string=" + String(errorString || "")
                + " normalized=" + phoneRoot.mirrorFeedError
                + phoneRoot.timingSuffix());
        }
    }

    Binding {
        target: mirrorCamera
        property: "cameraDevice"
        when: phoneRoot.shouldActivateMirrorCamera
            && phoneRoot.hasVideoInput(phoneRoot.selectedVideoInput)
        value: phoneRoot.selectedVideoInput
    }

    Binding {
        target: mirrorCamera
        property: "cameraDevice"
        when: !phoneRoot.shouldActivateMirrorCamera
        value: null
    }

    Process {
        id: debugResetProc

        running: false
        command: ["sh", "-lc",
            "log=" + phoneRoot.shellQuote(phoneRoot.debugLogPath) + "; "
            + ": > \"$log\"; "
            + "{ "
            + "printf '=== AndroidConnect preview debug session ===\\n'; "
            + "printf 'banner time=%s pid=%s\\n' \"$(date -Iseconds 2>/dev/null)\" \"$$\"; "
            + "if command -v v4l2-ctl >/dev/null 2>&1; then "
            + "  v4l2-ctl --list-devices 2>&1 | sed 's/^/banner   /'; "
            + "  if [ -r /sys/module/v4l2loopback/parameters/exclusive_caps ]; then "
            + "    printf 'banner v4l2loopback.exclusive_caps=%s\\n' \"$(cat /sys/module/v4l2loopback/parameters/exclusive_caps)\"; "
            + "  fi; "
            + "fi; "
            + "} >> \"$log\" 2>&1"
        ]

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: {
            phoneRoot.debugLog("ready devicePath=" + trimmedMirrorDevicePath
                + " descriptionMatch=" + String(mirrorDeviceDescriptionMatch || ""));
        }
    }

    Process {
        id: debugAppendProc

        running: false
        command: ["sh", "-lc",
            "line=" + phoneRoot.shellQuote(phoneRoot.debugAppendLine)
            + "; printf '%s\\n' \"$line\" >> " + phoneRoot.shellQuote(phoneRoot.debugLogPath)
        ]

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: phoneRoot.flushDebugLogQueue()
    }

    RectangularShadow {
        anchors.fill: phoneRect
        radius: phoneRoot.frameShadowRadius
        blur: 24
        spread: 0.08
        color: phoneRoot.frameShadowColor
    }

    Item {
        id: phoneRect

        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: !phoneRoot.interactiveScreen
            onClicked: phoneRoot.clicked()
        }

        Image {
            id: phoneFrameImage

            anchors.fill: parent
            source: "Celu.png"
            sourceClipRect: phoneRoot.deviceArtCropRect
            fillMode: Image.Stretch
            smooth: true
            mipmap: true
        }

        Rectangle {
            id: screen

            radius: phoneRoot.screenRadius
            color: phoneRoot.screenIdleBaseColor
            antialiasing: true
            clip: true
            layer.enabled: !phoneRoot.mirrorDisplayVisible

            anchors {
                fill: parent
                leftMargin: phoneRect.width * phoneRoot.screenInsetLeftRatio
                rightMargin: phoneRect.width * phoneRoot.screenInsetRightRatio
                topMargin: phoneRect.height * phoneRoot.screenInsetTopRatio
                bottomMargin: phoneRect.height * phoneRoot.screenInsetBottomRatio
            }

            Rectangle {
                anchors.fill: parent
                opacity: phoneRoot.mirrorDisplayVisible ? 0 : 1

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: phoneRoot.screenIdleTopColor
                    }

                    GradientStop {
                        position: 0.55
                        color: phoneRoot.screenIdleMidColor
                    }

                    GradientStop {
                        position: 1
                        color: phoneRoot.screenIdleBottomColor
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                id: videoFrame

                anchors.centerIn: parent
                width: phoneRoot.videoFrameWidth
                height: phoneRoot.videoFrameHeight
                radius: phoneRoot.videoFrameRadius
                color: "transparent"
                antialiasing: true
                visible: phoneRoot.mirrorFeedEnabled
                clip: true
                layer.enabled: videoFrame.visible && mirrorVideoReveal.visible

                Rectangle {
                    id: videoFrameBed

                    anchors.fill: parent
                    color: phoneRoot.screenIdleBaseColor
                    opacity: mirrorVideoReveal.opacity

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Item {
                    id: mirrorVideoReveal

                    anchors.fill: parent
                    visible: phoneRoot.shouldActivateMirrorCamera || opacity > 0.001
                    opacity: phoneRoot.mirrorDisplayVisible ? 1 : 0
                    scale: phoneRoot.mirrorDisplayVisible ? 1 : 0.9875
                    y: phoneRoot.mirrorDisplayVisible ? 0 : (8 * phoneRoot.scaleFactor)
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }

                    VideoOutput {
                        id: mirrorVideoOutput

                        anchors.fill: parent
                        visible: phoneRoot.shouldActivateMirrorCamera || parent.opacity > 0.001
                        fillMode: VideoOutput.Stretch
                        onSourceRectChanged: {
                            const isZero = sourceRect.width <= 0 || sourceRect.height <= 0;
                            if (!isZero) {
                                phoneRoot.nativeAttachStartedAtMs = 0;
                                phoneRoot.nativeZeroRectRecoveryScheduled = false;
                                phoneRoot.debugLog("sourceRect=" + phoneRoot.activeSourceRectSummary + phoneRoot.timingSuffix());
                            } else if (phoneRoot.shouldActivateMirrorCamera
                                    && phoneRoot.nativeZeroRectObserved
                                    && !phoneRoot.nativeZeroRectRecoveryScheduled
                                    && phoneRoot.nativeAttachRecoveryAttempts === 0) {
                                phoneRoot.nativeZeroRectRecoveryScheduled = true;
                                nativeZeroRectRecoveryTimer.restart();
                            }
                        }
                    }
                }

                Connections {
                    function onVideoFrameChanged(frame) {
                        phoneRoot.noteMirrorFrameDelivered();
                    }

                    target: mirrorVideoOutput.videoSink
                    enabled: target !== null && target !== undefined
                }

                MouseArea {
                    id: touchSurface

                    property real startXNorm: 0
                    property real startYNorm: 0
                    property real endXNorm: 0
                    property real endYNorm: 0
                    property real startLocalX: 0
                    property real startLocalY: 0
                    property real wheelXNorm: 0.5
                    property real wheelYNorm: 0.5
                    property real wheelAccumX: 0
                    property real wheelAccumY: 0
                    property bool moved: false
                    property double pressTimestamp: 0
                    property int activeButton: Qt.NoButton

                    function clampNorm(value, maxValue) {
                        if (maxValue <= 0)
                            return 0;

                        return Math.max(0, Math.min(1, value / maxValue));
                    }

                    function forwardSpecialKey(key) {
                        switch (key) {
                        case Qt.Key_Backspace:
                            phoneRoot.keyRequested(67);
                            return true;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            phoneRoot.keyRequested(66);
                            return true;
                        case Qt.Key_Tab:
                            phoneRoot.keyRequested(61);
                            return true;
                        case Qt.Key_Delete:
                            phoneRoot.keyRequested(112);
                            return true;
                        case Qt.Key_Home:
                            phoneRoot.homeRequested();
                            return true;
                        case Qt.Key_Escape:
                            phoneRoot.keyRequested(111);
                            return true;
                        case Qt.Key_Left:
                            phoneRoot.keyRequested(21);
                            return true;
                        case Qt.Key_Right:
                            phoneRoot.keyRequested(22);
                            return true;
                        case Qt.Key_Up:
                            phoneRoot.keyRequested(19);
                            return true;
                        case Qt.Key_Down:
                            phoneRoot.keyRequested(20);
                            return true;
                        default:
                            return false;
                        }
                    }

                    anchors.fill: parent
                    enabled: phoneRoot.interactiveScreen
                    hoverEnabled: true
                    activeFocusOnTab: phoneRoot.interactiveScreen
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: (event) => {
                        if (!phoneRoot.interactiveScreen)
                            return;

                        let handled = forwardSpecialKey(event.key);
                        const hasCommandModifier = (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0;
                        if (!handled && !hasCommandModifier) {
                            const text = String(event.text || "");
                            if (text !== "" && text >= " ") {
                                phoneRoot.textRequested(text);
                                handled = true;
                            }
                        }
                        if (handled)
                            event.accepted = true;
                    }
                    onPressed: (mouse) => {
                        touchSurface.forceActiveFocus();
                        activeButton = mouse.button;
                        if (mouse.button === Qt.RightButton) {
                            phoneRoot.keyRequested(4);
                            return;
                        }
                        if (mouse.button === Qt.MiddleButton) {
                            phoneRoot.recentsRequested();
                            return;
                        }
                        startLocalX = mouse.x;
                        startLocalY = mouse.y;
                        startXNorm = clampNorm(mouse.x, width);
                        startYNorm = clampNorm(mouse.y, height);
                        endXNorm = startXNorm;
                        endYNorm = startYNorm;
                        moved = false;
                        pressTimestamp = Date.now();
                    }
                    onPositionChanged: (mouse) => {
                        if (activeButton !== Qt.LeftButton || !(mouse.buttons & Qt.LeftButton))
                            return;

                        endXNorm = clampNorm(mouse.x, width);
                        endYNorm = clampNorm(mouse.y, height);
                        if (!moved)
                            moved = Math.abs(mouse.x - startLocalX) > 8 || Math.abs(mouse.y - startLocalY) > 8;
                    }
                    onReleased: (mouse) => {
                        if (activeButton !== Qt.LeftButton) {
                            activeButton = Qt.NoButton;
                            return;
                        }
                        const releaseXNorm = clampNorm(mouse.x, width);
                        const releaseYNorm = clampNorm(mouse.y, height);
                        const durationMs = Math.max(80, Math.min(1200, Math.round(Date.now() - pressTimestamp)));
                        if (moved)
                            phoneRoot.swipeRequested(startXNorm, startYNorm, releaseXNorm, releaseYNorm, durationMs);
                        else
                            phoneRoot.tapRequested(releaseXNorm, releaseYNorm);
                        activeButton = Qt.NoButton;
                    }
                    onCanceled: {
                        activeButton = Qt.NoButton;
                    }
                    onWheel: (wheel) => {
                        if (!phoneRoot.interactiveScreen)
                            return;

                        const rawDeltaX = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x / 24 : wheel.angleDelta.x / 120;
                        const rawDeltaY = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y / 24 : wheel.angleDelta.y / 120;
                        if (rawDeltaX === 0 && rawDeltaY === 0)
                            return;

                        wheelXNorm = clampNorm(wheel.x, width);
                        wheelYNorm = clampNorm(wheel.y, height);
                        wheelAccumX += rawDeltaX;
                        wheelAccumY += rawDeltaY;
                        wheelDispatchTimer.restart();
                        wheel.accepted = true;
                    }

                    Timer {
                        id: wheelDispatchTimer

                        interval: 40
                        repeat: false
                        onTriggered: {
                            if (touchSurface.wheelAccumX === 0 && touchSurface.wheelAccumY === 0)
                                return;

                            phoneRoot.scrollRequested(touchSurface.wheelXNorm, touchSurface.wheelYNorm, touchSurface.wheelAccumX, touchSurface.wheelAccumY);
                            touchSurface.wheelAccumX = 0;
                            touchSurface.wheelAccumY = 0;
                        }
                    }
                }

                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: videoFrame.width
                        height: videoFrame.height
                        radius: videoFrame.radius
                        antialiasing: true
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                visible: phoneRoot.showStatusOverlay && (phoneRoot.statusTitle !== "" || phoneRoot.statusSubtitle !== "" || phoneRoot.busy)
                opacity: visible ? 1 : 0

                MouseArea {
                    anchors.fill: parent
                    enabled: visible && !phoneRoot.interactiveScreen && !phoneRoot.busy
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: phoneRoot.clicked()
                }

                Rectangle {
                    anchors.fill: parent

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: phoneRoot.overlayFadeTopColor
                        }

                        GradientStop {
                            position: 0.55
                            color: phoneRoot.overlayFadeMidColor
                        }

                        GradientStop {
                            position: 1
                            color: phoneRoot.overlayFadeBottomColor
                        }
                    }
                }

                Rectangle {
                    id: statusCard

                    anchors.centerIn: parent
                    width: parent.width - (22 * phoneRoot.scaleFactor)
                    implicitHeight: statusContent.implicitHeight + (20 * phoneRoot.scaleFactor)
                    radius: phoneRoot.statusCardRadius
                    color: phoneRoot.overlayCardColor
                    border.width: Math.max(1, Math.round(1 * phoneRoot.scaleFactor))
                    border.color: phoneRoot.overlayCardBorderColor

                    ColumnLayout {
                        id: statusContent

                        anchors.fill: parent
                        anchors.margins: phoneRoot.statusCardMargin
                        spacing: phoneRoot.statusCardSpacing

                        BusyIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            running: phoneRoot.busy
                            visible: phoneRoot.busy
                            implicitWidth: 18 * phoneRoot.scaleFactor
                            implicitHeight: 18 * phoneRoot.scaleFactor
                        }

                        Text {
                            visible: phoneRoot.statusTitle !== ""
                            text: phoneRoot.statusTitle
                            color: phoneRoot.overlayTitleColor
                            textFormat: Text.PlainText
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            font.pixelSize: Math.max(11, Math.round(18 * phoneRoot.scaleFactor))
                            font.weight: Font.DemiBold
                            lineHeight: 1.08
                            lineHeightMode: Text.ProportionalHeight
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: phoneRoot.statusSubtitle !== ""
                            text: phoneRoot.statusSubtitle
                            color: phoneRoot.overlaySubtitleColor
                            textFormat: Text.PlainText
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            font.pixelSize: Math.max(10, Math.round(14 * phoneRoot.scaleFactor))
                            lineHeight: 1.14
                            lineHeightMode: Text.ProportionalHeight
                            maximumLineCount: 5
                            elide: Text.ElideRight
                            Layout.topMargin: phoneRoot.statusTitle !== "" ? 4 * phoneRoot.scaleFactor : 0
                            Layout.fillWidth: true
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }

            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: screen.width
                    height: screen.height
                    radius: screen.radius
                    antialiasing: true
                }
            }
        }

        Rectangle {
            width: 183 * phoneRoot.scaleFactor
            height: 4.8 * phoneRoot.scaleFactor
            radius: height / 2
            color: phoneRoot.homeIndicatorColor
            opacity: 0.66
            visible: phoneRoot.showHomeIndicator

            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 35 * phoneRoot.scaleFactor
            }
        }
    }
}
