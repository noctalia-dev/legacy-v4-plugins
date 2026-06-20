import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property string badgeIcon: ""
  property string badgeText: ""
  property color badgeColor: Color.mOnSurfaceVariant
  property color badgeBgColor: Qt.alpha(Color.mSurfaceVariant, 0.24)
  property bool compact: false

  color: badgeBgColor
  radius: compact ? Style.radiusXS : Style.radiusS
  implicitWidth: compact ? badgeIconItem.implicitWidth + Style.marginXS * 2 : badgeRow.implicitWidth + Style.marginS * 2
  implicitHeight: compact ? badgeIconItem.implicitHeight + Style.marginXS * 2 : badgeRow.implicitHeight + Style.marginXS * 2

  RowLayout {
    id: badgeRow
    anchors.centerIn: parent
    spacing: Style.marginXS
    visible: !root.compact

    NIcon {
      icon: root.badgeIcon
      pointSize: Style.fontSizeM
      color: root.badgeColor
    }

    NText {
      text: root.badgeText
      color: root.badgeColor
      font.pointSize: Style.fontSizeXS
      font.weight: Font.Medium
      elide: Text.ElideRight
      visible: root.badgeText.length > 0
    }
  }

  NIcon {
    id: badgeIconItem
    anchors.centerIn: parent
    visible: root.compact
    icon: root.badgeIcon
    pointSize: Style.fontSizeM
    color: root.badgeColor
  }
}
