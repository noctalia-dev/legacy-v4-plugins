import QtQuick
import qs.Commons
import qs.Widgets
import Quickshell

NIconButton {
  id: root

  // Required properties for bar widgets
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  // Plugin API (injected by PluginService)
  property var pluginApi: null

  // Per-screen bar properties
  readonly property string screenName: screen?.name ?? ""
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

  // NIconButton configuration
  baseSize: capsuleHeight
  applyUiScale: false
  customRadius: Style.radiusL
  icon: "screenshot"
  tooltipText: pluginApi?.tr("panel.title") || "Screenshot"
  tooltipDirection: BarService.getTooltipDirection(screenName)
  colorBg: Style.capsuleColor
  colorFg: Color.mOnSurface
  colorBgHover: Color.mHover
  colorFgHover: Color.mOnHover
  colorBorder: Style.capsuleBorderColor
  colorBorderHover: Style.capsuleBorderColor

  onClicked: {
    if (pluginApi) {
      pluginApi.openPanel(root.screen, root)
    }
  }
}