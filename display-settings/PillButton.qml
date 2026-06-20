import QtQuick
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property string label: ""
  property bool active: false
  property real horizontalPadding: Style.marginM

  signal activated()

  property bool hovered: false

  width: text.implicitWidth + horizontalPadding * 2
  height: 28 * Style.uiScaleRatio
  radius: Style.radiusS
  color: active
    ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.18)
    : hovered ? Color.mSurface : "transparent"
  border.color: active ? Color.mPrimary : Color.mOutline
  border.width: Style.borderS
  Behavior on color { ColorAnimation { duration: 100 } }

  NText {
    id: text
    anchors.centerIn: parent
    text: root.label
    pointSize: Style.fontSizeXS
    color: root.active ? Color.mPrimary : Color.mOnSurfaceVariant
    font.weight: root.active ? 600 : 400
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    enabled: root.enabled
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.activated()
  }
}
