import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets
import qs.Modules.Bar.Extras

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property var main: pluginApi?.mainInstance ?? ({})

    readonly property real connectedCount: root.main.connectedCount ?? 0
    readonly property bool isLoading: root.main.isLoading ?? false
    readonly property int configCount: (root.main.configList ?? []).length
    readonly property bool hasConfigs: root.configCount > 0
    readonly property string connectedColor: root.cfg.connectedColor ?? defaults.connectedColor ?? "primary"
    readonly property string disconnectedColor: root.cfg.disconnectedColor ?? defaults.disconnectedColor ?? "none"
    readonly property string displayMode: root.cfg.displayMode ?? defaults.displayMode ?? "onhover"
    readonly property bool hideWhenInactive: root.cfg.hideWhenInactive ?? defaults.hideWhenInactive ?? false
    readonly property bool isInactive: root.connectedCount === 0 && !root.isLoading

    readonly property bool isHidden: root.hideWhenInactive && root.isInactive

    readonly property var sessionList: root.main.sessionList ?? []

    readonly property string connectedName: {
        if (root.connectedCount !== 1 || root.sessionList.length === 0) return ""
        const name = root.sessionList[0]?.name
        return (name && name.length > 0) ? name : ""
    }

    function _tooltipText() {
        if (root.isLoading)
            return pluginApi?.tr("bar.connecting")
        if (root.connectedCount > 0) {
            const lines = []
            for (let i = 0; i < root.sessionList.length; i++) {
                const s = root.sessionList[i]
                const name = (s?.name && s.name.length > 0) ? s.name : (s?.sessionPath || "session")
                lines.push(name)
            }
            return lines.join("\n")
        }
        if (!root.hasConfigs)
            return pluginApi?.tr("bar.noConfigs")
        return pluginApi?.tr("bar.disconnected")
    }

    readonly property string pillIcon: {
        if (root.isLoading) return "shield-check"
        if (root.connectedCount > 0) return "shield-lock"
        if (!root.hasConfigs) return "shield-off"
        return "shield"
    }

    readonly property string pillText: {
        if (root.connectedCount > 0) {
            if (root.connectedCount === 1 && root.connectedName.length > 0)
                return root.connectedName
            return root.connectedCount + " " + pluginApi?.tr("bar.active")
        }
        if (root.isLoading) return pluginApi?.tr("bar.connecting")
        if (!root.hasConfigs) return pluginApi?.tr("bar.noConfigs")
        return pluginApi?.tr("bar.disconnected")
    }

    opacity: root.isHidden ? 0.0 : 1.0
    implicitWidth: root.isHidden ? 0 : pill.width
    implicitHeight: root.isHidden ? 0 : pill.height

    NPopupContextMenu {
        id: contextMenu

        model: [{
            "label": pluginApi?.tr("menu.settings"),
            "action": "plugin-settings",
            "icon": "settings"
        }]
        onTriggered: (action) => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)
            if (action === "plugin-settings")
                BarService.openPluginSettings(screen, pluginApi.manifest)
        }
    }

    BarPill {
        id: pill

        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)
        autoHide: false
        text: root.pillText
        icon: root.pillIcon
        tooltipText: root._tooltipText()
        customIconColor: Color.resolveColorKeyOptional(root.connectedCount > 0 ? root.connectedColor : root.disconnectedColor)
        customTextColor: Color.resolveColorKeyOptional(root.connectedCount > 0 ? root.connectedColor : root.disconnectedColor)
        forceOpen: root.displayMode === "alwaysShow"
        forceClose: root.displayMode === "alwaysHide"

        onClicked: {
            if (pluginApi)
                pluginApi.togglePanel(root.screen, root)
        }
        onRightClicked: {
            PanelService.showContextMenu(contextMenu, root, screen)
        }
    }
}