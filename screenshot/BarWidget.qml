import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Services.System
import qs.Services.Compositor
import qs.Widgets
import "."

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    icon: "camera"
    tooltipText: pluginApi?.tr("tooltip")
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

    ScreenshotHelper {
        id: helper
        pluginApi: root.pluginApi
    }

    onClicked: {
        helper.takeScreenshot(root.screenshotMode);
    }

    onRightClicked: {
        PanelService.showContextMenu(contextMenu, root, screen);
    }

    NPopupContextMenu {
        id: contextMenu

        model: {
            var items = [
                {
                    "label": pluginApi?.tr("tooltip"),
                    "action": "take-screenshot",
                    "icon": "camera"
                }
            ];

            if (CompositorService.isHyprland) {
                items.push({
                    "label": pluginApi?.tr("actions.active-window"),
                    "action": "take-screenshot-active-window",
                    "icon": "window"
                });

                items.push({
                    "label": pluginApi?.tr("actions.active-screen"),
                    "action": "take-screenshot-active-screen",
                    "icon": "screen-share"
                });
            }

            items.push({
                "label": I18n.tr("actions.widget-settings"),
                "action": "widget-settings",
                "icon": "settings"
            });

            return items;
        }

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            if (action === "take-screenshot") {
                helper.takeScreenshot(root.screenshotMode);
            } else if (action === "take-screenshot-active-window") {
                helper.takeScreenshot("active-window");
            } else if (action === "take-screenshot-active-screen") {
                helper.takeScreenshot("active-screen");
            } else if (action === "widget-settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            }
        }
    }
}
