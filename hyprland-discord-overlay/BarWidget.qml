import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  implicitWidth: barIsVertical ? Style.capsuleHeight : contentRow.implicitWidth + Style.marginM * 2
  implicitHeight: Style.capsuleHeight

  property bool discordRunning: false

  readonly property string barPosition: Settings.data.bar.position || "top"
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

  color: Style.capsuleColor
  radius: Style.radiusL

  // Process to check Discord status
  Process {
    id: checkDiscordProcess
    command: ["pidof", "discord"]
    running: false

    onExited: (exitCode, exitStatus) => {
      discordRunning = (exitCode === 0);
    }
  }

  // IPC Process to toggle overlay
  Process {
    id: ipcProcess
    command: ["qs", "-p", Quickshell.shellDir, "ipc", "call", "plugin:hyprland-discord-overlay", "toggle"]
    running: false
  }

  // Update discord status periodically
  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: {
      checkDiscordProcess.running = true;
    }
  }

  Component.onCompleted: {
    checkDiscordProcess.running = true;
  }

  RowLayout {
    id: contentRow
    anchors.centerIn: parent
    spacing: Style.marginS

    NIcon {
      icon: "brand-discord"
      pointSize: Style.fontSizeL
      color: discordRunning ? Color.mPrimary : (mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface)
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onEntered: {
      root.color = Color.mHover;
    }

    onExited: {
      root.color = Style.capsuleColor;
    }

    onClicked: {
      if (pluginApi) {
        Logger.i("DiscordOverlay.BarWidget: Calling Discord overlay toggle");
        ipcProcess.running = true;
      }
    }
  }
}
