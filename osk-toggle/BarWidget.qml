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

    readonly property var mainInstance: pluginApi?.mainInstance
    property bool keyboardActive: mainInstance?.keyboardActive ?? false
    property bool available: mainInstance?.available ?? false

    readonly property var pluginDefaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})
    readonly property bool hideWhenUnavailable: pluginApi?.pluginSettings?.hideWhenUnavailable ?? pluginDefaults.hideWhenUnavailable ?? false
    readonly property bool disableHoverIcon: pluginApi?.pluginSettings?.disableHoverIcon ?? pluginDefaults.disableHoverIcon ?? false

    readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name ?? "")
    readonly property bool flipHoverIcons: barPosition === "bottom"
    readonly property bool isVerticalBar: barPosition === "left" || barPosition === "right"

    visible: available || !hideWhenUnavailable

    icon: !available ? "alert-circle"
        : (hovering && !isVerticalBar && !disableHoverIcon
            ? (keyboardActive
                ? (flipHoverIcons ? "keyboard-show" : "keyboard-hide")
                : (flipHoverIcons ? "keyboard-hide" : "keyboard-show"))
            : (keyboardActive ? "keyboard" : "keyboard-off"))
    tooltipText: !available
        ? pluginApi?.tr(mainInstance?.unavailableTooltipKey ?? "tooltip.detecting")
        : (keyboardActive ? pluginApi?.tr("tooltip.active") : pluginApi?.tr("tooltip.hidden"))
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    applyUiScale: false
    customRadius: Style.radiusL
    colorBg: Style.capsuleColor
    colorFg: !available ? Color.mError : (keyboardActive ? Color.mPrimary : Color.mOnSurfaceVariant)
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    onClicked: { if (available) mainInstance?.toggleKeyboard() }

    onRightClicked: {
        PanelService.showContextMenu(contextMenu, root, screen)
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": pluginApi?.tr("menu.settings"),
                "action": "widget-settings",
                "icon": "settings"
            }
        ]

        onTriggered: function(action) {
            contextMenu.close()
            PanelService.closeContextMenu(screen)
            if (action === "widget-settings") {
                BarService.openPluginSettings(root.screen, pluginApi.manifest)
            }
        }
    }
}
