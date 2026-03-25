import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    id: selectorVariants

    // ── Public API ────────────────────────────────────────────
    signal regionSelected(real x, real y, real w, real h, var screen)
    signal cancelled()

    property bool isVisible: false
    property var activeScreen: null

    function show(screen) {
        var target = screen || null
        if (!target && Quickshell.screens.length > 0)
            target = Quickshell.screens[0]
        selectorVariants.activeScreen = target
        selectorVariants.isVisible = true
    }

    function hide() {
        selectorVariants.isVisible = false
        selectorVariants.activeScreen = null
    }

    // ── Per-screen delegate ───────────────────────────────────
    model: Quickshell.screens

    delegate: PanelWindow {
        id: win

        required property ShellScreen modelData
        screen: modelData

        visible: selectorVariants.isVisible && modelData === selectorVariants.activeScreen

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "noctalia-region-selector"

        // ── Selection state ───────────────────────────────────
        property real selX: 0
        property real selY: 0
        property real selW: 0
        property real selH: 0

        property real dispX: selX
        property real dispY: selY
        property real dispW: selW
        property real dispH: selH

        property real mouseX: 0
        property real mouseY: 0
        property point startPos
        property bool dragging: false

        // ── Fade-in on open ───────────────────────────────────
        property real fadeOpacity: 0.0

        onVisibleChanged: {
            if (visible) {
                fadeOpacity = 0.0
                fadeIn.restart()
            } else {
                fadeIn.stop()
                selX = 0; selY = 0; selW = 0; selH = 0
                dragging = false
            }
        }

        NumberAnimation {
            id: fadeIn
            target: win
            property: "fadeOpacity"
            from: 0.0; to: 1.0
            duration: 140
            easing.type: Easing.OutCubic
        }

        // ── Pending capture ───────────────────────────────────
        property var pendingCapture: null
        Timer {
            id: captureDelay
            interval: 80; repeat: false
            onTriggered: {
                if (win.pendingCapture) {
                    var p = win.pendingCapture
                    win.pendingCapture = null
                    selectorVariants.regionSelected(p.x, p.y, p.w, p.h, p.screen)
                }
            }
        }

        // ── GLSL shader dimming ───────────────────────────────
        ShaderEffect {
            anchors.fill: parent
            z: 0
            opacity: win.fadeOpacity

            property vector4d selectionRect: Qt.vector4d(win.dispX, win.dispY, win.dispW, win.dispH)
            property real dimOpacity: 0.72
            property vector2d screenSize: Qt.vector2d(win.width, win.height)
            property real borderRadius: 6.0
            property real outlineThickness: 1.5

            fragmentShader: Qt.resolvedUrl("dimming.frag.qsb")
        }

        // ── Crosshair + edge guides (Canvas) ──────────────────
        Canvas {
            id: guides
            anchors.fill: parent
            z: 2
            opacity: win.fadeOpacity

            property real rectX: win.dispX
            property real rectY: win.dispY
            property real rectW: win.dispW
            property real rectH: win.dispH
            property real curX: win.mouseX
            property real curY: win.mouseY
            property bool isDragging: win.dragging

            onRectXChanged: requestPaint()
            onRectYChanged: requestPaint()
            onRectWChanged: requestPaint()
            onRectHChanged: requestPaint()
            onCurXChanged:  requestPaint()
            onCurYChanged:  requestPaint()
            onIsDraggingChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                if (!win.dragging) {
                    // ── Solid crosshair before drag ────────────
                    ctx.setLineDash([])
                    // Shadow pass
                    ctx.strokeStyle = "rgba(0,0,0,0.45)"
                    ctx.lineWidth = 2.5
                    ctx.beginPath()
                    ctx.moveTo(win.mouseX, 0);   ctx.lineTo(win.mouseX, height)
                    ctx.moveTo(0, win.mouseY);   ctx.lineTo(width, win.mouseY)
                    ctx.stroke()
                    // White pass
                    ctx.strokeStyle = "rgba(255,255,255,0.92)"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(win.mouseX, 0);   ctx.lineTo(win.mouseX, height)
                    ctx.moveTo(0, win.mouseY);   ctx.lineTo(width, win.mouseY)
                    ctx.stroke()
                } else {
                    // ── Dashed edge guides during drag ─────────
                    var x1 = win.dispX, y1 = win.dispY
                    var x2 = win.dispX + win.dispW, y2 = win.dispY + win.dispH
                    // Shadow
                    ctx.strokeStyle = "rgba(0,0,0,0.45)"
                    ctx.lineWidth = 2.5
                    ctx.setLineDash([6, 4])
                    ctx.beginPath()
                    ctx.moveTo(x1, 0); ctx.lineTo(x1, height)
                    ctx.moveTo(x2, 0); ctx.lineTo(x2, height)
                    ctx.moveTo(0, y1); ctx.lineTo(width, y1)
                    ctx.moveTo(0, y2); ctx.lineTo(width, y2)
                    ctx.stroke()
                    // White
                    ctx.strokeStyle = "rgba(255,255,255,0.92)"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(x1, 0); ctx.lineTo(x1, height)
                    ctx.moveTo(x2, 0); ctx.lineTo(x2, height)
                    ctx.moveTo(0, y1); ctx.lineTo(width, y1)
                    ctx.moveTo(0, y2); ctx.lineTo(width, y2)
                    ctx.stroke()
                }
            }
        }

        // ── Corner + mid-edge handles ─────────────────────────
        // 8 handles: 0=TL 1=TC 2=TR 3=RC 4=BR 5=BC 6=BL 7=LC
        Repeater {
            model: (win.dragging && win.selW > 30 && win.selH > 30) ? 8 : 0
            delegate: Rectangle {
                z: 11
                width: 7; height: 7; radius: 1
                color: "white"
                border.color: Qt.rgba(0,0,0,0.55); border.width: 1
                opacity: win.fadeOpacity

                readonly property real hx: win.dispX
                readonly property real hy: win.dispY
                readonly property real hw: win.dispW
                readonly property real hh: win.dispH
                readonly property real mx: hx + hw / 2
                readonly property real my: hy + hh / 2

                x: [hx, mx, hx+hw, hx+hw, hx+hw, mx, hx, hx][index] - 3.5
                y: [hy, hy, hy,    my,    hy+hh, hy+hh, hy+hh, my][index] - 3.5
            }
        }

        // ── Size badge ────────────────────────────────────────
        Rectangle {
            visible: win.dragging && win.selW > 20
            opacity: win.fadeOpacity
            x: Math.max(4, Math.min(win.dispX + win.dispW / 2 - width / 2, win.width - width - 4))
            y: win.dispY > 36 ? win.dispY - 34 : win.dispY + win.dispH + 8
            width: sizeLabel.implicitWidth + 16
            height: 26; radius: 6
            color: Qt.rgba(0, 0, 0, 0.75)
            z: 10
            Text {
                id: sizeLabel
                anchors.centerIn: parent
                text: Math.round(win.selW) + " × " + Math.round(win.selH)
                color: "white"; font.pixelSize: 12
                font.family: "monospace"; font.weight: Font.Bold
            }
        }

        // ── Cursor coordinates (pre-drag only) ────────────────
        Rectangle {
            visible: !win.dragging
            opacity: win.fadeOpacity
            z: 10
            width: coordLabel.implicitWidth + 14
            height: 22; radius: 5
            color: Qt.rgba(0, 0, 0, 0.72)
            x: {
                var bx = win.mouseX + 18
                return bx + width > win.width - 4 ? win.mouseX - width - 18 : bx
            }
            y: {
                var by = win.mouseY + 18
                return by + height > win.height - 4 ? win.mouseY - height - 18 : by
            }
            Text {
                id: coordLabel
                anchors.centerIn: parent
                text: Math.round(win.mouseX) + ", " + Math.round(win.mouseY)
                color: Qt.rgba(1,1,1,0.85); font.pixelSize: 11
                font.family: "monospace"
            }
        }

        // ── Mouse interaction ─────────────────────────────────
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.CrossCursor
            z: 3

            onPressed: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    selectorVariants.hide(); selectorVariants.cancelled(); return
                }
                win.startPos = Qt.point(mouse.x, mouse.y)
                win.selX = mouse.x; win.selY = mouse.y
                win.selW = 0; win.selH = 0
                win.dragging = true
            }

            onPositionChanged: (mouse) => {
                win.mouseX = mouse.x; win.mouseY = mouse.y
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
                var w = Math.round(win.selW), h = Math.round(win.selH)
                var scale = win.screen?.devicePixelRatio ?? 1.0
                if (w > 4 && h > 4) {
                    win.pendingCapture = {
                        x: Math.round(win.selX * scale),
                        y: Math.round(win.selY * scale),
                        w: Math.round(w * scale),
                        h: Math.round(h * scale),
                        screen: win.screen
                    }
                    selectorVariants.hide()
                    captureDelay.start()
                } else {
                    selectorVariants.hide(); selectorVariants.cancelled()
                }
            }
        }

        // ── Keyboard ──────────────────────────────────────────
        Shortcut {
            sequence: "Escape"; enabled: win.visible
            onActivated: { selectorVariants.hide(); selectorVariants.cancelled() }
        }
    }
}
