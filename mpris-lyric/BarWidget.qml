import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property bool pillDirection: BarService.getPillDirection(root)

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property bool isActive: mainInstance && mainInstance.isPlaying
  readonly property bool hasContent: mainInstance && (mainInstance.currentLyric !== "" || mainInstance.trackTitle !== "")

  readonly property int widgetWidth: pluginApi?.pluginSettings?.width ||
      pluginApi?.manifest?.metadata?.defaultSettings?.width || 300

  readonly property string barPosition: Settings.data.bar.position || "top"
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

  // Calculate display text
  readonly property string displayText: {
    if (!mainInstance) return ""
    if (mainInstance.currentLyric) {
      var lyric = mainInstance.currentLyric
      if (mainInstance.currentTranslation) {
        lyric += " | " + mainInstance.currentTranslation
      }
      return lyric
    }
    // Fallback to track info if no lyrics
    if (mainInstance.trackTitle) {
      if (mainInstance.trackArtist) {
        return mainInstance.trackArtist + " - " + mainInstance.trackTitle
      }
      return mainInstance.trackTitle
    }
    return ""
  }

  readonly property real contentWidth: {
    if (barIsVertical) return Style.capsuleHeight
    if (isActive && hasContent) return widgetWidth
    return Style.capsuleHeight
  }
  readonly property real contentHeight: Style.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: Style.capsuleColor
    radius: Style.radiusL
    clip: true

    RowLayout {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.marginS
      layoutDirection: pillDirection ? Qt.LeftToRight : Qt.RightToLeft

      NIcon {
        id: musicIcon
        icon: isActive ? "music" : "music-off"
        applyUiScale: false
        color: isActive ? Color.mPrimary : Color.mOnSurface
      }

      // Lyric container with scroll
      Item {
        id: lyricContainer
        visible: !barIsVertical && isActive && hasContent
        Layout.preferredWidth: widgetWidth - Style.marginM * 2 - musicIcon.width - Style.marginS
        Layout.preferredHeight: lyricText.implicitHeight
        clip: true

        readonly property bool needsScroll: lyricText.implicitWidth > lyricContainer.width && lyricContainer.width > 0

        NText {
          id: lyricText
          anchors.verticalCenter: parent.verticalCenter
          family: Settings.data.ui.font || ""
          pointSize: Style.barFontSize
          text: displayText
          color: isActive ? Color.mPrimary : Color.mOnSurface

          x: 0

          SequentialAnimation {
            id: scrollAnim
            running: lyricContainer.needsScroll && isActive
            loops: Animation.Infinite

            // Wait 1 second before scrolling
            PauseAnimation { duration: 1000 }

            // Scroll to the left
            NumberAnimation {
              target: lyricText
              property: "x"
              from: 0
              to: lyricContainer.width - lyricText.implicitWidth
              duration: Math.max(2000, (lyricText.implicitWidth - lyricContainer.width) * 20)
              easing.type: Easing.Linear
            }

            // Pause at the end
            PauseAnimation { duration: 1000 }

            // Reset to start
            NumberAnimation {
              target: lyricText
              property: "x"
              to: 0
              duration: 300
              easing.type: Easing.OutQuad
            }
          }

          onTextChanged: {
            x = 0
            if (lyricContainer.needsScroll) {
              scrollAnim.restart()
            } else {
              scrollAnim.stop()
            }
          }
        }
      }
    }
  }

  // Context menu
  NPopupContextMenu {
    id: contextMenu

    model: {
      var items = [];

      if (mainInstance) {
        // Play/Pause
        if (mainInstance.canPlay || mainInstance.canPause) {
          items.push({
            "label": mainInstance.isPlaying ? pluginApi.tr("menu.pause") : pluginApi.tr("menu.play"),
            "action": "play-pause",
            "icon": mainInstance.isPlaying ? "media-pause" : "media-play"
          });
        }

        // Previous
        if (mainInstance.canGoPrevious) {
          items.push({
            "label": pluginApi.tr("menu.previous"),
            "action": "previous",
            "icon": "media-prev"
          });
        }

        // Next
        if (mainInstance.canGoNext) {
          items.push({
            "label": pluginApi.tr("menu.next"),
            "action": "next",
            "icon": "media-next"
          });
        }
      }

      return items;
    }

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (mainInstance) {
        if (action === "play-pause") {
          mainInstance.playPause();
        } else if (action === "previous") {
          mainInstance.previous();
        } else if (action === "next") {
          mainInstance.next();
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.RightButton

    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen);
      }
    }
  }
}
