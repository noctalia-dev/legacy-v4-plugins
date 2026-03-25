import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings
import qs.Services.Hardware
import qs.Services.UI
import qs.Widgets
import "./Services"

Item {
  id: root

  property var pluginApi: null

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""

  // Explicit screenName property ensures reactive binding when screen changes
  readonly property string screenName: screen ? screen.name : ""

  implicitWidth: pill.width
  implicitHeight: pill.height
  visible: !hideIfNoDeviceConnected ? true : KDEConnect.anyDevicesConnected;
  opacity: (!hideIfNoDeviceConnected ? true : KDEConnect.anyDevicesConnected) ? 1.0 : 0.0;

  property bool hideIfNoDeviceConnected: !(root.pluginApi?.mainInstance?.hideIfNoDeviceConnected ?? false)


  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    customIconColor: Color.resolveColorKeyOptional(root.iconColorKey)
    customTextColor: Color.resolveColorKeyOptional(root.textColorKey)
    icon: KDEConnectUtils.getConnectionStateIcon(KDEConnect.mainDevice, KDEConnect.daemonAvailable)
    autoHide: false // Important to be false so we can hover as long as we want
    text: !KDEConnect.daemonAvailable || KDEConnect.mainDevice === null || KDEConnect.mainDevice.battery === -1 ? "" : (KDEConnect.mainDevice.battery + "%")
    tooltipText: pluginApi?.tr("bar.tooltip")
    onClicked: {
      if (pluginApi) {
        pluginApi.openPanel(root.screen, this);
      }
    }
  }
}
