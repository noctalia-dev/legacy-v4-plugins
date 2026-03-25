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

    property int _elapsed: 0
    property int _frameToken: 0
    property string format: "gif"
    property bool audioOutput: false
    property bool audioInput: false

    property bool _previewBusy: false

    function startRecording(regionStr, fmt, audOut, audIn) {
        if (root.isRecording || root.isConverting) return
        root.format = (fmt === "mp4") ? "mp4" : "gif"
        root.audioOutput = audOut === true
        root.audioInput  = audIn  === true

        var parts = regionStr.trim().split(" ")
        if (parts.length >= 2) {
            var xy = parts[0].split(",")
            var wh = parts[1].split("x")
            root.regionX = parseInt(xy[0]) || 0
            root.regionY = parseInt(xy[1]) || 0
            root.regionW = parseInt(wh[0]) || 400
            root.regionH = parseInt(wh[1]) || 300
        }

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

        wfRecorderProc.exec({ command: [
            "bash", "-c",
            "wf-recorder -g " + shellEscape(regionStr) +
            (root.audioOutput && root.audioInput
                ? " --audio=$(pactl get-default-sink 2>/dev/null).monitor"
                : root.audioOutput
                    ? " --audio=$(pactl get-default-sink 2>/dev/null).monitor"
                    : root.audioInput
                        ? " --audio=$(pactl get-default-source 2>/dev/null)"
                        : "") +
            " -c libx264 -p crf=0 -p preset=ultrafast -p tune=zerolatency -f " + root.mp4Path + " 2>/dev/null"
        ]})
    }

    function stopRecording() {
        if (!root.isRecording) return
        elapsedTimer.stop()
        previewTimer.stop()
        stopProc.exec({ command: ["bash", "-c", "pkill -INT wf-recorder 2>/dev/null || true"] })
    }

    function dismiss() {
        if (root.gifPath !== "")
            stopProc.exec({ command: ["bash", "-c", "rm -f " + root.gifPath] })
        root.isRecording  = false
        root.isConverting = false
        root.isDone       = false
        root.gifPath      = ""
        root._previewBusy = false
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

    // ── Processes ─────────────────────────────────────────────

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
            root.isRecording = false
            root._previewBusy = false
            previewTimer.stop()
            elapsedTimer.stop()
            if (code === 0 || code === 130 || code === 2) {
                root.isConverting = true
                var ts = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19)
                if (root.format === "mp4") {
                    root.gifPath = "/tmp/screen-toolkit-record-" + ts + ".mp4"
                    gifConvertProc.exec({ command: [
                        "bash", "-c",
                        "ffmpeg -y -i " + root.mp4Path +
                        " -c:v libx264 -crf 16 -preset veryslow -pix_fmt yuv420p" +
                        " -movflags +faststart " + root.gifPath + " 2>/dev/null && " +
                        "rm -f " + root.mp4Path + " && " +
                        "ffmpeg -y -ss 0 -i " + root.gifPath +
                        " -frames:v 1 /tmp/screen-toolkit-record-preview.png 2>/dev/null; " +
                        "exit 0"
                    ]})
                } else {
                    root.gifPath = "/tmp/screen-toolkit-record-" + ts + ".gif"
                    var framesDir = "/tmp/screen-toolkit-frames-" + Date.now()
                    gifConvertProc.exec({ command: [
                        "bash", "-c",
                        "mkdir -p " + framesDir + " && " +
                        "ffmpeg -y -i " + root.mp4Path +
                        " -vf 'fps=20,scale=trunc(iw/2)*2:-2' " +
                        framesDir + "/frame%04d.png 2>/dev/null && " +
                        "gifski --fps 20 --quality 100 -o " + root.gifPath +
                        " " + framesDir + "/frame*.png 2>/dev/null && " +
                        "rm -rf " + framesDir + " " + root.mp4Path
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
                ToastService.showError(root.format === "mp4" ? root.pluginApi?.tr("record.saveMp4Failed") : root.pluginApi?.tr("record.saveGifFailed"))
            }
        }
    }

    Process {
        id: saveProc
        property string savedPath: ""
        onExited: (code) => {
            if (code === 0) ToastService.showNotice(root.pluginApi?.tr("record.saved"), saveProc.savedPath, "device-floppy")
            else ToastService.showError(root.format === "mp4" ? root.pluginApi?.tr("record.saveMp4Failed") : root.pluginApi?.tr("record.saveGifFailed"))
            root.dismiss()
        }
    }

    // ── Timers ────────────────────────────────────────────────

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

    // ── Overlay ───────────────────────────────────────────────

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            required property ShellScreen modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            visible: root.isRecording || root.isConverting || root.isDone

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "noctalia-record"

            Rectangle {
                visible: root.isRecording
                x: root.regionX - 2
                y: root.regionY - 2
                width:  root.regionW + 4
                height: root.regionH + 4
                color: "transparent"
                border.color: "#FF4444"
                border.width: 2
                radius: 3
                opacity: 0.85
            }

            Item {
                id: cardAnchor

                readonly property real cardW: cardRect.implicitWidth  + 2
                readonly property real cardH: cardRect.implicitHeight + 2
                readonly property real spaceBelow: parent.height - (root.regionY + root.regionH)

                x: Math.max(8, Math.min(
                    root.regionX + (root.regionW - cardW) / 2,
                    parent.width - cardW - 8))
                y: spaceBelow >= cardH + 10
                   ? root.regionY + root.regionH + 8
                   : root.regionY - cardH - 8

                width: cardW
                height: cardH

                Rectangle {
                    id: cardRect
                    anchors.centerIn: parent
                    radius: Style.radiusL
                    color: Color.mSurface
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
                            radius: Style.radiusM
                            color: Color.mSurfaceVariant
                            clip: true
                            anchors.horizontalCenter: parent.horizontalCenter

                            Image {
                                anchors.fill: parent
                                visible: root.isRecording || root.isConverting
                                source: root._frameToken >= 0
                                    ? "file:///tmp/screen-toolkit-record-preview.png?" + root._frameToken
                                    : ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true; cache: false
                            }

                            AnimatedImage {
                                anchors.fill: parent
                                visible: root.isDone && root.format === "gif"
                                source: root.isDone && root.format === "gif" && root.gifPath !== ""
                                    ? "file://" + root.gifPath : ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true; cache: false
                                playing: root.isDone
                            }

                            Image {
                                anchors.fill: parent
                                visible: root.isDone && root.format === "mp4"
                                source: root.isDone && root.format === "mp4"
                                    ? "file:///tmp/screen-toolkit-record-preview.png?" + root._frameToken
                                    : ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true; cache: false
                            }

                            Rectangle {
                                visible: root.isRecording
                                anchors { top: parent.top; left: parent.left; margins: 6 }
                                width: recBadge.implicitWidth + 10; height: 20; radius: 4
                                color: Qt.rgba(0, 0, 0, 0.65)
                                Row {
                                    id: recBadge
                                    anchors.centerIn: parent; spacing: 4
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
                                visible: root.isConverting
                                anchors.fill: parent; radius: Style.radiusM
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
                                        text: root.format === "mp4" ? root.pluginApi?.tr("record.savingMp4") : root.pluginApi?.tr("record.convertingGif")
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
                                    id: readyBadge
                                    anchors.centerIn: parent; spacing: 4
                                    NIcon { icon: "circle-check"; color: Color.mPrimary; scale: 0.75 }
                                    NText {
                                        text: root.format === "mp4" ? root.pluginApi?.tr("record.mp4Ready") : root.pluginApi?.tr("record.gifReady")
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
                                id: stopRow
                                anchors.centerIn: parent; spacing: Style.marginS
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
                                id: stopBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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
                                    id: saveRow
                                    anchors.centerIn: parent; spacing: Style.marginS
                                    NIcon { icon: "device-floppy"; color: saveBtn.containsMouse ? Color.mOnPrimary : Color.mOnSurface }
                                    NText {
                                        text: root.format === "mp4" ? root.pluginApi?.tr("record.saveMp4") : root.pluginApi?.tr("record.saveGif")
                                        color: saveBtn.containsMouse ? Color.mOnPrimary : Color.mOnSurface
                                        font.weight: Font.Bold; pointSize: Style.fontSizeS
                                    }
                                }
                                MouseArea {
                                    id: saveBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var ts = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19)
                                        var ext = root.format === "mp4" ? ".mp4" : ".gif"
                                        var fname = "record-" + ts + ext
                                        saveProc.savedPath = fname
                                        saveProc.exec({ command: [
                                            "bash", "-c",
                                            "mkdir -p ~/Videos && cp " + root.gifPath + " ~/Videos/" + fname
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
                                    id: discardBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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
