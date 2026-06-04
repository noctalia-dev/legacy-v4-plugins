import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

// One pill per enabled device: a device icon inside a circular battery ring.
// Live battery data comes from Main.qml via pluginApi.mainInstance.devices;
// per-device appearance/behaviour comes from pluginApi.pluginSettings.devices.
Item {
    id: root

    // Plugin API (injected by PluginService).
    property var pluginApi: null

    // Required properties for bar widgets.
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    // Pills are sized to the capsule height (smaller than the full bar height)
    // so the bar centers them, matching the core widgets.
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

    // Live data from Main.qml.
    readonly property var liveDevices: (pluginApi && pluginApi.mainInstance) ? (pluginApi.mainInstance.devices || []) : []

    // Devices the user has enabled, merged with their live battery readings.
    readonly property var shownDevices: {
        var settings = pluginApi ? pluginApi.pluginSettings : null // dependency for re-eval
        var out = []
        for (var i = 0; i < liveDevices.length; i++) {
            var d = liveDevices[i]
            var cfg = cfgFor(d.id)
            if (cfg && cfg.enabled === true)
                out.push(d)
        }
        // Order to match the settings list (top = left-most / top-most).
        var order = (settings && settings.deviceOrder) ? settings.deviceOrder : []
        out.sort(function (a, b) {
            var ia = order.indexOf(a.id)
            var ib = order.indexOf(b.id)
            return (ia < 0 ? 9999 : ia) - (ib < 0 ? 9999 : ib)
        })
        return out
    }

    readonly property bool showPercentage: pluginApi && pluginApi.pluginSettings
                                           && pluginApi.pluginSettings.showPercentage === true

    readonly property bool showCharging: pluginApi && pluginApi.pluginSettings
                                         && pluginApi.pluginSettings.showCharging === true

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    visible: shownDevices.length > 0

    // ---- Helpers -----------------------------------------------------------

    function cfgFor(id) {
        var all = (pluginApi && pluginApi.pluginSettings) ? pluginApi.pluginSettings.devices : null
        return (all && all[id]) ? all[id] : null
    }

    function defaultIconForType(type) {
        switch (type) {
        case "mouse": return "mouse"
        case "keyboard": return "keyboard"
        case "headset": return "headphones"
        case "gamepad": return "device-gamepad"
        default: return "battery"
        }
    }

    // Theme color-role keys ("none"/"primary"/"secondary"/"tertiary"/"error"),
    // resolved with the same helper the core widgets use.
    function ringColorFor(device, cfg) {
        var key = cfg ? cfg.ringColor : ""
        if (key && key !== "" && key !== "none")
            return Color.resolveColorKey(key)
        // Auto: colour by charge state / level.
        if (device.charging)
            return Color.mTertiary
        var b = (typeof device.battery === "number") ? device.battery : 100
        if (b <= 15) return Color.mError
        if (b <= 35) return Color.mSecondary
        return Color.mPrimary
    }

    function launch(cfg) {
        if (cfg && cfg.launchCmd && cfg.launchCmd.trim() !== "")
            Quickshell.execDetached(["sh", "-lc", cfg.launchCmd])
    }

    // ---- Right-click menu (shared) -----------------------------------------

    NPopupContextMenu {
        id: contextMenu
        model: [
            { "label": "Settings", "action": "settings", "icon": "settings" },
            { "label": "Refresh now", "action": "refresh", "icon": "refresh" }
        ]
        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(root.screen)
            if (action === "settings")
                BarService.openPluginSettings(root.screen, pluginApi.manifest)
            else if (action === "refresh" && pluginApi && pluginApi.mainInstance)
                pluginApi.mainInstance.refresh()
        }
    }

    // ---- Layout ------------------------------------------------------------

    GridLayout {
        id: layout
        anchors.centerIn: parent
        columns: root.isBarVertical ? 1 : Math.max(1, shownDevices.length)
        rowSpacing: Style.marginXS
        columnSpacing: Style.marginXS

        Repeater {
            model: root.shownDevices

            delegate: Rectangle {
                id: pill

                required property var modelData
                readonly property var cfg: root.cfgFor(modelData.id)
                readonly property int battery: (typeof modelData.battery === "number") ? modelData.battery : -1
                readonly property color ringColor: root.ringColorFor(modelData, cfg)
                readonly property color iconColor: Color.resolveColorKey((cfg && cfg.iconColor) ? cfg.iconColor : "none")
                readonly property string iconName: (cfg && cfg.icon) ? cfg.icon : root.defaultIconForType(modelData.type)

                readonly property string tooltipLabel: modelData.name
                                                       + (pill.battery >= 0 ? " — " + pill.battery + "%" : "")
                                                       + (modelData.charging ? " ⚡" : "")

                implicitWidth: pillRow.implicitWidth + Style.marginM * 2
                implicitHeight: root.capsuleHeight
                radius: Style.radiusM
                color: pillMouse.containsMouse ? Color.mHover : Style.capsuleColor

                Behavior on color {
                    enabled: !Color.isTransitioning
                    ColorAnimation {
                        duration: Style.animationFast
                        easing.type: Easing.InOutQuad
                    }
                }

                RowLayout {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: Style.marginXS

                    // Circular battery ring with the device icon in the centre.
                    Item {
                        id: ring
                        readonly property real size: Math.round(root.capsuleHeight * 0.82)
                        implicitWidth: size
                        implicitHeight: size
                        Layout.alignment: Qt.AlignVCenter

                        Canvas {
                            id: ringCanvas
                            anchors.fill: parent
                            renderStrategy: Canvas.Cooperative
                            renderTarget: Canvas.FramebufferObject

                            readonly property real ratio: pill.battery >= 0 ? Math.max(0, Math.min(1, pill.battery / 100)) : 0
                            // Repaint when any visual input changes.
                            onRatioChanged: requestPaint()
                            property color trackColor: Qt.alpha(Color.mOnSurface, 0.22)
                            property color valueColor: pill.ringColor
                            onValueColorChanged: requestPaint()
                            onTrackColorChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var lw = Math.max(2, Math.round(width * 0.11))
                                var cx = width / 2
                                var cy = height / 2
                                var r = (width - lw) / 2
                                var start = -Math.PI / 2 // 12 o'clock

                                ctx.lineWidth = lw
                                ctx.lineCap = "round"

                                // Track
                                ctx.strokeStyle = trackColor
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                                ctx.stroke()

                                // Value arc
                                if (ratio > 0.001) {
                                    ctx.strokeStyle = valueColor
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, start, start + ratio * 2 * Math.PI)
                                    ctx.stroke()
                                }
                            }
                        }

                        NIcon {
                            anchors.centerIn: parent
                            icon: pill.iconName
                            color: pill.iconColor
                            applyUiScale: false // ring.size already accounts for UI scale
                            pointSize: Math.round(ring.size * 0.5)
                        }
                    }

                    NIcon {
                        visible: root.showCharging && modelData.charging
                        icon: "bolt"
                        color: Color.mTertiary
                        applyUiScale: false
                        pointSize: Math.round(root.capsuleHeight * 0.4)
                        Layout.alignment: Qt.AlignVCenter
                    }

                    NText {
                        visible: root.showPercentage && pill.battery >= 0
                        text: pill.battery + "%"
                        color: Color.mOnSurface
                        pointSize: root.barFontSize
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        TooltipService.hide()
                        if (mouse.button === Qt.RightButton)
                            PanelService.showContextMenu(contextMenu, pill, root.screen)
                        else
                            root.launch(pill.cfg)
                    }
                    onEntered: {
                        TooltipService.show(pill, pill.tooltipLabel, BarService.getTooltipDirection(root.screenName))
                        tooltipRefreshTimer.start()
                    }
                    onExited: {
                        tooltipRefreshTimer.stop()
                        TooltipService.hide()
                    }

                    // Keep the tooltip percentage current while hovering.
                    Timer {
                        id: tooltipRefreshTimer
                        interval: 1000
                        repeat: true
                        onTriggered: {
                            if (pillMouse.containsMouse)
                                TooltipService.updateText(pill.tooltipLabel)
                        }
                    }
                }
            }
        }
    }

    readonly property real barFontSize: Style.fontSizeXS
}
