import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
    id: root
    property var pluginApi: null
    property ShellScreen screen

    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings
    readonly property string iconColorKey: pluginApi?.pluginSettings.iconColor ?? defaults.iconColor ?? "mPrimary"

    icon: "coin"
    tooltipText: pluginApi?.tr("widget.tooltip")
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    applyUiScale: false
    colorFg: Color.resolveColorKey(iconColorKey)
    customRadius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    transformOrigin: Item.Center
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    onClicked: {
        // bounce effect
        root.scale = 1.2
        bounceBack.start()

        // open panel
        if (pluginApi && pluginApi.openPanel) {
            pluginApi.openPanel(root.screen, root)
        }
    }

    Timer {
        id: bounceBack
        interval: 100
        running: false
        repeat: false
        onTriggered: { root.scale = 1.0 }
    }
}
