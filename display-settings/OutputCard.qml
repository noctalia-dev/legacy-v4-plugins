import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  default property alias content: contentArea.children
  property string headerIcon: "device-desktop"
  property color headerIconColor: Color.mPrimary
  property string outputName: ""
  property string disabledText: ""
  property bool isDisabled: false
  property real contentSpacing: Style.marginXS

  Layout.fillWidth: true
  implicitHeight: outerCol.implicitHeight + Style.marginM * 2
  color: Color.mSurfaceVariant
  radius: Style.radiusM

  data: [
    ColumnLayout {
      id: outerCol
      anchors {
        left: parent.left; right: parent.right
        verticalCenter: parent.verticalCenter
        margins: Style.marginM
      }
      spacing: Style.marginS

      RowLayout {
        spacing: Style.marginS
        NIcon { icon: root.headerIcon; color: root.headerIconColor; pointSize: Style.fontSizeS }
        NText {
          text: root.outputName
          pointSize: Style.fontSizeM; font.weight: Font.Bold; color: Color.mOnSurface
        }
        NText {
          visible: root.isDisabled
          text: root.disabledText
          pointSize: Style.fontSizeXS; color: Color.mError
        }
      }

      ColumnLayout {
        id: contentArea
        Layout.fillWidth: true
        spacing: root.contentSpacing
      }
    }
  ]
}
