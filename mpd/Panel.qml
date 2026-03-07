import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets
import "state.js" as State

Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null

  // SmartPanel required properties
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 340 * Style.uiScaleRatio
  property real contentPreferredHeight: 130 * Style.uiScaleRatio
  readonly property bool allowAttach: true

  anchors.fill: parent

  // Song detail state
  property string songArtist: ""
  property string songTitle: ""
  property string songAlbum: ""
  property string songFile: ""
  property string coverArtPath: ""

  Component.onCompleted: detailProc.running = true

  // Track whether cursor is on this panel via the shared state.js singleton so that
  // MPD.qml's widgetExitTimer knows not to close the panel when cursor moves here.
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

  // Close panel after cursor leaves the panel, but only if it didn't move back onto the widget.
  // State.cursorOnWidget is set by MPD.qml via the shared state.js singleton.
  Timer {
    id: panelCloseTimer
    interval: 500
    repeat: false
    onTriggered: {
      if (pluginApi && !State.cursorOnWidget)
        pluginApi.closePanel(pluginApi.panelOpenScreen)
    }
  }

  // Fetch artist / title / album / file path
  Process {
    id: detailProc
    command: ["mpc", "-f", "%artist%\t%title%\t%album%\t%file%", "current"]

    stdout: StdioCollector {
      onStreamFinished: {
        const output = this.text.trim()
        if (!output) return
        const parts = output.split("\t")
        root.songArtist = parts[0] || ""
        root.songTitle  = parts[1] || ""
        root.songAlbum  = parts[2] || ""
        root.songFile   = parts[3] || ""
        if (root.songFile) coverProc.running = true
      }
    }
  }

  // Fetch embedded cover art via mpc readpicture, writing binary to a temp file.
  // $1 is the song URI (relative to MPD music_directory), passed as a safe shell argument.
  Process {
    id: coverProc
    command: ["sh", "-c", 'mpc readpicture "$1" > /tmp/noctalia-mpd-cover', "sh", root.songFile]

    stdout: StdioCollector {
      onStreamFinished: {
        // stdout is empty (binary was redirected to file); this fires when done.
        // Image.cache is false, so a source change always reloads from disk.
        root.coverArtPath = "file:///tmp/noctalia-mpd-cover"
      }
    }
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

      RowLayout {
        anchors {
          fill: parent
          margins: Style.marginM
        }
        spacing: Style.marginM

        // Cover art box — always present; NIcon is fallback when no embedded art
        Rectangle {
          width: 80 * Style.uiScaleRatio
          height: 80 * Style.uiScaleRatio
          Layout.alignment: Qt.AlignVCenter
          radius: Style.radiusL
          color: Color.mSurfaceVariant
          clip: true

          Image {
            id: coverImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false  // always reload from temp file, never use a cached old song's art
            source: root.coverArtPath
          }

          NIcon {
            anchors.centerIn: parent
            visible: coverImage.status !== Image.Ready
            icon: "music-note"
            color: Color.mOnSurface
            applyUiScale: true
          }
        }

        // Song details
        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 2

          NText {
            visible: root.songArtist !== ""
            text: root.songArtist
            color: Color.mOnSurface
            pointSize: Style.fontSizeS
            font.weight: Font.Medium
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          NText {
            text: root.songTitle
            color: Color.mOnSurface
            pointSize: Style.fontSizeM
            font.weight: Font.Bold
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            visible: root.songAlbum !== ""
            text: root.songAlbum
            color: Color.mOnSurface
            pointSize: Style.fontSizeS
            opacity: 0.7
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }
    }
  }
}
