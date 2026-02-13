import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.System

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
  readonly property bool isActive: mainInstance && (mainInstance.timerRunning || mainInstance.timerElapsedSeconds > 0 || mainInstance.timerRemainingSeconds > 0)

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string iconColorKey: cfg.iconColor ?? defaults.iconColor ?? "none"
  readonly property color iconColor: Color.resolveColorKey(iconColorKey)

  // Bar positioning properties
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property real contentWidth: {
    if (isVertical) return Style.capsuleHeight
    if (isActive) return contentRow.implicitWidth + Style.marginM * 2
    return Style.capsuleHeight
  }
  readonly property real contentHeight: root.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  function formatTime(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (hours > 0) {
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: {
      if (mainInstance && (mainInstance.timerRunning || mainInstance.timerSoundPlaying)) {
        return Style.capsuleColor
      }
      return mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    }
    radius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    RowLayout {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.marginS
      layoutDirection: pillDirection ? Qt.LeftToRight : Qt.RightToLeft

      NIcon {
        icon: {
          if (mainInstance && mainInstance.timerSoundPlaying) return "bell-ringing"
          if (mainInstance && mainInstance.timerStopwatchMode) return "stopwatch"
          return "hourglass"
        }
        applyUiScale: false
        color: {
          if (mainInstance && (mainInstance.timerRunning || mainInstance.timerSoundPlaying)) {
            return Color.mPrimary
          }
          return mouseArea.containsMouse ? Color.mOnHover : root.iconColor
        }
      }

      NText {
        visible: !isVertical && mainInstance && (mainInstance.timerRunning || mainInstance.timerElapsedSeconds > 0 || mainInstance.timerRemainingSeconds > 0)
        family: Settings.data.ui.fontFixed
        pointSize: Style.barFontSize
        text: {
          if (!mainInstance) return ""
          if (mainInstance.timerStopwatchMode) {
            return formatTime(mainInstance.timerElapsedSeconds)
          }
          return formatTime(mainInstance.timerRemainingSeconds)
        }
        color: {
          if (mainInstance && (mainInstance.timerRunning || mainInstance.timerSoundPlaying)) {
            return Color.mPrimary
          }
          return mouseArea.containsMouse ? Color.mOnHover : root.iconColor
        }
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: {
      var items = [];

      if (mainInstance) {
        // Pause / Resume & Reset
        if (mainInstance.timerRunning || mainInstance.timerElapsedSeconds > 0 || mainInstance.timerRemainingSeconds > 0) {
          items.push({
            "label": mainInstance.timerRunning ? pluginApi.tr("panel.pause") : pluginApi.tr("panel.resume"),
            "action": "toggle",
            "icon": mainInstance.timerRunning ? "media-pause" : "media-play"
          });

          items.push({
            "label": pluginApi.tr("panel.reset"),
            "action": "reset",
            "icon": "refresh"
          });
        }
      }

      // Settings
      items.push({
        "label": pluginApi.tr("panel.settings"),
        "action": "widget-settings",
        "icon": "settings"
      });

      return items;
    }

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "widget-settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest);
      } else if (mainInstance) {
        if (action === "toggle") {
          if (mainInstance.timerRunning) {
            mainInstance.timerPause();
          } else {
            mainInstance.timerStart();
          }
        } else if (action === "reset") {
          mainInstance.timerReset();
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi) {
          pluginApi.openPanel(root.screen, root)
        }
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen);
      }
    }
  }
}
