import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Services.System
import qs.Services.Compositor
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    icon: "camera"
    tooltipText: pluginApi?.tr("tooltip") || "Take a screenshot"
    tooltipDirection: BarService.getTooltipDirection()
    baseSize: Style.capsuleHeight
    applyUiScale: false
    customRadius: Style.radiusL
    colorBg: Style.capsuleColor
    colorFg: Color.mOnSurface
    colorBorder: "transparent"
    colorBorderHover: "transparent"
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    readonly property string screenshotMode: 
        pluginApi?.pluginSettings?.mode || 
        pluginApi?.manifest?.metadata?.defaultSettings?.mode || 
        "region"

    function takeScreenshot() {
        if (CompositorService.isHyprland) {
            var args = ["hyprshot", "--freeze", "--clipboard-only", "--mode", screenshotMode, "--silent"];
            Quickshell.execDetached(args);
        } else if (CompositorService.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "screenshot"]);
        } else {
            // Fallback to hyprshot for other compositors
            var args = ["hyprshot", "--freeze", "--clipboard-only", "--mode", screenshotMode, "--silent"];
            Quickshell.execDetached(args);
        }
    }

    onClicked: {
        takeScreenshot();
    }

    onRightClicked: {
        PanelService.showContextMenu(contextMenu, root, screen);
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": I18n.tr("actions.widget-settings"),
                "action": "widget-settings",
                "icon": "settings"
            },
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            if (action === "widget-settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            }
        }
    }
}
