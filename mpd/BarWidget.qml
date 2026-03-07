import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Widgets
import "state.js" as State

Item {
  id: root

  // Plugin API (injected by PluginService)
  property var pluginApi: null

  // Required properties for bar widgets
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  // Settings helpers
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Per-screen bar properties (for multi-monitor and vertical bar support)
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  // MPD State
  property string mpdStatus: "stopped"  // "playing", "paused", "stopped"
  property string songName: ""

  // Configured button actions (with fallback to defaults)
  readonly property string leftAction:   cfg.leftButton   ?? defaults.leftButton   ?? "next"
  readonly property string rightAction:  cfg.rightButton  ?? defaults.rightButton  ?? "toggle"
  readonly property string middleAction: cfg.middleButton ?? defaults.middleButton ?? "shuffle"

  // Icon based on status
  readonly property string statusIcon: {
    switch (mpdStatus) {
      case "playing": return "player-play"
      case "paused":  return "player-pause"
      default:        return "player-stop"
    }
  }

  // Content dimensions (visual capsule size)
  readonly property real contentWidth: content.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: capsuleHeight

  // Widget dimensions (extends to full bar height for better click area)
  implicitWidth: contentWidth
  implicitHeight: contentHeight

  // Maps action ID to command array; returns null for "none" or special-cased actions
  function commandForAction(action) {
    switch (action) {
      case "next":   return ["mpc", "next"]
      case "prev":   return ["mpc", "prev"]
      case "toggle": return ["mpc", "toggle"]
      case "stop":   return ["mpc", "stop"]
      default:       return null
    }
  }

  // Toggle ashuffle: start if stopped, stop (+ optionally stop playback) if running.
  // Runs entirely inline — no external script required.
  function toggleShuffle() {
    const stopPlayback = cfg.shuffleStopsPlayback ?? defaults.shuffleStopsPlayback ?? true
    const onStop = stopPlayback
      ? "systemctl --user stop ashuffle.service && mpc stop"
      : "systemctl --user stop ashuffle.service"
    Quickshell.execDetached(["sh", "-c",
      `if systemctl --user is-active --quiet ashuffle.service; then ${onStop}; else systemctl --user start ashuffle.service; fi`
    ])
  }

  // MPD status polling
  Process {
    id: mpcProc
    command: ["mpc", "status"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const lines = this.text.trim().split("\n")

        if (lines.length <= 1 || !lines[1].startsWith("[")) {
          // Only volume/options line = stopped
          root.mpdStatus = "stopped"
          root.songName = ""
        } else {
          // First line is song info
          root.songName = lines[0]

          // Second line contains [playing] or [paused]
          if (lines[1].includes("[playing]")) {
            root.mpdStatus = "playing"
          } else if (lines[1].includes("[paused]")) {
            root.mpdStatus = "paused"
          }
        }
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: mpcProc.running = true
  }

  // Open panel after a short hover delay.
  // Guard: only open if the panel isn't already open — openPanel() toggles (closes) when
  // called on an already-open panel, and a Wayland leave→enter bounce causes it to fire twice.
  Timer {
    id: hoverOpenTimer
    interval: 700
    repeat: false
    onTriggered: {
      if (mouseArea.containsMouse && root.mpdStatus !== "stopped"
          && pluginApi && !pluginApi.panelOpenScreen)
        pluginApi.openPanel(root.screen, root)
    }
  }

  // Close panel after cursor leaves the widget, but only if it didn't move onto the panel.
  // State.cursorOnPanel is set by Panel.qml via the shared state.js singleton.
  Timer {
    id: widgetExitTimer
    interval: 400
    repeat: false
    onTriggered: {
      if (pluginApi && !State.cursorOnPanel)
        pluginApi.closePanel(root.screen)
    }
  }

  // Visual capsule - centered within the full click area
  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    RowLayout {
      id: content
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        icon: root.statusIcon
        color: Color.mOnSurface
        applyUiScale: true
      }

      NText {
        visible: root.songName !== ""
        text: root.songName
        color: Color.mOnSurface
        pointSize: barFontSize
        font.weight: Font.Medium
        elide: Text.ElideRight
        Layout.maximumWidth: 200  // prevent overly long names
      }
    }
  }

  // MouseArea at root level for extended click area
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onEntered: {
      State.cursorOnWidget = true
      widgetExitTimer.stop()
      hoverOpenTimer.start()
    }

    onExited: {
      State.cursorOnWidget = false
      hoverOpenTimer.stop()
      if (pluginApi?.panelOpenScreen) widgetExitTimer.start()
    }

    onClicked: (mouse) => {
      var action = null
      if (mouse.button === Qt.LeftButton)       action = root.leftAction
      else if (mouse.button === Qt.RightButton) action = root.rightAction
      else if (mouse.button === Qt.MiddleButton) action = root.middleAction

      if (action === "shuffle") {
        toggleShuffle()
      } else {
        const cmd = commandForAction(action)
        if (cmd) Quickshell.execDetached(cmd)
      }

      // Refresh status immediately after action
      mpcProc.running = true
    }
  }
}
