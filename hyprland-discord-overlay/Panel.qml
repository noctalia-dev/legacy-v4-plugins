import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  property real contentPreferredWidth: 3440
  property real contentPreferredHeight: 1080
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: false
  readonly property bool panelAnchorHorizontalCenter: true
  readonly property bool panelAnchorTop: true
  anchors.fill: parent

  // Semi-transparent background
  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    // Top bar with status and close button
    Rectangle {
      id: topBar
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 40
      color: Color.mSurfaceVariant
      opacity: 0.95

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        spacing: Style.marginM

        NIcon {
          icon: "discord"
          pointSize: Style.fontSizeL
          color: Color.mPrimary
        }

        NText {
          text: "Discord Overlay"
          font.pointSize: Style.fontSizeM
          font.weight: Font.Bold
          color: Color.mOnSurface
        }

        Item {
          Layout.fillWidth: true
        }

        // Discord status indicator
        RowLayout {
          spacing: Style.marginS

          Rectangle {
            width: 10
            height: 10
            radius: 5
            color: discordRunning ? "#5865F2" : "#F44336"
          }

          NText {
            text: discordRunning ? "Discord Running" : "Discord Stopped"
            font.pointSize: Style.fontSizeS
            color: Color.mOnSurface
          }
        }

        // Close button
        NButton {
          text: "Zamknij (ESC)"
          onClicked: {
            if (pluginApi) {
              pluginApi.closePanel();
            }
          }
        }
      }
    }

    // Window layout guide (semi-transparent overlay showing where window should be)
    Rectangle {
      anchors.top: topBar.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: centerX
      anchors.rightMargin: parent.width - centerX - windowWidth
      color: "#5865F2"
      opacity: 0.1
      border.color: Color.mPrimary
      border.width: 2

      NText {
        anchors.centerIn: parent
        text: "Discord Window\n" + windowWidth + "x" + windowHeight + "px"
        font.pointSize: Style.fontSizeL
        color: Color.mPrimary
        horizontalAlignment: Text.AlignHCenter
        opacity: 0.5
      }
    }
  }

  // Settings
  property bool discordRunning: false
  property int windowWidth: Math.round(3440 * 0.8)
  property int windowHeight: Math.round(1440 * 0.9)
  property int centerX: Math.round((3440 - windowWidth) / 2)

  // Keyboard shortcut to close
  Keys.onEscapePressed: {
    if (pluginApi) {
      pluginApi.closePanel();
    }
  }

  Component.onCompleted: {
    forceActiveFocus();
  }
}
