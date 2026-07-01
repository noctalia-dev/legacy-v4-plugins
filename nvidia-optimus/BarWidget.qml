import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Bar button: the NVIDIA "eye" mark, tinted to the active Noctalia theme — the accent
// colour (Color.mPrimary) when the dGPU is awake / driving a display, and a neutral
// colour (Color.mOnSurface) when it is asleep. Hidden when no NVIDIA dGPU is present.
NIconButton {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var main: pluginApi?.mainInstance
  readonly property string rt: main ? main.runtime : "unknown"
  readonly property bool ext: main ? main.external : false
  readonly property string md: main ? main.mode : "battery"
  readonly property bool present: main ? main.present : true
  readonly property bool lit: root.ext || root.rt === "active"

  visible: root.present
  icon: "" // hidden: we draw the tinted NVIDIA mark below

  tooltipText: {
    if (root.ext)
      return "dGPU — driving external display";
    var m = (root.md === "hdmi") ? "HDMI-Ready" : "Battery";
    return "dGPU — " + (root.rt === "active" ? "active" : "asleep") + "  (" + m + " mode)";
  }
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  Item {
    id: mark
    anchors.centerIn: parent
    width: Math.round(root.buttonSize * 0.9)
    height: width

    Image {
      id: eyeImg
      anchors.fill: parent
      source: Qt.resolvedUrl("Assets/nvidia-eye.svg")
      fillMode: Image.PreserveAspectFit
      sourceSize.width: mark.width
      sourceSize.height: mark.height
      smooth: true
      mipmap: true
      visible: false // shown via the tinting effect below
    }

    MultiEffect {
      anchors.fill: eyeImg
      source: eyeImg
      colorization: 1.0
      colorizationColor: root.lit ? Color.mPrimary : Color.mOnSurface
      Behavior on colorizationColor {
        ColorAnimation {
          duration: Style.animationFast
        }
      }
    }
  }

  onClicked: {
    if (pluginApi)
      pluginApi.openPanel(root.screen, this);
  }
}
