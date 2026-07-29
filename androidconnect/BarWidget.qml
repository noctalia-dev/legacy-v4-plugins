import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings
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
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  // Explicit screenName property ensures reactive binding when screen changes
  readonly property string screenName: screen ? screen.name : ""

  implicitWidth: pill.width
  implicitHeight: pill.height
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property bool hideIfNoDeviceConnected: cfg.hideIfNoDeviceConnected ?? defaults.hideIfNoDeviceConnected ?? false
  property string iconColorKey: cfg.iconColor ?? defaults.iconColor ?? "none"
  readonly property string wirelessAdbConnectHost: cfg.wirelessAdbConnectHost ?? defaults.wirelessAdbConnectHost ?? ""
  readonly property string activeWirelessAdbSerial: {
    const host = String(wirelessAdbConnectHost || "").trim();
    if (host === "")
      return "";

    return KDEConnect.adbConnectedSerialForHost(host);
  }
  readonly property string transportIcon: {
    if (!KDEConnect.daemonAvailable || KDEConnect.mainDevice === null || !KDEConnect.mainDevice.reachable)
      return "device-mobile-off";

    if (KDEConnect.adbHasUsbTransport)
      return "device-mobile-bolt";

    if (activeWirelessAdbSerial !== "")
      return "device-mobile";

    return "device-mobile";
  }

  visible: !hideIfNoDeviceConnected ? true : KDEConnect.anyDevicesConnected;
  opacity: (!hideIfNoDeviceConnected ? true : KDEConnect.anyDevicesConnected) ? 1.0 : 0.0;

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(root.screen);

      if (action === "settings" && pluginApi?.manifest) {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }
  }

  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    customIconColor: Color.resolveColorKeyOptional(root.iconColorKey)
    icon: root.transportIcon
    autoHide: false // Important to be false so we can hover as long as we want
    text: !KDEConnect.daemonAvailable || KDEConnect.mainDevice === null || KDEConnect.mainDevice.battery === -1 ? "" : (KDEConnect.mainDevice.battery + "%")
    tooltipText: pluginApi?.tr("bar.tooltip")
    onClicked: {
      if (pluginApi) {
        pluginApi.openPanel(root.screen);
      }
    }
    onRightClicked: {
      PanelService.showContextMenu(contextMenu, root, root.screen);
    }
  }
}
