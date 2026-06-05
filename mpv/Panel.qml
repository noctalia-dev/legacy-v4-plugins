import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets
import "state.js" as State

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 340 * Style.uiScaleRatio
  property real contentPreferredHeight: 280 * Style.uiScaleRatio
  readonly property bool allowAttach: true

  anchors.fill: parent

  property string songTitle: ""
  property string videoId: ""
  property string songArtist: ""

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    property bool wasEntered: false

    onEntered: {
      wasEntered = true
      State.cursorOnPanel = true
      panelCloseTimer.stop()
    }

    onExited: {
      if (!wasEntered) return
        State.cursorOnPanel = false
        panelCloseTimer.start()
    }
  }

  Timer {
    id: panelCloseTimer
    interval: 500
    repeat: false
    onTriggered: {
      if (pluginApi && !State.cursorOnWidget)
        pluginApi.closePanel(pluginApi.panelOpenScreen)
    }
  }

  // fetches title via socat
  Process {
    id: mpvDetailProc
    command: ["sh", "-c", "echo '{\"command\":[\"get_property\",\"media-title\"]}' | socat - UNIX-CONNECT:/tmp/mpvsocket 2>/dev/null"]

    stdout: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim()
        if (!text) return
          try {
            const json = JSON.parse(text)
            if (json.error === "success" && json.data) {
              const raw = json.data
              if (raw.includes(" - ")) {
                root.songTitle  = raw.split(" - ")[0].trim()
                root.songArtist = raw.split(" - ")[1].replace(/\s*\(.*$/, "").trim()
              } else {
                root.songTitle  = raw
                root.songArtist = ""
              }
            }
          } catch (e) {}
      }
    }
  }

  // fetches video ID for thumbnail
  Process {
    id: mpvUrlProc
    command: ["sh", "-c", "echo '{\"command\":[\"get_property\",\"path\"]}' | socat - UNIX-CONNECT:/tmp/mpvsocket 2>/dev/null"]

    stdout: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim()
        if (!text) return
          try {
            const json = JSON.parse(text)
            if (json.error === "success" && json.data) {
              const match = json.data.match(/[?&]v=([^&]+)/)
              if (match) root.videoId = match[1]
            }
          } catch (e) {}
      }
    }
  }

  Component.onCompleted: {
    mpvDetailProc.running = true
    mpvUrlProc.running = true
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    Rectangle {
      anchors {
        fill: parent
        margins: Style.marginS
      }
      color: Style.capsuleColor
      radius: Style.radiusL
      border.color: Style.capsuleBorderColor
      border.width: Style.capsuleBorderWidth
      clip: true

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // thumbnail
        Rectangle {
          Layout.fillWidth: true
          height: 180 * Style.uiScaleRatio
          color: Color.mSurfaceVariant

          Image {
            id: thumbImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            source: root.videoId !== ""
            ? "https://img.youtube.com/vi/" + root.videoId + "/maxresdefault.jpg"
            : ""
          }

          NIcon {
            anchors.centerIn: parent
            visible: thumbImage.status !== Image.Ready
            icon: "music-note"
            color: Color.mOnSurface
            applyUiScale: true
          }
        }

        // track info below
        ColumnLayout {
          Layout.fillWidth: true
          Layout.topMargin: Style.marginM
          Layout.bottomMargin: Style.marginM
          Layout.leftMargin: Style.marginM
          Layout.rightMargin: Style.marginM
          spacing: 4

          NText {
            text: root.songTitle !== "" ? root.songTitle : "Loading..."
            color: Color.mOnSurface
            pointSize: Style.fontSizeM
            font.weight: Font.Bold
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            visible: root.songArtist !== ""
            text: root.songArtist
            color: Color.mOnSurface
            pointSize: Style.fontSizeS
            font.weight: Font.Medium
            opacity: 0.7
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }
    }
  }
}
