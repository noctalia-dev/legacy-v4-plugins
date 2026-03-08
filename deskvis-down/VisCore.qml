import QtQuick
import qs.Commons
import qs.Services.Media

Item {
    id: core

    property var    pluginApi:        null
    property string fixedOrientation: "up"
    property real   widgetScaleHint:  1.0

    readonly property string visMode:      pluginApi?.pluginSettings?.mode                  ?? "bars"
    readonly property int    barCount:     pluginApi?.pluginSettings?.barCount              ?? 64
    readonly property int    fps:          pluginApi?.pluginSettings?.fps                   ?? 60
    readonly property real   sensitivity:  pluginApi?.pluginSettings?.sensitivity           ?? 1.5
    readonly property real   smoothingVal: pluginApi?.pluginSettings?.smoothing             ?? 0.18
    readonly property bool   useGradient:  pluginApi?.pluginSettings?.useGradient           ?? true
    readonly property bool   fadeWhenIdle: pluginApi?.pluginSettings?.fadeWhenIdle          ?? true
    readonly property bool   useCustomColors:  pluginApi?.pluginSettings?.useCustomColors   ?? false
    readonly property color  customPrimary:    pluginApi?.pluginSettings?.customPrimaryColor    ?? "#6750A4"
    readonly property color  customSecondary:  pluginApi?.pluginSettings?.customSecondaryColor  ?? "#625B71"
    readonly property int    customWidth:  pluginApi?.pluginSettings?.customWidth           ?? 0
    readonly property int    customHeight: pluginApi?.pluginSettings?.customHeight          ?? 0

    readonly property color colorA: useCustomColors ? customPrimary   : Color.mPrimary
    readonly property color colorB: useCustomColors ? customSecondary : Color.mSecondary
    readonly property bool isVertical: fixedOrientation === "left" || fixedOrientation === "right"

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

        // ── BARS ──────────────────────────────────────────────────────────────
        function _paintBars(ctx) {
            var n        = core.barCount
            var levels   = core.smoothed
            var W        = width
            var H        = height
            var ori      = core.fixedOrientation
            var vert     = core.isVertical
            var trackLen = vert ? H : W
            var crossLen = vert ? W : H
            var gap      = 4

            for (var i = 0; i < n; i++) {
                var si    = Math.floor(i / n * 32)
                var level = Math.min(1.0, Math.max(0.0, levels[si] || 0))
                var blen  = Math.max(1, level * crossLen)
                var p1    = Math.floor(i       / n * trackLen)
                var p2    = Math.floor((i + 1) / n * trackLen)
                var thick = Math.max(1, p2 - p1 - gap)

                if (core.useGradient) {
                    var g = vert
                        ? ((ori === "right") ? ctx.createLinearGradient(0,0,W,0) : ctx.createLinearGradient(W,0,0,0))
                        : ((ori === "up")    ? ctx.createLinearGradient(0,H,0,0) : ctx.createLinearGradient(0,0,0,H))
                    g.addColorStop(0, _rgba(core.colorA, 1.0))
                    g.addColorStop(1, _rgba(core.colorB, 0.75))
                    ctx.fillStyle = g
                } else {
                    ctx.fillStyle = _rgba(core.colorA, 1.0)
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

        // ── MIRROR ────────────────────────────────────────────────────────────
        function _paintMirror(ctx) {
            var n        = core.barCount
            var levels   = core.smoothed
            var W        = width
            var H        = height
            var vert     = core.isVertical
            var trackLen = vert ? H : W
            var crossLen = vert ? W : H
            var mid      = crossLen * 0.5
            var gap      = 4

            for (var i = 0; i < n; i++) {
                var si    = Math.floor(i / n * 32)
                var level = Math.min(1.0, Math.max(0.0, levels[si] || 0))
                var half  = Math.max(1, level * mid)
                var p1    = Math.floor(i       / n * trackLen)
                var p2    = Math.floor((i + 1) / n * trackLen)
                var thick = Math.max(1, p2 - p1 - gap)

                if (core.useGradient) {
                    var g = vert
                        ? ctx.createLinearGradient(0,0,W,0)
                        : ctx.createLinearGradient(0,0,0,H)
                    g.addColorStop(0,   _rgba(core.colorA, 1.0))
                    g.addColorStop(0.5, _rgba(core.colorB, 0.75))
                    g.addColorStop(1,   _rgba(core.colorA, 1.0))
                    ctx.fillStyle = g
                } else {
                    ctx.fillStyle = _rgba(core.colorA, 1.0)
                }

                if (vert) ctx.fillRect(mid - half, p1, half * 2, thick)
                else      ctx.fillRect(p1, mid - half, thick, half * 2)
            }
        }

        // ── WAVE — smooth filled blob, mirrored from center ───────────────────
        function _paintWave(ctx) {
            var levels = core.smoothed
            var W      = width
            var H      = height
            var vert   = core.isVertical
            var n      = 32  // use all 32 bands for smooth shape

            if (core.useGradient) {
                var g = vert ? ctx.createLinearGradient(0,0,W,0) : ctx.createLinearGradient(0,0,0,H)
                g.addColorStop(0,   _rgba(core.colorA, 1.0))
                g.addColorStop(0.5, _rgba(core.colorB, 0.85))
                g.addColorStop(1,   _rgba(core.colorA, 1.0))
                ctx.fillStyle = g
            } else {
                ctx.fillStyle = _rgba(core.colorA, 0.95)
            }

            ctx.beginPath()

            if (vert) {
                var midX = W * 0.5
                // Forward: left edge top to bottom
                ctx.moveTo(midX, 0)
                for (var i = 0; i < n; i++) {
                    var si  = Math.floor(i / n * 32)
                    var lvl = Math.min(1.0, Math.max(0.0, levels[si] || 0))
                    var y   = (i / (n - 1)) * H
                    var x   = midX - lvl * midX * 0.92
                    ctx.lineTo(x, y)
                }
                // Return: right edge bottom to top
                ctx.lineTo(midX, H)
                for (var i = n - 1; i >= 0; i--) {
                    var si  = Math.floor(i / n * 32)
                    var lvl = Math.min(1.0, Math.max(0.0, levels[si] || 0))
                    var y   = (i / (n - 1)) * H
                    var x   = midX + lvl * midX * 0.92
                    ctx.lineTo(x, y)
                }
            } else {
                var midY = H * 0.5
                // Forward: top edge left to right
                ctx.moveTo(0, midY)
                for (var i = 0; i < n; i++) {
                    var si  = Math.floor(i / n * 32)
                    var lvl = Math.min(1.0, Math.max(0.0, levels[si] || 0))
                    var x   = (i / (n - 1)) * W
                    var y   = midY - lvl * midY * 0.92
                    ctx.lineTo(x, y)
                }
                // Return: bottom edge right to left
                ctx.lineTo(W, midY)
                for (var i = n - 1; i >= 0; i--) {
                    var si  = Math.floor(i / n * 32)
                    var lvl = Math.min(1.0, Math.max(0.0, levels[si] || 0))
                    var x   = (i / (n - 1)) * W
                    var y   = midY + lvl * midY * 0.92
                    ctx.lineTo(x, y)
                }
            }

            ctx.closePath()
            ctx.fill()
        }

        function _rgba(color, alpha) {
            return "rgba("
                + Math.round((color.r || 0) * 255) + ","
                + Math.round((color.g || 0) * 255) + ","
                + Math.round((color.b || 0) * 255) + ","
                + alpha + ")"
        }
    }
}
