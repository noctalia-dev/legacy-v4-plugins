import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
    id: root

    property ShellScreen screen
    property var pluginApi: null
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property bool alwaysShowBarWidget: cfg.alwaysShowBarWidget !== undefined
        ? cfg.alwaysShowBarWidget
        : (defaults.alwaysShowBarWidget !== undefined ? defaults.alwaysShowBarWidget : false)

    readonly property var main: pluginApi ? pluginApi.mainInstance : null
    readonly property bool isActive: !!main && main.enabled && main.externalPresent
    readonly property bool isDisabled: !main || !main.enabled
    readonly property string stateText: main?.stateLabel ? main.stateLabel() : (pluginApi?.tr("state.disabled") || "Off")
    readonly property string outputsText: main?.outputSummary ? main.outputSummary() : ""

    visible: root.alwaysShowBarWidget || (!!main && main.inhibitorActive)
    icon: root.alwaysShowBarWidget
        ? (root.isActive ? "display" : (root.isDisabled ? "display-off" : "laptop"))
        : "display"
    tooltipText: outputsText ? stateText + "\n" + outputsText : stateText
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    applyUiScale: false
    customRadius: Style.radiusL
    colorBg: Style.capsuleColor
    colorFg: root.isActive ? Color.mPrimary : (root.isDisabled ? Color.mOnSurfaceVariant : Color.mSecondary)

    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    onClicked: {
        if (root.main) {
            root.main.toggle();
        }
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": pluginApi?.tr("menu.settings") || "Settings",
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);
            if (action === "settings") {
                BarService.openPluginSettings(root.screen, pluginApi.manifest);
            }
        }
    }

    onRightClicked: {
        if (pluginApi) {
            PanelService.showContextMenu(contextMenu, root, screen);
        }
    }
}
