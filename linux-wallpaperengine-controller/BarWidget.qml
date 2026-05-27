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

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string iconColorKey: cfg.iconColor ?? defaults.iconColor ?? "none"
  readonly property color resolvedIconColor: Color.resolveColorKey(iconColorKey)
  readonly property bool hasCustomIconColor: iconColorKey !== "none"

  icon: "wallpaper-selector"
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: {
    if (root.hasCustomIconColor) {
      return root.resolvedIconColor;
    }
    return Color.mOnSurface;
  }

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  tooltipText: {
    if (mainInstance?.checkingEngine) {
      return pluginApi?.tr("widget.tooltip.checking");
    }
    if (!mainInstance?.engineAvailable) {
      return pluginApi?.tr("widget.tooltip.unavailable");
    }
    if (mainInstance?.isApplying) {
      return pluginApi?.tr("widget.tooltip.running");
    }
    return pluginApi?.tr("widget.tooltip.ready");
  }

  onClicked: {
    if (pluginApi) {
      pluginApi.togglePanel(root.screen, this);
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("menu.refreshWallpapers"),
        "action": "refreshWallpapers",
        "icon": "refresh"
      },
      {
        "label": mainInstance?.engineRunning ? pluginApi?.tr("menu.stop") : pluginApi?.tr("menu.start"),
        "action": mainInstance?.engineRunning ? "stop" : "start",
        "icon": mainInstance?.engineRunning ? "player-stop" : "player-play"
      },
      {
        "label": pluginApi?.tr("menu.settings"),
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: function (action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "refreshWallpapers") {
        mainInstance?.refreshWallpaperCache(true, true);
      } else if (action === "stop") {
        mainInstance?.stopAll(true);
      } else if (action === "start") {
        mainInstance?.reload(true);
      } else if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi?.manifest);
      }
    }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
