import QtQuick
import qs.Commons
import qs.Widgets

Item {
  id: root

  property string iconPath: ""
  property string fallbackIcon: "sparkles"
  property color statusColor: Color.mOnSurface
  property real iconSize: Style.fontSizeXL
  property real dotSize: 8 * Style.uiScaleRatio

  Image {
    id: avatarImage
    anchors.fill: parent
    source: root.iconPath
    sourceSize.width: width
    sourceSize.height: height
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    visible: status === Image.Ready
  }

  NIcon {
    anchors.centerIn: parent
    visible: avatarImage.status !== Image.Ready
    icon: root.fallbackIcon
    pointSize: root.iconSize
    applyUiScale: false
    color: root.statusColor
  }

  Rectangle {
    width: root.dotSize
    height: width
    radius: width / 2
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    color: root.statusColor
    border.width: Style.borderS
    border.color: Color.mSurface
  }
}