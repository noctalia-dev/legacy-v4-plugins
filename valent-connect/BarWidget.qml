import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings
import qs.Services.UI
import QtQuick.Layouts
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  readonly property string screenName: screen ? screen.name : ""

  readonly property var main: pluginApi?.mainInstance ?? null

  implicitWidth:  pill.width
  implicitHeight: pill.height

  visible: true

  RowLayout {
    id: layouts
    anchors.fill: parent
    spacing: Style.marginS

    BarPill {
      id: pill
      Layout.alignment: Qt.AlignVCenter
      screen: root.screen
      oppositeDirection: BarService.getPillDirection(root)
      icon: root.main?.getConnectionStateIcon(root.main?.mainDevice ?? null, root.main?.daemonAvailable ?? false) ?? "exclamation-circle"
      autoHide: false
      text: {
        var m = root.main
        if (!m || !m.daemonAvailable || !m.mainDevice) return ""
        if (m.mainDevice.batteryCharge === -1) return ""
        return m.mainDevice.batteryCharge + "%"
      }
      tooltipText: pluginApi?.tr("bar.tooltip")
      onClicked: {
        if (pluginApi) {
          pluginApi.openPanel(root.screen, this)
        }
      }
    }
  }
}
