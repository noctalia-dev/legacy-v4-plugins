import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets


Item {
  id: root

  // Plugin API (injected by PluginService)
  property var pluginApi: null

  // Required properties for bar widgets
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  readonly property real contentWidth: row.implicitWidth + Style.marginS * 2
  readonly property real contentHeight: Style.barHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL

    RowLayout {
      id: row
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        icon: "lamp"
        color: Color.mPrimary
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: {
      if (pluginApi) {
        pluginApi.openPanel(root.screen, root)
      }
    }
  }
}
