import QtQuick
import "components" as Components

Item {
  id: root

  property var pluginApi
  property var screen

  readonly property var service: root.pluginApi?.mainInstance
  readonly property bool showShortcut: root.service?.showInControlCenter ?? false

  visible: root.showShortcut
  implicitWidth: root.showShortcut ? button.implicitWidth : 0
  implicitHeight: root.showShortcut ? button.implicitHeight : 0

  Components.ObsButton {
    id: button

    anchors.fill: parent
    visible: root.showShortcut
    pluginApi: root.pluginApi
    screen: root.screen
  }
}
