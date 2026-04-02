import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  // Required properties for bar widgets
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  // Plugin API (injected by PluginService)
  property var pluginApi: null
  // Bound to plugin-managed state so color changes are event-driven (no polling loop).
  readonly property bool recording: pluginApi?.mainInstance?.recordingActive ?? false

  // Per-screen bar properties
  readonly property string screenName: screen?.name ?? ""
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

  // NIconButton configuration
  baseSize: capsuleHeight
  applyUiScale: false
  customRadius: Style.radiusL
  icon: "screenshot"
  tooltipText: pluginApi?.tr("panel.title")
  tooltipDirection: BarService.getTooltipDirection(screenName)
  colorBg: recording ? Color.mError : Style.capsuleColor
  colorFg: recording ? Color.mOnError : Color.mOnSurface
  colorBgHover: recording ? Color.mError : Color.mHover
  colorFgHover: recording ? Color.mOnError : Color.mOnHover
  colorBorder: Style.capsuleBorderColor
  colorBorderHover: Style.capsuleBorderColor

  onClicked: {
    if (pluginApi) {
      pluginApi.openPanel(root.screen, root)
    }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen)
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)

      if (action === "widget-settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest)
      }
    }
  }
}