import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  property bool discordRunning: false

  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  icon: "brand-discord"
  tooltipText: discordRunning ? "Discord Running - Toggle Overlay" : "Discord Stopped"
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  customRadius: Style.radiusL

  colorBg: Style.capsuleColor
  colorFg: Color.mOnSurface
  colorBgHover: Color.mHover
  colorFgHover: Color.mOnHover
  colorBorder: "transparent"
  colorBorderHover: "transparent"

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": "Toggle Overlay",
        "action": "toggle-overlay",
        "icon": "brand-discord"
      },
      {
        "label": "Plugin Settings",
        "action": "plugin-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "toggle-overlay") {
        if (pluginApi?.mainInstance) {
          pluginApi.mainInstance.toggleOverlay();
        }
      } else if (action === "plugin-settings") {
        if (pluginApi) {
          BarService.openPluginSettings(screen, pluginApi.manifest);
        }
      }
    }
  }

  // Process to check Discord status
  Process {
    id: checkDiscordProcess
    command: ["pidof", "discord"]
    running: false

    onExited: (exitCode, exitStatus) => {
      discordRunning = (exitCode === 0);
    }
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

  onClicked: {
    if (pluginApi?.mainInstance) {
      Logger.i("DiscordOverlay.BarWidget", "Calling Discord overlay toggle");
      pluginApi.mainInstance.toggleOverlay();
    }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
