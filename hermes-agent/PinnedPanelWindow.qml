import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
  id: root

  property var pluginApi: null
  property var panelScreen: null
  property bool active: false

  readonly property string screenName: panelScreen ? panelScreen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real sideMargin: Style.marginM
  readonly property real panelWidth: {
    var screenWidth = panelScreen ? panelScreen.width : 1920;
    return Math.min(1080 * Style.uiScaleRatio, Math.max(860 * Style.uiScaleRatio, screenWidth * 0.52));
  }

  screen: panelScreen
  visible: active && panelScreen !== null
  color: "transparent"
  implicitWidth: Math.round(panelWidth)

  anchors {
    top: true
    bottom: true
    right: true
  }

  margins {
    top: sideMargin + (barPosition === "top" ? barHeight : 0)
    bottom: sideMargin + (barPosition === "bottom" ? barHeight : 0)
    right: sideMargin + (barPosition === "right" ? barHeight : 0)
  }

  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "noctalia-hermes-pinned-" + (screenName || "unknown")

  Rectangle {
    anchors.fill: parent
    color: Color.mSurface
    border.color: Color.mOutline
    border.width: Style.borderS
    radius: Style.radiusL
  }

  Panel {
    anchors.fill: parent
    pluginApi: root.pluginApi
  }
}
