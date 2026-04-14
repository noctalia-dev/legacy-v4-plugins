import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Modules.Bar.Extras
import qs.Services.UI

Item {
    id: root
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0
    property var pluginApi: null

    implicitWidth:  pill.width
    implicitHeight: pill.height

    BarPill {
        id: pill
        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)
        forceClose: true

        icon:        "crosshair"
        tooltipText: pluginApi?.tr("widget.tooltip")

        onClicked: {
            if (pluginApi) pluginApi.togglePanel(root.screen, pill)
        }

        onRightClicked: {
            PanelService.showContextMenu(contextMenu, pill, root.screen)
        }
    }

    NPopupContextMenu {
        id: contextMenu
        model: [
            {
                "label":   pluginApi?.tr("settings.widgetSettings"),
                "action":  "widget-settings",
                "icon":    "settings",
                "enabled": true
            }
        ]
        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(root.screen)
            if (action === "widget-settings")
                BarService.openPluginSettings(screen, pluginApi.manifest)
        }
    }
}
