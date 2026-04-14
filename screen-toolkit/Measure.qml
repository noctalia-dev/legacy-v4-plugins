import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI
Variants {
    id: measureVariants
    property bool isVisible: false
    property var mainInstance: null
    function show() { isVisible = true }
    function hide() { isVisible = false }
    model: Quickshell.screens
    delegate: PanelWindow {
        id: overlayWin
        required property ShellScreen modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        visible: measureVariants.isVisible
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: measureVariants.isVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "noctalia-measure"
        Shortcut {
            sequence: "Escape"
            onActivated: measureVariants.hide()
        }
        property bool measuring: false
        property var current: null
        property var pinned: []
        property bool _isShooting: false
        readonly property var palette: [
            "#A78BFA", "#34D399", "#F87171", "#FBBF24",
            "#60A5FA", "#F472B6", "#A3E635", "#FB923C"
        ]
        function colorForIndex(i) { return palette[i % palette.length] }
        property real x1: 0; property real y1: 0
        property real x2: 0; property real y2: 0
        readonly property real curW: current ? Math.abs(current.x2 - current.x1) : 0
        readonly property real curH: current ? Math.abs(current.y2 - current.y1) : 0
        readonly property real curDist: Math.round(Math.sqrt(curW*curW + curH*curH))
        onMeasuringChanged: measureCanvas.requestPaint()
        onCurrentChanged:   measureCanvas.requestPaint()
        onPinnedChanged:    measureCanvas.requestPaint()
        function doPin() {
            if (!current) return
            var p = pinned.slice()
            p.push({ x1: current.x1, y1: current.y1, x2: current.x2, y2: current.y2, color: colorForIndex(p.length) })
            pinned = p
            current = null
        }
        function removePinned(i) {
            var p = pinned.slice()
            p.splice(i, 1)
            for (var j = 0; j < p.length; j++)
                p[j] = { x1: p[j].x1, y1: p[j].y1, x2: p[j].x2, y2: p[j].y2, color: colorForIndex(j) }
            pinned = p
        }
        function clearAll() { pinned = [] }
        property var _shotMeasure: null
        property string _shotColor: "#ffffff"
        function _tr(key, interp) {
            return measureVariants.mainInstance?.pluginApi?.tr(key, interp ?? {}) ?? key
        }
        function expandPath(p) {
            if (!p || p.trim() === "") return ""
            if (p.startsWith("~/"))
                return Quickshell.env("HOME") + "/" + p.substring(2)
            return p
        }
        function getScreenshotDir() {
            if (measureVariants.mainInstance && measureVariants.mainInstance.pluginApi) {
                var custom = measureVariants.mainInstance.pluginApi.pluginSettings?.screenshotPath ?? ""
                if (custom.trim() !== "") return expandPath(custom.trim())
            }
            return Quickshell.env("HOME") + "/Pictures/Screenshots"
        }
        function buildMeasureFilename() {
            if (measureVariants.mainInstance && measureVariants.mainInstance.pluginApi) {
                var fmt = measureVariants.mainInstance.pluginApi.pluginSettings?.filenameFormat ?? ""
                if (fmt.trim() !== "") {
                    var now = new Date()
                    var s = fmt.trim()
                    s = s.replace(/%Y/g, Qt.formatDateTime(now, "yyyy"))
                    s = s.replace(/%m/g, Qt.formatDateTime(now, "MM"))
                    s = s.replace(/%d/g, Qt.formatDateTime(now, "dd"))
                    s = s.replace(/%H/g, Qt.formatDateTime(now, "HH"))
                    s = s.replace(/%M/g, Qt.formatDateTime(now, "mm"))
                    s = s.replace(/%S/g, Qt.formatDateTime(now, "ss"))
                    s = s.replace(/[\/\\\n\r\0]/g, "_").trim()
                    if (s !== "") return s
                }
            }
            var now = new Date()
            return "measure-" + Qt.formatDateTime(now, "yyyy-MM-dd_HH-mm-ss")
        }
        Process {
            id: shotProc
            stdout: StdioCollector {}
            onExited: (code) => {
                overlayWin._isShooting = false
                measureVariants.isVisible = true
                if (code === 0) {
                    var dest = shotProc.stdout.text.trim()
                    ToastService.showNotice(_tr("messages.measure-saved", { dest: dest !== "" ? dest : "~/Pictures" }), "", "camera")
                } else {
                    ToastService.showError(_tr("messages.measure-failed"))
                }
            }
        }
        Timer {
            id: shotTimer
            interval: 400
            repeat: false
            onTriggered: {
                var m = overlayWin._shotMeasure
                if (!m) {
                    overlayWin._isShooting = false
                    measureVariants.isVisible = true
                    return
                }
                var scale = overlayWin.modelData.devicePixelRatio ?? 1.0
                var sx = overlayWin.modelData.x, sy = overlayWin.modelData.y
                var pad  = 40
                var minX = Math.min(m.x1, m.x2)
                var minY = Math.min(m.y1, m.y2)
                var maxX = Math.max(m.x1, m.x2)
                var maxY = Math.max(m.y1, m.y2)
                var rx = Math.round(Math.max(0, minX - pad))
                var ry = Math.round(Math.max(0, minY - pad))
                var rw = Math.round(maxX + pad) - rx
                var rh = Math.round(maxY + pad) - ry
                var lx1 = Math.round((m.x1 - rx) * scale)
                var ly1 = Math.round((m.y1 - ry) * scale)
                var lx2 = Math.round((m.x2 - rx) * scale)
                var ly2 = Math.round((m.y2 - ry) * scale)
                var lw  = Math.abs(lx2 - lx1)
                var lh  = Math.abs(ly2 - ly1)
                var col = overlayWin._shotColor
                var destDir = getScreenshotDir()
                var baseName = buildMeasureFilename()
                var fullPath = destDir + "/" + baseName + ".png"
                var cmd = [
                    "bash", "-c",
                    "mkdir -p '" + destDir + "' || exit 1; " +
                    "grim -g '" + (sx + rx) + "," + (sy + ry) + " " + rw + "x" + rh + "' /tmp/measure-crop.png || exit 1; " +
                    (function() {
                        var bx1 = Math.min(lx1,lx2), bx2 = Math.max(lx1,lx2)
                        var by1 = Math.min(ly1,ly2), by2 = Math.max(ly1,ly2)
                        var midX = Math.round((bx1+bx2)/2)
                        var midY = Math.round((by1+by2)/2)
                        var d = "magick /tmp/measure-crop.png"
                        d += " -strokewidth " + Math.max(1, Math.round(1*scale)) + " -stroke 'rgba(255,255,255,0.25)' -fill none"
                        d += " -draw 'rectangle " + bx1 + "," + by1 + " " + bx2 + "," + by2 + "'"
                        d += " -fill 'rgba(255,255,255,0.6)' -stroke none"
                        ;[[lx1,ly1],[lx2,ly2],[lx1,ly2],[lx2,ly1]].forEach(function(c) {
                            d += " -draw 'circle " + c[0] + "," + c[1] + " " + (c[0]+Math.round(3*scale)) + "," + c[1] + "'"
                        })
                        d += " -strokewidth " + Math.max(1, Math.round(2*scale)) + " -stroke '" + col + "' -fill none"
                        d += " -draw 'line " + lx1 + "," + ly1 + " " + lx2 + "," + ly2 + "'"
                        d += " -fill '" + col + "' -stroke none"
                        d += " -draw 'circle " + lx1 + "," + ly1 + " " + (lx1+Math.round(5*scale)) + "," + ly1 + "'"
                        d += " -draw 'circle " + lx2 + "," + ly2 + " " + (lx2+Math.round(5*scale)) + "," + ly2 + "'"
                        if (lw > 20 * scale) {
                            var htxt = Math.round(lw/scale) + "px"
                            var gy = by1 - Math.round(20*scale)
                            var labelBelow = gy < 18 * scale
                            gy = labelBelow ? by2 + Math.round(20*scale) : gy
                            d += " -strokewidth " + Math.max(1, Math.round(1*scale)) + " -stroke 'rgba(255,255,255,0.5)' -fill none"
                            d += " -draw 'line " + bx1 + "," + gy + " " + bx2 + "," + gy + "'"
                            var tx = Math.max(6 * scale, Math.min(rw * scale - htxt.length*8*scale - 6*scale, midX - Math.round(htxt.length*4*scale)))
                            var ty = labelBelow ? gy + Math.round(16*scale) : gy - Math.round(8*scale)
                            d += " -fill white -stroke none -pointsize " + Math.round(13*scale) + " -font DejaVu-Sans"
                            d += " -draw 'text " + tx + "," + ty + " \"" + htxt + "\"'"
                        }
                        return d
                    })() +
                    " /tmp/measure-out.png || exit 1; " +
                    (function() {
                        if (lh <= 20 * scale) return ""
                        var bx1v = Math.min(lx1,lx2), bx2v = Math.max(lx1,lx2)
                        var by1v = Math.min(ly1,ly2), by2v = Math.max(ly1,ly2)
                        var midYv = Math.round((by1v+by2v)/2)
                        var vtxt = Math.round(lh/scale) + "px"
                        var vph = Math.round(22*scale), vpw = vtxt.length * Math.round(9*scale) + Math.round(16*scale)
                        var spaceLeft = lx1 - vph - Math.round(14*scale)
                        var labelRight = spaceLeft < 4 * scale
                        var compX = labelRight
                            ? Math.min(rw - vph - 2, bx2v + Math.round(10*scale))
                            : Math.max(2, bx1v - Math.round(10*scale) - vph)
                        var compY = Math.max(2, Math.min(rh - vpw - 2, midYv - Math.round(vpw/2)))
                        return "magick -size " + vpw + "x" + vph + " xc:'rgba(0,0,0,0)'" +
                            " -fill white -stroke none -pointsize " + Math.round(13*scale) + " -font DejaVu-Sans" +
                            " -draw 'text " + (Math.round(vpw/2) - Math.round(vtxt.length*4*scale)) + "," + (vph-Math.round(6*scale)) + " \"" + vtxt + "\"'" +
                            " -rotate -90" +
                            " /tmp/measure-vlabel.png" +
                            " && magick /tmp/measure-out.png /tmp/measure-vlabel.png" +
                            " -geometry +" + compX + "+" + compY + " -composite" +
                            " /tmp/measure-out.png" +
                            " && rm -f /tmp/measure-vlabel.png; "
                    })() +
                    "cp /tmp/measure-out.png '" + fullPath + "' || exit 1; " +
                    "wl-copy -t image/png < /tmp/measure-out.png || exit 1; " +
                    "rm -f /tmp/measure-crop.png /tmp/measure-out.png; " +
                    "echo '" + destDir + "'"
                ]
                shotProc.exec({ command: cmd })
            }
        }
        function doScreenshot(m, color) {
            if (_isShooting) return
            _shotMeasure = m
            _shotColor   = color || "#ffffff"
            _isShooting  = true
            measureVariants.isVisible = false
            shotTimer.restart()
        }
        Connections {
            target: measureVariants
            function onIsVisibleChanged() {
                if (!measureVariants.isVisible && !overlayWin._isShooting) {
                    overlayWin.measuring = false
                    overlayWin.current = null
                    overlayWin.pinned = []
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            Column {
                anchors.centerIn: parent
                spacing: Style.marginS
                visible: !overlayWin.measuring && !overlayWin.current && overlayWin.pinned.length === 0
                NIcon { icon: "ruler"; color: "white"; anchors.horizontalCenter: parent.horizontalCenter; scale: 2 }
                NText {
                    text: _tr("measure.hint")
                    color: "white"; font.weight: Font.Bold; pointSize: Style.fontSizeL
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                NText {
                    text: _tr("measure.subHint")
                    color: Qt.rgba(1,1,1,0.5); pointSize: Style.fontSizeS
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                hoverEnabled: true
                onPositionChanged: (mouse) => {
                    if (overlayWin.measuring) {
                        overlayWin.x2 = mouse.x
                        overlayWin.y2 = mouse.y
                        measureCanvas.requestPaint()
                    }
                }
                onPressed: (mouse) => {
                    overlayWin.measuring = true
                    overlayWin.current = null
                    overlayWin.x1 = mouse.x; overlayWin.y1 = mouse.y
                    overlayWin.x2 = mouse.x; overlayWin.y2 = mouse.y
                }
                onReleased: (mouse) => {
                    overlayWin.x2 = mouse.x; overlayWin.y2 = mouse.y
                    overlayWin.measuring = false
                    var dist = Math.sqrt(
                        Math.pow(overlayWin.x2 - overlayWin.x1, 2) +
                        Math.pow(overlayWin.y2 - overlayWin.y1, 2))
                    if (dist > 4)
                        overlayWin.current = { x1: overlayWin.x1, y1: overlayWin.y1, x2: overlayWin.x2, y2: overlayWin.y2 }
                    else
                        overlayWin.current = null
                }
            }
        }
        Canvas {
            id: measureCanvas
            anchors.fill: parent
            function drawLine(ctx, m, color) {
                var x1 = m.x1, y1 = m.y1, x2 = m.x2, y2 = m.y2
                var w = Math.abs(x2-x1), h = Math.abs(y2-y1)
                ctx.save()
                ctx.strokeStyle = "rgba(255,255,255,0.2)"; ctx.lineWidth = 1; ctx.setLineDash([4,4])
                ctx.strokeRect(Math.min(x1,x2), Math.min(y1,y2), w, h)
                ctx.restore()
                ctx.fillStyle = color
                ;[[x1,y1],[x2,y2],[x1,y2],[x2,y1]].forEach(function(pt) {
                    ctx.beginPath(); ctx.arc(pt[0],pt[1],3,0,Math.PI*2); ctx.fill()
                })
                ctx.save()
                ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.setLineDash([])
                ctx.beginPath(); ctx.moveTo(x1,y1); ctx.lineTo(x2,y2); ctx.stroke()
                ctx.restore()
                ctx.fillStyle = color
                ;[[x1,y1],[x2,y2]].forEach(function(pt) {
                    ctx.beginPath(); ctx.arc(pt[0],pt[1],5,0,Math.PI*2); ctx.fill()
                })
                if (w > 20) {
                    var midX = (Math.min(x1,x2)+Math.max(x1,x2))/2
                    var ty = Math.min(y1,y2)-12
                    ctx.save(); ctx.strokeStyle="rgba(255,255,255,0.5)"; ctx.lineWidth=1; ctx.setLineDash([])
                    ctx.beginPath(); ctx.moveTo(Math.min(x1,x2),ty); ctx.lineTo(Math.max(x1,x2),ty); ctx.stroke(); ctx.restore()
                    ctx.fillStyle="white"; ctx.font="bold 11px sans-serif"; ctx.textAlign="center"
                    ctx.fillText(Math.round(w)+"px", midX, ty-4)
                }
                if (h > 20) {
                    var midY = (Math.min(y1,y2)+Math.max(y1,y2))/2
                    var tx = Math.min(x1,x2)-12
                    ctx.save(); ctx.strokeStyle="rgba(255,255,255,0.5)"; ctx.lineWidth=1; ctx.setLineDash([])
                    ctx.beginPath(); ctx.moveTo(tx,Math.min(y1,y2)); ctx.lineTo(tx,Math.max(y1,y2)); ctx.stroke(); ctx.restore()
                    ctx.fillStyle="white"; ctx.font="bold 11px sans-serif"; ctx.textAlign="center"
                    ctx.save(); ctx.translate(tx-4,midY); ctx.rotate(-Math.PI/2)
                    ctx.fillText(Math.round(h)+"px",0,0); ctx.restore()
                }
            }
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0,0,width,height)
                for (var i = 0; i < overlayWin.pinned.length; i++)
                    drawLine(ctx, overlayWin.pinned[i], overlayWin.pinned[i].color)
                if (overlayWin.measuring)
                    drawLine(ctx, {x1:overlayWin.x1,y1:overlayWin.y1,x2:overlayWin.x2,y2:overlayWin.y2}, "#ffffff")
                if (overlayWin.current)
                    drawLine(ctx, overlayWin.current, "#ffffff")
            }
        }
        Rectangle {
            id: activeCard
            visible: overlayWin.current !== null && !overlayWin.measuring
            property real ex: overlayWin.current ? overlayWin.current.x2 : 0
            property real ey: overlayWin.current ? overlayWin.current.y2 : 0
            property real rawX: ex + 16
            property real rawY: ey + 16
            x: {
                var rx = rawX
                if (rx + width + 8 > overlayWin.width) rx = ex - width - 16
                return Math.max(8, rx)
            }
            y: {
                var ry = rawY
                if (ry + height + 8 > overlayWin.height) ry = ey - height - 16
                return Math.max(8, ry)
            }
            width: activeRow.implicitWidth + Style.marginL * 2
            height: activeRow.implicitHeight + Style.marginM * 2
            radius: Style.radiusL
            color: Color.mSurface
            border.color: "white"; border.width: 2
            Row {
                id: activeRow
                anchors.centerIn: parent
                spacing: Style.marginS
                Column {
                    spacing: 1; anchors.verticalCenter: parent.verticalCenter
                    NText { text: overlayWin.curDist + " px"; color: Color.mOnSurface; font.weight: Font.Bold; pointSize: Style.fontSizeM; anchors.horizontalCenter: parent.horizontalCenter }
                    NText { text: Math.round(overlayWin.curW) + " × " + Math.round(overlayWin.curH); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS; anchors.horizontalCenter: parent.horizontalCenter }
                }
                Rectangle {
                    width: 28; height: 28; radius: Style.radiusS; anchors.verticalCenter: parent.verticalCenter
                    color: acopyBtn.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                    NIcon { anchors.centerIn: parent; icon: "copy"; color: acopyBtn.containsMouse ? Color.mOnPrimary : Color.mOnSurface; scale: 0.85 }
                    MouseArea { id: acopyBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { measureVariants.copyResult(overlayWin.curDist + "px (" + Math.round(overlayWin.curW) + "×" + Math.round(overlayWin.curH) + ")"); ToastService.showNotice(_tr("messages.measure-copied")) }
                        onEntered: TooltipService.show(acopyBtn, _tr("measure.copyMeasurement")); onExited: TooltipService.hide()
                    }
                }
                Rectangle {
                    width: 28; height: 28; radius: Style.radiusS; anchors.verticalCenter: parent.verticalCenter
                    color: ascreenshotBtn.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                    NIcon { anchors.centerIn: parent; icon: "camera"; color: ascreenshotBtn.containsMouse ? Color.mOnPrimary : Color.mOnSurface; scale: 0.85 }
                    MouseArea { id: ascreenshotBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: overlayWin.doScreenshot(overlayWin.current, "#ffffff")
                        onEntered: TooltipService.show(ascreenshotBtn, _tr("measure.screenshot")); onExited: TooltipService.hide()
                    }
                }
                Rectangle {
                    width: 28; height: 28; radius: Style.radiusS; anchors.verticalCenter: parent.verticalCenter
                    color: pinBtn.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                    NIcon { anchors.centerIn: parent; icon: "pin"; color: pinBtn.containsMouse ? Color.mOnPrimary : Color.mOnSurface; scale: 0.85 }
                    MouseArea { id: pinBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { overlayWin.doPin(); ToastService.showNotice(_tr("messages.measure-pinned")) }
                        onEntered: TooltipService.show(pinBtn, _tr("measure.pin")); onExited: TooltipService.hide()
                    }
                }
                Rectangle {
                    width: 28; height: 28; radius: Style.radiusS; anchors.verticalCenter: parent.verticalCenter
                    color: discardBtn.containsMouse ? Color.mErrorContainer || "#ffcdd2" : Color.mSurfaceVariant
                    NIcon { anchors.centerIn: parent; icon: "x"; color: discardBtn.containsMouse ? Color.mError || "#f44336" : Color.mOnSurface; scale: 0.85 }
                    MouseArea { id: discardBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { overlayWin.current = null; if (overlayWin.pinned.length === 0) measureVariants.hide() }
                        onEntered: TooltipService.show(discardBtn, _tr("measure.discard")); onExited: TooltipService.hide()
                    }
                }
            }
        }
        Repeater {
            model: overlayWin.pinned
            delegate: Rectangle {
                readonly property var mdata: modelData
                readonly property int myIdx: index
                readonly property real mw: Math.abs(mdata.x2 - mdata.x1)
                readonly property real mh: Math.abs(mdata.y2 - mdata.y1)
                readonly property real mdist: Math.round(Math.sqrt(mw*mw + mh*mh))
                x: {
                    var rx = mdata.x2 + 16
                    if (rx + width + 8 > overlayWin.width) rx = mdata.x2 - width - 16
                    return Math.max(8, rx)
                }
                y: {
                    var ry = mdata.y2 + 16
                    if (ry + height + 8 > overlayWin.height) ry = mdata.y2 - height - 16
                    return Math.max(8, ry)
                }
                width: pinnedRow.implicitWidth + Style.marginL * 2
                height: pinnedRow.implicitHeight + Style.marginM * 2
                radius: Style.radiusL
                color: Color.mSurface
                border.color: mdata.color; border.width: 2
                Row {
                    id: pinnedRow
                    anchors.centerIn: parent
                    spacing: Style.marginS
                    Rectangle { width: 10; height: 10; radius: 5; color: mdata.color; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        spacing: 1; anchors.verticalCenter: parent.verticalCenter
                        NText { text: mdist + " px"; color: Color.mOnSurface; font.weight: Font.Bold; pointSize: Style.fontSizeM; anchors.horizontalCenter: parent.horizontalCenter }
                        NText { text: Math.round(mw) + " × " + Math.round(mh); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                    Rectangle {
                        width: 26; height: 26; radius: Style.radiusS; anchors.verticalCenter: parent.verticalCenter
                        color: pcopyBtn.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                        NIcon { anchors.centerIn: parent; icon: "copy"; color: pcopyBtn.containsMouse ? Color.mOnPrimary : Color.mOnSurface; scale: 0.8 }
                        MouseArea { id: pcopyBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { measureVariants.copyResult(mdist + "px (" + Math.round(mw) + "×" + Math.round(mh) + ")"); ToastService.showNotice(_tr("messages.measure-copied")) }
                            onEntered: TooltipService.show(pcopyBtn, _tr("measure.copy")); onExited: TooltipService.hide()
                        }
                    }
                    Rectangle {
                        width: 26; height: 26; radius: Style.radiusS; anchors.verticalCenter: parent.verticalCenter
                        color: pscreenshotBtn.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                        NIcon { anchors.centerIn: parent; icon: "camera"; color: pscreenshotBtn.containsMouse ? Color.mOnPrimary : Color.mOnSurface; scale: 0.8 }
                        MouseArea { id: pscreenshotBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: overlayWin.doScreenshot(mdata, mdata.color)
                            onEntered: TooltipService.show(pscreenshotBtn, _tr("measure.screenshot")); onExited: TooltipService.hide()
                        }
                    }
                    Rectangle {
                        width: 26; height: 26; radius: Style.radiusS; anchors.verticalCenter: parent.verticalCenter
                        color: premoveBtn.containsMouse ? Color.mErrorContainer || "#ffcdd2" : Color.mSurfaceVariant
                        NIcon { anchors.centerIn: parent; icon: "x"; color: premoveBtn.containsMouse ? Color.mError || "#f44336" : Color.mOnSurface; scale: 0.8 }
                        MouseArea { id: premoveBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: overlayWin.removePinned(myIdx)
                            onEntered: TooltipService.show(premoveBtn, _tr("measure.remove")); onExited: TooltipService.hide()
                        }
                    }
                }
            }
        }
        Rectangle {
            visible: overlayWin.pinned.length >= 2
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 32
            width: clearRow.implicitWidth + Style.marginL * 2
            height: 38; radius: Style.radiusM
            color: clearAllBtn.containsMouse ? Color.mErrorContainer || "#ffcdd2" : Color.mSurface
            border.color: Color.mError || "#f44336"; border.width: 1
            Row {
                id: clearRow; anchors.centerIn: parent; spacing: Style.marginS
                NIcon { icon: "trash"; color: Color.mError || "#f44336" }
                NText { text: "Clear all"; color: Color.mError || "#f44336"; font.weight: Font.Bold; pointSize: Style.fontSizeS }
            }
            MouseArea { id: clearAllBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: overlayWin.clearAll()
            }
        }
    }
    function copyResult(txt) {
        if (mainInstance) mainInstance.copyToClipboard(txt)
    }
}
