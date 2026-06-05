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

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  property string mpvStatus: "stopped"
  property string rawTitle: ""

  readonly property string leftAction:   cfg.leftButton   ?? defaults.leftButton   ?? "toggle"
  readonly property string rightAction:  cfg.rightButton  ?? defaults.rightButton  ?? "next"
  readonly property string middleAction: cfg.middleButton ?? defaults.middleButton ?? "prev"

  readonly property string shortTitle: {
    if (!rawTitle) return ""
      if (rawTitle.startsWith("https://") || rawTitle.startsWith("http://")) return ""
        return rawTitle
  }

  // icons: playing = pause (can pause), paused = play (can play)
  readonly property string statusIcon: {
    switch (mpvStatus) {
      case "playing": return "player-pause"
      case "paused":  return "player-play"
      default:        return "music-note"
    }
  }

  readonly property real contentWidth: content.implicitWidth + Style.marginM * 0.5
  readonly property real contentHeight: capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  function commandForAction(action) {
    switch (action) {
      case "next":   return ["sh", "-c", "echo '{\"command\":[\"playlist-next\"]}' | socat - UNIX-CONNECT:/tmp/mpvsocket"]
      case "prev":   return ["sh", "-c", "echo '{\"command\":[\"playlist-prev\"]}' | socat - UNIX-CONNECT:/tmp/mpvsocket"]
      case "toggle": return ["sh", "-c", "echo '{\"command\":[\"cycle\",\"pause\"]}' | socat - UNIX-CONNECT:/tmp/mpvsocket"]
      case "stop":   return ["sh", "-c", "echo '{\"command\":[\"stop\"]}' | socat - UNIX-CONNECT:/tmp/mpvsocket"]
      default:       return null
    }
  }

  Process {
    id: mpvTitleProc
    command: ["sh", "-c", "echo '{\"command\":[\"get_property\",\"media-title\"]}' | socat - UNIX-CONNECT:/tmp/mpvsocket 2>/dev/null"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim()
        if (!text) {
          root.mpvStatus = "stopped"
          root.rawTitle = ""
          return
        }

        const lines = text.split("\n").filter(l => l.trim() !== "")
        let title = ""
        for (const line of lines) {
          try {
            const json = JSON.parse(line)
            if (json.error === "success" && json.data) {
              const data = json.data
              if (!data.startsWith("https://") &&
                !data.startsWith("http://") &&
                !data.includes("watch?v=")) {
                title = data
                }
            }
          } catch (e) {}
        }

        if (title) {
          root.rawTitle = title
        } else {
          root.rawTitle = ""
        }
      }
    }
  }

  Process {
    id: mpvPauseProc
    command: ["sh", "-c", "echo '{\"command\":[\"get_property\",\"pause\"]}' | socat - UNIX-CONNECT:/tmp/mpvsocket 2>/dev/null"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim()
        if (!text) {
          root.mpvStatus = "stopped"
          return
        }
        try {
          const json = JSON.parse(text)
          if (json.error === "success") {
            if (root.rawTitle) {
              root.mpvStatus = json.data ? "paused" : "playing"
            } else {
              root.mpvStatus = "stopped"
            }
          }
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      mpvTitleProc.running = true
      mpvPauseProc.running = true
    }
  }

  Timer {
    id: hoverOpenTimer
    interval: 700
    repeat: false
    onTriggered: {
      if (mouseArea.containsMouse && root.mpvStatus !== "stopped"
        && pluginApi && !pluginApi.panelOpenScreen)
        pluginApi.openPanel(root.screen, root)
    }
  }

  Timer {
    id: widgetExitTimer
    interval: 400
    repeat: false
    onTriggered: {
      if (pluginApi && !State.cursorOnPanel)
        pluginApi.closePanel(root.screen)
    }
  }

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
        visible: root.shortTitle !== ""
        text: root.shortTitle
        color: Color.mOnSurface
        pointSize: barFontSize
        font.weight: Font.Medium
        elide: Text.ElideRight
        Layout.maximumWidth: 200
      }
    }
  }

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
      if (mouse.button === Qt.LeftButton)        action = root.leftAction
        else if (mouse.button === Qt.RightButton)  action = root.rightAction
          else if (mouse.button === Qt.MiddleButton) action = root.middleAction

            const cmd = commandForAction(action)
            if (cmd) Quickshell.execDetached(cmd)

              mpvTitleProc.running = true
              mpvPauseProc.running = true
    }
  }
}
