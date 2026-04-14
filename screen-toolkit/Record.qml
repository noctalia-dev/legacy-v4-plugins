import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI
Item {
    id: root
    property var pluginApi: null
    property string region: ""
    property string mp4Path: ""
    property string gifPath: ""
    property bool isRecording: false
    property bool isConverting: false
    property bool isDone: false
    property int regionX: 0
    property int regionY: 0
    property int regionW: 400
    property int regionH: 300
    property int uiX: 0
    property int uiY: 0
    property var _primaryScreen: null
    property int _elapsed: 0
    property int _frameToken: 0
    property string format: "gif"
    property bool audioOutput: false
    property bool audioInput: false
    property bool includeCursor: false
    property string _recorderBin: "wl-screenrec"
    property bool _previewBusy: false
    property real _maskW: 0
    property real _maskH: 0
    function _expandPath(p) {
        if (!p || p === "") return ""
        if (p.startsWith("~/"))
            return Quickshell.env("HOME") + "/" + p.substring(2)
        return p
    }
    function _recordOutputDir() {
        var custom = pluginApi?.pluginSettings?.videoPath ?? ""
        if (custom !== "") return _expandPath(custom.trim().replace(/\/$/, ""))
        return Quickshell.env("HOME") + "/Videos"
    }
    function _buildFilename(toolName, ext) {
        var fmt = pluginApi?.pluginSettings?.filenameFormat ?? ""
        if (fmt.trim() !== "") {
            var now = new Date()
            var name = fmt.trim()
                .replace(/%Y/g, Qt.formatDateTime(now, "yyyy"))
                .replace(/%m/g, Qt.formatDateTime(now, "MM"))
                .replace(/%d/g, Qt.formatDateTime(now, "dd"))
                .replace(/%H/g, Qt.formatDateTime(now, "HH"))
                .replace(/%M/g, Qt.formatDateTime(now, "mm"))
                .replace(/%S/g, Qt.formatDateTime(now, "ss"))
                .replace(/[\/\\\n\r\0]/g, "_").trim()
            if (name !== "") return name + ext
        }
        return toolName + "-" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ext
    }
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
        var pw = Math.min(root.regionW, 300)
        var ph = Math.round(pw * root.regionH / Math.max(root.regionW, 1))
        root._maskW = pw + Style.marginL * 2 + 2
        root._maskH = ph + Style.marginM * 3 + 34 + 2
        root._recorderBin = (pluginApi?.pluginSettings?.detectedRecorder === "wf-recorder")
                            ? "wf-recorder" : "wl-screenrec"
        root.region       = regionStr
        root.mp4Path      = "/tmp/screen-toolkit-record-" + Date.now() + ".mp4"
        root.gifPath      = ""
        root.isRecording  = true
        root.isConverting = false
        root.isDone       = false
        root._elapsed     = 0
        root._frameToken  = 0
        root._previewBusy = false
        elapsedTimer.start()
        previewTimer.start()
        _capturePreview()
        var cmd
        if (root._recorderBin === "wf-recorder") {
            cmd = "wf-recorder -g " + shellEscape(regionStr) +
                  (root.audioOutput
                      ? " -a=$(pactl get-default-sink 2>/dev/null).monitor"
                      : root.audioInput
                          ? " -a=$(pactl get-default-source 2>/dev/null)"
                          : "") +
                  " -f " + shellEscape(root.mp4Path) + " 2>/dev/null" +
                  "; [ -s " + shellEscape(root.mp4Path) + " ] && exit 0 || exit 1"
        } else {
            cmd = "wl-screenrec -g " + shellEscape(regionStr) +
                  (root.includeCursor ? "" : " --no-cursor") +
                  (root.audioOutput
                      ? " --audio --audio-device $(pactl get-default-sink 2>/dev/null).monitor"
                      : root.audioInput
                          ? " --audio --audio-device $(pactl get-default-source 2>/dev/null)"
                          : "") +
                  " -f " + shellEscape(root.mp4Path) + " 2>/dev/null" +
                  "; [ -s " + shellEscape(root.mp4Path) + " ] && exit 0 || exit 1"
        }
        wfRecorderProc.exec({ command: ["bash", "-c", cmd] })
    }
    function stopRecording() {
        if (!root.isRecording) return
        elapsedTimer.stop()
        previewTimer.stop()
        stopProc.exec({ command: ["bash", "-c", "pkill -INT " + root._recorderBin + " 2>/dev/null || true"] })
    }
    function dismiss() {
        if (root.isRecording) root.stopRecording()
        if (root.gifPath !== "")
            stopProc.exec({ command: ["bash", "-c", "rm -f " + shellEscape(root.gifPath)] })
        root.isRecording    = false
        root.isConverting   = false
        root.isDone         = false
        root.gifPath        = ""
        root._previewBusy   = false
        root._primaryScreen = null
    }
    function shellEscape(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'"
    }
    function formatTime(secs) {
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
    function _capturePreview() {
        if (root._previewBusy || !root.isRecording) return
        root._previewBusy = true
        previewCaptureProc.exec({ command: [
            "bash", "-c",
            "grim -g " + shellEscape(root.region) +
            " /tmp/screen-toolkit-record-preview.png 2>/dev/null"
        ]})
    }
    Process {
        id: previewCaptureProc
        onExited: (code) => {
            root._previewBusy = false
            if (code === 0) root._frameToken++
        }
    }
    Process {
        id: wfRecorderProc
        onExited: (code) => {
            root.isRecording  = false
            root._previewBusy = false
            previewTimer.stop()
            elapsedTimer.stop()
            if (code === 0 || code === 130 || code === 2) {
                root.isConverting = true
                var tmpTs    = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")
                var optimOut = "/tmp/screen-toolkit-record-" + tmpTs
                if (root.format === "mp4") {
                    root.gifPath = optimOut + ".mp4"
                    gifConvertProc.exec({ command: [
                        "bash", "-c",
                        "ffmpeg -y -i " + shellEscape(root.mp4Path) +
                        " -vf 'scale=trunc(iw/2)*2:trunc(ih/2)*2'" +
                        " -c:v libx264 -crf 15 -preset slow -tune animation" +
                        " -pix_fmt yuv444p -movflags +faststart" +
                        (root.audioOutput || root.audioInput ? " -c:a aac -b:a 128k" : " -an") +
                        " " + shellEscape(root.gifPath) + " 2>/dev/null && " +
                        "rm -f " + shellEscape(root.mp4Path) + " && " +
                        "ffmpeg -y -ss 0 -i " + shellEscape(root.gifPath) +
                        " -frames:v 1 /tmp/screen-toolkit-record-preview.png 2>/dev/null; exit 0"
                    ]})
                } else {
                    root.gifPath = optimOut + ".gif"
                    var framesDir = "/tmp/screen-toolkit-frames-" + Date.now()
                    gifConvertProc.exec({ command: [
                        "bash", "-c",
                        "mkdir -p " + shellEscape(framesDir) + " && " +
                        "ffmpeg -y -i " + shellEscape(root.mp4Path) +
                        " -vf 'fps=24,scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=lanczos'" +
                        " " + shellEscape(framesDir) + "/frame%04d.png 2>/dev/null && " +
                        "gifski --fps 24 --quality 97 -o " + shellEscape(root.gifPath) +
                        " " + shellEscape(framesDir) + "/frame*.png 2>/dev/null && " +
                        "rm -rf " + shellEscape(framesDir) + " " + shellEscape(root.mp4Path)
                    ]})
                }
            } else {
                root.dismiss()
                ToastService.showError(root.pluginApi?.tr("record.failed"))
            }
        }
    }
    Process { id: stopProc }
    Process {
        id: gifConvertProc
        onExited: (code) => {
            root.isConverting = false
            if (code === 0) {
                root._frameToken++
                root.isDone = true
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
            if (code === 0)
                ToastService.showNotice(root.pluginApi?.tr("record.saved"), saveProc.savedPath, "device-floppy")
            else
                ToastService.showError(root.format === "mp4"
                    ? root.pluginApi?.tr("record.saveMp4Failed")
                    : root.pluginApi?.tr("record.saveGifFailed"))
            root.dismiss()
        }
    }
    Timer {
        id: elapsedTimer
        interval: 1000; repeat: true
        onTriggered: {
            root._elapsed++
            if (root.format === "gif" && root._elapsed >= 30)
                root.stopRecording()
        }
    }
    Timer {
        id: previewTimer
        interval: 150; repeat: true
        onTriggered: _capturePreview()
    }
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property ShellScreen modelData
            screen: modelData
            readonly property bool isPrimary: modelData === root._primaryScreen
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            visible: root.isRecording || root.isConverting || root.isDone
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "noctalia-record"
            Item {
                id: maskItem
                readonly property real spaceBelow: parent.height - (root.uiY + root.regionH)
                x: Math.max(8, Math.min(root.uiX + (root.regionW - root._maskW) / 2,
                                        parent.width - root._maskW - 8))
                y: spaceBelow >= root._maskH + 10
                   ? root.uiY + root.regionH + 8
                   : root.uiY - root._maskH - 8
                width: root._maskW; height: root._maskH
            }
            mask: Region { item: isPrimary ? maskItem : null }
            Rectangle {
                visible: isPrimary && root.isRecording
                x: root.uiX - 4; y: root.uiY - 4
                width: root.regionW + 8; height: root.regionH + 8
                color: "transparent"
                border.color: "#FF4444"; border.width: Style.capsuleBorderWidth || 2; radius: Style.radiusS; opacity: 0.85
            }
            Item {
                id: cardAnchor
                visible: isPrimary
                readonly property real cardW: cardRect.implicitWidth  + 2
                readonly property real cardH: cardRect.implicitHeight + 2
                readonly property real spaceBelow: parent.height - (root.uiY + root.regionH)
                x: Math.max(8, Math.min(root.uiX + (root.regionW - cardW) / 2, parent.width - cardW - 8))
                y: spaceBelow >= cardH + 10 ? root.uiY + root.regionH + 8 : root.uiY - cardH - 8
                width: cardW; height: cardH
                Rectangle {
                    id: cardRect
                    anchors.centerIn: parent
                    radius: Style.radiusL; color: Color.mSurface
                    border.color: Style.capsuleBorderColor || "transparent"
                    border.width: Style.capsuleBorderWidth || 1
                    implicitWidth:  cardCol.implicitWidth  + Style.marginL * 2
                    implicitHeight: cardCol.implicitHeight + Style.marginM * 2
                    Column {
                        id: cardCol
                        anchors.centerIn: parent
                        spacing: Style.marginM
                        Rectangle {
                            readonly property real previewW: Math.min(root.regionW, 300)
                            readonly property real previewH: previewW * (root.regionH / Math.max(root.regionW, 1))
                            width: previewW; height: previewH
                            radius: Style.radiusM; color: Color.mSurfaceVariant; clip: true
                            anchors.horizontalCenter: parent.horizontalCenter
                            Image {
                                anchors.fill: parent
                                visible: root.isRecording || root.isConverting
                                source: root._frameToken > 0
                                    ? "file:///tmp/screen-toolkit-record-preview.png?" + root._frameToken : ""
                                fillMode: Image.PreserveAspectFit; smooth: true; cache: false
                            }
                            AnimatedImage {
                                anchors.fill: parent
                                visible: root.isDone && root.format === "gif"
                                source: root.isDone && root.format === "gif" && root.gifPath !== ""
                                    ? "file://" + root.gifPath : ""
                                fillMode: Image.PreserveAspectFit; smooth: true; cache: false
                                playing: root.isDone
                            }
                            Image {
                                anchors.fill: parent
                                visible: root.isDone && root.format === "mp4"
                                source: root.isDone && root.format === "mp4"
                                    ? "file:///tmp/screen-toolkit-record-preview.png?" + root._frameToken : ""
                                fillMode: Image.PreserveAspectFit; smooth: true; cache: false
                            }
                            Rectangle {
                                visible: root.isRecording
                                anchors { top: parent.top; left: parent.left; margins: 6 }
                                width: recBadge.implicitWidth + 10; height: 20; radius: 4
                                color: Qt.rgba(0, 0, 0, 0.65)
                                Row {
                                    id: recBadge; anchors.centerIn: parent; spacing: Style.marginXS
                                    Rectangle {
                                        width: 7; height: 7; radius: 4; color: "#FF4444"
                                        anchors.verticalCenter: parent.verticalCenter
                                        SequentialAnimation on opacity {
                                            running: root.isRecording; loops: Animation.Infinite
                                            NumberAnimation { to: 0.15; duration: 600 }
                                            NumberAnimation { to: 1.0;  duration: 600 }
                                        }
                                    }
                                    NText {
                                        text: "REC " + root.formatTime(root._elapsed)
                                        color: "white"; font.weight: Font.Bold; pointSize: Style.fontSizeXS
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                            Rectangle {
                                visible: root.isConverting; anchors.fill: parent; radius: Style.radiusM
                                color: Qt.rgba(0, 0, 0, 0.55)
                                Column {
                                    anchors.centerIn: parent; spacing: Style.marginS
                                    NIcon {
                                        icon: "loader"; color: "white"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        RotationAnimation on rotation {
                                            running: root.isConverting
                                            from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                                        }
                                    }
                                    NText {
                                        text: root.format === "mp4"
                                            ? root.pluginApi?.tr("record.savingMp4")
                                            : root.pluginApi?.tr("record.convertingGif")
                                        color: "white"; pointSize: Style.fontSizeXS
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                            Rectangle {
                                visible: root.isDone
                                anchors { top: parent.top; left: parent.left; margins: 6 }
                                width: readyBadge.implicitWidth + 10; height: 20; radius: 4
                                color: Qt.rgba(0, 0, 0, 0.65)
                                Row {
                                    id: readyBadge; anchors.centerIn: parent; spacing: Style.marginXS
                                    NIcon { icon: "circle-check"; color: Color.mPrimary; scale: 0.75 }
                                    NText {
                                        text: root.format === "mp4"
                                            ? root.pluginApi?.tr("record.mp4Ready")
                                            : root.pluginApi?.tr("record.gifReady")
                                        color: "white"; font.weight: Font.Bold; pointSize: Style.fontSizeXS
                                    }
                                }
                            }
                        }
                        Rectangle {
                            visible: root.isRecording
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 34; radius: Style.radiusM
                            width: stopRow.implicitWidth + Style.marginL * 2
                            color: stopBtn.containsMouse ? Color.mError || "#f44336" : Color.mSurfaceVariant
                            Row {
                                id: stopRow; anchors.centerIn: parent; spacing: Style.marginS
                                Rectangle {
                                    width: 10; height: 10; radius: 2
                                    color: stopBtn.containsMouse ? "white" : (Color.mError || "#f44336")
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                NText {
                                    text: root.pluginApi?.tr("record.stop")
                                    color: stopBtn.containsMouse ? "white" : Color.mOnSurface
                                    font.weight: Font.Bold; pointSize: Style.fontSizeS
                                }
                            }
                            MouseArea {
                                id: stopBtn; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.stopRecording()
                            }
                        }
                        Row {
                            visible: root.isDone
                            spacing: Style.marginS
                            anchors.horizontalCenter: parent.horizontalCenter
                            Rectangle {
                                height: 34; radius: Style.radiusM
                                width: saveRow.implicitWidth + Style.marginL * 2
                                color: saveBtn.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                                Row {
                                    id: saveRow; anchors.centerIn: parent; spacing: Style.marginS
                                    NIcon { icon: "device-floppy"; color: saveBtn.containsMouse ? Color.mOnPrimary : Color.mOnSurface }
                                    NText {
                                        text: root.format === "mp4"
                                            ? root.pluginApi?.tr("record.saveMp4")
                                            : root.pluginApi?.tr("record.saveGif")
                                        color: saveBtn.containsMouse ? Color.mOnPrimary : Color.mOnSurface
                                        font.weight: Font.Bold; pointSize: Style.fontSizeS
                                    }
                                }
                                MouseArea {
                                    id: saveBtn; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var ext  = root.format === "mp4" ? ".mp4" : ".gif"
                                        var dir  = root._recordOutputDir()
                                        var dest = dir + "/" + root._buildFilename("record", ext)
                                        saveProc.savedPath = dest
                                        saveProc.exec({ command: [
                                            "bash", "-c",
                                            "mkdir -p " + shellEscape(dir) + " && " +
                                            "cp " + shellEscape(root.gifPath) + " " + shellEscape(dest)
                                        ]})
                                    }
                                }
                            }
                            Rectangle {
                                width: 34; height: 34; radius: Style.radiusM
                                color: discardBtn.containsMouse ? Color.mErrorContainer || "#ffcdd2" : Color.mSurface
                                border.color: discardBtn.containsMouse ? Color.mError || "#f44336" : (Style.capsuleBorderColor || "transparent")
                                border.width: Style.capsuleBorderWidth || 1
                                NIcon { anchors.centerIn: parent; icon: "trash"; color: discardBtn.containsMouse ? Color.mError || "#f44336" : Color.mOnSurfaceVariant }
                                MouseArea {
                                    id: discardBtn; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.dismiss()
                                    onEntered: TooltipService.show(discardBtn, root.pluginApi?.tr("record.discard"))
                                    onExited:  TooltipService.hide()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
