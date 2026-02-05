import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  readonly property string barPosition: Settings.data.bar.position || "top"
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

  // Settings
  readonly property bool showCount: pluginApi?.pluginSettings?.showCountInBar ?? true

  function getIntValue(value, defaultValue) {
    return (typeof value === 'number') ? Math.floor(value) : defaultValue;
  }

  readonly property int noteCount: getIntValue(pluginApi?.pluginSettings?.count, 0)

  readonly property real contentWidth: barIsVertical ? Style.capsuleHeight : contentRow.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: Style.capsuleHeight

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
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        icon: "paperclip"
        applyUiScale: false
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
      }

      NText {
        visible: !barIsVertical && root.showCount
        text: root.noteCount.toString()
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        font.pointSize: Style.barFontSize
        font.weight: Font.Medium
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
        pluginApi.openPanel(root.screen);
      }
    }
  }
}
