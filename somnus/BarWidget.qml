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
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property string iconColorKey: pluginApi?.pluginSettings?.iconColor
        || pluginApi?.manifest?.metadata?.defaultSettings?.iconColor || "primary"

    icon: "power"
    tooltipText: pluginApi?.tr("widget.tooltip")
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    applyUiScale: false
    customRadius: Style.radiusL

    colorBg: Style.capsuleColor
    colorFg: Color.resolveColorKey(iconColorKey)
    colorBgHover: Color.mHover
    colorFgHover: Color.mOnHover
    colorBorder: "transparent"
    colorBorderHover: "transparent"
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    onClicked: {
        Logger.i("Somnus", "Bar button pressed")
        pluginApi?.mainInstance?.togglePanel?.(screen)
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": pluginApi?.tr("menu.settings"),
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)
            if (action === "settings") {
                BarService.openPluginSettings(screen, pluginApi?.manifest)
            }
        }
    }

    onRightClicked: {
        PanelService.showContextMenu(contextMenu, root, screen)
    }
}
