import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI
import "../utils/utils.js" as U
Item {
    id: root
    property var pluginApi: null
    property string region:  ""
    property string mp4Path: ""
    property string gifPath: ""
    property int regionX: 0
    property int regionY: 0
    property int regionW: 400
    property int regionH: 300
    property int uiX: 0
    property int uiY: 0
    property var _primaryScreen: null
    property int _elapsed:    0
    property int _frameToken: 0
    property string format:        "gif"
    property bool   audioOutput:   false
    property bool   audioInput:    false
    property bool   includeCursor: false
    property string _recorderBin:  "wl-screenrec"
    readonly property int gifMaxSeconds: pluginApi?.pluginSettings?.gifMaxSeconds ?? 30
    readonly property string _scriptPath: {
        var url = Qt.resolvedUrl("../scripts/record.sh").toString()
        return url.startsWith("file://") ? url.slice(7) : url
    }
    property string recordState: ""
    readonly property bool isRecording:  recordState === "recording"
    readonly property bool isConverting: recordState === "converting"
    readonly property bool isDone:       recordState === "done"
    signal dismissed()
    function startRecording(regionStr, fmt, audOut, audIn, cursor, uiOffsetX, uiOffsetY, screen) {
        if (root.isRecording || root.isConverting) return
        root.format        = (fmt === "mp4") ? "mp4" : "gif"
        root.audioOutput   = audOut  === true
        root.audioInput    = audIn   === true
        root.includeCursor = cursor  === true
        var parts = regionStr.trim().split(" ")
        if (parts.length >= 2) {
            var xy = parts[0].split(",")
            var wh = parts[1].split("x")
            root.regionX = parseInt(xy[0]) || 0
            root.regionY = parseInt(xy[1]) || 0
            root.regionW = parseInt(wh[0]) || 400
            root.regionH = parseInt(wh[1]) || 300
        }
        root.uiX = uiOffsetX || 0
        root.uiY = uiOffsetY || 0
        root._primaryScreen = screen ?? Quickshell.screens[0] ?? null
        root._recorderBin = (pluginApi?.mainInstance?.detectedRecorder === "wf-recorder")
                            ? "wf-recorder" : "wl-screenrec"
        root.region      = regionStr
        root.mp4Path     = "/tmp/screen-toolkit-record-" + Date.now() + ".mp4"
        root.gifPath     = ""
        root.recordState = "recording"
        root._elapsed    = 0
        root._frameToken = 0
        elapsedTimer.start()
        var cmd
        if (root._recorderBin === "wf-recorder") {
            cmd = "wf-recorder -g " + U.shellEscape(regionStr) +
                  (root.audioOutput
                      ? " -a=$(pactl get-default-sink 2>/dev/null).monitor"
                      : root.audioInput
                          ? " -a=$(pactl get-default-source 2>/dev/null)"
                          : "") +
                  " -f " + U.shellEscape(root.mp4Path) + " 2>/dev/null" +
                  "; [ -s " + U.shellEscape(root.mp4Path) + " ] && exit 0 || exit 1"
        } else {
            cmd = "wl-screenrec -g " + U.shellEscape(regionStr) +
                  (root.includeCursor ? "" : " --no-cursor") +
                  (root.audioOutput
                      ? " --audio --audio-device $(pactl get-default-sink 2>/dev/null).monitor"
                      : root.audioInput
                          ? " --audio --audio-device $(pactl get-default-source 2>/dev/null)"
                          : "") +
                  " -f " + U.shellEscape(root.mp4Path) + " 2>/dev/null" +
                  "; [ -s " + U.shellEscape(root.mp4Path) + " ] && exit 0 || exit 1"
        }
        wfRecorderProc.exec({ command: ["bash", "-c", cmd] })
    }
    function stopRecording() {
        if (!root.isRecording) return
        stopProc.exec({ command: ["bash", root._scriptPath, "stop", root._recorderBin] })
    }
    function dismiss() {
        if (root.isRecording) root.stopRecording()
        var toClipboard = root.pluginApi?.pluginSettings?.recordCopyToClipboard ?? false
        if (root.gifPath !== "" && !toClipboard)
            stopProc.exec({ command: ["bash", "-c", "rm -f " + U.shellEscape(root.gifPath)] })
        root.recordState    = ""
        root.gifPath        = ""
        root._primaryScreen = null
        root.dismissed()
    }
    function _handleDone() {
        var skipConfirm = root.pluginApi?.pluginSettings?.recordSkipConfirmation ?? false
        var toClipboard = root.pluginApi?.pluginSettings?.recordCopyToClipboard  ?? false
        if (skipConfirm) {
            _saveToFile()
        } else if (toClipboard) {
            _copyPathToClipboard(root.gifPath)
            ToastService.showNotice(root.pluginApi?.tr("record.copiedToClipboard"))
            root.dismiss()
        } else {
            root.recordState = "done"
        }
    }
    function _copyPathToClipboard(path) {
        var cmd = "printf 'file://%s\\r\\n' " + U.shellEscape(path) +
                  " | wl-copy --type text/uri-list"
        clipProc.exec({ command: ["bash", "-c", cmd] })
    }
    function _saveToFile() {
        var ext  = root.format === "mp4" ? ".mp4" : ".gif"
        var home = Quickshell.env("HOME")
        var dir  = U.videoDir(home, pluginApi?.pluginSettings?.videoPath)
        var dest = dir + "/" + U.buildFilename("record", ext, pluginApi?.pluginSettings?.filenameFormat)
        saveProc.savedPath = dest
        saveProc.exec({ command: ["bash", "-c",
            "mkdir -p " + U.shellEscape(dir) + " && " +
            "cp " + U.shellEscape(root.gifPath) + " " + U.shellEscape(dest)
        ]})
    }
    function formatTime(secs) {
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
    Process {
        id: wfRecorderProc
        onExited: (code) => {
            elapsedTimer.stop()
            var isCleanExit = (code === 0 || code === 130 || code === 2) ||
                              (root._recorderBin === "wf-recorder" && code === 1)
            if (isCleanExit) {
                root.recordState = "converting"
                var tmpTs    = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")
                var optimOut = "/tmp/screen-toolkit-record-" + tmpTs
                if (root.format === "mp4") {
                    root.gifPath = optimOut + ".mp4"
                    var needsRecode = root.audioOutput || root.audioInput
                    gifConvertProc.exec({ command: needsRecode
                        ? ["bash", root._scriptPath, "convert-mp4", root.mp4Path, root.gifPath, "--recode"]
                        : ["bash", root._scriptPath, "convert-mp4", root.mp4Path, root.gifPath]
                    })
                } else {
                    root.gifPath = optimOut + ".gif"
                    gifConvertProc.exec({ command:
                        ["bash", root._scriptPath, "convert-gif", root.mp4Path, root.gifPath]
                    })
                }
            } else {
                root.dismiss()
                ToastService.showError(root.pluginApi?.tr("record.failed"))
            }
        }
    }
    Process { id: stopProc }
    Process { id: clipProc }
    Process {
        id: gifConvertProc
        onExited: (code) => {
            root.recordState = ""
            if (code === 0) {
                root._frameToken++
                _handleDone()
            } else {
                root.dismiss()
                ToastService.showError(root.format === "mp4"
                    ? root.pluginApi?.tr("record.saveMp4Failed")
                    : root.pluginApi?.tr("record.saveGifFailed"))
            }
        }
    }
    Process {
        id: saveProc
        property string savedPath: ""
        onExited: (code) => {
            if (code === 0) {
                var toClipboard = root.pluginApi?.pluginSettings?.recordCopyToClipboard ?? false
                if (toClipboard) _copyPathToClipboard(saveProc.savedPath)
                var msg = toClipboard
                    ? root.pluginApi?.tr("record.savedAndCopied")
                    : root.pluginApi?.tr("record.saved")
                ToastService.showNotice(msg, saveProc.savedPath, "device-floppy")
            } else {
                ToastService.showError(root.format === "mp4"
                    ? root.pluginApi?.tr("record.saveMp4Failed")
                    : root.pluginApi?.tr("record.saveGifFailed"))
            }
            if (root.pluginApi) {
                var screen = root._primaryScreen
                if (screen) root.pluginApi.closePanel(screen)
                else root.pluginApi.withCurrentScreen(sc => root.pluginApi.closePanel(sc))
            }
            root.dismiss()
        }
    }
    Timer {
        id: elapsedTimer
        interval: 1000; repeat: true
        onTriggered: {
            root._elapsed++
            if (root.format === "gif" && root._elapsed >= root.gifMaxSeconds)
                root.stopRecording()
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: recWin
            required property ShellScreen modelData
            screen: modelData
            readonly property bool isPrimary: modelData === root._primaryScreen
            readonly property bool _isFullscreen:
                root.uiX === 0 && root.uiY === 0 &&
                root.regionW >= modelData.width * (modelData.devicePixelRatio ?? 1.0) - 4 &&
                root.regionH >= modelData.height * (modelData.devicePixelRatio ?? 1.0) - 4
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            visible: root.isRecording
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "noctalia-record"
            Item {
                id: stopBtnAnchor
                readonly property real btnW: 110
                readonly property real btnH: 36
                readonly property real spaceBelow: parent.height - (root.uiY + root.regionH)
                readonly property real spaceAbove: root.uiY
                readonly property bool hasRoomBelow: spaceBelow >= btnH + 10
                readonly property bool hasRoomAbove: spaceAbove >= btnH + 10
                visible: isPrimary && !_isFullscreen && (hasRoomBelow || hasRoomAbove)
                x: Math.max(8, Math.min(root.uiX + (root.regionW - btnW) / 2, parent.width - btnW - 8))
                y: hasRoomBelow
                    ? root.uiY + root.regionH + 8       // preferred: below
                    : root.uiY - btnH - 8               // fallback: above
                width: btnW; height: btnH
                Rectangle {
                    anchors.fill: parent
                    radius: Style.radiusL
                    color: stopMA.containsMouse ? Color.mError || "#f44336" : Color.mSurface
                    border.color: Color.mError || "#f44336"
                    border.width: Style.borderM
                    Row {
                        anchors.centerIn: parent; spacing: Style.marginS
                        Rectangle {
                            width: 10; height: 10; radius: Style.radiusXXXS
                            color: stopMA.containsMouse ? "white" : Color.mError || "#f44336"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        NText {
                            text: root.pluginApi?.tr("record.stop")
                            color: stopMA.containsMouse ? "white" : Color.mOnSurface
                            font.weight: Font.Bold; pointSize: Style.fontSizeS
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: stopMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stopRecording()
                    }
                }
            }
            Item {
                id: compactBtn
                readonly property real btnC: 36
                readonly property bool hasRoomLeft:  root.uiX >= btnC + 10
                readonly property bool hasRoomRight: (parent.width - root.uiX - root.regionW) >= btnC + 10
                visible: isPrimary && !_isFullscreen
                         && !stopBtnAnchor.hasRoomBelow && !stopBtnAnchor.hasRoomAbove
                         && (hasRoomLeft || hasRoomRight)
                width: btnC; height: btnC
                y: Math.max(8, Math.min(
                    root.uiY + (root.regionH - btnC) / 2,
                    parent.height - btnC - 8))
                x: hasRoomLeft
                    ? root.uiX - btnC - 8               // left of region
                    : root.uiX + root.regionW + 8       // right of region
                Rectangle {
                    anchors.fill: parent
                    radius: Style.radiusL
                    color: stopCMA.containsMouse ? Color.mError || "#f44336" : Color.mSurface
                    border.color: Color.mError || "#f44336"
                    border.width: Style.borderM
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 12; radius: Style.radiusXXXS
                        color: stopCMA.containsMouse ? "white" : Color.mError || "#f44336"
                    }
                    MouseArea {
                        id: stopCMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stopRecording()
                    }
                }
            }
            Item {
                id: maskItem
                x:      stopBtnAnchor.visible ? stopBtnAnchor.x : compactBtn.x
                y:      stopBtnAnchor.visible ? stopBtnAnchor.y : compactBtn.y
                width:  stopBtnAnchor.visible ? stopBtnAnchor.width  : compactBtn.width
                height: stopBtnAnchor.visible ? stopBtnAnchor.height : compactBtn.height
            }
            mask: Region {
                item: (isPrimary && (stopBtnAnchor.visible || compactBtn.visible)) ? maskItem : null
            }
            Rectangle {
                visible: isPrimary && !_isFullscreen
                x: root.uiX - 4; y: root.uiY - 4
                width:  root.regionW + 8
                height: root.regionH + 8
                color: "transparent"
                border.color: Color.mError || "#f44336"
                border.width: Style.borderM
                radius: Style.radiusS; opacity: 0.85
            }
            Rectangle {
                visible: isPrimary && !_isFullscreen
                readonly property real badgeH: 22
                readonly property real spaceAbove: root.uiY - badgeH - 8
                x: Math.max(8, Math.min(root.uiX + 4, parent.width - recBadge.implicitWidth - 20))
                y: spaceAbove >= 8
                    ? root.uiY - badgeH - 6
                    : root.uiY + root.regionH + 8
                width:  recBadge.implicitWidth + 10
                height: badgeH; radius: Style.radiusXXS
                color:  Qt.rgba(0, 0, 0, 0.65)
                Row {
                    id: recBadge; anchors.centerIn: parent; spacing: Style.marginXS
                    Rectangle {
                        width: 7; height: 7; radius: Style.radiusXXS
                        color: "#FF4444"
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            running: root.isRecording; loops: Animation.Infinite
                            NumberAnimation { to: 0.15; duration: 600 }
                            NumberAnimation { to: 1.0;  duration: 600 }
                        }
                    }
                    NText {
                        text: root.pluginApi?.tr("record.recLabel") + " " + root.formatTime(root._elapsed)
                        color: "white"; font.weight: Font.Bold; pointSize: Style.fontSizeXS
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
