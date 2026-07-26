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
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string barPosition: Settings.data.bar.position || "top"
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property bool showCount: cfg.showCountInBar ?? defaults.showCountInBar ?? true
  readonly property string barIcon: cfg.barIcon ?? defaults.barIcon ?? "paperclip"
  readonly property bool hideBarWidget: cfg.hideBarWidget ?? defaults.hideBarWidget ?? false

  function getIntValue(value, defaultValue) {
    return (typeof value === 'number') ? Math.floor(value) : defaultValue;
  }

  readonly property int noteCount: getIntValue(cfg.count, 0)

  readonly property real contentWidth: barIsVertical ? Style.capsuleHeight : contentRow.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: Style.capsuleHeight

  opacity: hideBarWidget ? 0.0 : 1.0
  implicitWidth: hideBarWidget ? 0 : contentWidth
  implicitHeight: hideBarWidget ? 0 : contentHeight

  Behavior on opacity {
    NumberAnimation { duration: Style.animationNormal }
  }

  Behavior on implicitWidth {
    NumberAnimation { duration: Style.animationNormal }
  }

  Behavior on implicitHeight {
    NumberAnimation { duration: Style.animationNormal }
  }

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
        icon: root.barIcon
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
