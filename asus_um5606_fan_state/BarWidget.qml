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

  property int fanState: -1

  icon: getIcon()
  tooltipText: getTooltipText()
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL

  colorBg: Style.capsuleColor
  colorFg: getColor()
  colorBgHover: Color.mHover
  colorFgHover: Color.mOnHover
  colorBorder: "transparent"
  colorBorderHover: "transparent"

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  Component.onCompleted: {
    if (pluginApi?.mainInstance) {
      root.fanState = pluginApi.mainInstance.fanState;
      pluginApi.mainInstance.refreshFanState();
    }
  }

  onPluginApiChanged: {
    if (pluginApi?.mainInstance) {
      root.fanState = pluginApi.mainInstance.fanState;
    }
  }

  Connections {
    target: pluginApi?.mainInstance ?? null

    function onFanStateChanged() {
      Logger.i("ASUS Fan State", `onFanStateChanged called, target: ${target}, new fanState: ${target?.fanState}`);
      if (target) {
        root.fanState = target.fanState;
      }
    }
  }

  function setFanState(value) {
    Logger.i("ASUS Fan State", `setFanState called with value ${value}, pluginApi.mainInstance: ${pluginApi?.mainInstance}`);
    if (pluginApi?.mainInstance) {
      pluginApi.mainInstance.setFanState(value);
    }
  }

  function getTooltipText() {
    switch (fanState) {
    case 0:
      return pluginApi?.tr("tooltip.standard");
    case 1:
      return pluginApi?.tr("tooltip.quiet");
    case 2:
      return pluginApi?.tr("tooltip.high");
    case 3:
      return pluginApi?.tr("tooltip.full");
    default:
      return pluginApi?.tr("tooltip.unknown");
    }
  }

  function getIcon() {
    switch (fanState) {
    case 0:
      return "car-fan";
    case 1:
      return "car-fan-1";
    case 2:
      return "car-fan-2";
    case 3:
      return "car-fan-3";
    default:
      return "car-fan";
    }
  }

  function getColor() {
    switch (fanState) {
    case 3:
      return Color.mPrimary;
    case 2:
      return Color.mTertiary;
    case 1:
      return Color.mSecondary;
    case 0:
      return Color.mOnSurface;
    default:
      return Color.mOnSurface;
    }
  }

  onClicked: {
    Logger.i("ASUS Fan State Widget", `Clicked, current fanState: ${fanState}`);
    setFanState((fanState + 1) % 4);
  }
}
