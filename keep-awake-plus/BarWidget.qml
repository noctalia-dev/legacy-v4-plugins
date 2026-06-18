import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property bool active: mainInstance ? mainInstance.active : false
  readonly property string scope: mainInstance ? mainInstance.scope : ""
  readonly property string remainingText: mainInstance ? mainInstance.formatRemaining() : ""
  readonly property bool showText: mainInstance ? mainInstance.showRemainingText : true
  readonly property bool activateOnLeftClick: mainInstance ? mainInstance.activateOnLeftClick : false

  implicitWidth: pill.implicitWidth
  implicitHeight: pill.implicitHeight

  // Hide on the bar when inhibit is off — the toggle lives in ControlCenter;
  // the bar entry surfaces scope/remaining-time while armed.
  visible: root.active

  function buildTooltip() {
    if (!root.active) return pluginApi?.tr("tooltip.off");
    const tgKey = (mainInstance && mainInstance.thermalGuardActive)
      ? "tooltip.thermal-guard-on"
      : "tooltip.thermal-guard-off";
    return pluginApi?.tr("tooltip.active", {
      scope: root.scope,
      remaining: root.remainingText,
      tg: pluginApi?.tr(tgKey)
    });
  }

  BarPill {
    id: pill
    screen: root.screen
    icon: root.active ? "coffee" : "coffee-off"
    text: (root.active && root.showText) ? root.remainingText : ""
    tooltipText: root.buildTooltip()
    customIconColor: root.active
      ? (root.scope === "full" ? Color.mSecondary : Color.mPrimary)
      : Color.mOnSurface
    oppositeDirection: BarService.getPillDirection(root)
    onEntered: { if (mainInstance) mainInstance.pollGuard(); }
    onClicked: {
      if (root.activateOnLeftClick) {
        if (mainInstance) mainInstance.toggleLast();
      } else if (pluginApi) {
        pluginApi.openPanel(root.screen, root);
      }
    }
    onRightClicked: { if (mainInstance) mainInstance.off(); }
    onMiddleClicked: { if (mainInstance) mainInstance.toggleLast(); }
  }
}
