import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var pluginApi: null

  property bool discordRunning: false
  property bool overlayActive: false
  property var discordWindow: null

  // Auto-detect screen resolution
  property int screenWidth: 3440
  property int screenHeight: 1440

  // Shortcut to settings and defaults
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // User-configurable settings with fallback chain
  readonly property bool autoLaunchDiscord: cfg.autoLaunchDiscord ?? defaults.autoLaunchDiscord ?? true
  readonly property real windowWidthPercent: cfg.windowWidthPercent ?? defaults.windowWidthPercent ?? 80
  readonly property real windowHeightPercent: cfg.windowHeightPercent ?? defaults.windowHeightPercent ?? 90
  readonly property real topMarginPercent: cfg.topMarginPercent ?? defaults.topMarginPercent ?? 5

  // Calculate pixel values from percentages
  readonly property int windowWidth: Math.round(screenWidth * (windowWidthPercent / 100))
  readonly property int windowHeight: Math.round(screenHeight * (windowHeightPercent / 100))
  readonly property int topMargin: Math.round(screenHeight * (topMarginPercent / 100))
  readonly property int centerX: Math.round((screenWidth - windowWidth) / 2)

  // Logger helper functions
  function logInfo(msg) {
    if (typeof Logger !== 'undefined') Logger.i(msg);
    else console.log(msg);
  }

  function logWarn(msg) {
    if (typeof Logger !== 'undefined') Logger.w(msg);
    else console.warn(msg);
  }

  function logError(msg) {
    if (typeof Logger !== 'undefined') Logger.e(msg);
    else console.error(msg);
  }

  onPluginApiChanged: {
    if (pluginApi) {
      logInfo("DiscordOverlay: " + (pluginApi?.tr("main.plugin_loaded") || "Plugin loaded"));
      checkDiscord.running = true;
    }
  }

  Component.onCompleted: {
    if (pluginApi) {
      checkDiscord.running = true;
    }
    detectResolution.running = true;
    monitorTimer.start();
  }

  // Check if Discord is running by checking if window exists
  Process {
    id: checkDiscord
    command: ["bash", "-c", "hyprctl clients -j | jq -e '.[] | select(.class == \"discord\")' > /dev/null"]
    running: false

    onExited: (exitCode, exitStatus) => {
      discordRunning = (exitCode === 0);
    }
  }

  // Launch Discord
  Process {
    id: launchDiscord
    command: ["discord"]
    running: false
  }

  // Detect screen resolution
  Process {
    id: detectResolution
    command: ["bash", "-c", "hyprctl monitors -j | jq -r '.[0] | \"\\(.width) \\(.height)\"'"]
    running: false

    stdout: SplitParser {
      onRead: data => {
        var parts = data.trim().split(" ");
        if (parts.length === 2) {
          screenWidth = parseInt(parts[0]);
          screenHeight = parseInt(parts[1]);
        }
      }
    }
  }

  // Detect Discord window
  Process {
    id: detectWindow
    command: ["bash", "-c", "hyprctl clients -j | jq -c '.[] | select(.class == \"discord\" and .fullscreen == 0) | {address: .address, title: .title}' | head -1"]
    running: false

    property var foundWindow: null

    stdout: SplitParser {
      onRead: data => {
        var line = data.trim();
        if (line) {
          try {
            detectWindow.foundWindow = JSON.parse(line);
          } catch (e) {}
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0 && foundWindow) {
        discordWindow = foundWindow;
        foundWindow = null;
        moveDiscordToOverlay();
      } else {
        discordWindow = null;
        logWarn("DiscordOverlay: " + (pluginApi?.tr("main.no_window_found") || "No Discord window found"));
      }
    }
  }

  // Move Discord window to overlay workspace
  Process {
    id: moveToOverlay
    command: ["bash", "-c", ""]
    running: false

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        positionWindow.running = true;
      }
    }
  }

  // Position and resize Discord window
  Process {
    id: positionWindow
    command: ["bash", "-c", ""]
    running: false

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        showWorkspace.running = true;
      }
    }
  }

  // Show special workspace
  Process {
    id: showWorkspace
    command: ["hyprctl", "dispatch", "togglespecialworkspace", "discord"]
    running: false

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        overlayActive = true;
      }
    }
  }

  // Hide special workspace
  Process {
    id: hideWorkspace
    command: ["hyprctl", "dispatch", "togglespecialworkspace", "discord"]
    running: false

    onExited: (exitCode, exitStatus) => {
      overlayActive = false;
    }
  }

  // Timer to monitor Discord
  Timer {
    id: monitorTimer
    interval: 3000
    repeat: true
    running: false

    onTriggered: {
      checkDiscord.running = true;
    }
  }

  // Timer to monitor for new Discord windows while overlay is active
  Timer {
    id: newWindowMonitor
    interval: 150
    repeat: true
    running: overlayActive

    onTriggered: {
      if (!detectNewWindow.running) {
        detectNewWindow.running = true;
      }
    }
  }

  // Detect new Discord window that appeared after overlay was opened
  Process {
    id: detectNewWindow
    command: ["bash", "-c", "hyprctl clients -j | jq -c '.[] | select(.class == \"discord\" and .fullscreen == 0) | {address: .address, workspace: .workspace.name}' | head -1"]
    running: false

    property var foundWindow: null

    stdout: SplitParser {
      onRead: data => {
        var line = data.trim();
        if (line) {
          try {
            detectNewWindow.foundWindow = JSON.parse(line);
          } catch (e) {}
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0 && foundWindow) {
        var addr = foundWindow.address;
        var workspace = foundWindow.workspace || "";

        // Move Discord window if not in special:discord
        if (workspace !== "special:discord") {
          var commands = [
            "hyprctl dispatch movetoworkspacesilent special:discord,address:" + addr,
            "hyprctl dispatch setfloating address:" + addr,
            "hyprctl dispatch alterzorder top,address:" + addr
          ];
          moveNewWindow.command = ["bash", "-c", commands.join(" && ")];
          if (!moveNewWindow.running) {
            moveNewWindow.running = true;
          }
        }
      }
      foundWindow = null;
    }
  }

  // Execute move commands for new window
  Process {
    id: moveNewWindow
    command: ["bash", "-c", ""]
    running: false
  }

  function toggleOverlay() {
    if (!discordRunning) {
      if (autoLaunchDiscord) {
        launchDiscord.running = true;
      }
      return;
    }

    if (overlayActive) {
      hideWorkspace.running = true;
    } else {
      detectWindow.running = true;
    }
  }

  function moveDiscordToOverlay() {
    if (!discordWindow) {
      logError("DiscordOverlay: No discord window to move");
      return;
    }

    var addr = discordWindow.address;

    // Move to overlay workspace and set as floating
    var moveCommands = [
      "hyprctl dispatch movetoworkspacesilent special:discord,address:" + addr,
      "hyprctl dispatch setfloating address:" + addr
    ];

    moveToOverlay.command = ["bash", "-c", moveCommands.join(" && ")];
    moveToOverlay.running = true;

    // Position window (center it)
    Qt.callLater(() => {
      var positionCommands = [
        "hyprctl dispatch resizewindowpixel exact " + windowWidth + " " + windowHeight + ",address:" + addr,
        "hyprctl dispatch movewindowpixel exact " + centerX + " " + topMargin + ",address:" + addr
      ];

      positionWindow.command = ["bash", "-c", positionCommands.join(" && ")];
    });
  }

  // IPC Handler
  IpcHandler {
    target: "plugin:hyprland-discord-overlay"

    function toggle() {
      root.toggleOverlay();
    }
  }
}
