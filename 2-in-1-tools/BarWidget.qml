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
    property var cfg: pluginApi?.pluginSettings ?? ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

    readonly property string outputName: screen?.name ?? ""
    readonly property var backend: pluginApi?.mainInstance
    readonly property string currentTransform: backend?.transformForOutput(outputName) ?? "Normal"
    readonly property string configuredIcon: cfg.iconName ?? defaults.iconName ?? "rotate-cw"
    readonly property bool showTransformInTooltip: cfg.showTransformInTooltip ?? defaults.showTransformInTooltip ?? true

    icon: backend?.buttonUsesManualRotate() ? configuredIcon : (backend?.buttonIconName() ?? "screen-rotation")
    visible: backend?.buttonVisible(outputName) ?? false
    enabled: backend?.buttonEnabled(outputName) ?? false
    tooltipText: backend?.buttonUsesManualRotate()
        ? (showTransformInTooltip
            ? "Rotate display · Current: " + (backend?.transformLabel(currentTransform) ?? "Normal")
            : "Rotate display")
        : (backend?.buttonTooltip(outputName) ?? "Auto-rotate")
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    applyUiScale: false
    customRadius: Style.radiusL
    colorBg: Style.capsuleColor
    colorFg: Color.mOnSurfaceVariant
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    onClicked: backend?.activatePrimaryButton(outputName)
    onRightClicked: PanelService.showContextMenu(contextMenu, root, screen)

    Component.onCompleted: backend?.refreshTransform(outputName)
    onScreenChanged: backend?.refreshTransform(outputName)

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": backend?.buttonUsesManualRotate() ? "Rotate now" : "Toggle rotation lock",
                "action": "rotate",
                "icon": backend?.buttonUsesManualRotate() ? configuredIcon : (backend?.buttonIconName() ?? "screen-rotation")
            },
            {
                "label": "Rotate manually",
                "action": "manual-rotate",
                "icon": configuredIcon
            },
            {
                "label": "Refresh state",
                "action": "refresh",
                "icon": "refresh"
            },
            {
                "label": "Settings",
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)

            if (action === "rotate")
                backend?.activatePrimaryButton(outputName)
            else if (action === "manual-rotate")
                backend?.cycleTransform(outputName)
            else if (action === "refresh")
                backend?.refreshTransform(outputName)
            else if (action === "settings")
                BarService.openPluginSettings(root.screen, pluginApi.manifest)
        }
    }
}
