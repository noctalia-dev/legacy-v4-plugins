import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    readonly property var pluginSettings: {
        return pluginApi && pluginApi.pluginSettings ? pluginApi.pluginSettings : {
        };
    }
    readonly property var main: {
        return pluginApi && pluginApi.mainInstance ? pluginApi.mainInstance : {
        };
    }
    readonly property var tr: {
        return pluginApi && pluginApi.tr ? pluginApi.tr : (key) => {
            return key;
        };
    }
    readonly property string screenName: screen && screen.name ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)
    readonly property string displayMode: root.pluginSettings.displayMode ?? "onhover"
    readonly property string connectedColor: root.pluginSettings.connectedColor
    readonly property string disconnectedColor: root.pluginSettings.disconnectedColor
    readonly property var vpnList: root.main.vpnList ? root.main.vpnList : []
    readonly property real connectedCount: root.main.connectedCount ? root.main.connectedCount : 0
    readonly property bool isLoading: root.main.isLoading ? root.main.isLoading : false

    implicitWidth: pill.width
    implicitHeight: pill.height
    Component.onCompleted: {
        Logger.i("NetworkManagerVPN", "Bar widget loaded");
    }

    NPopupContextMenu {
        id: contextMenu

        model: [{
            "label": root.tr("settings.pluginSettings"),
            "action": "plugin-settings",
            "icon": "settings"
        }]
        onTriggered: (action) => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);
            if (action === "plugin-settings")
                BarService.openPluginSettings(screen, pluginApi.manifest);

        }
    }

    BarPill {
        id: pill

        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)
        autoHide: false
        text: root.connectedCount > 0 ? root.tr("common.connected") : root.tr("common.disconnected")
        icon: root.isLoading ? "reload" : root.connectedCount > 0 ? "shield-lock" : "shield"
        onClicked: {
            if (pluginApi)
                pluginApi.openPanel(root.screen, root);

        }
        onRightClicked: {
            PanelService.showContextMenu(contextMenu, pill, screen);
        }
        customIconColor: Color.resolveColorKeyOptional(root.connectedCount > 0 ? root.connectedColor : root.disconnectedColor)
        customTextColor: Color.resolveColorKeyOptional(root.connectedCount > 0 ? root.connectedColor : root.disconnectedColor)
        forceOpen: root.displayMode === "alwaysShow"
        forceClose: root.displayMode === "alwaysHide"
    }

}
