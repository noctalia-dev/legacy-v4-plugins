import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property var pluginApi: null
  property var approval: ({})
  signal approve(bool all)
  signal deny()

  readonly property bool pending: approval.pending || false
  readonly property string toolName: approval.tool_name || approval.tool || ""
  readonly property string message: approval.message || approval.reason || ""

  Layout.fillWidth: true
  visible: pending
  radius: Style.radiusS
  color: Qt.rgba(0.96, 0.62, 0.04, 0.14)
  border.color: "#f59e0b"
  border.width: Style.borderS
  implicitHeight: approvalLayout.implicitHeight + Style.marginL * 2

  ColumnLayout {
    id: approvalLayout
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      margins: Style.marginL
    }
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIcon {
        icon: "shield-question"
        pointSize: Style.fontSizeXL
        color: "#f59e0b"
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NText {
          text: toolName !== "" ? toolName : pluginApi?.tr("panel.approvalRequired")
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightSemiBold
          color: Color.mOnSurface
          Layout.fillWidth: true
          elide: Text.ElideRight
        }

        NText {
          visible: message !== ""
          text: message
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          wrapMode: Text.Wrap
          Layout.fillWidth: true
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      Item { Layout.fillWidth: true }

      NButton {
        text: pluginApi?.tr("panel.deny")
        icon: "x"
        onClicked: root.deny()
      }

      NButton {
        text: pluginApi?.tr("panel.approve")
        icon: "check"
        onClicked: root.approve(false)
      }

      NButton {
        text: pluginApi?.tr("panel.approveSession")
        icon: "checks"
        onClicked: root.approve(true)
      }
    }
  }
}
