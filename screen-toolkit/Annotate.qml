import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI

Variants {
    id: root

    property string imagePath: "/tmp/screen-toolkit-annotate.png"
    property var mainInstance: null
    property bool isVisible: false

    property int regionX: 0
    property int regionY: 0
    property int regionW: 0
    property int regionH: 0

    property real zoomScale: 1.0
    property string lastRegion: ""

    function parseAndShow(regionStr, imgPath) {
        var parts = regionStr.trim().split(" ")
        if (parts.length < 2) return
        var xy = parts[0].split(",")
        var wh = parts[1].split("x")
        regionX = parseInt(xy[0]) || 0
        regionY = parseInt(xy[1]) || 0
        regionW = parseInt(wh[0]) || 400
        regionH = parseInt(wh[1]) || 300
        zoomScale = 1.0
        lastRegion = regionStr
        imagePath = imgPath
        _resetToken = !_resetToken
        isVisible = true
    }

    function parseAndShowZoomed(regionStr, imgPath, scale) {
        var parts = regionStr.trim().split(" ")
        if (parts.length < 2) return
        var xy = parts[0].split(",")
        var wh = parts[1].split("x")
        regionX = parseInt(xy[0]) || 0
        regionY = parseInt(xy[1]) || 0
        regionW = parseInt(wh[0]) || 400
        regionH = parseInt(wh[1]) || 300
        zoomScale = scale
        imagePath = imgPath
        _resetToken = !_resetToken
        isVisible = true
    }

    property bool _resetToken: false

    function hide() { isVisible = false }

    model: Quickshell.screens

    delegate: PanelWindow {
        id: overlayWin

        required property ShellScreen modelData
        screen: modelData

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        visible: root.isVisible

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.isVisible
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "noctalia-annotate"

        // ── State ──────────────────────────────────────
        property string tool: "pencil"
        property color drawColor: "#FF4444"
        property int drawSize: 3
        property var strokes: []
        property var currentStroke: null
        property bool drawing: false
        property bool textMode: false
        property bool isSaving: false
        property real textX: 0
        property real textY: 0
        property bool pixelImgReady: false
        property bool showPopover: false
        property int _pixelCacheBust: 0

        property real _pendingZoomScale: 1.0
        property real panX: 0.0
        property real panY: 0.0
        property real _panStartX: 0.0
        property real _panStartY: 0.0
        property real _panStartMouseX: 0.0
        property real _panStartMouseY: 0.0
        property bool isPanning: false
        property var _savedStrokes: []

        // ── Zoom ───────────────────────────────────────
        function requestZoom(scale) {
            var region = root.lastRegion
            if (region === "") return
            if (scale === 1.0) {
                overlayWin.strokes = overlayWin._savedStrokes.slice()
                overlayWin._savedStrokes = []
                overlayWin.panX = 0.0
                overlayWin.panY = 0.0
                root.parseAndShow(region, "/tmp/screen-toolkit-annotate.png")
                drawCanvas.requestPaint()
                return
            }
            if (root.zoomScale === 1.0) {
                overlayWin._savedStrokes = overlayWin.strokes.slice()
                overlayWin.strokes = []
                overlayWin.currentStroke = null
            }
            _pendingZoomScale = scale
            overlayWin.panX = 0.0
            overlayWin.panY = 0.0
            var newW = Math.round(root.regionW * scale)
            var newH = Math.round(root.regionH * scale)
            zoomProc.exec({ command: [
                "bash", "-c",
                "magick /tmp/screen-toolkit-annotate.png -resize " + newW + "x" + newH + "! /tmp/screen-toolkit-annotate-zoom.png 2>/dev/null"
            ]})
        }

        // ── Pixelate ───────────────────────────────────
        Process {
            id: pixelateProc
            onExited: (code) => {
                if (code === 0) {
                    overlayWin._pixelCacheBust++
                    overlayWin.pixelImgReady = false
                    overlayWin.pixelImgReady = true
                }
            }
        }

        property string _lastPreparedPath: ""

        function preparePixelImage() {
            if (root.imagePath === overlayWin._lastPreparedPath && overlayWin.pixelImgReady) {
                drawCanvas.requestPaint()
                return
            }
            overlayWin._lastPreparedPath = root.imagePath
            pixelImgReady = false
            pixelateProc.exec({ command: [
                "bash", "-c",
                "magick /tmp/screen-toolkit-annotate.png -scale 5% -scale 2000% /tmp/screen-toolkit-annotate-pixel.png 2>/dev/null"
            ]})
        }

        onPixelImgReadyChanged: {
            if (pixelImgReady) {
                drawCanvas.unloadImage("file:///tmp/screen-toolkit-annotate-pixel.png?" + (overlayWin._pixelCacheBust - 1))
                drawCanvas.requestPaint()
            }
        }

        // ── Processes ──────────────────────────────────
        Process {
            id: zoomProc
            onExited: (code) => {
                if (code === 0) {
                    root.parseAndShowZoomed(
                        root.lastRegion,
                        "/tmp/screen-toolkit-annotate-zoom.png",
                        overlayWin._pendingZoomScale)
                }
            }
        }

        Process {
            id: copyProc
            onExited: (code) => {
                overlayWin.isSaving = false
                if (code === 0) {
                    ToastService.showNotice(root.mainInstance?.pluginApi?.tr("annotate.copied"), "", "copy")
                    root.hide()
                } else {
                    ToastService.showError(root.mainInstance?.pluginApi?.tr("annotate.copyFailed"))
                }
            }
        }

        Process {
            id: saveProc
            onExited: (code) => {
                overlayWin.isSaving = false
                if (code === 0) {
                    ToastService.showNotice(root.mainInstance?.pluginApi?.tr("annotate.copied"), "", "copy")
                    root.hide()
                } else {
                    ToastService.showError(root.mainInstance?.pluginApi?.tr("annotate.saveFailed"))
                }
            }
        }

        Process {
            id: saveFileProc
            property string savedPath: ""
            stdout: StdioCollector {}
            onExited: (code) => {
                overlayWin.isSaving = false
                if (code === 0) {
                    var dest = saveFileProc.stdout.text.trim()
                    ToastService.showNotice(root.mainInstance?.pluginApi?.tr("annotate.savedTo", { dest: dest !== "" ? dest : "~/Pictures" }), saveFileProc.savedPath, "device-floppy")
                    root.hide()
                } else {
                    ToastService.showError(root.mainInstance?.pluginApi?.tr("annotate.saveFileFailed"))
                }
            }
        }

        // ── Keys ───────────────────────────────────────
        Shortcut {
            sequence: "Escape"
            onActivated: { overlayWin.strokes = []; root.hide() }
        }

        // ── Reset on hide ──────────────────────────────
        Connections {
            target: root
            function onIsVisibleChanged() {
                if (!root.isVisible) {
                    overlayWin.strokes = []
                    overlayWin._savedStrokes = []
                    overlayWin.currentStroke = null
                    overlayWin.drawing = false
                    overlayWin.textMode = false
                    overlayWin.showPopover = false
                    overlayWin.pixelImgReady = false
                    overlayWin._lastPreparedPath = ""
                    overlayWin.panX = 0.0
                    overlayWin.panY = 0.0
                    overlayWin.isPanning = false
                    drawCanvas.requestPaint()
                } else {
                    overlayWin.preparePixelImage()
                }
            }
        }

        // ── Dark overlay ───────────────────────────────
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            Rectangle {
                x: root.regionX
                y: root.regionY
                width: root.regionW
                height: root.regionH
                color: "transparent"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                    var ix = root.regionX, iy = root.regionY
                    var iw = root.regionW, ih = root.regionH
                    var inRegion  = mouse.x >= ix && mouse.x <= ix+iw && mouse.y >= iy && mouse.y <= iy+ih
                    var inToolbar = mouse.x >= toolbar.x && mouse.x <= toolbar.x+toolbar.width
                                 && mouse.y >= toolbar.y && mouse.y <= toolbar.y+toolbar.height
                    var inPopover = overlayWin.showPopover
                                 && mouse.x >= popover.x && mouse.x <= popover.x+popover.width
                                 && mouse.y >= popover.y && mouse.y <= popover.y+popover.height
                    if (!inRegion && !inToolbar && !inPopover) {
                        overlayWin.strokes = []
                        root.hide()
                    }
                }
            }
        }

        // ── Capture root ───────────────────────────────
        Item {
            id: captureRoot
            x: root.regionX
            y: root.regionY
            width: root.regionW
            height: root.regionH
            clip: true

            Image {
                id: imgLoader
                width:  root.zoomScale > 1.0 ? root.regionW * root.zoomScale : root.regionW
                height: root.zoomScale > 1.0 ? root.regionH * root.zoomScale : root.regionH
                x: root.zoomScale > 1.0
                   ? Math.max(root.regionW - width, Math.min(0, (root.regionW - width) / 2 + overlayWin.panX))
                   : 0
                y: root.zoomScale > 1.0
                   ? Math.max(root.regionH - height, Math.min(0, (root.regionH - height) / 2 + overlayWin.panY))
                   : 0
                source: root.isVisible ? "file://" + root.imagePath + "?v=" + root._resetToken : ""
                fillMode: Image.Stretch
                cache: false; smooth: true
            }

            Repeater {
                model: overlayWin.strokes.filter(s => s.type === "blur" && !s.preview)
                delegate: Item {
                    x: Math.min(modelData.x1, modelData.x2)
                    y: Math.min(modelData.y1, modelData.y2)
                    width: Math.abs(modelData.x2 - modelData.x1)
                    height: Math.abs(modelData.y2 - modelData.y1)
                    clip: true
                    Image {
                        x: -parent.x; y: -parent.y
                        width: root.regionW
                        height: root.regionH
                        source: overlayWin.pixelImgReady ? "file:///tmp/screen-toolkit-annotate-pixel.png?" + overlayWin._pixelCacheBust : ""
                        fillMode: Image.Stretch; cache: false; smooth: false
                    }
                }
            }
        }

        // ── Blur preview ───────────────────────────────
        Rectangle {
            visible: root.zoomScale <= 1.0 && overlayWin.drawing && overlayWin.currentStroke && overlayWin.currentStroke.type === "blur"
            x: root.regionX + (overlayWin.currentStroke ? Math.min(overlayWin.currentStroke.x1, overlayWin.currentStroke.x2) : 0)
            y: root.regionY + (overlayWin.currentStroke ? Math.min(overlayWin.currentStroke.y1, overlayWin.currentStroke.y2) : 0)
            width:  overlayWin.currentStroke ? Math.abs(overlayWin.currentStroke.x2 - overlayWin.currentStroke.x1) : 0
            height: overlayWin.currentStroke ? Math.abs(overlayWin.currentStroke.y2 - overlayWin.currentStroke.y1) : 0
            color: "transparent"; border.color: "#ffffff"; border.width: 1.5; opacity: 0.8
        }

        // ── Zoom badge ─────────────────────────────────
        Rectangle {
            visible: root.zoomScale > 1.0
            x: root.regionX + root.regionW - width - 8
            y: root.regionY + 8
            width: zoomBadgeRow.implicitWidth + 12; height: 22; radius: 6
            color: Qt.rgba(0, 0, 0, 0.6)
            Row {
                id: zoomBadgeRow
                anchors.centerIn: parent; spacing: 4
                NIcon { icon: "zoom-in"; color: "#ffffff" }
                NText { text: Math.round(root.zoomScale) + "× — view only"; color: "#ffffff"; pointSize: Style.fontSizeXS }
            }
        }

        // ── Drawing canvas ─────────────────────────────
        Canvas {
            id: drawCanvas
            x: root.regionX
            y: root.regionY
            width: root.regionW
            height: root.regionH
            visible: root.zoomScale <= 1.0

            onImageLoaded: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var pixUrl = "file:///tmp/screen-toolkit-annotate-pixel.png?" + overlayWin._pixelCacheBust
                if (overlayWin.pixelImgReady && !isImageLoaded(pixUrl)) loadImage(pixUrl)
                for (var i = 0; i < overlayWin.strokes.length; i++)
                    drawStroke(ctx, overlayWin.strokes[i])
                if (overlayWin.currentStroke && overlayWin.drawing)
                    drawStroke(ctx, overlayWin.currentStroke)
            }

            function drawStroke(ctx, stroke) {
                ctx.strokeStyle = stroke.color
                ctx.fillStyle   = stroke.color
                ctx.lineWidth   = stroke.size
                ctx.lineCap     = "round"
                ctx.lineJoin    = "round"

                if (stroke.type === "blur" && !stroke.preview) {
                    var bx = Math.min(stroke.x1, stroke.x2), by = Math.min(stroke.y1, stroke.y2)
                    var bw = Math.abs(stroke.x2 - stroke.x1), bh = Math.abs(stroke.y2 - stroke.y1)
                    if (bw > 0 && bh > 0) {
                        var pixUrl = "file:///tmp/screen-toolkit-annotate-pixel.png?" + overlayWin._pixelCacheBust
                        if (isImageLoaded(pixUrl)) {
                            ctx.save()
                            ctx.beginPath(); ctx.rect(bx, by, bw, bh); ctx.clip()
                            ctx.drawImage(pixUrl, 0, 0, root.regionW, root.regionH)
                            ctx.restore()
                        }
                    }
                } else if (stroke.type === "pencil" && stroke.points.length > 1) {
                    ctx.beginPath()
                    ctx.moveTo(stroke.points[0].x, stroke.points[0].y)
                    for (var i = 1; i < stroke.points.length; i++)
                        ctx.lineTo(stroke.points[i].x, stroke.points[i].y)
                    ctx.stroke()
                } else if (stroke.type === "arrow") {
                    var dx = stroke.x2 - stroke.x1, dy = stroke.y2 - stroke.y1
                    var len = Math.sqrt(dx*dx + dy*dy)
                    if (len < 2) return
                    ctx.beginPath(); ctx.moveTo(stroke.x1, stroke.y1); ctx.lineTo(stroke.x2, stroke.y2); ctx.stroke()
                    var angle = Math.atan2(dy, dx), hs = Math.max(stroke.size * 4, 12)
                    ctx.beginPath()
                    ctx.moveTo(stroke.x2, stroke.y2)
                    ctx.lineTo(stroke.x2 - hs * Math.cos(angle - Math.PI/6), stroke.y2 - hs * Math.sin(angle - Math.PI/6))
                    ctx.lineTo(stroke.x2 - hs * Math.cos(angle + Math.PI/6), stroke.y2 - hs * Math.sin(angle + Math.PI/6))
                    ctx.closePath(); ctx.fill()
                } else if (stroke.type === "rect") {
                    ctx.beginPath()
                    ctx.strokeRect(stroke.x1, stroke.y1, stroke.x2 - stroke.x1, stroke.y2 - stroke.y1)
                } else if (stroke.type === "text") {
                    ctx.font = (stroke.size * 5 + 12) + "px sans-serif"
                    ctx.fillText(stroke.text, stroke.x1, stroke.y1)
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: overlayWin.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor

                onPressed: (mouse) => {
                    overlayWin.showPopover = false
                    if (overlayWin.tool === "text") {
                        overlayWin.textX = mouse.x
                        overlayWin.textY = mouse.y
                        overlayWin.textMode = true
                        textInput.text = ""
                        textInput.forceActiveFocus()
                        return
                    }
                    overlayWin.drawing = true
                    if (overlayWin.tool === "pencil") {
                        overlayWin.currentStroke = { type: "pencil", color: overlayWin.drawColor, size: overlayWin.drawSize, points: [{ x: mouse.x, y: mouse.y }] }
                    } else if (overlayWin.tool === "blur") {
                        overlayWin.currentStroke = { type: "blur", color: overlayWin.drawColor, size: overlayWin.drawSize, x1: mouse.x, y1: mouse.y, x2: mouse.x, y2: mouse.y, preview: true }
                    } else {
                        overlayWin.currentStroke = { type: overlayWin.tool, color: overlayWin.drawColor, size: overlayWin.drawSize, x1: mouse.x, y1: mouse.y, x2: mouse.x, y2: mouse.y }
                    }
                }

                onPositionChanged: (mouse) => {
                    if (!overlayWin.drawing || !overlayWin.currentStroke) return
                    if (overlayWin.tool === "pencil") {
                        var s = overlayWin.currentStroke
                        var pts = s.points.slice()
                        pts.push({ x: mouse.x, y: mouse.y })
                        overlayWin.currentStroke = { type: s.type, color: s.color, size: s.size, points: pts }
                    } else {
                        overlayWin.currentStroke = {
                            type: overlayWin.currentStroke.type, color: overlayWin.currentStroke.color,
                            size: overlayWin.currentStroke.size,
                            x1: overlayWin.currentStroke.x1, y1: overlayWin.currentStroke.y1,
                            x2: mouse.x, y2: mouse.y, preview: true
                        }
                    }
                    drawCanvas.requestPaint()
                }

                onReleased: {
                    if (!overlayWin.drawing || !overlayWin.currentStroke) return
                    overlayWin.drawing = false
                    var stroke = overlayWin.currentStroke
                    if (stroke.type === "blur")
                        stroke = { type: "blur", color: stroke.color, size: stroke.size, x1: stroke.x1, y1: stroke.y1, x2: stroke.x2, y2: stroke.y2, preview: false }
                    var s = overlayWin.strokes.slice()
                    s.push(stroke)
                    overlayWin.strokes = s
                    overlayWin.currentStroke = null
                    drawCanvas.requestPaint()
                }
            }

            TextInput {
                id: textInput
                visible: overlayWin.textMode
                x: overlayWin.textX
                y: overlayWin.textY - height
                width: Math.min(300, drawCanvas.width - x - 4)
                color: overlayWin.drawColor
                font.pixelSize: overlayWin.drawSize * 5 + 12
                font.bold: true
                Keys.onReturnPressed: commitText()
                Keys.onEscapePressed: { overlayWin.textMode = false; text = "" }
                function commitText() {
                    if (text.trim() !== "") {
                        var s = overlayWin.strokes.slice()
                        s.push({ type: "text", color: overlayWin.drawColor, size: overlayWin.drawSize, x1: overlayWin.textX, y1: overlayWin.textY, text: text })
                        overlayWin.strokes = s
                        drawCanvas.requestPaint()
                    }
                    overlayWin.textMode = false; text = ""
                }
            }
        }

        // ── Pan area (zoom mode only) ───────────────────
        MouseArea {
            x: root.regionX; y: root.regionY
            width: root.regionW; height: root.regionH
            visible: root.zoomScale > 1.0
            hoverEnabled: true
            cursorShape: overlayWin.isPanning ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: (mouse) => {
                overlayWin.isPanning = true
                overlayWin._panStartX = overlayWin.panX; overlayWin._panStartY = overlayWin.panY
                overlayWin._panStartMouseX = mouse.x; overlayWin._panStartMouseY = mouse.y
            }
            onPositionChanged: (mouse) => {
                if (!overlayWin.isPanning) return
                overlayWin.panX = overlayWin._panStartX + (mouse.x - overlayWin._panStartMouseX)
                overlayWin.panY = overlayWin._panStartY + (mouse.y - overlayWin._panStartMouseY)
            }
            onReleased: overlayWin.isPanning = false
        }

        // ── Toolbar ────────────────────────────────────
        Rectangle {
            id: toolbar

            readonly property real spaceBelow: overlayWin.height - (root.regionY + root.regionH)
            readonly property real spaceAbove: root.regionY
            readonly property real spaceRight: overlayWin.width - (root.regionX + root.regionW)
            readonly property bool useVertical: spaceBelow < 56 && spaceAbove < 56

            width:  useVertical ? 56 : (toolbarContent.implicitWidth + Style.marginM * 2)
            height: useVertical ? (toolbarContent.implicitHeight + Style.marginM * 2) : 52

            x: useVertical
               ? (spaceRight >= 56 ? root.regionX + root.regionW + 8 : Math.max(8, root.regionX - width - 8))
               : Math.max(8, Math.min(root.regionX + (root.regionW - width) / 2, overlayWin.width - width - 8))
            y: useVertical
               ? Math.max(8, Math.min(root.regionY + (root.regionH - height) / 2, overlayWin.height - height - 8))
               : (spaceBelow >= 56 ? root.regionY + root.regionH + 8 : Math.max(8, root.regionY - height - 8))

            radius: Style.radiusL
            color: Color.mSurface
            border.color: Style.capsuleBorderColor || "transparent"
            border.width: Style.capsuleBorderWidth || 1

            component ToolbarSeparator: Rectangle {
                readonly property bool vertical: toolbar.useVertical
                width:  vertical ? 28 : 1
                height: vertical ? 1  : 28
                color: Color.mOnSurfaceVariant; opacity: 0.3
                anchors.horizontalCenter: vertical ? parent.horizontalCenter : undefined
                anchors.verticalCenter:   vertical ? undefined : parent.verticalCenter
            }

            Loader {
                id: toolbarContent
                anchors.centerIn: parent
                sourceComponent: toolbar.useVertical ? colLayout : rowLayout
            }

            readonly property var toolDefs: [
                { id: "pencil", icon: "pencil",         tooltip: "Draw freehand"  },
                { id: "arrow",  icon: "arrow-up-right", tooltip: "Draw arrow"      },
                { id: "rect",   icon: "square",         tooltip: "Draw rectangle"  },
                { id: "text",   icon: "text-size",      tooltip: "Add text"        },
                { id: "blur",   icon: "eye-off",        tooltip: "Pixelate region" }
            ]

            readonly property var colorDefs: ["#FF4444","#FF8C00","#FFD700","#44FF88","#44AAFF","#CC44FF","#FF44CC","#FFFFFF","#000000"]
            readonly property var sizeDefs:  [{ size: 2, label: "S" }, { size: 4, label: "M" }, { size: 7, label: "L" }]

            function doUndo()  { if (overlayWin.strokes.length > 0) { overlayWin.strokes = overlayWin.strokes.slice(0, -1); drawCanvas.requestPaint() } }
            function doClear() { overlayWin.strokes = []; drawCanvas.requestPaint() }
            function doClose() { overlayWin.strokes = []; root.hide() }

            component ToolBtn: Rectangle {
                property string toolId: ""
                property string iconName: ""
                property string tip: ""
                width: 34; height: 34; radius: Style.radiusS
                opacity: root.zoomScale > 1.0 ? 0.35 : 1.0
                color: overlayWin.tool === toolId ? Color.mPrimary : (tbHover.containsMouse ? Color.mHover : "transparent")
                NIcon { anchors.centerIn: parent; icon: iconName; color: overlayWin.tool === toolId ? Color.mOnPrimary : Color.mOnSurface }
                MouseArea {
                    id: tbHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    enabled: root.zoomScale <= 1.0
                    onClicked: { if (overlayWin.textMode) textInput.commitText(); overlayWin.tool = toolId; overlayWin.textMode = false }
                    onEntered: TooltipService.show(parent, tip)
                    onExited:  TooltipService.hide()
                }
            }

            component ZoomBtn: Rectangle {
                property string iconName: ""
                property string tip: ""
                property bool btnEnabled: true
                width: 28; height: 34; radius: Style.radiusS
                color: zbHover.containsMouse ? Color.mHover : "transparent"
                enabled: btnEnabled; opacity: enabled ? 1.0 : 0.3
                signal clicked()
                NIcon { anchors.centerIn: parent; icon: iconName; color: Color.mOnSurface }
                MouseArea { id: zbHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: parent.clicked()
                    onEntered: TooltipService.show(parent, tip)
                    onExited:  TooltipService.hide() }
            }

            component ActionBtn: Rectangle {
                property string iconName: ""
                property string tip: ""
                property bool danger: false
                width: 34; height: 34; radius: Style.radiusS
                color: abHover.containsMouse ? (danger ? Color.mErrorContainer || "#ffcdd2" : Color.mHover) : "transparent"
                NIcon { anchors.centerIn: parent; icon: iconName
                    color: abHover.containsMouse && danger ? Color.mError || "#f44336" : Color.mOnSurface }
                signal clicked()
                MouseArea { id: abHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: parent.clicked()
                    onEntered: TooltipService.show(parent, tip)
                    onExited:  TooltipService.hide() }
            }

            component SaveBtn: Rectangle {
                property string iconName: ""
                property string labelText: ""
                property string tip: ""
                property bool primary: false
                height: 36; radius: Style.radiusS
                width: _sbRow.implicitWidth + 32
                color: sbHover.containsMouse ? (primary ? Color.mPrimary : Color.mSecondary || Color.mPrimary) : (primary ? Color.mPrimaryContainer || Color.mSurfaceVariant : Color.mSurfaceVariant)
                opacity: overlayWin.isSaving ? 0.5 : 1.0
                signal clicked()
                Row { id: _sbRow; anchors.centerIn: parent; spacing: Style.marginXS
                    NIcon { icon: iconName; color: sbHover.containsMouse ? Color.mOnPrimary : (primary ? Color.mPrimary : Color.mOnSurface) }
                    NText { text: labelText; color: sbHover.containsMouse ? Color.mOnPrimary : (primary ? Color.mPrimary : Color.mOnSurface); font.weight: Font.Bold; pointSize: Style.fontSizeS }
                }
                MouseArea { id: sbHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !overlayWin.isSaving
                    onClicked: parent.clicked()
                    onEntered: TooltipService.show(parent, tip)
                    onExited:  TooltipService.hide() }
            }

            Component {
                id: rowLayout
                Row {
                    spacing: Style.marginXS

                    Repeater {
                        model: toolbar.toolDefs
                        ToolBtn { toolId: modelData.id; iconName: modelData.icon; tip: modelData.tooltip }
                    }

                    ToolbarSeparator {}

                    ZoomBtn {
                        iconName: "zoom-out"; tip: "Zoom out"
                        btnEnabled: root.zoomScale > 1.0
                        onClicked: overlayWin.requestZoom(Math.max(1.0, root.zoomScale - 1.0))
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.zoomScale === 1.0 ? "1×" : Math.round(root.zoomScale) + "×"
                        color: root.zoomScale > 1.0 ? Color.mPrimary : Color.mOnSurfaceVariant
                        font.pixelSize: 11; font.bold: root.zoomScale > 1.0
                        width: 22; horizontalAlignment: Text.AlignHCenter
                    }
                    ZoomBtn {
                        iconName: "zoom-in"; tip: "Zoom in (view only)"
                        btnEnabled: root.zoomScale < 5.0
                        onClicked: overlayWin.requestZoom(Math.min(5.0, root.zoomScale + 1.0))
                    }

                    ToolbarSeparator {}

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: overlayWin.drawColor
                        border.color: overlayWin.showPopover ? Color.mPrimary : Qt.rgba(0,0,0,0.2)
                        border.width: overlayWin.showPopover ? 2 : 1
                        scale: colorBtnH.containsMouse ? 1.1 : 1
                        Behavior on scale { NumberAnimation { duration: 80 } }
                        MouseArea { id: colorBtnH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: overlayWin.showPopover = !overlayWin.showPopover
                            onEntered: TooltipService.show(parent, root.mainInstance?.pluginApi?.tr("annotate.colorSize"))
                            onExited: TooltipService.hide() }
                    }

                    ToolbarSeparator {}

                    ActionBtn { iconName: "corner-up-left"; tip: "Undo last stroke";  onClicked: toolbar.doUndo() }
                    ActionBtn { iconName: "trash";          tip: "Clear all"; danger: true; onClicked: toolbar.doClear() }
                    SaveBtn   { iconName: "copy";         labelText: overlayWin.isSaving ? "Copying..." : "Copy"; tip: "Copy to clipboard"; primary: true;  onClicked: overlayWin.flattenAndCopy() }
                    SaveBtn   { iconName: "device-floppy"; labelText: overlayWin.isSaving ? "Saving..."  : "Save"; tip: "Save to ~/Pictures"; primary: false; onClicked: overlayWin.flattenAndSave() }
                    ActionBtn { iconName: "x"; tip: "Close"; onClicked: toolbar.doClose() }
                }
            }

            Component {
                id: colLayout
                Column {
                    spacing: Style.marginXS

                    Repeater {
                        model: toolbar.toolDefs
                        ToolBtn { toolId: modelData.id; iconName: modelData.icon; tip: modelData.tooltip }
                    }

                    ToolbarSeparator {}

                    ZoomBtn {
                        iconName: "zoom-out"; tip: "Zoom out"
                        btnEnabled: root.zoomScale > 1.0
                        onClicked: overlayWin.requestZoom(Math.max(1.0, root.zoomScale - 1.0))
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.zoomScale === 1.0 ? "1×" : Math.round(root.zoomScale) + "×"
                        color: root.zoomScale > 1.0 ? Color.mPrimary : Color.mOnSurfaceVariant
                        font.pixelSize: 10; font.bold: root.zoomScale > 1.0
                    }
                    ZoomBtn {
                        iconName: "zoom-in"; tip: "Zoom in (view only)"
                        btnEnabled: root.zoomScale < 5.0
                        onClicked: overlayWin.requestZoom(Math.min(5.0, root.zoomScale + 1.0))
                    }

                    ToolbarSeparator {}

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: overlayWin.drawColor
                        border.color: overlayWin.showPopover ? Color.mPrimary : Qt.rgba(0,0,0,0.2)
                        border.width: overlayWin.showPopover ? 2 : 1
                        scale: colorBtnV.containsMouse ? 1.1 : 1
                        Behavior on scale { NumberAnimation { duration: 80 } }
                        MouseArea { id: colorBtnV; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: overlayWin.showPopover = !overlayWin.showPopover
                            onEntered: TooltipService.show(parent, root.mainInstance?.pluginApi?.tr("annotate.colorSize"))
                            onExited: TooltipService.hide() }
                    }

                    ToolbarSeparator {}

                    ActionBtn { iconName: "corner-up-left"; tip: "Undo last stroke";  onClicked: toolbar.doUndo() }
                    ActionBtn { iconName: "trash";          tip: "Clear all"; danger: true; onClicked: toolbar.doClear() }
                    ActionBtn { iconName: "copy";           tip: "Copy to clipboard";  onClicked: overlayWin.flattenAndCopy() }
                    ActionBtn { iconName: "device-floppy";  tip: "Save to ~/Pictures"; onClicked: overlayWin.flattenAndSave() }
                    ActionBtn { iconName: "x";              tip: "Close";              onClicked: toolbar.doClose() }
                }
            }
        }

        // ── Color & Size Popover ───────────────────────
        Rectangle {
            id: popover
            visible: overlayWin.showPopover
            radius: Style.radiusL
            color: Color.mSurface
            border.color: Style.capsuleBorderColor || "transparent"
            border.width: Style.capsuleBorderWidth || 1

            width:  toolbar.useVertical ? (popContent.implicitWidth + 12)  : (popContent.implicitWidth + 16)
            height: toolbar.useVertical ? (popContent.implicitHeight + 16) : (popContent.implicitHeight + 12)

            x: toolbar.useVertical
               ? (toolbar.spaceRight >= 56 ? toolbar.x + toolbar.width + 6 : toolbar.x - width - 6)
               : Math.max(8, Math.min(toolbar.x + (toolbar.width - width) / 2, overlayWin.width - width - 8))
            y: toolbar.useVertical
               ? Math.max(8, Math.min(toolbar.y + (toolbar.height - height) / 2, overlayWin.height - height - 8))
               : (toolbar.spaceAbove >= height + 10 ? toolbar.y - height - 6 : toolbar.y + toolbar.height + 6)

            Loader {
                id: popContent
                anchors.centerIn: parent
                sourceComponent: toolbar.useVertical ? popColComp : popRowComp
            }

            Component {
                id: popRowComp
                Row {
                    spacing: Style.marginS

                    Repeater {
                        model: toolbar.colorDefs
                        delegate: Rectangle {
                            width: 20; height: 20; radius: 10; color: modelData
                            border.color: overlayWin.drawColor === modelData ? Color.mPrimary : Qt.rgba(0,0,0,0.15)
                            border.width: overlayWin.drawColor === modelData ? 2 : 1
                            scale: chH.containsMouse ? 1.2 : 1
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            MouseArea { id: chH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { overlayWin.drawColor = modelData; overlayWin.showPopover = false } }
                        }
                    }

                    Rectangle { width: 1; height: 16; color: Color.mOnSurfaceVariant; opacity: 0.3; anchors.verticalCenter: parent.verticalCenter }

                    Repeater {
                        model: toolbar.sizeDefs
                        delegate: Rectangle {
                            width: 28; height: 24; radius: Style.radiusS
                            color: overlayWin.drawSize === modelData.size ? Color.mPrimaryContainer || Color.mSurfaceVariant : (shH.containsMouse ? Color.mHover : "transparent")
                            border.color: overlayWin.drawSize === modelData.size ? Color.mPrimary : "transparent"; border.width: 1
                            Row { anchors.centerIn: parent; spacing: 3
                                Rectangle { width: modelData.size*2; height: modelData.size*2; radius: modelData.size; color: overlayWin.drawColor; anchors.verticalCenter: parent.verticalCenter }
                                NText { text: modelData.label; pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: shH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { overlayWin.drawSize = modelData.size; overlayWin.showPopover = false } }
                        }
                    }
                }
            }

            Component {
                id: popColComp
                Column {
                    spacing: Style.marginXS

                    Repeater {
                        model: toolbar.colorDefs
                        delegate: Rectangle {
                            width: 20; height: 20; radius: 10; color: modelData
                            border.color: overlayWin.drawColor === modelData ? Color.mPrimary : Qt.rgba(0,0,0,0.15)
                            border.width: overlayWin.drawColor === modelData ? 2 : 1
                            scale: chV.containsMouse ? 1.2 : 1
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            MouseArea { id: chV; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { overlayWin.drawColor = modelData; overlayWin.showPopover = false } }
                        }
                    }

                    Rectangle { width: 16; height: 1; color: Color.mOnSurfaceVariant; opacity: 0.3; anchors.horizontalCenter: parent.horizontalCenter }

                    Repeater {
                        model: toolbar.sizeDefs
                        delegate: Rectangle {
                            width: 32; height: 24; radius: Style.radiusS
                            color: overlayWin.drawSize === modelData.size ? Color.mPrimaryContainer || Color.mSurfaceVariant : (shV.containsMouse ? Color.mHover : "transparent")
                            border.color: overlayWin.drawSize === modelData.size ? Color.mPrimary : "transparent"; border.width: 1
                            Row { anchors.centerIn: parent; spacing: 3
                                Rectangle { width: modelData.size*2; height: modelData.size*2; radius: modelData.size; color: overlayWin.drawColor; anchors.verticalCenter: parent.verticalCenter }
                                NText { text: modelData.label; pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: shV; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { overlayWin.drawSize = modelData.size; overlayWin.showPopover = false } }
                        }
                    }
                }
            }
        }

        // ── Save / Copy functions ──────────────────────
        function flattenAndSave() {
            if (overlayWin.isSaving) return
            overlayWin.isSaving = true
            var ts = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19)
            var filename = "annotate-" + ts + ".png"
            saveFileProc.savedPath = filename
            if (root.zoomScale > 1.0) {
                saveFileProc.exec({ command: [
                    "bash", "-c",
                    "DEST=$([ -d \"$HOME/Pictures/Screenshots\" ] && echo \"$HOME/Pictures/Screenshots\" || echo \"$HOME/Pictures\"); " +
                    "cp " + root.imagePath + " \"$DEST/" + filename + "\" && echo \"$DEST\""
                ]})
            } else {
                var dpr = overlayWin.screen?.devicePixelRatio ?? 1.0
                var pw = Math.round(root.regionW * dpr)
                var ph = Math.round(root.regionH * dpr)
                drawCanvas.grabToImage(function(result) {
                    result.saveToFile("/tmp/screen-toolkit-overlay.png")
                    saveFileProc.exec({ command: [
                        "bash", "-c",
                        "DEST=$([ -d \"$HOME/Pictures/Screenshots\" ] && echo \"$HOME/Pictures/Screenshots\" || echo \"$HOME/Pictures\"); " +
                        "magick /tmp/screen-toolkit-overlay.png -resize " + pw + "x" + ph + "! /tmp/screen-toolkit-overlay-hires.png && " +
                        "magick /tmp/screen-toolkit-annotate.png /tmp/screen-toolkit-overlay-hires.png " +
                        "-composite \"$DEST/" + filename + "\" && " +
                        "rm -f /tmp/screen-toolkit-overlay.png /tmp/screen-toolkit-overlay-hires.png && echo \"$DEST\""
                    ]})
                })
            }
        }

        function flattenAndCopy() {
            if (overlayWin.isSaving) return
            overlayWin.isSaving = true
            if (root.zoomScale > 1.0) {
                copyProc.exec({ command: ["bash", "-c", "wl-copy < " + root.imagePath] })
            } else {
                var dpr = overlayWin.screen?.devicePixelRatio ?? 1.0
                var pw = Math.round(root.regionW * dpr)
                var ph = Math.round(root.regionH * dpr)
                drawCanvas.grabToImage(function(result) {
                    result.saveToFile("/tmp/screen-toolkit-overlay.png")
                    saveProc.exec({ command: [
                        "bash", "-c",
                        "magick /tmp/screen-toolkit-overlay.png -resize " + pw + "x" + ph + "! /tmp/screen-toolkit-overlay-hires.png && " +
                        "magick /tmp/screen-toolkit-annotate.png /tmp/screen-toolkit-overlay-hires.png " +
                        "-composite /tmp/screen-toolkit-annotated.png && " +
                        "wl-copy < /tmp/screen-toolkit-annotated.png && " +
                        "rm -f /tmp/screen-toolkit-overlay.png /tmp/screen-toolkit-overlay-hires.png"
                    ]})
                })
            }
        }
    }
}
