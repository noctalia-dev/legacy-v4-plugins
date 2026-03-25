import QtQuick
import qs.Commons
import qs.Services.Media

Item {
    id: core

    property string orientation:     "up"
    property real   widgetScaleHint: 1.0

    property string visMode:         "bars"
    property int    barCount:        64
    property int    fps:             60
    property real   sensitivity:     1.5
    property real   smoothingVal:    0.18
    property bool   useGradient:     true
    property bool   fadeWhenIdle:    true
    property bool   useCustomColors: false
    property color  customPrimary:   "#6750A4"
    property color  customSecondary: "#625B71"

    readonly property color colorA: useCustomColors ? customPrimary   : Color.mPrimary
    readonly property color colorB: useCustomColors ? customSecondary : Color.mSecondary
    readonly property bool isVertical: orientation === "left" || orientation === "right"

    opacity: (fadeWhenIdle && SpectrumService.isIdle) ? 0.0 : 1.0
    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

    property var smoothed: { var a=[]; for(var i=0;i<32;i++) a.push(0.0); return a }

    function updateAudio() {
        var values = SpectrumService.values
        if (!values || values.length === 0) return
        var arr  = smoothed.slice()
        var slow = smoothingVal
        var sens = sensitivity
        for (var i = 0; i < 32; i++) {
            var si  = Math.floor(i / 32 * values.length)
            var raw = Math.min(1.0, (values[si] || 0.0) * sens)
            arr[i]  = raw > arr[i] ? arr[i] + (raw - arr[i]) * 0.65
                                   : arr[i] + (raw - arr[i]) * slow
        }
        smoothed = arr
    }

    function symmetricBands(n) {
        var out = []
        for (var i = 0; i < n; i++) {
            var distFromCenter = Math.abs(i - (n - 1) / 2)
            var t  = distFromCenter / ((n - 1) / 2)
            var si = Math.floor(t * 31)
            out.push(smoothed[si] || 0.0)
        }
        return out
    }

    Connections {
        target: SpectrumService
        function onValuesChanged() {
            if (!SpectrumService.isIdle) { core.updateAudio(); canvas.requestPaint() }
        }
    }

    Timer {
        interval: Math.round(1000 / Math.max(1, core.fps))
        running:  SpectrumService.isIdle && !core.fadeWhenIdle
        repeat:   true
        property real phase: 0.0
        onTriggered: {
            phase += 0.05
            var bars = []
            for (var i = 0; i < 32; i++) bars.push((Math.sin(phase + i * 0.35) * 0.5 + 0.5) * 0.12)
            core.smoothed = bars
            canvas.requestPaint()
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        layer.enabled: false

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if      (core.visMode === "wave")   _paintWave(ctx)
            else if (core.visMode === "mirror") _paintMirror(ctx)
            else                               _paintBars(ctx)
        }

        function _paintBars(ctx) {
            var n        = core.barCount
            var levels   = core.symmetricBands(n)
            var W        = width
            var H        = height
            var ori      = core.orientation
            var vert     = core.isVertical
            var trackLen = vert ? H : W
            var crossLen = vert ? W : H
            var gap      = 4

            for (var i = 0; i < n; i++) {
                var level = Math.min(1.0, Math.max(0.0, levels[i] || 0))
                var blen  = Math.max(1, level * crossLen)
                var p1    = Math.floor(i       / n * trackLen)
                var p2    = Math.floor((i + 1) / n * trackLen)
                var thick = Math.max(1, p2 - p1 - gap)

                if (core.useGradient) {
                    var g = vert
                        ? ((ori === "right") ? ctx.createLinearGradient(0,0,W,0) : ctx.createLinearGradient(W,0,0,0))
                        : ((ori === "up")    ? ctx.createLinearGradient(0,H,0,0) : ctx.createLinearGradient(0,0,0,H))
                    g.addColorStop(0, Qt.alpha(core.colorA, 1.0))
                    g.addColorStop(1, Qt.alpha(core.colorB, 0.75))
                    ctx.fillStyle = g
                } else {
                    ctx.fillStyle = Qt.alpha(core.colorA, 1.0)
                }

                if (vert) {
                    if (ori === "left") ctx.fillRect(W - blen, p1, blen,  thick)
                    else                ctx.fillRect(0,        p1, blen,  thick)
                } else {
                    if (ori === "up")   ctx.fillRect(p1, H - blen, thick, blen)
                    else                ctx.fillRect(p1, 0,        thick, blen)
                }
            }
        }

        function _paintMirror(ctx) {
            var n        = core.barCount
            var levels   = core.symmetricBands(n)
            var W        = width
            var H        = height
            var vert     = core.isVertical
            var trackLen = vert ? H : W
            var crossLen = vert ? W : H
            var mid      = crossLen * 0.5
            var gap      = 4

            for (var i = 0; i < n; i++) {
                var level = Math.min(1.0, Math.max(0.0, levels[i] || 0))
                var half  = Math.max(1, level * mid)
                var p1    = Math.floor(i       / n * trackLen)
                var p2    = Math.floor((i + 1) / n * trackLen)
                var thick = Math.max(1, p2 - p1 - gap)

                if (core.useGradient) {
                    var g = vert
                        ? ctx.createLinearGradient(0,0,W,0)
                        : ctx.createLinearGradient(0,0,0,H)
                    g.addColorStop(0,   Qt.alpha(core.colorA, 1.0))
                    g.addColorStop(0.5, Qt.alpha(core.colorB, 0.75))
                    g.addColorStop(1,   Qt.alpha(core.colorA, 1.0))
                    ctx.fillStyle = g
                } else {
                    ctx.fillStyle = Qt.alpha(core.colorA, 1.0)
                }

                if (vert) ctx.fillRect(mid - half, p1, half * 2, thick)
                else      ctx.fillRect(p1, mid - half, thick, half * 2)
            }
        }

        function _paintWave(ctx) {
            var n      = 64
            var levels = core.symmetricBands(n)
            var W      = width
            var H      = height
            var vert   = core.isVertical

            if (core.useGradient) {
                var g = vert ? ctx.createLinearGradient(0,0,W,0) : ctx.createLinearGradient(0,0,0,H)
                g.addColorStop(0,   Qt.alpha(core.colorA, 1.0))
                g.addColorStop(0.5, Qt.alpha(core.colorB, 0.85))
                g.addColorStop(1,   Qt.alpha(core.colorA, 1.0))
                ctx.fillStyle = g
            } else {
                ctx.fillStyle = Qt.alpha(core.colorA, 0.95)
            }

            ctx.beginPath()

            if (vert) {
                var midX = W * 0.5
                ctx.moveTo(midX, 0)
                for (var i = 0; i < n; i++) {
                    var lvl = Math.min(1.0, Math.max(0.0, levels[i] || 0))
                    ctx.lineTo(midX - lvl * midX * 0.92, (i / (n - 1)) * H)
                }
                ctx.lineTo(midX, H)
                for (var i = n - 1; i >= 0; i--) {
                    var lvl = Math.min(1.0, Math.max(0.0, levels[i] || 0))
                    ctx.lineTo(midX + lvl * midX * 0.92, (i / (n - 1)) * H)
                }
            } else {
                var midY = H * 0.5
                ctx.moveTo(0, midY)
                for (var i = 0; i < n; i++) {
                    var lvl = Math.min(1.0, Math.max(0.0, levels[i] || 0))
                    ctx.lineTo((i / (n - 1)) * W, midY - lvl * midY * 0.92)
                }
                ctx.lineTo(W, midY)
                for (var i = n - 1; i >= 0; i--) {
                    var lvl = Math.min(1.0, Math.max(0.0, levels[i] || 0))
                    ctx.lineTo((i / (n - 1)) * W, midY + lvl * midY * 0.92)
                }
            }

            ctx.closePath()
            ctx.fill()
        }
    }
}
