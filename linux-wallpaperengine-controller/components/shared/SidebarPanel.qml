import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  default property alias content: contentColumn.data
  property alias footerContent: footerRow.data

  property bool panelVisible: true
  property real panelWidth: 340 * Style.uiScaleRatio

  Layout.preferredWidth: panelWidth
  Layout.maximumWidth: panelWidth
  Layout.fillWidth: false
  Layout.fillHeight: true
  Layout.alignment: Qt.AlignTop
  visible: panelVisible
  spacing: 0

  Rectangle {
    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: Style.radiusL
    color: Qt.alpha(Color.mSurfaceVariant, 0.35)
    border.width: Style.borderS
    border.color: Qt.alpha(Color.mOutline, 0.35)
    clip: true

    NScrollView {
      id: sidebarScrollView
      anchors.fill: parent
      anchors.margins: Style.marginM
      anchors.bottomMargin: Style.marginM + 56 * Style.uiScaleRatio
      contentWidth: availableWidth
      showScrollbarWhenScrollable: true
      gradientColor: "transparent"

      ColumnLayout {
        id: contentColumn
        width: sidebarScrollView.availableWidth
        spacing: Style.marginS
      }
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: footerRow.implicitHeight > 0 ? footerRow.implicitHeight + Style.marginM * 2 : 0
      color: Qt.rgba(0, 0, 0, 0)
      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
        GradientStop { position: 1.0; color: Qt.alpha(Color.mSurface, 0.32) }
      }

      RowLayout {
        id: footerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.marginM
        spacing: Style.marginS
      }
    }
  }
}
