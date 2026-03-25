import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    property var cfg:      pluginApi?.pluginSettings                      || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    // Use "none" as sentinel — when none, omit colorFg so Noctalia's color scheme applies
    property string iconColorKey: cfg.iconColor ?? "none"
    readonly property color iconColor: Color.resolveColorKey(iconColorKey)
    readonly property bool hasCustomColor: iconColorKey !== "none"

    icon: "sparkles"
    tooltipText: pluginApi?.tr("widget.tooltip")
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    customRadius: Style.radiusL
    colorBg: Style.capsuleColor
    colorFg: hasCustomColor ? iconColor : Color.mOnSurface
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    onClicked: {
        if (pluginApi) {
            pluginApi.openPanel(root.screen, this)
        }
    }

    NPopupContextMenu {
        id: contextMenu
        model: [
            { "label": I18n.tr("actions.widget-settings"), "action": "settings", "icon": "settings" }
        ]
        onTriggered: function(action) {
            contextMenu.close()
            PanelService.closeContextMenu(screen)
            if (action === "settings") {
                BarService.openPluginSettings(root.screen, pluginApi.manifest)
            }
        }
    }

    onRightClicked: {
        PanelService.showContextMenu(contextMenu, root, screen)
    }
}
