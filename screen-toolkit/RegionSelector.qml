import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root
    signal regionSelected(real x, real y, real w, real h, var screen)
    signal cancelled()
    property bool isVisible: false
    property var activeScreen: null
    property var windowRegions: []
    property bool windowRegionsFetched: false
    property bool isNiri: false

    function show(screen) {
        var target = screen || null
        if (!target && Quickshell.screens.length > 0)
            target = Quickshell.screens[0]
        root.activeScreen = target
        root.windowRegions = []
        root.windowRegionsFetched = false
        root.isVisible = true
        _envCheckProc.exec({
            command: ["bash", "-c",
                "[ -n \"$NIRI_SOCKET\" ] && echo 1 || echo 0"
            ]
        })
        _winFetchProc.exec({
            command: ["bash", "-c",
                "if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then" +
                "  hyprctl clients -j 2>/dev/null | jq -r '" +
                "    .[] | select(.mapped == true) | " +
                "    \"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1]) \\(.title)\"' 2>/dev/null;" +
                "elif [ -n \"$NIRI_SOCKET\" ]; then" +
                "  OUT=$(niri msg --json focused-output 2>/dev/null);" +
                "  OX=$(printf '%s' \"$OUT\" | jq -r '(.logical.x // 0)' 2>/dev/null);" +
                "  OY=$(printf '%s' \"$OUT\" | jq -r '(.logical.y // 0)' 2>/dev/null);" +
                "  niri msg --json windows 2>/dev/null | jq -r --argjson ox \"$OX\" --argjson oy \"$OY\" '" +
                "    .[] | select(.layout.tile_pos_in_workspace_view != null) | " +
                "    \"\\(($ox + .layout.tile_pos_in_workspace_view[0]) | floor)," +
                "      \\(($oy + .layout.tile_pos_in_workspace_view[1]) | floor) " +
                "      \\(.layout.tile_size[0] | floor)x\\(.layout.tile_size[1] | floor) " +
                "      \\(.title)\"' 2>/dev/null;" +
                "fi"
            ]
        })
    }

    function hide() {
        root.isVisible = false
        root.activeScreen = null
    }

    Process {
        id: _envCheckProc
        stdout: StdioCollector {}
        onExited: {
            root.isNiri = _envCheckProc.stdout.text.trim() === "1"
        }
    }

    Process {
        id: _winFetchProc
        stdout: StdioCollector {}
        onExited: {
            var lines = _winFetchProc.stdout.text.trim().split("\n")
            var regions = []
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (line === "") continue
                var m = line.match(/^(-?\d+),\s*(-?\d+)\s+(\d+)x(\d+)\s*(.*)$/)
                if (!m) continue
                var rw = parseInt(m[3]), rh = parseInt(m[4])
                if (rw < 10 || rh < 10) continue
                regions.push({
                    x: parseInt(m[1]),
                    y: parseInt(m[2]),
                    w: rw,
                    h: rh,
                    title: m[5].trim()
                })
            }
            root.windowRegions = regions
            root.windowRegionsFetched = true
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property ShellScreen modelData
            screen: modelData
            visible: root.isVisible
            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "noctalia-region-selector"
            property real selX: 0
            property real selY: 0
            property real selW: 0
            property real selH: 0
            property real mouseX: 0
            property real mouseY: 0
            property point startPos
            property bool dragging: false
            property real fadeOpacity: 0.0
            NumberAnimation {
                id: fadeIn
                target: win
                property: "fadeOpacity"
                from: 0.0; to: 1.0
                duration: 150
                easing.type: Easing.OutCubic
            }
            onVisibleChanged: {
                if (visible) {
                    fadeOpacity = 0.0
                    dragging = false
                    selX = 0; selY = 0; selW = 0; selH = 0
                    fadeIn.restart()
                } else {
                    fadeIn.stop()
                    dragging = false
                }
            }
            property var pendingCapture: null
            Timer {
                id: captureDelay
                interval: 80; repeat: false
                onTriggered: {
                    if (win.pendingCapture) {
                        var p = win.pendingCapture
                        win.pendingCapture = null
                        root.regionSelected(p.x, p.y, p.w, p.h, p.screen)
                    }
                }
            }
            function _winAt(px, py) {
                var regions = root.windowRegions
                var sx = win.screen?.x ?? 0, sy = win.screen?.y ?? 0
                for (var i = 0; i < regions.length; i++) {
                    var r = regions[i]
                    var lx = r.x - sx, ly = r.y - sy
                    if (px >= lx && px <= lx + r.w && py >= ly && py <= ly + r.h) return i
                }
                return -1
            }
            ShaderEffect {
                anchors.fill: parent
                z: 0
                opacity: win.fadeOpacity
                property vector4d selectionRect: Qt.vector4d(win.selX, win.selY, win.selW, win.selH)
                property real dimOpacity: 0.72
                property vector2d screenSize: Qt.vector2d(win.width, win.height)
                fragmentShader: Qt.resolvedUrl("dimming.frag.qsb")
            }
            Canvas {
                id: guides
                anchors.fill: parent
                z: 2
                opacity: win.fadeOpacity
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var hasSel = win.selW > 4 && win.selH > 4
                    var mx = win.mouseX, my = win.mouseY
                    var sx = win.selX,   sy = win.selY
                    var sw = win.selW,   sh = win.selH
                    if (!win.dragging && !hasSel) {
                        ctx.setLineDash([])
                        ctx.strokeStyle = "rgba(0,0,0,0.6)"; ctx.lineWidth = 3
                        ctx.beginPath()
                        ctx.moveTo(mx, 0); ctx.lineTo(mx, height)
                        ctx.moveTo(0, my); ctx.lineTo(width, my)
                        ctx.stroke()
                        ctx.strokeStyle = "rgba(255,255,255,0.9)"; ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(mx, 0); ctx.lineTo(mx, height)
                        ctx.moveTo(0, my); ctx.lineTo(width, my)
                        ctx.stroke()
                        ctx.strokeStyle = "rgba(255,255,255,0.9)"; ctx.lineWidth = 1.5
                        ctx.beginPath(); ctx.arc(mx, my, 6, 0, Math.PI * 2); ctx.stroke()
                        ctx.fillStyle = "rgba(255,255,255,1.0)"
                        ctx.beginPath(); ctx.arc(mx, my, 2, 0, Math.PI * 2); ctx.fill()
                    }
                    if (win.dragging || hasSel) {
                        var ex = sx + sw, ey = sy + sh
                        ctx.strokeStyle = "rgba(0,0,0,0.5)"; ctx.lineWidth = 3
                        ctx.setLineDash([])
                        ctx.beginPath()
                        ctx.moveTo(sx, 0); ctx.lineTo(sx, height)
                        ctx.moveTo(ex, 0); ctx.lineTo(ex, height)
                        ctx.moveTo(0, sy); ctx.lineTo(width, sy)
                        ctx.moveTo(0, ey); ctx.lineTo(width, ey)
                        ctx.stroke()
                        ctx.strokeStyle = "rgba(255,255,255,0.8)"; ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(sx, 0); ctx.lineTo(sx, height)
                        ctx.moveTo(ex, 0); ctx.lineTo(ex, height)
                        ctx.moveTo(0, sy); ctx.lineTo(width, sy)
                        ctx.moveTo(0, ey); ctx.lineTo(width, ey)
                        ctx.stroke()
                    }
                    if (hasSel) {
                        ctx.setLineDash([])
                        ctx.strokeStyle = "rgba(255,255,255,0.15)"; ctx.lineWidth = 0.5
                        ctx.beginPath()
                        ctx.moveTo(sx + sw/3,   sy);        ctx.lineTo(sx + sw/3,   sy + sh)
                        ctx.moveTo(sx + 2*sw/3, sy);        ctx.lineTo(sx + 2*sw/3, sy + sh)
                        ctx.moveTo(sx,          sy + sh/3); ctx.lineTo(sx + sw,     sy + sh/3)
                        ctx.moveTo(sx,          sy+2*sh/3); ctx.lineTo(sx + sw,     sy+2*sh/3)
                        ctx.stroke()
                        ctx.strokeStyle = "rgba(0,0,0,0.6)"; ctx.lineWidth = 3
                        ctx.strokeRect(sx, sy, sw, sh)
                        ctx.strokeStyle = "rgba(255,255,255,0.9)"; ctx.lineWidth = 1.5
                        ctx.strokeRect(sx, sy, sw, sh)
                        var handles = [
                            [sx,      sy     ], [sx+sw/2, sy     ], [sx+sw, sy     ],
                            [sx+sw,   sy+sh/2],
                            [sx+sw,   sy+sh  ], [sx+sw/2, sy+sh  ], [sx,    sy+sh  ],
                            [sx,      sy+sh/2]
                        ]
                        var hs = 8
                        for (var i = 0; i < handles.length; i++) {
                            var hx = handles[i][0], hy = handles[i][1]
                            ctx.fillStyle = "rgba(0,0,0,0.5)"
                            ctx.fillRect(hx - hs/2 - 0.5, hy - hs/2 - 0.5, hs+1, hs+1)
                            ctx.fillStyle = "white"
                            ctx.fillRect(hx - hs/2, hy - hs/2, hs, hs)
                        }
                    }
                }
            }
            Rectangle {
                readonly property real dpr: win.screen?.devicePixelRatio ?? 1.0
                visible: win.selW > 30 && win.selH > 10
                z: 10
                opacity: win.fadeOpacity
                width: _szText.implicitWidth + Style.marginL
                height: Style.controlHeightS
                radius: Style.controlHeightS / 2
                color: Qt.rgba(0, 0, 0, 0.85)
                border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
                x: Math.max(4, Math.min(win.selX + win.selW/2 - width/2, win.width - width - 4))
                y: win.selY > 48 ? win.selY - height - Style.marginS : win.selY + win.selH + Style.marginS
                NText {
                    id: _szText
                    anchors.centerIn: parent
                    font.weight: Font.Bold
                    text: Math.round(win.selW * parent.dpr) + " × " + Math.round(win.selH * parent.dpr)
                    color: "white"
                    pointSize: Style.fontSizeXS
                }
            }
            Rectangle {
                visible: !win.dragging && win.selW < 4
                z: 10
                opacity: win.fadeOpacity
                width: _coordText.implicitWidth + Style.marginM
                height: Style.controlHeightXXS
                radius: Style.radiusS
                color: Qt.rgba(0, 0, 0, 0.75)
                x: { var bx = win.mouseX + 20; return bx + width > win.width - 4 ? win.mouseX - width - 20 : bx }
                y: { var by = win.mouseY + 20; return by + height > win.height - 4 ? win.mouseY - height - 20 : by }
                NText {
                    id: _coordText
                    anchors.centerIn: parent
                    text: Math.round(win.mouseX) + ", " + Math.round(win.mouseY)
                    color: Qt.rgba(1,1,1,0.9)
                    pointSize: Style.fontSizeXS
                }
            }
            Rectangle {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Style.marginXL }
                z: 10
                opacity: win.fadeOpacity * 0.9
                width: _hintRow.implicitWidth + Style.marginXL
                height: Style.controlHeightS
                radius: Style.controlHeightS / 2
                color: Qt.rgba(0, 0, 0, 0.75)
                border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                Row {
                    id: _hintRow
                    anchors.centerIn: parent
                    spacing: 0
                    NText { text: pluginApi?.tr("regionSelector.drag");        color: Qt.rgba(1,1,1,0.7); pointSize: Style.fontSizeXS; font.weight: Font.Bold }
                    NText { text: pluginApi?.tr("regionSelector.toSelect");    color: Qt.rgba(1,1,1,0.4); pointSize: Style.fontSizeXS }
                    Item { width: Style.marginL; height: 1; visible: !root.isNiri }
                    Rectangle { width: 1; height: 14; color: Qt.rgba(1,1,1,0.25); anchors.verticalCenter: parent.verticalCenter; visible: !root.isNiri }
                    Item { width: Style.marginL; height: 1; visible: !root.isNiri }
                    NText { text: pluginApi?.tr("regionSelector.clickWindow"); color: Qt.rgba(1,1,1,0.7); pointSize: Style.fontSizeXS; font.weight: Font.Bold; visible: !root.isNiri }
                    NText { text: pluginApi?.tr("regionSelector.toSnap");      color: Qt.rgba(1,1,1,0.4); pointSize: Style.fontSizeXS; visible: !root.isNiri }
                    Item { width: Style.marginL; height: 1 }
                    Rectangle { width: 1; height: 14; color: Qt.rgba(1,1,1,0.25); anchors.verticalCenter: parent.verticalCenter }
                    Item { width: Style.marginL; height: 1 }
                    NText { text: pluginApi?.tr("regionSelector.esc");         color: Qt.rgba(1,1,1,0.7); pointSize: Style.fontSizeXS; font.weight: Font.Bold }
                    NText { text: pluginApi?.tr("regionSelector.toCancel");    color: Qt.rgba(1,1,1,0.4); pointSize: Style.fontSizeXS }
                }
            }
            MouseArea {
                anchors.fill: parent
                z: 3
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.CrossCursor
                onPressed: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        root.hide(); root.cancelled(); return
                    }
                    win.startPos = Qt.point(mouse.x, mouse.y)
                    win.selX = mouse.x; win.selY = mouse.y
                    win.selW = 0;       win.selH = 0
                    win.dragging = true
                    guides.requestPaint()
                }
                onPositionChanged: (mouse) => {
                    win.mouseX = mouse.x; win.mouseY = mouse.y
                    guides.requestPaint()
                    if (win.dragging) {
                        win.selX = Math.min(win.startPos.x, mouse.x)
                        win.selY = Math.min(win.startPos.y, mouse.y)
                        win.selW = Math.abs(mouse.x - win.startPos.x)
                        win.selH = Math.abs(mouse.y - win.startPos.y)
                    }
                }
                onReleased: (mouse) => {
                    if (mouse.button === Qt.RightButton) return
                    win.dragging = false
                    if (win.selW < 5 && win.selH < 5) {
                        if (!root.isNiri) {
                            var hi = win._winAt(mouse.x, mouse.y)
                            if (hi >= 0) {
                                var region = root.windowRegions[hi]
                                var scale = win.screen?.devicePixelRatio ?? 1.0
                                var offx = win.screen?.x ?? 0, offy = win.screen?.y ?? 0
                                win.pendingCapture = {
                                    x: Math.round((region.x - offx) * scale),
                                    y: Math.round((region.y - offy) * scale),
                                    w: Math.round(region.w * scale),
                                    h: Math.round(region.h * scale),
                                    screen: win.screen
                                }
                                root.hide(); captureDelay.start(); return
                            }
                        }
                        root.hide(); root.cancelled(); return
                    }
                    var w = Math.round(win.selW), h = Math.round(win.selH)
                    if (w > 4 && h > 4) {
                        var scale2 = win.screen?.devicePixelRatio ?? 1.0
                        win.pendingCapture = {
                            x: Math.round(win.selX * scale2),
                            y: Math.round(win.selY * scale2),
                            w: Math.round(w * scale2),
                            h: Math.round(h * scale2),
                            screen: win.screen
                        }
                        root.hide(); captureDelay.start()
                    } else {
                        root.hide(); root.cancelled()
                    }
                }
            }
            Shortcut {
                sequence: "Escape"; enabled: win.visible
                onActivated: { root.hide(); root.cancelled() }
            }
        }
    }
}
