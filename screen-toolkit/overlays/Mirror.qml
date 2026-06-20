import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI
import "../utils/utils.js" as U
Item {
    id: root
    property var  pluginApi: null
    property bool isVisible: false
    function show(screen) {
        if (screen) {
            var changed = screen !== _primaryScreen
            _primaryScreen = screen
            if (changed) { xPos = -1; yPos = -1 }
        } else if (_primaryScreen === null) {
            _primaryScreen = Quickshell.screens[0] ?? null
        }
        isVisible     = true
        _cameraActive = true
    }
    function hide() {
        isVisible      = false
        _cameraActive  = false
        _primaryScreen = null
        _cancelCountdown()
        if (_isRecording) _doStopRecord()
        pluginApi?.withCurrentScreen(screen => pluginApi?.closePanel(screen))
    }
    function toggle(screen) {
        if (!isVisible) show(screen)
        else            hide()
    }
    property bool   isSquare:      true
    property bool   isFlipped:     true
    property int    cameraIndex:   0
    property int    currentWidth:  300
    property int    currentHeight: 300
    property int    xPos: -1
    property int    yPos: -1
    property string scriptsDir:    ""
    property var    _primaryScreen:   null
    property bool   _cameraActive:    false
    property bool   _audioEnabled:    false
    property bool   _pinOnShot:       true
    property int    _countdown:        0
    property bool   _countdownActive:  false
    property string _pendingAction:    ""
    property bool   _isRecording:     false
    property bool   _isSaving:        false
    property int    _recElapsed:      0
    property string _recTmpPath:      ""
    readonly property int _ctrlBtnSize: Style.baseWidgetSize - Style.borderS
    readonly property int _ctrlPillH:   _ctrlBtnSize + Style.marginS * 2
    property var _imgCapture: null
    property var _recorder:   null
    function _formatTime(secs) {
        var m = Math.floor(secs / 60), s = secs % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
    function _startCountdown(action) {
        if (_countdownActive || _isRecording) return
        _pendingAction   = action
        _countdown       = 3
        _countdownActive = true
        countdownTimer.start()
    }
    function _cancelCountdown() {
        countdownTimer.stop()
        _countdownActive = false
        _countdown       = 0
        _pendingAction   = ""
    }
    function _fireAction() {
        _countdownActive = false
        _countdown       = 0
        if      (_pendingAction === "screenshot") _doScreenshot()
        else if (_pendingAction === "record")     _doStartRecord()
        _pendingAction = ""
    }
    Timer {
        id: countdownTimer
        interval: 1000; repeat: true
        onTriggered: {
            root._countdown--
            if (root._countdown <= 0) { stop(); root._fireAction() }
        }
    }
    function _doScreenshot() {
        if (!root._imgCapture) return
        root._imgCapture.captureToFile("/tmp/mirror-shot-" + Date.now() + ".png")
    }
    function _onImageCaptured(tmpPath) {
        var home    = Quickshell.env("HOME")
        var dir     = U.screenshotDir(home, pluginApi?.pluginSettings?.screenshotPath)
        var file    = U.buildFilename("mirror", ".png", pluginApi?.pluginSettings?.filenameFormat)
        var filters = []
        if (root.isFlipped) filters.push("hflip")
        if (root.isSquare)  filters.push("crop=min(iw\\,ih):min(iw\\,ih)")
        screenshotProc.destPath = dir + "/" + file
        screenshotProc.exec({ command: [
            "bash", scriptsDir + "mirror-screenshot.sh",
            tmpPath, dir, file, filters.join(",")
        ]})
    }
    Process {
        id: screenshotProc
        property string destPath: ""
        onExited: (code) => {
            if (code === 0) {
                if (root._pinOnShot) {
                    var mi = root.pluginApi?.mainInstance
                    if (mi && typeof mi.pinFile === "function")
                        mi.pinFile(destPath, root._primaryScreen)
                }
                ToastService.showNotice(
                    root.pluginApi?.tr("mirror.screenshotSaved"),
                    destPath, "camera")
            } else {
                ToastService.showError(root.pluginApi?.tr("mirror.screenshotFailed"))
            }
        }
    }
    function _doStartRecord() {
        if (!root._recorder) return
        var tmpPath = "/tmp/mirror-record-" + Date.now() + ".mp4"
        root._recTmpPath  = tmpPath
        root._recorder.outputLocation = "file://" + tmpPath
        root._isRecording = true
        root._isSaving    = false
        root._recElapsed  = 0
        elapsedRecTimer.start()
        root._recorder.record()
    }
    function _doStopRecord() {
        if (!root._isRecording) return
        root._isRecording = false
        root._isSaving    = true
        elapsedRecTimer.stop()
        if (root._recorder) root._recorder.stop()
    }
    function _doSaveRecord() {
        var home    = Quickshell.env("HOME")
        var dir     = U.videoDir(home, pluginApi?.pluginSettings?.videoPath)
        var file    = U.buildFilename("mirror", ".mp4", pluginApi?.pluginSettings?.filenameFormat)
        var filters = []
        if (root.isFlipped) filters.push("hflip")
        if (root.isSquare)  filters.push("crop=min(iw\\,ih):min(iw\\,ih)")
        recSaveProc.savedPath = dir + "/" + file
        recSaveProc.exec({ command: [
            "bash", scriptsDir + "mirror-record.sh",
            root._recTmpPath, dir, file, filters.join(","),
            root._audioEnabled ? "1" : "0"
        ]})
    }
    Process {
        id: recSaveProc
        property string savedPath: ""
        onExited: (code) => {
            root._isSaving   = false
            root._recElapsed = 0
            root._recTmpPath = ""
            if (code === 0)
                ToastService.showNotice(
                    root.pluginApi?.tr("mirror.recordSaved"),
                    recSaveProc.savedPath, "device-floppy")
            else
                ToastService.showError(root.pluginApi?.tr("mirror.recordFailed"))
        }
    }
    Timer {
        id: elapsedRecTimer
        interval: 1000; repeat: true
        onTriggered: root._recElapsed++
    }
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property ShellScreen modelData
            readonly property bool isPrimary: modelData === root._primaryScreen
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            visible: root.isVisible
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "noctalia-mirror"
            onVisibleChanged: {
                if (visible && isPrimary && root.xPos !== -1 && screen.width > 0) {
                    root.xPos = Math.max(0, Math.min(root.xPos, screen.width  - root.currentWidth))
                    root.yPos = Math.max(0, Math.min(root.yPos, screen.height - root.currentHeight))
                } else if (visible && isPrimary && root.xPos === -1 && screen.width > 0) {
                    root.xPos = screen.width  - root.currentWidth  - 24
                    root.yPos = Math.round((screen.height - root.currentHeight) / 2)
                }
            }
            readonly property bool isInteracting:
                isPrimary && (dragArea.pressed || resizeBR.pressed || resizeBL.pressed ||
                              resizeTR.pressed || resizeTL.pressed)
            Item { id: fullMask; anchors.fill: parent }
            mask: Region { item: !win.isPrimary ? null : (win.isInteracting ? fullMask : container) }
            MediaDevices { id: mediaDevices }
            Rectangle {
                id: container
                visible: win.isPrimary
                x: root.xPos;              y: root.yPos
                width:  root.currentWidth; height: root.currentHeight
                radius: Style.radiusL;     color: "black"; clip: true
                Loader {
                    id: cameraLoader
                    active: root._cameraActive && win.isPrimary
                    anchors.fill: parent
                    sourceComponent: Component {
                        Item {
                            anchors.fill: parent
                            Component.onCompleted: {
                                root._imgCapture = imgCap
                                root._recorder   = mediaRec
                            }
                            Component.onDestruction: {
                                if (root._imgCapture === imgCap)   root._imgCapture = null
                                if (root._recorder   === mediaRec) root._recorder   = null
                            }
                            CaptureSession {
                                id: session
                                camera: Camera {
                                    active: true
                                    cameraDevice: {
                                        var inputs = mediaDevices.videoInputs
                                        if (inputs.length === 0) return mediaDevices.defaultVideoInput
                                        return inputs[root.cameraIndex % Math.max(1, inputs.length)]
                                    }
                                }
                                audioInput: root._audioEnabled ? micIn : null
                                videoOutput: videoOut
                                imageCapture: ImageCapture {
                                    id: imgCap
                                    onImageSaved:    (id, path) => root._onImageCaptured(path)
                                    onErrorOccurred: (id, err, msg) =>
                                        ToastService.showError(root.pluginApi?.tr("mirror.screenshotFailed"))
                                }
                                recorder: MediaRecorder {
                                    id: mediaRec
                                    mediaFormat {
                                        fileFormat: MediaFormat.MPEG4
                                        videoCodec: MediaFormat.VideoCodec.H264
                                        audioCodec: MediaFormat.AudioCodec.AAC
                                    }
                                    videoBitRate: 8000000
                                    audioBitRate: 192000
                                    onRecorderStateChanged: {
                                        if (recorderState === MediaRecorder.StoppedState && root._isSaving)
                                            root._doSaveRecord()
                                    }
                                    onErrorOccurred: (error, errorString) => {
                                        root._isRecording = false
                                        root._isSaving    = false
                                        elapsedRecTimer.stop()
                                        root._recTmpPath  = ""
                                        root._recElapsed  = 0
                                        ToastService.showError(root.pluginApi?.tr("mirror.recordFailed"))
                                    }
                                }
                            }
                            AudioInput { id: micIn }
                            VideoOutput {
                                id: videoOut
                                anchors.fill: parent
                                fillMode: VideoOutput.PreserveAspectCrop
                                transform: Scale {
                                    origin.x: videoOut.width / 2
                                    xScale: root.isFlipped ? -1 : 1
                                }
                            }
                        }
                    }
                }
                Column {
                    anchors.centerIn: parent; spacing: Style.marginS
                    visible: mediaDevices.videoInputs.length === 0
                    NIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "video-off"; color: "white" }
                    NText { anchors.horizontalCenter: parent.horizontalCenter
                            text: root.pluginApi?.tr("mirror.noCamera"); color: "white"; pointSize: Style.fontSizeXS }
                }
                Rectangle {
                    anchors.fill: parent; radius: Style.radiusL
                    color: "transparent"; border.color: "#FF4444"; border.width: Style.borderL
                    visible: root._isRecording
                    SequentialAnimation on opacity {
                        running: root._isRecording; loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }
                Rectangle {
                    visible: root._isRecording
                    anchors { top: parent.top; left: parent.left; margins: Style.marginXS * 2 }
                    width: recBadge.implicitWidth + Style.marginM; height: Style.marginXL + Style.marginXXS; radius: Style.radiusS
                    color: Qt.rgba(0, 0, 0, 0.65); z: 5
                    Row {
                        id: recBadge
                        anchors.centerIn: parent; spacing: Style.marginXS
                        Rectangle {
                            width: Style.marginXS * 2; height: Style.marginXS * 2; radius: Style.radiusXXS; color: "#FF4444"
                            anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity {
                                running: root._isRecording; loops: Animation.Infinite
                                NumberAnimation { to: 0.15; duration: 600 }
                                NumberAnimation { to: 1.0;  duration: 600 }
                            }
                        }
                        NText {
                            text: root.pluginApi?.tr("mirror.recordingInProgress", { time: root._formatTime(root._recElapsed) })
                            color: "white"; font.weight: Font.Bold; pointSize: Style.fontSizeXS
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                Rectangle {
                    visible: root._isSaving
                    anchors { top: parent.top; left: parent.left; margins: Style.marginXS * 2 }
                    width: savingBadge.implicitWidth + Style.marginM; height: Style.marginXL + Style.marginXXS; radius: Style.radiusS
                    color: Qt.rgba(0, 0, 0, 0.65); z: 5
                    Row {
                        id: savingBadge
                        anchors.centerIn: parent; spacing: Style.marginXS
                        NIcon {
                            icon: "device-floppy"; color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity {
                                running: root._isSaving; loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }
                        NText {
                            text: root.pluginApi?.tr("mirror.saving")
                            color: "white"; pointSize: Style.fontSizeXS
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent; radius: Style.radiusL
                    color: Qt.rgba(0, 0, 0, 0.55); visible: root._countdownActive; z: 10
                    NText {
                        anchors.centerIn: parent
                        text: root._countdown > 0 ? root._countdown.toString() : ""
                        color: "white"
                        font.pixelSize: Math.min(container.width, container.height) * 0.45
                        font.weight: Font.Bold; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.6)
                        SequentialAnimation on scale {
                            running: root._countdownActive; loops: Animation.Infinite
                            NumberAnimation { from: 1.2; to: 0.85; duration: 900; easing.type: Easing.InQuad }
                            NumberAnimation { from: 0.85; to: 1.2;  duration: 100 }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root._cancelCountdown()
                    }
                }
                HoverHandler { id: containerHover }
                MouseArea {
                    id: dragArea
                    anchors.fill: parent; hoverEnabled: true
                    enabled: !root._isRecording
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point startPoint: Qt.point(0, 0)
                    property int startX: 0; property int startY: 0
                    onPressed: mouse => {
                        startPoint = mapToItem(null, mouse.x, mouse.y)
                        startX = root.xPos; startY = root.yPos
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        var p = mapToItem(null, mouse.x, mouse.y)
                        root.xPos = Math.max(0, Math.min(win.screen.width  - root.currentWidth,  startX + (p.x - startPoint.x)))
                        root.yPos = Math.max(0, Math.min(win.screen.height - root.currentHeight, startY + (p.y - startPoint.y)))
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: Style.marginM
                    width:  ctrlRow.implicitWidth + Style.marginM * 2
                    height: root._ctrlPillH; radius: root._ctrlPillH / 2
                    color:  Qt.rgba(0, 0, 0, 0.55); z: 3
                    opacity: (containerHover.hovered && !root._countdownActive && !root._isSaving) ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Row {
                        id: ctrlRow
                        anchors.centerIn: parent; spacing: Style.marginS
                        Rectangle {
                            width: root._ctrlBtnSize; height: root._ctrlBtnSize; radius: root._ctrlBtnSize / 2
                            visible: !root._isRecording
                            color: sqHover.containsMouse ? Qt.rgba(1,1,1,0.2) : "transparent"
                            NIcon { anchors.centerIn: parent; icon: root.isSquare ? "arrows-maximize" : "crop"; color: "white" }
                            MouseArea {
                                id: sqHover
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: {
                                    root.isSquare = !root.isSquare
                                    root.currentHeight = root.isSquare
                                        ? root.currentWidth
                                        : Math.max(100, Math.round(root.currentWidth * 9 / 16))
                                    root.xPos = Math.max(0, Math.min(win.screen.width  - root.currentWidth,  root.xPos))
                                    root.yPos = Math.max(0, Math.min(win.screen.height - root.currentHeight, root.yPos))
                                }
                                onEntered: TooltipService.show(parent, root.isSquare
                                    ? root.pluginApi?.tr("tooltips.switchToWide")
                                    : root.pluginApi?.tr("tooltips.switchToSquare"))
                                onExited: TooltipService.hide()
                            }
                        }
                        Rectangle {
                            width: root._ctrlBtnSize; height: root._ctrlBtnSize; radius: root._ctrlBtnSize / 2
                            visible: !root._isRecording
                            color: root.isFlipped ? Qt.rgba(1,1,1,0.25) : (flipHover.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent")
                            NIcon { anchors.centerIn: parent; icon: "flip-horizontal"; color: "white" }
                            MouseArea {
                                id: flipHover
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: root.isFlipped = !root.isFlipped
                                onEntered: TooltipService.show(parent, root.isFlipped
                                    ? root.pluginApi?.tr("tooltips.unflipCamera")
                                    : root.pluginApi?.tr("tooltips.flipCamera"))
                                onExited: TooltipService.hide()
                            }
                        }
                        Rectangle {
                            width: root._ctrlBtnSize; height: root._ctrlBtnSize; radius: root._ctrlBtnSize / 2
                            color: shotHover.containsMouse ? Qt.rgba(1,1,1,0.25) : "transparent"
                            NIcon { anchors.centerIn: parent; icon: "camera"; color: "white" }
                            MouseArea {
                                id: shotHover
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: {
                                    if (root._isRecording) root._doScreenshot()
                                    else root._startCountdown("screenshot")
                                }
                                onEntered: TooltipService.show(parent, root.pluginApi?.tr("mirror.takeScreenshot"))
                                onExited:  TooltipService.hide()
                            }
                        }
                        Rectangle {
                            width: root._ctrlBtnSize; height: root._ctrlBtnSize; radius: root._ctrlBtnSize / 2
                            color: recHover.containsMouse
                                ? (root._isRecording ? Qt.rgba(1,0,0,0.55) : Qt.rgba(1,1,1,0.25))
                                : (root._isRecording ? Qt.rgba(1,0,0,0.30) : "transparent")
                            Behavior on color { ColorAnimation { duration: 120 } }
                            NIcon {
                                anchors.centerIn: parent
                                icon:  root._isRecording ? "square" : "video"
                                color: root._isRecording ? "#FF4444" : "white"
                            }
                            MouseArea {
                                id: recHover
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: {
                                    if (root._isRecording) root._doStopRecord()
                                    else root._startCountdown("record")
                                }
                                onEntered: TooltipService.show(parent, root._isRecording
                                    ? root.pluginApi?.tr("mirror.stopRecord")
                                    : root.pluginApi?.tr("mirror.startRecord"))
                                onExited: TooltipService.hide()
                            }
                        }
                        Rectangle {
                            width: root._ctrlBtnSize; height: root._ctrlBtnSize; radius: root._ctrlBtnSize / 2
                            color: root._audioEnabled
                                ? Qt.rgba(1,1,1,0.25)
                                : (micHover.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent")
                            opacity: root._isRecording ? 0.4 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            NIcon {
                                anchors.centerIn: parent
                                icon:  root._audioEnabled ? "microphone" : "microphone-off"
                                color: root._audioEnabled ? "white" : Qt.rgba(1,1,1,0.45)
                            }
                            MouseArea {
                                id: micHover
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                enabled: !root._isRecording
                                onClicked: root._audioEnabled = !root._audioEnabled
                                onEntered: TooltipService.show(parent, root._audioEnabled
                                    ? root.pluginApi?.tr("mirror.micDisable")
                                    : root.pluginApi?.tr("mirror.micEnable"))
                                onExited: TooltipService.hide()
                            }
                        }
                        Rectangle {
                            width: root._ctrlBtnSize; height: root._ctrlBtnSize; radius: root._ctrlBtnSize / 2
                            visible: !root._isRecording
                            color: root._pinOnShot ? Qt.rgba(1,1,1,0.25) : (pinToggleMA.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent")
                            NIcon { anchors.centerIn: parent; icon: root._pinOnShot ? "pin" : "pinned-off"; color: "white" }
                            MouseArea {
                                id: pinToggleMA
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: root._pinOnShot = !root._pinOnShot
                                onEntered: TooltipService.show(parent, root._pinOnShot
                                    ? root.pluginApi?.tr("mirror.pinDisable")
                                    : root.pluginApi?.tr("mirror.pinEnable"))
                                onExited: TooltipService.hide()
                            }
                        }
                        Rectangle {
                            width: root._ctrlBtnSize; height: root._ctrlBtnSize; radius: root._ctrlBtnSize / 2
                            visible: mediaDevices.videoInputs.length > 1 && !root._isRecording
                            color: camHover.containsMouse ? Qt.rgba(1,1,1,0.2) : "transparent"
                            NIcon { anchors.centerIn: parent; icon: "camera-rotate"; color: "white" }
                            MouseArea {
                                id: camHover
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: root.cameraIndex = (root.cameraIndex + 1) % mediaDevices.videoInputs.length
                                onEntered: TooltipService.show(parent, root.pluginApi?.tr("tooltips.switchCamera"))
                                onExited:  TooltipService.hide()
                            }
                        }
                        Rectangle {
                            width: root._ctrlBtnSize; height: root._ctrlBtnSize; radius: root._ctrlBtnSize / 2
                            visible: !root._isRecording
                            color: closeHover.containsMouse ? Qt.rgba(1,1,1,0.2) : "transparent"
                            NIcon { anchors.centerIn: parent; icon: "x"; color: "white" }
                            MouseArea {
                                id: closeHover
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.hide()
                                onEntered: TooltipService.show(parent, root.pluginApi?.tr("mirror.close"))
                                onExited:  TooltipService.hide()
                            }
                        }
                    }
                }
                component ResizeHandle: MouseArea {
                    property int mode: 0
                    width: 24; height: 24; hoverEnabled: true; preventStealing: true
                    enabled: !root._isRecording
                    cursorShape: (mode === 0 || mode === 3) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                    z: 4
                    property point startPt: Qt.point(0, 0)
                    property int startW: 0; property int startH: 0
                    property int startX: 0; property int startY: 0
                    onPressed: mouse => {
                        startPt = mapToItem(null, mouse.x, mouse.y)
                        startW  = root.currentWidth;  startH = root.currentHeight
                        startX  = root.xPos;          startY = root.yPos
                        mouse.accepted = true
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        var p  = mapToItem(null, mouse.x, mouse.y)
                        var dx = p.x - startPt.x
                        var nw = startW, nx = startX, ny = startY
                        if (mode === 0 || mode === 2) nw = Math.max(150, startW + dx)
                        else { nw = Math.max(150, startW - dx); nx = startX + (startW - nw) }
                        var nh = root.isSquare ? nw : Math.round(nw * 9 / 16)
                        nh = Math.max(100, nh)
                        if (mode === 2 || mode === 3) ny = startY + (startH - nh)
                        root.currentWidth  = nw; root.currentHeight = nh
                        root.xPos = Math.max(0, nx); root.yPos = Math.max(0, ny)
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: Style.marginXS * 2; height: Style.marginXS * 2; radius: Style.radiusXXS
                        color: Color.mPrimary
                        opacity: parent.containsMouse || parent.pressed ? 1.0 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }
                ResizeHandle { id: resizeBR; mode: 0; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.bottomMargin: -4; anchors.rightMargin: -4 }
                ResizeHandle { id: resizeBL; mode: 1; anchors.bottom: parent.bottom; anchors.left:  parent.left;  anchors.bottomMargin: -4; anchors.leftMargin:  -4 }
                ResizeHandle { id: resizeTR; mode: 2; anchors.top:    parent.top;    anchors.right: parent.right; anchors.topMargin:    -4; anchors.rightMargin: -4 }
                ResizeHandle { id: resizeTL; mode: 3; anchors.top:    parent.top;    anchors.left:  parent.left;  anchors.topMargin:    -4; anchors.leftMargin:  -4 }
            }
        }
    }
}
