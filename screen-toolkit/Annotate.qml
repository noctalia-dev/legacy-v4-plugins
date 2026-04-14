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
    property var    mainInstance: null
    property bool   isVisible: false
    property int  regionX: 0
    property int  regionY: 0
    property int  regionW: 0
    property int  regionH: 0
    property real   zoomScale:  1.0
    property string lastRegion: ""
    property var _primaryScreen: null
    function parseAndShow(regionStr, imgPath, screen) {
        var parts = regionStr.trim().split(" ")
        if (parts.length < 2) return
        var xy = parts[0].split(",")
        var wh = parts[1].split("x")
        regionX      = parseInt(xy[0]) || 0
        regionY      = parseInt(xy[1]) || 0
        regionW      = parseInt(wh[0]) || 400
        regionH      = parseInt(wh[1]) || 300
        zoomScale    = 1.0
        lastRegion   = regionStr
        imagePath    = imgPath
        _resetToken  = !_resetToken
        _primaryScreen = screen ?? Quickshell.screens[0] ?? null
        isVisible    = true
    }
    function parseAndShowZoomed(regionStr, imgPath, scale) {
        var parts = regionStr.trim().split(" ")
        if (parts.length < 2) return
        var xy = parts[0].split(",")
        var wh = parts[1].split("x")
        regionX     = parseInt(xy[0]) || 0
        regionY     = parseInt(xy[1]) || 0
        regionW     = parseInt(wh[0]) || 400
        regionH     = parseInt(wh[1]) || 300
        zoomScale   = scale
        imagePath   = imgPath
        _resetToken = !_resetToken
        isVisible   = true
    }
    property bool _resetToken: false
    function hide() {
        isVisible      = false
        _primaryScreen = null
    }
    function _expandPath(p) {
        if (!p || p === "") return ""
        if (p.startsWith("~/"))
            return (Quickshell.env("HOME") || "") + p.substring(1)
        return p
    }
    function _buildFilename(toolName, ext) {
        var fmt = mainInstance?.pluginApi?.pluginSettings?.filenameFormat ?? ""
        if (fmt.trim() !== "") {
            var now  = new Date()
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
    function _annotateOutputDir() {
        var custom = mainInstance?.pluginApi?.pluginSettings?.screenshotPath ?? ""
        if (custom !== "") return _expandPath(custom.replace(/\/$/, ""))
        return "__auto__"
    }
    model: Quickshell.screens
    delegate: PanelWindow {
        id: overlayWin
        required property ShellScreen modelData
        readonly property bool isPrimary: modelData === root._primaryScreen
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color:   "transparent"
        visible: root.isVisible
        WlrLayershell.layer:         WlrLayer.Top
        WlrLayershell.keyboardFocus: (root.isVisible && isPrimary)
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace:     "noctalia-annotate"
        Item { id: fullMask; anchors.fill: parent }
        mask: Region { item: !overlayWin.isPrimary ? null : fullMask }
        readonly property real localX: root.regionX
        readonly property real localY: root.regionY
        property string tool:         "pencil"
        property color  drawColor:    "#FF4444"
        property int    drawSize:     3
        property var    strokes:      []
        property var    currentStroke: null
        property bool   drawing:      false
        property bool   textMode:     false
        property bool   isSaving:     false
        property real   textX:        0
        property real   textY:        0
        property bool   pixelImgReady: false
        property bool   showPopover:  false
        property int    _pixelCacheBust: 0
        property real _pendingZoomScale: 1.0
        property real panX:              0.0
        property real panY:              0.0
        property real _panStartX:        0.0
        property real _panStartY:        0.0
        property real _panStartMouseX:   0.0
        property real _panStartMouseY:   0.0
        property bool isPanning:         false
        property var  _savedStrokes:     []
        property real _tbUserX: -1
        property real _tbUserY: -1
        property real _lastMouseX:  0
        property real _lastMouseY:  0
        property real _speedSmooth: 0
        property bool _cacheValid:      false
        property bool _cacheRebuilding: false
        function _invalidateCache() {
            _cacheValid      = false
            _cacheRebuilding = false
        }
        function _rebuildCache() {
            if (overlayWin._cacheRebuilding) return
            overlayWin._cacheRebuilding = true
            var ctx    = cacheCanvas.getContext("2d")
            var pixUrl = "file:///tmp/screen-toolkit-annotate-pixel.png?" + overlayWin._pixelCacheBust
            ctx.clearRect(0, 0, cacheCanvas.width, cacheCanvas.height)
            if (overlayWin.pixelImgReady && !cacheCanvas.isImageLoaded(pixUrl))
                cacheCanvas.loadImage(pixUrl)
            for (var i = 0; i < overlayWin.strokes.length; i++)
                overlayWin._drawStrokeToCtx(ctx, overlayWin.strokes[i])
            overlayWin._cacheValid      = true
            overlayWin._cacheRebuilding = false
        }
        function _drawStrokeToCtx(ctx, stroke) {
            ctx.save()
            ctx.strokeStyle = stroke.color
            ctx.fillStyle   = stroke.color
            ctx.lineWidth   = stroke.size
            ctx.lineCap     = "round"
            ctx.lineJoin    = "round"
            ctx.globalAlpha = 1.0
            if (stroke.type === "blur" && !stroke.preview) {
                var bx = Math.min(stroke.x1, stroke.x2)
                var by = Math.min(stroke.y1, stroke.y2)
                var bw = Math.abs(stroke.x2 - stroke.x1)
                var bh = Math.abs(stroke.y2 - stroke.y1)
                if (bw > 0 && bh > 0) {
                    var pixUrl = "file:///tmp/screen-toolkit-annotate-pixel.png?" + overlayWin._pixelCacheBust
                    if (cacheCanvas.isImageLoaded(pixUrl)) {
                        ctx.beginPath()
                        ctx.rect(bx, by, bw, bh)
                        ctx.clip()
                        ctx.drawImage(pixUrl, 0, 0, root.regionW, root.regionH)
                    }
                }
            } else if (stroke.type === "pencil" && stroke.points.length > 1) {
                var pts = stroke.points
                for (var si = 1; si < pts.length; si++) {
                    ctx.lineWidth = pts[si].w !== undefined ? pts[si].w : stroke.size
                    ctx.beginPath()
                    if (si === 1) {
                        ctx.moveTo(pts[0].x, pts[0].y)
                        ctx.lineTo(pts[1].x, pts[1].y)
                    } else {
                        var pmx = (pts[si - 2].x + pts[si - 1].x) / 2
                        var pmy = (pts[si - 2].y + pts[si - 1].y) / 2
                        var cmx = (pts[si - 1].x + pts[si].x)     / 2
                        var cmy = (pts[si - 1].y + pts[si].y)     / 2
                        ctx.moveTo(pmx, pmy)
                        ctx.quadraticCurveTo(pts[si - 1].x, pts[si - 1].y, cmx, cmy)
                    }
                    ctx.stroke()
                }
            } else if (stroke.type === "highlighter" && stroke.points.length > 1) {
                var hpts = stroke.points
                ctx.globalAlpha = 0.35
                ctx.lineWidth   = stroke.size * 6
                ctx.lineCap     = "square"
                ctx.beginPath()
                ctx.moveTo(hpts[0].x, hpts[0].y)
                for (var hj = 1; hj < hpts.length - 1; hj++) {
                    var hmx = (hpts[hj].x + hpts[hj + 1].x) / 2
                    var hmy = (hpts[hj].y + hpts[hj + 1].y) / 2
                    ctx.quadraticCurveTo(hpts[hj].x, hpts[hj].y, hmx, hmy)
                }
                ctx.lineTo(hpts[hpts.length - 1].x, hpts[hpts.length - 1].y)
                ctx.stroke()
            } else if (stroke.type === "line") {
                ctx.beginPath()
                ctx.moveTo(stroke.x1, stroke.y1)
                ctx.lineTo(stroke.x2, stroke.y2)
                ctx.stroke()
            } else if (stroke.type === "arrow") {
                var dx    = stroke.x2 - stroke.x1
                var dy    = stroke.y2 - stroke.y1
                var len   = Math.sqrt(dx * dx + dy * dy)
                if (len < 2) { ctx.restore(); return }
                var angle = Math.atan2(dy, dx)
                var hs    = Math.max(stroke.size * 3.5, 10)
                var hw    = Math.PI / 5
                var baseFrac = Math.max(0, 1 - hs / len)
                var bx    = stroke.x1 + dx * baseFrac
                var by    = stroke.y1 + dy * baseFrac
                ctx.beginPath()
                ctx.moveTo(stroke.x1, stroke.y1)
                ctx.lineTo(bx, by)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(stroke.x2, stroke.y2)
                ctx.lineTo(stroke.x2 - hs * Math.cos(angle - hw),
                           stroke.y2 - hs * Math.sin(angle - hw))
                ctx.lineTo(stroke.x2 - hs * Math.cos(angle + hw),
                           stroke.y2 - hs * Math.sin(angle + hw))
                ctx.closePath()
                ctx.fill()
            } else if (stroke.type === "rect") {
                ctx.beginPath()
                ctx.strokeRect(stroke.x1, stroke.y1,
                               stroke.x2 - stroke.x1, stroke.y2 - stroke.y1)
            } else if (stroke.type === "circle") {
                var rx = Math.abs(stroke.x2 - stroke.x1)
                var ry = Math.abs(stroke.y2 - stroke.y1)
                if (rx > 0 || ry > 0) {
                    ctx.beginPath()
                    ctx.ellipse(stroke.x1, stroke.y1,
                                Math.max(rx, 1), Math.max(ry, 1),
                                0, 0, Math.PI * 2)
                    ctx.stroke()
                }
            } else if (stroke.type === "text") {
                ctx.font = (stroke.size * 5 + 12) + "px sans-serif"
                ctx.fillText(stroke.text, stroke.x1, stroke.y1)
            }
            ctx.restore()
        }
        function requestZoom(scale) {
            var region = root.lastRegion
            if (region === "") return
            if (scale === 1.0) {
                overlayWin.strokes       = overlayWin._savedStrokes.slice()
                overlayWin._savedStrokes = []
                overlayWin.panX          = 0.0
                overlayWin.panY          = 0.0
                root.parseAndShow(region, "/tmp/screen-toolkit-annotate.png", root._primaryScreen)
                _invalidateCache()
                drawCanvas.requestPaint()
                return
            }
            if (root.zoomScale === 1.0) {
                overlayWin._savedStrokes = overlayWin.strokes.slice()
                overlayWin.strokes       = []
                overlayWin.currentStroke = null
            }
            _pendingZoomScale = scale
            overlayWin.panX   = 0.0
            overlayWin.panY   = 0.0
            var newW = Math.round(root.regionW * scale)
            var newH = Math.round(root.regionH * scale)
            zoomProc.exec({ command: [
                "bash", "-c",
                "magick /tmp/screen-toolkit-annotate.png -resize "
                    + newW + "x" + newH + "! /tmp/screen-toolkit-annotate-zoom.png 2>/dev/null"
            ]})
        }
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
            var basePath = "/tmp/screen-toolkit-annotate.png"
            if (basePath === overlayWin._lastPreparedPath && overlayWin.pixelImgReady) {
                drawCanvas.requestPaint()
                return
            }
            overlayWin._lastPreparedPath = basePath
            pixelImgReady = false
            pixelateProc.exec({ command: [
                "bash", "-c",
                "magick /tmp/screen-toolkit-annotate.png -scale 5% -scale 2000% "
                    + "/tmp/screen-toolkit-annotate-pixel.png 2>/dev/null"
            ]})
        }
        onPixelImgReadyChanged: {
            if (pixelImgReady) {
                var stale = "file:///tmp/screen-toolkit-annotate-pixel.png?"
                    + (overlayWin._pixelCacheBust - 1)
                cacheCanvas.unloadImage(stale)
                drawCanvas.unloadImage(stale)
                _invalidateCache()
                drawCanvas.requestPaint()
            }
        }
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
            stdout: StdioCollector {}
            onExited: (code) => {
                overlayWin.isSaving = false
                if (code === 0) {
                    var dest = saveFileProc.stdout.text.trim()
                    ToastService.showNotice(
                        root.mainInstance?.pluginApi?.tr("annotate.savedTo", { dest: dest }),
                        dest,
                        "device-floppy")
                    root.hide()
                } else {
                    ToastService.showError(root.mainInstance?.pluginApi?.tr("annotate.saveFileFailed"))
                }
            }
        }
        Process { id: cleanupProc }
        Shortcut {
            sequence: "Escape"
            onActivated: {
                if (overlayWin.isSaving) return
                overlayWin.strokes = []
                _invalidateCache()
                root.hide()
            }
        }
        Connections {
            target: root
            function onIsVisibleChanged() {
                if (!overlayWin.isPrimary) return
                if (!root.isVisible) {
                    overlayWin.strokes           = []
                    overlayWin._savedStrokes     = []
                    overlayWin.currentStroke     = null
                    overlayWin.drawing           = false
                    overlayWin.textMode          = false
                    overlayWin.showPopover       = false
                    overlayWin.pixelImgReady     = false
                    overlayWin._lastPreparedPath = ""
                    overlayWin.panX              = 0.0
                    overlayWin.panY              = 0.0
                    overlayWin.isPanning         = false
                    overlayWin._cacheValid       = false
                    overlayWin._tbUserX          = -1
                    overlayWin._tbUserY          = -1
                    drawCanvas.requestPaint()
                    cleanupProc.exec({ command: ["bash", "-c", "rm -f /tmp/screen-toolkit-annotate-zoom.png"] })
                } else {
                    overlayWin.preparePixelImage()
                }
            }
        }
        Rectangle {
            visible: overlayWin.isPrimary
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                    var ix = overlayWin.localX
                    var iy = overlayWin.localY
                    var iw = root.regionW
                    var ih = root.regionH
                    var inRegion  = mouse.x >= ix && mouse.x <= ix + iw
                                 && mouse.y >= iy && mouse.y <= iy + ih
                    var inToolbar = mouse.x >= toolbar.x && mouse.x <= toolbar.x + toolbar.width
                                 && mouse.y >= toolbar.y && mouse.y <= toolbar.y + toolbar.height
                    var inPopover = overlayWin.showPopover
                                 && mouse.x >= popover.x && mouse.x <= popover.x + popover.width
                                 && mouse.y >= popover.y && mouse.y <= popover.y + popover.height
                    if (!inRegion && !inToolbar && !inPopover) {
                        overlayWin.strokes = []
                        _invalidateCache()
                        root.hide()
                    }
                }
            }
        }
        Item {
            id: captureRoot
            visible: overlayWin.isPrimary
            x: overlayWin.localX
            y: overlayWin.localY
            width:  root.regionW
            height: root.regionH
            clip:   true
            Image {
                id: imgLoader
                width:  root.zoomScale > 1.0 ? root.regionW * root.zoomScale : root.regionW
                height: root.zoomScale > 1.0 ? root.regionH * root.zoomScale : root.regionH
                x: root.zoomScale > 1.0
                   ? Math.max(root.regionW - width,  Math.min(0, (root.regionW - width)  / 2 + overlayWin.panX))
                   : 0
                y: root.zoomScale > 1.0
                   ? Math.max(root.regionH - height, Math.min(0, (root.regionH - height) / 2 + overlayWin.panY))
                   : 0
                source: root.isVisible && overlayWin.isPrimary
                    ? "file://" + root.imagePath + "?v=" + root._resetToken
                    : ""
                fillMode: Image.Stretch
                cache:    false
                smooth:   true
            }
            Repeater {
                model: overlayWin.strokes.filter(s => s.type === "blur" && !s.preview)
                delegate: Item {
                    x:      Math.min(modelData.x1, modelData.x2)
                    y:      Math.min(modelData.y1, modelData.y2)
                    width:  Math.abs(modelData.x2 - modelData.x1)
                    height: Math.abs(modelData.y2 - modelData.y1)
                    clip:   true
                    Image {
                        x: -parent.x; y: -parent.y
                        width:  root.regionW
                        height: root.regionH
                        source: overlayWin.pixelImgReady
                            ? "file:///tmp/screen-toolkit-annotate-pixel.png?" + overlayWin._pixelCacheBust
                            : ""
                        fillMode: Image.Stretch
                        cache:    false
                        smooth:   false
                    }
                }
            }
        }
        Rectangle {
            visible: overlayWin.isPrimary
                  && root.zoomScale <= 1.0
                  && overlayWin.drawing
                  && overlayWin.currentStroke !== null
                  && overlayWin.currentStroke.type === "blur"
            x: overlayWin.localX
                + (overlayWin.currentStroke ? Math.min(overlayWin.currentStroke.x1, overlayWin.currentStroke.x2) : 0)
            y: overlayWin.localY
                + (overlayWin.currentStroke ? Math.min(overlayWin.currentStroke.y1, overlayWin.currentStroke.y2) : 0)
            width:  overlayWin.currentStroke ? Math.abs(overlayWin.currentStroke.x2 - overlayWin.currentStroke.x1) : 0
            height: overlayWin.currentStroke ? Math.abs(overlayWin.currentStroke.y2 - overlayWin.currentStroke.y1) : 0
            color:        "transparent"
            border.color: "#ffffff"
            border.width: Style.borderM
            opacity:      0.8
        }
        Rectangle {
            visible: overlayWin.isPrimary && root.zoomScale > 1.0
            x:      overlayWin.localX + root.regionW - width - Style.marginXS
            y:      overlayWin.localY + Style.marginXS
            width:  zoomBadgeRow.implicitWidth + Style.marginS * 2
            height: 22
            radius: Style.radiusS
            color:  Qt.rgba(0, 0, 0, 0.6)
            Row {
                id: zoomBadgeRow
                anchors.centerIn: parent
                spacing: Style.marginXS
                NIcon { icon: "zoom-in"; color: "#ffffff" }
                NText {
                    text:       Math.round(root.zoomScale) + "× — view only"
                    color:      "#ffffff"
                    pointSize:  Style.fontSizeXS
                }
            }
        }
        Canvas {
            id: cacheCanvas
            width:   root.regionW
            height:  root.regionH
            visible: false
            onImageLoaded: {
                overlayWin._rebuildCache()
                drawCanvas.requestPaint()
            }
        }
        Canvas {
            id: drawCanvas
            visible: overlayWin.isPrimary && root.zoomScale <= 1.0
            x:      overlayWin.localX
            y:      overlayWin.localY
            width:  root.regionW
            height: root.regionH
            onImageLoaded: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (!overlayWin._cacheValid) overlayWin._rebuildCache()
                ctx.drawImage(cacheCanvas, 0, 0)
                if (overlayWin.currentStroke && overlayWin.drawing)
                    overlayWin._drawStrokeToCtx(ctx, overlayWin.currentStroke)
            }
            function eraseAt(ex, ey) {
                var r  = overlayWin.drawSize * 12
                var r2 = r * r
                function seg2(px, py, ax, ay, bx, by) {
                    var dx = bx - ax, dy = by - ay
                    var l2 = dx * dx + dy * dy
                    if (l2 === 0) {
                        var ex2 = px - ax, ey2 = py - ay
                        return ex2 * ex2 + ey2 * ey2
                    }
                    var t  = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2))
                    var nx = ax + t * dx - px
                    var ny = ay + t * dy - py
                    return nx * nx + ny * ny
                }
                for (var i = overlayWin.strokes.length - 1; i >= 0; i--) {
                    var s   = overlayWin.strokes[i]
                    var hit = false
                    if (s.points) {
                        for (var p = 0; p < s.points.length; p++) {
                            var dx = s.points[p].x - ex
                            var dy = s.points[p].y - ey
                            if (dx * dx + dy * dy < r2) { hit = true; break }
                        }
                    } else if (s.type === "line" || s.type === "arrow") {
                        hit = seg2(ex, ey, s.x1, s.y1, s.x2, s.y2) < r2
                    } else if (s.type === "rect" || s.type === "blur") {
                        var lx = Math.min(s.x1, s.x2); var rx2 = Math.max(s.x1, s.x2)
                        var ty = Math.min(s.y1, s.y2); var by2 = Math.max(s.y1, s.y2)
                        hit = seg2(ex, ey, lx,  ty,  rx2, ty)  < r2
                           || seg2(ex, ey, rx2, ty,  rx2, by2) < r2
                           || seg2(ex, ey, rx2, by2, lx,  by2) < r2
                           || seg2(ex, ey, lx,  by2, lx,  ty)  < r2
                    } else if (s.type === "circle") {
                        var cdx  = ex - s.x1
                        var cdy  = ey - s.y1
                        var erx  = Math.max(Math.abs(s.x2 - s.x1), 1)
                        var ery  = Math.max(Math.abs(s.y2 - s.y1), 1)
                        var norm = Math.sqrt((cdx / erx) * (cdx / erx) + (cdy / ery) * (cdy / ery))
                        hit = Math.abs(norm - 1.0) < (r / Math.max(erx, ery))
                    } else if (s.type === "text") {
                        var tdx = ex - s.x1
                        var tdy = ey - s.y1
                        hit = tdx * tdx + tdy * tdy < r2 * 4
                    }
                    if (hit) {
                        var arr = overlayWin.strokes.slice()
                        arr.splice(i, 1)
                        overlayWin.strokes = arr
                        overlayWin._invalidateCache()
                        requestPaint()
                        return
                    }
                }
            }
            MouseArea {
                anchors.fill:    parent
                hoverEnabled:    true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape:     overlayWin.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                onPressed: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        overlayWin.drawing       = false
                        overlayWin.currentStroke = null
                        drawCanvas.eraseAt(mouse.x, mouse.y)
                        return
                    }
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
                    var col = overlayWin.drawColor.toString()
                    if (overlayWin.tool === "pencil" || overlayWin.tool === "highlighter") {
                        overlayWin._lastMouseX  = mouse.x
                        overlayWin._lastMouseY  = mouse.y
                        overlayWin._speedSmooth = overlayWin.drawSize
                        overlayWin.currentStroke = {
                            type:   overlayWin.tool,
                            color:  col,
                            size:   overlayWin.drawSize,
                            points: [{ x: mouse.x, y: mouse.y, w: overlayWin.drawSize }]
                        }
                    } else if (overlayWin.tool === "blur") {
                        overlayWin.currentStroke = {
                            type: "blur", color: col, size: overlayWin.drawSize,
                            x1: mouse.x, y1: mouse.y, x2: mouse.x, y2: mouse.y, preview: true
                        }
                    } else {
                        overlayWin.currentStroke = {
                            type: overlayWin.tool, color: col, size: overlayWin.drawSize,
                            x1: mouse.x, y1: mouse.y, x2: mouse.x, y2: mouse.y
                        }
                    }
                }
                onPositionChanged: (mouse) => {
                    if (mouse.buttons & Qt.RightButton) {
                        overlayWin.drawing       = false
                        overlayWin.currentStroke = null
                        drawCanvas.eraseAt(mouse.x, mouse.y)
                        return
                    }
                    if (!overlayWin.drawing || !overlayWin.currentStroke) return
                    if (overlayWin.tool === "pencil" || overlayWin.tool === "highlighter") {
                        var s    = overlayWin.currentStroke
                        var pts  = s.points.slice()
                        var newW = s.size
                        if (s.type === "pencil") {
                            var ddx   = mouse.x - overlayWin._lastMouseX
                            var ddy   = mouse.y - overlayWin._lastMouseY
                            var speed = Math.sqrt(ddx * ddx + ddy * ddy)
                            overlayWin._speedSmooth = overlayWin._speedSmooth * 0.7 + speed * 0.3
                            var minW = Math.max(1, s.size * 0.35)
                            var maxW = s.size * 1.6
                            var t    = Math.min(overlayWin._speedSmooth, 20) / 20
                            newW = maxW - t * (maxW - minW)
                        }
                        overlayWin._lastMouseX = mouse.x
                        overlayWin._lastMouseY = mouse.y
                        pts.push({ x: mouse.x, y: mouse.y, w: newW })
                        if (pts.length > 2000) {
                            var committed = overlayWin.strokes.slice()
                            committed.push({ type: s.type, color: s.color, size: s.size, points: pts })
                            overlayWin.strokes       = committed
                            overlayWin.currentStroke = {
                                type: s.type, color: s.color, size: s.size,
                                points: [pts[pts.length - 1]]
                            }
                            overlayWin._invalidateCache()
                            drawCanvas.requestPaint()
                            return
                        }
                        overlayWin.currentStroke = { type: s.type, color: s.color, size: s.size, points: pts }
                    } else {
                        overlayWin.currentStroke = {
                            type:    overlayWin.currentStroke.type,
                            color:   overlayWin.currentStroke.color,
                            size:    overlayWin.currentStroke.size,
                            x1:      overlayWin.currentStroke.x1,
                            y1:      overlayWin.currentStroke.y1,
                            x2:      mouse.x,
                            y2:      mouse.y,
                            preview: true
                        }
                    }
                    drawCanvas.requestPaint()
                }
                onReleased: (mouse) => {
                    if (mouse.button === Qt.RightButton) return
                    if (!overlayWin.drawing || !overlayWin.currentStroke) return
                    overlayWin.drawing = false
                    var stroke = overlayWin.currentStroke
                    if (stroke.type === "blur")
                        stroke = {
                            type: "blur", color: stroke.color, size: stroke.size,
                            x1: stroke.x1, y1: stroke.y1, x2: stroke.x2, y2: stroke.y2,
                            preview: false
                        }
                    var s = overlayWin.strokes.slice()
                    s.push(stroke)
                    overlayWin.strokes = s
                    var cctx = cacheCanvas.getContext("2d")
                    overlayWin._drawStrokeToCtx(cctx, stroke)
                    overlayWin._cacheValid   = true
                    overlayWin.currentStroke = null
                    drawCanvas.requestPaint()
                }
            }
            TextInput {
                id: textInput
                visible:        overlayWin.textMode
                x:              overlayWin.textX
                y:              overlayWin.textY - height
                width:          Math.min(300, drawCanvas.width - x - 4)
                color:          overlayWin.drawColor
                font.pixelSize: overlayWin.drawSize * 5 + 12
                font.bold:      true
                Keys.onReturnPressed: commitText()
                Keys.onEscapePressed: { overlayWin.textMode = false; text = "" }
                function commitText() {
                    if (text.trim() !== "") {
                        var stroke = {
                            type:  "text",
                            color: overlayWin.drawColor.toString(),
                            size:  overlayWin.drawSize,
                            x1:    overlayWin.textX,
                            y1:    overlayWin.textY,
                            text:  text
                        }
                        var s = overlayWin.strokes.slice()
                        s.push(stroke)
                        overlayWin.strokes = s
                        var cctx = cacheCanvas.getContext("2d")
                        overlayWin._drawStrokeToCtx(cctx, stroke)
                        overlayWin._cacheValid = true
                        drawCanvas.requestPaint()
                    }
                    overlayWin.textMode = false
                    text = ""
                }
            }
        }
        MouseArea {
            visible:      overlayWin.isPrimary && root.zoomScale > 1.0
            x:            overlayWin.localX
            y:            overlayWin.localY
            width:        root.regionW
            height:       root.regionH
            hoverEnabled: true
            cursorShape:  overlayWin.isPanning ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: (mouse) => {
                overlayWin.isPanning       = true
                overlayWin._panStartX      = overlayWin.panX
                overlayWin._panStartY      = overlayWin.panY
                overlayWin._panStartMouseX = mouse.x
                overlayWin._panStartMouseY = mouse.y
            }
            onPositionChanged: (mouse) => {
                if (!overlayWin.isPanning) return
                overlayWin.panX = overlayWin._panStartX + (mouse.x - overlayWin._panStartMouseX)
                overlayWin.panY = overlayWin._panStartY + (mouse.y - overlayWin._panStartMouseY)
            }
            onReleased: overlayWin.isPanning = false
        }
        Rectangle {
            id: toolbar
            visible: overlayWin.isPrimary
            readonly property real spaceBelow: overlayWin.height - (overlayWin.localY + root.regionH)
            readonly property real spaceAbove: overlayWin.localY
            readonly property real spaceRight: overlayWin.width  - (overlayWin.localX + root.regionW)
            readonly property bool useVertical: spaceBelow < 56 && spaceAbove < 52
            width:  useVertical ? 56 : (toolbarContent.implicitWidth + Style.marginS * 2)
            height: useVertical ? (toolbarContent.implicitHeight + Style.marginS * 2) : 52
            readonly property real _autoX: useVertical
                ? (spaceRight >= 56
                    ? Math.min(overlayWin.localX + root.regionW + Style.marginS, overlayWin.width - width - Style.marginS)
                    : Math.max(Style.marginS, overlayWin.localX - width - Style.marginS))
                : Math.max(Style.marginS, Math.min(overlayWin.localX + (root.regionW - width) / 2, overlayWin.width - width - Style.marginS))
            readonly property real _autoY: useVertical
                ? Math.max(Style.marginS, Math.min(overlayWin.localY + (root.regionH - height) / 2, overlayWin.height - height - Style.marginS))
                : (spaceBelow >= 56
                    ? overlayWin.localY + root.regionH + Style.marginS
                    : Math.max(Style.marginS, overlayWin.localY - height - Style.marginS))
            x: overlayWin._tbUserX >= 0
               ? Math.max(0, Math.min(overlayWin.width  - width,  overlayWin._tbUserX))
               : _autoX
            y: overlayWin._tbUserY >= 0
               ? Math.max(0, Math.min(overlayWin.height - height, overlayWin._tbUserY))
               : _autoY
            radius:       Style.radiusL
            color:        Color.mSurface
            border.color: Style.capsuleBorderColor || "transparent"
            border.width: Style.capsuleBorderWidth || Style.borderS
            component ToolbarSeparator: Rectangle {
                readonly property bool vertical: toolbar.useVertical
                width:   vertical ? 28 : Style.borderS
                height:  vertical ? Style.borderS : 28
                color:   Color.mOnSurfaceVariant
                opacity: 0.3
                anchors.horizontalCenter: vertical ? parent.horizontalCenter : undefined
                anchors.verticalCenter:   vertical ? undefined               : parent.verticalCenter
            }
            component ToolBtn: Rectangle {
                property string toolId:   ""
                property string iconName: ""
                property string tip:      ""
                width:   34; height: 34
                radius:  Style.radiusS
                opacity: root.zoomScale > 1.0 ? 0.35 : 1.0
                color:   overlayWin.tool === toolId
                    ? Color.mPrimary
                    : (tbHover.containsMouse ? Color.mHover : "transparent")
                NIcon {
                    anchors.centerIn: parent
                    icon:  iconName
                    color: overlayWin.tool === toolId ? Color.mOnPrimary : Color.mOnSurface
                }
                MouseArea {
                    id: tbHover
                    anchors.fill:  parent
                    hoverEnabled:  true
                    cursorShape:   Qt.PointingHandCursor
                    enabled:       root.zoomScale <= 1.0
                    onClicked: {
                        if (overlayWin.textMode) textInput.commitText()
                        overlayWin.tool     = toolId
                        overlayWin.textMode = false
                    }
                    onEntered: TooltipService.show(parent, tip)
                    onExited:  TooltipService.hide()
                }
            }
            component ZoomBtn: Rectangle {
                property string iconName:   ""
                property string tip:        ""
                property bool   btnEnabled: true
                width:   28; height: 34
                radius:  Style.radiusS
                color:   zbHover.containsMouse ? Color.mHover : "transparent"
                enabled: btnEnabled
                opacity: enabled ? 1.0 : 0.3
                signal clicked()
                NIcon { anchors.centerIn: parent; icon: iconName; color: Color.mOnSurface }
                MouseArea {
                    id: zbHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:  parent.clicked()
                    onEntered:  TooltipService.show(parent, tip)
                    onExited:   TooltipService.hide()
                }
            }
            component ActionBtn: Rectangle {
                property string iconName: ""
                property string tip:      ""
                property bool   danger:   false
                width:  34; height: 34
                radius: Style.radiusS
                color:  abHover.containsMouse
                    ? (danger ? Color.mErrorContainer || "#ffcdd2" : Color.mHover)
                    : "transparent"
                NIcon {
                    anchors.centerIn: parent
                    icon:  iconName
                    color: abHover.containsMouse && danger ? Color.mError || "#f44336" : Color.mOnSurface
                }
                signal clicked()
                MouseArea {
                    id: abHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:  parent.clicked()
                    onEntered:  TooltipService.show(parent, tip)
                    onExited:   TooltipService.hide()
                }
            }
            component SaveBtn: Rectangle {
                property string iconName:   ""
                property string labelText:  ""
                property string tip:        ""
                property bool   primary:    false
                height: 36
                radius: Style.radiusS
                width:  _sbRow.implicitWidth + Style.marginL
                color:  sbHover.containsMouse
                    ? (primary ? Color.mPrimary : Color.mSecondary || Color.mPrimary)
                    : (primary ? Color.mPrimaryContainer || Color.mSurfaceVariant : Color.mSurfaceVariant)
                opacity: overlayWin.isSaving ? 0.5 : 1.0
                signal clicked()
                Row {
                    id: _sbRow
                    anchors.centerIn: parent
                    spacing: Style.marginXS
                    NIcon { icon: iconName; color: sbHover.containsMouse ? Color.mOnPrimary : (primary ? Color.mPrimary : Color.mOnSurface) }
                    NText { text: labelText; color: sbHover.containsMouse ? Color.mOnPrimary : (primary ? Color.mPrimary : Color.mOnSurface); font.weight: Font.Bold; pointSize: Style.fontSizeS }
                }
                MouseArea {
                    id: sbHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    enabled:      !overlayWin.isSaving
                    onClicked:  parent.clicked()
                    onEntered:  TooltipService.show(parent, tip)
                    onExited:   TooltipService.hide()
                }
            }
            property real _dragSx:  0; property real _dragSy:  0
            property real _dragStx: 0; property real _dragSty: 0
            component DragBtn: Rectangle {
                property bool isVertical: false
                width:  30; height: 30
                radius: Style.radiusS
                color:  dragMA.containsMouse || dragMA.pressed ? Color.mHover : "transparent"
                Column {
                    anchors.centerIn: parent
                    spacing: Style.marginXS
                    visible: !parent.isVertical
                    Repeater {
                        model: 3
                        Rectangle {
                            width:  Style.marginL
                            height: Style.marginXXS
                            radius: Style.radiusXXXS
                            color:  Color.mOnSurfaceVariant
                            opacity: 0.6
                        }
                    }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: Style.marginXS
                    visible: parent.isVertical
                    Repeater {
                        model: 3
                        Rectangle {
                            width:  Style.marginXXS
                            height: Style.marginL
                            radius: Style.radiusXXXS
                            color:  Color.mOnSurfaceVariant
                            opacity: 0.6
                        }
                    }
                }
                MouseArea {
                    id: dragMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.SizeAllCursor
                    onPressed: (mouse) => {
                        var gp = mapToItem(null, mouse.x, mouse.y)
                        toolbar._dragSx  = gp.x
                        toolbar._dragSy  = gp.y
                        toolbar._dragStx = toolbar.x
                        toolbar._dragSty = toolbar.y
                    }
                    onPositionChanged: (mouse) => {
                        if (!pressed) return
                        var gp = mapToItem(null, mouse.x, mouse.y)
                        overlayWin._tbUserX = toolbar._dragStx + (gp.x - toolbar._dragSx)
                        overlayWin._tbUserY = toolbar._dragSty + (gp.y - toolbar._dragSy)
                    }
                    onEntered: TooltipService.show(parent, root.mainInstance?.pluginApi?.tr("annotate.dragToolbar"))
                    onExited:  TooltipService.hide()
                }
            }
            readonly property var toolDefs: [
                { id: "pencil",      icon: "pencil",         tooltip: root.mainInstance?.pluginApi?.tr("annotate.toolPencil")      },
                { id: "highlighter", icon: "highlight",      tooltip: root.mainInstance?.pluginApi?.tr("annotate.toolHighlighter") },
                { id: "line",        icon: "slash",          tooltip: root.mainInstance?.pluginApi?.tr("annotate.toolLine")        },
                { id: "arrow",       icon: "arrow-up-right", tooltip: root.mainInstance?.pluginApi?.tr("annotate.toolArrow")       },
                { id: "rect",        icon: "square",         tooltip: root.mainInstance?.pluginApi?.tr("annotate.toolRect")        },
                { id: "circle",      icon: "circle",         tooltip: root.mainInstance?.pluginApi?.tr("annotate.toolCircle")      },
                { id: "text",        icon: "text-size",      tooltip: root.mainInstance?.pluginApi?.tr("annotate.toolText")        },
                { id: "blur",        icon: "eye-off",        tooltip: root.mainInstance?.pluginApi?.tr("annotate.toolBlur")        }
            ]
            readonly property var colorDefs: [
                "#FF4444", "#FF8C00", "#FFD700", "#44FF88",
                "#44AAFF", "#CC44FF", "#FF44CC", "#FFFFFF", "#000000"
            ]
            readonly property var sizeDefs: [
                { size: 2, label: root.mainInstance?.pluginApi?.tr("annotate.sizeS") },
                { size: 4, label: root.mainInstance?.pluginApi?.tr("annotate.sizeM") },
                { size: 7, label: root.mainInstance?.pluginApi?.tr("annotate.sizeL") }
            ]
            function doUndo() {
                if (overlayWin.strokes.length > 0) {
                    overlayWin.strokes = overlayWin.strokes.slice(0, -1)
                    overlayWin._invalidateCache()
                    drawCanvas.requestPaint()
                }
            }
            function doClear() {
                overlayWin.strokes = []
                overlayWin._invalidateCache()
                drawCanvas.requestPaint()
            }
            function doClose() {
                overlayWin.strokes = []
                overlayWin._invalidateCache()
                root.hide()
            }
            Loader {
                id: toolbarContent
                anchors.centerIn: parent
                sourceComponent: toolbar.useVertical ? colLayout : rowLayout
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
                        iconName:   "zoom-out"
                        tip:        root.mainInstance?.pluginApi?.tr("annotate.zoomOut")
                        btnEnabled: root.zoomScale > 1.0
                        onClicked:  overlayWin.requestZoom(Math.max(1.0, root.zoomScale - 1.0))
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:                   root.zoomScale === 1.0 ? "1×" : Math.round(root.zoomScale) + "×"
                        color:                  root.zoomScale > 1.0 ? Color.mPrimary : Color.mOnSurfaceVariant
                        font.pixelSize:         11
                        font.bold:              root.zoomScale > 1.0
                        width:                  22
                        horizontalAlignment:    Text.AlignHCenter
                    }
                    ZoomBtn {
                        iconName:   "zoom-in"
                        tip:        root.mainInstance?.pluginApi?.tr("annotate.zoomIn")
                        btnEnabled: root.zoomScale < 5.0
                        onClicked:  overlayWin.requestZoom(Math.min(5.0, root.zoomScale + 1.0))
                    }
                    ToolbarSeparator {}
                    Rectangle {
                        width:  18; height: 18; radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color:        overlayWin.drawColor
                        border.color: overlayWin.showPopover ? Color.mPrimary : Qt.rgba(0, 0, 0, 0.2)
                        border.width: overlayWin.showPopover ? Style.borderM : Style.borderS
                        scale: colorBtnH.containsMouse ? 1.1 : 1
                        Behavior on scale { NumberAnimation { duration: 80 } }
                        MouseArea {
                            id: colorBtnH
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:  overlayWin.showPopover = !overlayWin.showPopover
                            onEntered:  TooltipService.show(parent, root.mainInstance?.pluginApi?.tr("annotate.colorSize"))
                            onExited:   TooltipService.hide()
                        }
                    }
                    ToolbarSeparator {}
                    ActionBtn { iconName: "corner-up-left"; tip: root.mainInstance?.pluginApi?.tr("annotate.undo");     onClicked: toolbar.doUndo() }
                    ActionBtn { iconName: "trash";          tip: root.mainInstance?.pluginApi?.tr("annotate.clearAll"); danger: true; onClicked: toolbar.doClear() }
                    SaveBtn {
                        iconName:  "copy"
                        labelText: overlayWin.isSaving
                            ? root.mainInstance?.pluginApi?.tr("annotate.copying")
                            : root.mainInstance?.pluginApi?.tr("annotate.copy")
                        tip:       root.mainInstance?.pluginApi?.tr("annotate.copyTip")
                        primary:   true
                        onClicked: overlayWin.flattenAndCopy()
                    }
                    SaveBtn {
                        iconName:  "device-floppy"
                        labelText: overlayWin.isSaving
                            ? root.mainInstance?.pluginApi?.tr("annotate.saving")
                            : root.mainInstance?.pluginApi?.tr("annotate.save")
                        tip:       root.mainInstance?.pluginApi?.tr("annotate.saveTip")
                        primary:   false
                        onClicked: overlayWin.flattenAndSave()
                    }
                    ActionBtn { iconName: "x"; tip: root.mainInstance?.pluginApi?.tr("annotate.close"); onClicked: toolbar.doClose() }
                    ToolbarSeparator {}
                    DragBtn { isVertical: false; anchors.verticalCenter: parent.verticalCenter }
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
                        iconName:   "zoom-out"
                        tip:        root.mainInstance?.pluginApi?.tr("annotate.zoomOut")
                        btnEnabled: root.zoomScale > 1.0
                        onClicked:  overlayWin.requestZoom(Math.max(1.0, root.zoomScale - 1.0))
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:               root.zoomScale === 1.0 ? "1×" : Math.round(root.zoomScale) + "×"
                        color:              root.zoomScale > 1.0 ? Color.mPrimary : Color.mOnSurfaceVariant
                        font.pixelSize:     10
                        font.bold:          root.zoomScale > 1.0
                    }
                    ZoomBtn {
                        iconName:   "zoom-in"
                        tip:        root.mainInstance?.pluginApi?.tr("annotate.zoomIn")
                        btnEnabled: root.zoomScale < 5.0
                        onClicked:  overlayWin.requestZoom(Math.min(5.0, root.zoomScale + 1.0))
                    }
                    ToolbarSeparator {}
                    Rectangle {
                        width:  18; height: 18; radius: 9
                        anchors.horizontalCenter: parent.horizontalCenter
                        color:        overlayWin.drawColor
                        border.color: overlayWin.showPopover ? Color.mPrimary : Qt.rgba(0, 0, 0, 0.2)
                        border.width: overlayWin.showPopover ? Style.borderM : Style.borderS
                        scale: colorBtnV.containsMouse ? 1.1 : 1
                        Behavior on scale { NumberAnimation { duration: 80 } }
                        MouseArea {
                            id: colorBtnV
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:  overlayWin.showPopover = !overlayWin.showPopover
                            onEntered:  TooltipService.show(parent, root.mainInstance?.pluginApi?.tr("annotate.colorSize"))
                            onExited:   TooltipService.hide()
                        }
                    }
                    ToolbarSeparator {}
                    ActionBtn { iconName: "corner-up-left"; tip: root.mainInstance?.pluginApi?.tr("annotate.undo");     onClicked: toolbar.doUndo() }
                    ActionBtn { iconName: "trash";          tip: root.mainInstance?.pluginApi?.tr("annotate.clearAll"); danger: true; onClicked: toolbar.doClear() }
                    ActionBtn { iconName: "copy";           tip: root.mainInstance?.pluginApi?.tr("annotate.copyTip");  onClicked: overlayWin.flattenAndCopy() }
                    ActionBtn { iconName: "device-floppy";  tip: root.mainInstance?.pluginApi?.tr("annotate.saveTip");  onClicked: overlayWin.flattenAndSave() }
                    ActionBtn { iconName: "x";              tip: root.mainInstance?.pluginApi?.tr("annotate.close");    onClicked: toolbar.doClose() }
                    ToolbarSeparator {}
                    DragBtn { isVertical: true; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }
        }
        Rectangle {
            id: popover
            visible: overlayWin.isPrimary && overlayWin.showPopover
            radius:       Style.radiusL
            color:        Color.mSurface
            border.color: Style.capsuleBorderColor || "transparent"
            border.width: Style.capsuleBorderWidth || Style.borderS
            width:  toolbar.useVertical ? (popContent.implicitWidth  + Style.marginS) : (popContent.implicitWidth  + Style.marginM)
            height: toolbar.useVertical ? (popContent.implicitHeight + Style.marginM) : (popContent.implicitHeight + Style.marginS)
            x: toolbar.useVertical
               ? (toolbar.spaceRight >= 56 ? toolbar.x + toolbar.width + Style.marginXS : toolbar.x - width - Style.marginXS)
               : Math.max(Style.marginS, Math.min(toolbar.x + (toolbar.width - width) / 2, overlayWin.width - width - Style.marginS))
            y: toolbar.useVertical
               ? Math.max(Style.marginS, Math.min(toolbar.y + (toolbar.height - height) / 2, overlayWin.height - height - Style.marginS))
               : (toolbar.spaceAbove >= height + Style.marginS ? toolbar.y - height - Style.marginXS : toolbar.y + toolbar.height + Style.marginXS)
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
                            border.color: overlayWin.drawColor === modelData ? Color.mPrimary : Qt.rgba(0, 0, 0, 0.15)
                            border.width: overlayWin.drawColor === modelData ? Style.borderM : Style.borderS
                            scale: chH.containsMouse ? 1.2 : 1
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            MouseArea {
                                id: chH
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { overlayWin.drawColor = modelData; overlayWin.showPopover = false }
                            }
                        }
                    }
                    Rectangle {
                        width: Style.borderS; height: 16
                        color: Color.mOnSurfaceVariant; opacity: 0.3
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Repeater {
                        model: toolbar.sizeDefs
                        delegate: Rectangle {
                            width:  28; height: 24; radius: Style.radiusS
                            color:        overlayWin.drawSize === modelData.size ? Color.mPrimaryContainer || Color.mSurfaceVariant : (shH.containsMouse ? Color.mHover : "transparent")
                            border.color: overlayWin.drawSize === modelData.size ? Color.mPrimary : "transparent"
                            border.width: Style.borderS
                            Row {
                                anchors.centerIn: parent; spacing: Style.marginXS
                                Rectangle { width: modelData.size * 2; height: modelData.size * 2; radius: modelData.size; color: overlayWin.drawColor; anchors.verticalCenter: parent.verticalCenter }
                                NText { text: modelData.label; pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                id: shH
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { overlayWin.drawSize = modelData.size; overlayWin.showPopover = false }
                            }
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
                            border.color: overlayWin.drawColor === modelData ? Color.mPrimary : Qt.rgba(0, 0, 0, 0.15)
                            border.width: overlayWin.drawColor === modelData ? Style.borderM : Style.borderS
                            scale: chV.containsMouse ? 1.2 : 1
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            MouseArea {
                                id: chV
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { overlayWin.drawColor = modelData; overlayWin.showPopover = false }
                            }
                        }
                    }
                    Rectangle {
                        width: 16; height: Style.borderS
                        color: Color.mOnSurfaceVariant; opacity: 0.3
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Repeater {
                        model: toolbar.sizeDefs
                        delegate: Rectangle {
                            width:  32; height: 24; radius: Style.radiusS
                            color:        overlayWin.drawSize === modelData.size ? Color.mPrimaryContainer || Color.mSurfaceVariant : (shV.containsMouse ? Color.mHover : "transparent")
                            border.color: overlayWin.drawSize === modelData.size ? Color.mPrimary : "transparent"
                            border.width: Style.borderS
                            Row {
                                anchors.centerIn: parent; spacing: Style.marginXS
                                Rectangle { width: modelData.size * 2; height: modelData.size * 2; radius: modelData.size; color: overlayWin.drawColor; anchors.verticalCenter: parent.verticalCenter }
                                NText { text: modelData.label; pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                id: shV
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { overlayWin.drawSize = modelData.size; overlayWin.showPopover = false }
                            }
                        }
                    }
                }
            }
        }
        function flattenAndSave() {
            if (overlayWin.isSaving) return
            overlayWin.isSaving  = true
            var filename = root._buildFilename("annotate", ".png")
            var custom   = root._annotateOutputDir()
            if (root.zoomScale > 1.0) {
                if (custom === "__auto__") {
                    var home   = Quickshell.env("HOME") || ""
                    var ssDir  = home + "/Pictures/Screenshots"
                    var picDir = home + "/Pictures"
                    saveFileProc.exec({ command: [
                        "bash", "-c",
                        "if [ -d " + JSON.stringify(ssDir) + " ]; then DEST=" + JSON.stringify(ssDir) +
                        "; elif [ -d " + JSON.stringify(picDir) + " ]; then DEST=" + JSON.stringify(picDir) +
                        "; else exit 1; fi; " +
                        "cp " + JSON.stringify(root.imagePath) + " \"$DEST/" + filename + "\" && " +
                        "echo \"$DEST/" + filename + "\""
                    ]})
                } else {
                    var dest = custom + "/" + filename
                    saveFileProc.exec({ command: [
                        "bash", "-c",
                        "cp " + JSON.stringify(root.imagePath) + " " + JSON.stringify(dest) + " && " +
                        "echo " + JSON.stringify(dest)
                    ]})
                }
            } else {
                drawCanvas.grabToImage(function(result) {
                    result.saveToFile("/tmp/screen-toolkit-overlay.png")
                    if (custom === "__auto__") {
                        var home2   = Quickshell.env("HOME") || ""
                        var ssDir2  = home2 + "/Pictures/Screenshots"
                        var picDir2 = home2 + "/Pictures"
                        saveFileProc.exec({ command: [
                            "bash", "-c",
                            "if [ -d " + JSON.stringify(ssDir2) + " ]; then DEST=" + JSON.stringify(ssDir2) +
                            "; elif [ -d " + JSON.stringify(picDir2) + " ]; then DEST=" + JSON.stringify(picDir2) +
                            "; else exit 1; fi; " +
                            "magick /tmp/screen-toolkit-annotate.png /tmp/screen-toolkit-overlay.png " +
                            "-composite \"$DEST/" + filename + "\" && " +
                            "rm -f /tmp/screen-toolkit-overlay.png && " +
                            "echo \"$DEST/" + filename + "\""
                        ]})
                    } else {
                        var dest2 = custom + "/" + filename
                        saveFileProc.exec({ command: [
                            "bash", "-c",
                            "magick /tmp/screen-toolkit-annotate.png /tmp/screen-toolkit-overlay.png " +
                            "-composite " + JSON.stringify(dest2) + " && " +
                            "rm -f /tmp/screen-toolkit-overlay.png && " +
                            "echo " + JSON.stringify(dest2)
                        ]})
                    }
                })
            }
        }
        function flattenAndCopy() {
            if (overlayWin.isSaving) return
            overlayWin.isSaving = true
            if (root.zoomScale > 1.0) {
                copyProc.exec({ command: ["bash", "-c", "wl-copy < " + JSON.stringify(root.imagePath)] })
            } else {
                drawCanvas.grabToImage(function(result) {
                    result.saveToFile("/tmp/screen-toolkit-overlay.png")
                    saveProc.exec({ command: [
                        "bash", "-c",
                        "magick /tmp/screen-toolkit-annotate.png /tmp/screen-toolkit-overlay.png " +
                        "-composite /tmp/screen-toolkit-annotated.png && " +
                        "wl-copy < /tmp/screen-toolkit-annotated.png && " +
                        "rm -f /tmp/screen-toolkit-overlay.png"
                    ]})
                })
            }
        }
    }
}
