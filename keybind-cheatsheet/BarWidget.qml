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

  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  icon: "keyboard"
  tooltipText: pluginApi?.tr("keybind-cheatsheet.barwidget.tooltip") || "Keybind Cheatsheet"
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  customRadius: Style.radiusL

  colorBg: Style.capsuleColor
  colorFg: Color.mOnSurface
  colorBgHover: Color.mHover
  colorFgHover: Color.mOnHover
  colorBorder: "transparent"
  colorBorderHover: "transparent"

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": "Open Cheatsheet",
        "action": "open-panel",
        "icon": "keyboard"
      },
      {
        "label": "Plugin Settings",
        "action": "plugin-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "open-panel") {
        if (pluginApi) {
          pluginApi.openPanel(screen);
        }
      } else if (action === "plugin-settings") {
        if (pluginApi) {
          BarService.openPluginSettings(screen, pluginApi.manifest);
        }
      }
    }
  }

  onClicked: {
    if (pluginApi) {
      pluginApi.openPanel(screen);
    }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
