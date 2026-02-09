import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Panel Component
Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null

  // SmartPanel
  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth: 440 * Style.uiScaleRatio
  property real contentPreferredHeight: 580 * Style.uiScaleRatio

  readonly property bool allowAttach: true
  // readonly property bool panelAnchorHorizontalCenter: true
  // readonly property bool panelAnchorVerticalCenter: true
  // readonly property bool panelAnchorTop: false
  // readonly property bool panelAnchorBottom: false
  // readonly property bool panelAnchorLeft: false
  // readonly property bool panelAnchorRight: false

  anchors.fill: parent

  Component.onCompleted: {
    if (pluginApi) {
      Logger.i("HelloWorld", "Panel initialized");
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginL
      }
      spacing: Style.marginL

      // Content area
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.marginL

          // Large hello message
          NIcon {
            icon: "noctalia"
            Layout.alignment: Qt.AlignHCenter
            pointSize: Style.fontSizeXXL * 3 * Style.uiScaleRatio
          }

          // Core I18n translation example
          NText {
            Layout.alignment: Qt.AlignHCenter
            text: I18n.tr("system.welcome-back")
            pointSize: Style.fontSizeL
            font.weight: Font.Medium
            color: Color.mOnSurface
          }

          // Local pluginApi translation
          NText {
            Layout.alignment: Qt.AlignHCenter
            text: pluginApi?.tr("panel.test")
            pointSize: Style.fontSizeL
            font.weight: Font.Medium
            color: Color.mOnSurface
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            text: pluginApi?.pluginSettings?.message || pluginApi?.manifest?.metadata?.defaultSettings?.message || ""
            font.pointSize: Style.fontSizeXXL * Style.uiScaleRatio
            font.weight: Font.Bold
            color: Color.mPrimary
          }

          // Button to open plugin settings - demonstrates using panelOpenScreen
          NButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Style.marginL
            text: pluginApi?.tr("panel.open-settings") || "Open Plugin Settings"
            icon: "settings"

            onClicked: {
              // Use panelOpenScreen to get the screen this panel is on
              var screen = pluginApi?.panelOpenScreen;
              if (screen && pluginApi?.manifest) {
                Logger.i("HelloWorld", "Opening plugin settings on screen:", screen.name);
                BarService.openPluginSettings(screen, pluginApi.manifest);
              }
            }
          }
        }
      }

      // Info section
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: "Plugin Information"
          font.pointSize: Style.fontSizeM * Style.uiScaleRatio
          font.weight: Font.Medium
          color: Color.mOnSurface
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: infoColumn.implicitHeight + Style.marginM * 2
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: infoColumn
            anchors {
              fill: parent
              margins: Style.marginM
            }
            spacing: Style.marginS

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM

              NText {
                text: "Plugin ID:"
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                Layout.preferredWidth: 100
              }

              NText {
                text: pluginApi?.pluginId || "unknown"
                font.pointSize: Style.fontSizeS
                font.family: Settings.data.ui.fontFixed
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM

              NText {
                text: "Plugin Dir:"
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                Layout.preferredWidth: 100
              }

              NText {
                text: pluginApi?.pluginDir || "unknown"
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurface
                Layout.fillWidth: true
                elide: Text.ElideMiddle
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM

              NText {
                text: "IPC Commands:"
                font.pointSize: Style.fontSizeS
                 font.family: Settings.data.ui.fontFixed
                color: Color.mOnSurfaceVariant
                Layout.preferredWidth: 100
              }

              NText {
                text: "setMessage"
                font.pointSize: Style.fontSizeS
                font.family: Settings.data.ui.fontFixed
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }
          }
        }

        // IPC Examples
        Text {
          Layout.topMargin: Style.marginM
          text: "Try these IPC commands:"
          font.pointSize: Style.fontSizeM * Style.uiScaleRatio
          font.weight: Font.Medium
          color: Color.mOnSurface
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: examplesColumn.implicitHeight + Style.marginM * 2
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: examplesColumn
            anchors {
              fill: parent
              margins: Style.marginM
            }
            spacing: Style.marginS

            NText {
              text: "$ qs -c noctalia-shell ipc call plugin:hello-world setMessage \"Bonjour\""
              font.pointSize: Style.fontSizeS
              font.family: Settings.data.ui.fontFixed
              color: Color.mPrimary
              Layout.fillWidth: true
              wrapMode: Text.WrapAnywhere
            }

            NText {
              text: "$ qs -c noctalia-shell ipc call plugin:hello-world toggle"
              font.pointSize: Style.fontSizeS
              font.family: Settings.data.ui.fontFixed
              color: Color.mPrimary
              Layout.fillWidth: true
              wrapMode: Text.WrapAnywhere
            }
          }
        }
      }
    }
  }
}
