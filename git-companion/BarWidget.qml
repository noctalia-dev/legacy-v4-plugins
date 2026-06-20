import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets
import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property string platform: cfg.platform ?? defaults.platform
    readonly property var main: pluginApi?.mainInstance

    property string requestLabel: platform === 'gitlab' ? pluginApi?.tr("panel.mr") : pluginApi?.tr("panel.pr")
    property string tooltipText: pluginApi?.tr("widget.tooltip", {
        issues: main?.issuesCount ?? 0,
        requestCount: main?.prsCount ?? 0,
        requestLabel
    })
    property var pluginApi: null
    property ShellScreen screen
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0
    property string section: ""
    property string widgetId: ""

    implicitWidth: pill.width
    implicitHeight: pill.height

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": pluginApi?.tr("menu.settings"),
                "action": "settings",
                "icon": "settings"
            },
        ]

        onTriggered: function (action) {
            contextMenu.close();
            PanelService.closeContextMenu(screen);
            if (action === "settings") {
                BarService.openPluginSettings(root.screen, pluginApi.manifest);
            }
        }
    }
    BarPill {
        id: pill

        autoHide: false
        customIconColor: Color.resolveColorKeyOptional(root.iconColorKey)
        customTextColor: Color.resolveColorKeyOptional(root.textColorKey)
        forceClose: isBarVertical || root.displayMode === "alwaysHide" || text === ""
        forceOpen: !isBarVertical && root.displayMode === "alwaysShow"
        icon: platform === 'gitlab' ? 'brand-gitlab' : "brand-github"
        oppositeDirection: BarService.getPillDirection(root)
        screen: root.screen
        tooltipText: root.tooltipText

        onClicked: {
            if (pluginApi) {
                pluginApi.openPanel(root.screen, this);
            }
        }
        onRightClicked: {
            PanelService.showContextMenu(contextMenu, root, screen);
        }
    }
}
