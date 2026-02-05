import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var pluginApi: null

  property bool steamRunning: false
  property bool overlayActive: false
  property var steamWindows: []

  // Auto-detect screen resolution
  property int screenWidth: 3440  // Default, will be updated
  property int screenHeight: 1440  // Default, will be updated

  // Shortcut to settings and defaults
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // User-configurable settings with fallback chain
  readonly property int gapSize: cfg.gapSize ?? defaults.gapSize ?? 10
  readonly property real topMarginPercent: cfg.topMarginPercent ?? defaults.topMarginPercent ?? 2.5
  readonly property real windowHeightPercent: cfg.windowHeightPercent ?? defaults.windowHeightPercent ?? 95
  readonly property real friendsWidthPercent: cfg.friendsWidthPercent ?? defaults.friendsWidthPercent ?? 10
  readonly property real mainWidthPercent: cfg.mainWidthPercent ?? defaults.mainWidthPercent ?? 60
  readonly property real chatWidthPercent: cfg.chatWidthPercent ?? defaults.chatWidthPercent ?? 25

  // Calculate pixel values from percentages (updates automatically when screen size changes)
  readonly property int topMargin: Math.round(screenHeight * (topMarginPercent / 100))
  readonly property int windowHeight: Math.round(screenHeight * (windowHeightPercent / 100))
  readonly property int friendsWidth: Math.round((screenWidth * (friendsWidthPercent / 100)) - gapSize)
  readonly property int mainWidth: Math.round((screenWidth * (mainWidthPercent / 100)) - (gapSize * 2))
  readonly property int chatWidth: Math.round((screenWidth * (chatWidthPercent / 100)) - gapSize)

  // Calculate center offset for horizontal centering
  readonly property int totalWidth: friendsWidth + gapSize + mainWidth + gapSize + chatWidth
  readonly property int centerOffset: Math.round((screenWidth - totalWidth) / 2)

  onPluginApiChanged: {
    if (pluginApi) {
      checkSteam.running = true;
    }
  }

  Component.onCompleted: {
    if (pluginApi) {
      checkSteam.running = true;
    }
    detectResolution.running = true;
    monitorTimer.start();
  }

  // Check if Steam is running
  Process {
    id: checkSteam
    command: ["pidof", "steam"]
    running: false

    onExited: (exitCode, exitStatus) => {
      steamRunning = (exitCode === 0);
    }
  }

  // Launch Steam
  Process {
    id: launchSteam
    command: ["steam", "steam://open/main"]
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

  // Detect Steam windows (only Friends List, Main, and small Chat windows)
  Process {
    id: detectWindows
    command: ["bash", "-c", "hyprctl clients -j | jq -c '.[] | select(.class == \"steam\" and .fullscreen == 0) | {address: .address, title: .title, x: .at[0], y: .at[1], w: .size[0], h: .size[1]}'"]
    running: false

    property var lines: []

    stdout: SplitParser {
      onRead: data => {
        detectWindows.lines.push(data.trim());
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0 && lines.length > 0) {
        var allWindows = lines.map(line => JSON.parse(line));

        // Filter only main Steam UI windows (Friends List, Main Window, Chat)
        steamWindows = allWindows.filter(win => {
          var title = win.title || "";
          var width = win.w || 0;
          var height = win.h || 0;

          // Accept Friends List
          if (title.includes("Friends List")) return true;

          // Accept main Steam window
          if (title === "Steam") return true;

          // Accept chat windows (< 30% screen width and < 100% screen height)
          var maxChatWidth = screenWidth * 0.30;
          var maxChatHeight = screenHeight * 1.0;
          if (width < maxChatWidth && height < maxChatHeight) return true;

          // Reject everything else (games, large auxiliary windows, etc.)
          return false;
        });

        lines = [];
      }
    }
  }

  // Move and position windows
  Process {
    id: moveWindows
    command: ["bash", "-c", ""]
    running: false

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        showWorkspace.running = true;
      }
    }
  }

  // Show special workspace (only when opening overlay)
  Process {
    id: showWorkspace
    command: ["hyprctl", "dispatch", "togglespecialworkspace", "steam"]
    running: false

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        overlayActive = true;
        Qt.callLater(() => {
          focusAdditionalWindows.running = true;
        });
      }
    }
  }

  // Hide special workspace (only when closing overlay)
  Process {
    id: hideWorkspace
    command: ["hyprctl", "dispatch", "togglespecialworkspace", "steam"]
    running: false

    onExited: (exitCode, exitStatus) => {
      overlayActive = false;
    }
  }

  // Focus additional (non-main) windows to bring them to front
  Process {
    id: focusAdditionalWindows
    command: ["bash", "-c", "hyprctl clients -j | jq -r '.[] | select(.class == \"steam\" and .workspace.name == \"special:steam\" and .fullscreen == 0) | .address'"]
    running: false

    property var addresses: []

    stdout: SplitParser {
      onRead: data => {
        var addr = data.trim();
        if (addr && addr.startsWith("0x")) {
          focusAdditionalWindows.addresses.push(addr);
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0 && addresses.length > 0) {
        var focusCommands = [];

        // Focus only non-main windows
        for (var i = 0; i < addresses.length; i++) {
          var addr = addresses[i];
          var isMain = false;

          // Check if this is one of the 3 main windows
          for (var j = 0; j < steamWindows.length; j++) {
            if (steamWindows[j].address === addr) {
              isMain = true;
              break;
            }
          }

          // Bring additional windows to top (without focusing/moving cursor)
          if (!isMain) {
            focusCommands.push("hyprctl dispatch alterzorder top,address:" + addr);
          }
        }

        if (focusCommands.length > 0) {
          executeFocus.command = ["bash", "-c", focusCommands.join(" && ")];
          executeFocus.running = true;
        }
      }
      addresses = [];
    }
  }

  // Execute focus commands
  Process {
    id: executeFocus
    command: ["bash", "-c", ""]
    running: false
  }

  // Timer to monitor Steam
  Timer {
    id: monitorTimer
    interval: 3000
    repeat: true
    running: false

    onTriggered: {
      checkSteam.running = true;
    }
  }

  // Timer to monitor for NEW Steam windows while overlay is active
  Timer {
    id: newWindowMonitor
    interval: 150
    repeat: true
    running: overlayActive

    onTriggered: {
      if (!detectNewWindows.running) {
        detectNewWindows.windowData = [];
        detectNewWindows.running = true;
      }
    }
  }

  // Process to detect new Steam windows that appeared after overlay was opened
  Process {
    id: detectNewWindows
    command: ["bash", "-c", "hyprctl clients -j | jq -c '.[] | select(.class == \"steam\" and .fullscreen == 0 and (.title | startswith(\"notificationtoasts\") | not)) | {address: .address, workspace: .workspace.name}'"]
    running: false

    property var windowData: []

    stdout: SplitParser {
      onRead: data => {
        var line = data.trim();
        if (line) {
          try {
            detectNewWindows.windowData.push(JSON.parse(line));
          } catch (e) {}
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0 && windowData.length > 0) {
        var windowsToMove = [];

        for (var i = 0; i < windowData.length; i++) {
          var win = windowData[i];
          var addr = win.address;
          var workspace = win.workspace || "";

          // Move ANY Steam window that is not in special:steam
          if (workspace !== "special:steam") {
            windowsToMove.push(addr);
          }
        }

        // Move windows to overlay and bring to top
        if (windowsToMove.length > 0) {
          var commands = [];
          for (var j = 0; j < windowsToMove.length; j++) {
            var addr = windowsToMove[j];
            commands.push("hyprctl dispatch movetoworkspacesilent special:steam,address:" + addr);
            commands.push("hyprctl dispatch setfloating address:" + addr);
            commands.push("hyprctl dispatch alterzorder top,address:" + addr);
          }
          moveNewWindows.command = ["bash", "-c", commands.join(" && ")];
          if (!moveNewWindows.running) {
            moveNewWindows.running = true;
          }
        }
      }
    }
  }

  // Execute move commands for new windows
  Process {
    id: moveNewWindows
    command: ["bash", "-c", ""]
    running: false
  }

  // Detect ALL Steam windows (including additional ones)
  Process {
    id: detectAllWindows
    command: ["bash", "-c", "hyprctl clients -j | jq -c '.[] | select(.class == \"steam\" and .fullscreen == 0) | {address: .address, title: .title}'"]
    running: false

    property var allSteamWindows: []

    stdout: SplitParser {
      onRead: data => {
        var line = data.trim();
        if (line) {
          try {
            detectAllWindows.allSteamWindows.push(JSON.parse(line));
          } catch (e) {}
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0 && allSteamWindows.length > 0) {
        var commands = [];

        for (var i = 0; i < allSteamWindows.length; i++) {
          var win = allSteamWindows[i];
          var addr = win.address;
          var title = win.title || "";

          // Skip notification toasts
          if (title.includes("notificationtoasts")) {
            continue;
          }

          // Move all Steam windows to overlay and set as floating
          commands.push("hyprctl dispatch movetoworkspacesilent special:steam,address:" + addr);
          commands.push("hyprctl dispatch setfloating address:" + addr);
        }

        if (commands.length > 0) {
          moveAllWindows.command = ["bash", "-c", commands.join(" && ")];
          moveAllWindows.running = true;
        }
      }
      allSteamWindows = [];
    }
  }

  // Execute move all windows commands
  Process {
    id: moveAllWindows
    command: ["bash", "-c", ""]
    running: false

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        Qt.callLater(() => {
          if (steamWindows.length > 0) {
            moveWindowsToOverlay();
          }
        });
      }
    }
  }


  function toggleOverlay() {
    if (!steamRunning) {
      launchSteam.running = true;
      return;
    }

    if (overlayActive) {
      hideWorkspace.running = true;
    } else {

      // Show overlay - detect main windows first, then all windows
      detectWindows.running = true;

      // Wait for main windows detection, then detect all windows
      Qt.callLater(() => {
        if (steamWindows.length > 0) {
          // Now detect and move ALL Steam windows
          detectAllWindows.running = true;
        }
      });
    }
  }

  function moveWindowsToOverlay() {
    var commands = [];

    for (var i = 0; i < steamWindows.length; i++) {
      var win = steamWindows[i];
      var addr = win.address;
      var title = win.title;

      // Position based on title with percentage layout + center offset
      var x = 0, y = topMargin, w = 800, h = windowHeight;

      if (title === "Steam") {
        // Main window: center + friends + gap
        x = centerOffset + friendsWidth + gapSize;
        w = mainWidth;
      } else if (title === "Friends List") {
        // Friends: center offset (left side)
        x = centerOffset;
        w = friendsWidth;
      } else {
        // Chat: center + friends + gap + main + gap
        x = centerOffset + friendsWidth + gapSize + mainWidth + gapSize;
        w = chatWidth;
      }

      // Position and size the 3 main windows (they are already floating and in overlay)
      commands.push("hyprctl dispatch resizewindowpixel exact " + w + " " + h + ",address:" + addr);
      commands.push("hyprctl dispatch movewindowpixel exact " + x + " " + y + ",address:" + addr);
    }

    if (commands.length > 0) {
      moveWindows.command = ["bash", "-c", commands.join(" && ")];
      moveWindows.running = true;
    }
  }

  // IPC Handler
  IpcHandler {
    target: "plugin:hyprland-steam-overlay"

    function toggle() {
      root.toggleOverlay();
    }
  }
}
