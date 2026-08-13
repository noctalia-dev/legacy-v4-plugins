import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  readonly property var mainInstance: pluginApi?.mainInstance

  property real contentPreferredWidth: 420 * Style.uiScaleRatio
  property real contentPreferredHeight: contentColumn.implicitHeight + Style.marginM * 2

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: contentColumn
      anchors {
        top: parent.top
        left: parent.left
        right: parent.right
        margins: Style.marginM
      }
      spacing: Style.marginM

      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: boxContent.implicitHeight + Style.marginM * 2

        ColumnLayout {
          id: boxContent
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Style.marginM
          }
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            CloudflareIcon {
              pointSize: Style.fontSizeL
              color: (mainInstance?.warpConnected ?? false) ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            NText {
              text: pluginApi?.tr("panel.title")
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: (mainInstance?.warpConnected ?? false)
                ? pluginApi?.tr("panel.status.connected")
                : pluginApi?.tr("panel.status.disconnected")
              pointSize: Style.fontSizeS
              color: (mainInstance?.warpConnected ?? false) ? Color.mPrimary : Color.mOnSurfaceVariant
            }
          }

          NText {
            visible: mainInstance?.warpInstalled ?? false
            text: pluginApi?.tr("panel.mode") + ":"
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightSemiBold
            color: Color.mOnSurfaceVariant
          }

          NComboBox {
            Layout.fillWidth: true
            minimumWidth: 340
            popupHeight: 260
            visible: mainInstance?.warpInstalled ?? false
            enabled: !(mainInstance?.isSwitchingMode ?? false)
            model: [
              { key: "warp", name: pluginApi?.tr("modes.warp") },
              { key: "doh", name: pluginApi?.tr("modes.doh") },
              { key: "warp+doh", name: pluginApi?.tr("modes.warp_doh") },
              { key: "dot", name: pluginApi?.tr("modes.dot") },
              { key: "warp+dot", name: pluginApi?.tr("modes.warp_dot") },
              { key: "proxy", name: pluginApi?.tr("modes.proxy") },
              { key: "tunnel_only", name: pluginApi?.tr("modes.tunnel_only") }
            ]
            currentKey: mainInstance?.warpMode ?? ""
            placeholder: pluginApi?.tr("panel.mode")

            onSelected: key => {
              mainInstance?.setMode(key)
            }
          }

          Rectangle {
            Layout.fillWidth: true
            visible: !(mainInstance?.warpInstalled ?? true)
            Layout.preferredHeight: notInstalledLayout.implicitHeight + Style.marginM * 2
            color: Qt.alpha(Color.mError, 0.1)
            radius: Style.radiusM
            border.width: Style.borderS
            border.color: Qt.alpha(Color.mError, 0.3)

            RowLayout {
              id: notInstalledLayout
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              NIcon {
                icon: "alert-circle"
                pointSize: Style.fontSizeM
                color: Color.mError
              }

              NText {
                text: pluginApi?.tr("panel.not-installed")
                pointSize: Style.fontSizeS
                color: Color.mError
                Layout.fillWidth: true
                wrapMode: Text.Wrap
              }
            }
          }
        }
      }

      NButton {
        Layout.fillWidth: true
        text: (mainInstance?.warpConnected ?? false)
          ? pluginApi?.tr("context.disconnect")
          : pluginApi?.tr("context.connect")
        icon: (mainInstance?.warpConnected ?? false) ? "plug-x" : "plug"
        backgroundColor: (mainInstance?.warpConnected ?? false) ? Color.mError : Color.mPrimary
        textColor: (mainInstance?.warpConnected ?? false) ? Color.mOnError : Color.mOnPrimary
        enabled: mainInstance?.warpInstalled ?? false

        onClicked: {
          mainInstance?.toggleWarp()
          pluginApi?.closePanel(pluginApi?.panelOpenScreen)
        }
      }
    }
  }
}
