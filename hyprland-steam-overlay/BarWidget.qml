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

  property bool steamRunning: false

  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  icon: "brand-steam"
  tooltipText: steamRunning ? "Steam Running - Toggle Overlay" : "Steam Stopped"
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
        "icon": "brand-steam"
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

  // Process to check Steam status
  Process {
    id: checkSteamProcess
    command: ["pidof", "steam"]
    running: false

    onExited: (exitCode, exitStatus) => {
      steamRunning = (exitCode === 0);
    }
  }

  // Update steam status periodically
  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: {
      checkSteamProcess.running = true;
    }
  }

  Component.onCompleted: {
    checkSteamProcess.running = true;
  }

  onClicked: {
    if (pluginApi?.mainInstance) {
      Logger.i("SteamOverlay.BarWidget", "Calling Steam overlay toggle");
      pluginApi.mainInstance.toggleOverlay();
    }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
