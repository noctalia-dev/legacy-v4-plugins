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
  readonly property bool isActive: mainInstance && (mainInstance.pomodoroRunning || mainInstance.pomodoroRemainingSeconds > 0 || mainInstance.pomodoroTotalSeconds > 0)

  readonly property int modeWork: 0
  readonly property int modeShortBreak: 1
  readonly property int modeLongBreak: 2

  readonly property string barPosition: Settings.data.bar.position || "top"
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

  readonly property real contentWidth: {
    if (barIsVertical) return Style.capsuleHeight
    if (isActive) return contentRow.implicitWidth + Style.marginM * 2
    return Style.capsuleHeight
  }
  readonly property real contentHeight: Style.capsuleHeight

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

  function getModeIcon() {
    if (!mainInstance) return "clock"
    if (mainInstance.pomodoroSoundPlaying) return "bell-ringing"
    if (mainInstance.pomodoroMode === modeWork) return "brain"
    if (mainInstance.pomodoroMode === modeShortBreak) return "coffee"
    if (mainInstance.pomodoroMode === modeLongBreak) return "bed"
    return "clock"
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: {
      if (mouseArea.containsMouse &&
          (!mainInstance || (!mainInstance.pomodoroRunning && !mainInstance.pomodoroSoundPlaying)))
        return Color.mHover
      return Style.capsuleColor
    }
    radius: Style.radiusL

    RowLayout {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.marginS
      layoutDirection: Qt.LeftToRight

      NIcon {
        icon: getModeIcon()
        applyUiScale: false
        color: {
          if (mainInstance && (mainInstance.pomodoroRunning || mainInstance.pomodoroSoundPlaying)) {
            return Color.mPrimary
          }
          return mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        }
      }

      NText {
        visible: !barIsVertical && mainInstance && (mainInstance.pomodoroRunning || mainInstance.pomodoroRemainingSeconds > 0 || mainInstance.pomodoroTotalSeconds > 0)
        family: Settings.data.ui.fontFixed
        pointSize: Style.barFontSize
        text: {
          if (!mainInstance) return ""
          return formatTime(mainInstance.pomodoroRemainingSeconds)
        }
        color: {
          if (mainInstance && (mainInstance.pomodoroRunning || mainInstance.pomodoroSoundPlaying)) {
            return Color.mPrimary
          }
          return mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        }
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: {
      var items = [];

      if (mainInstance) {
        if (mainInstance.pomodoroRunning || mainInstance.pomodoroRemainingSeconds > 0 || mainInstance.pomodoroTotalSeconds > 0) {
          items.push({
            "label": mainInstance.pomodoroRunning ? pluginApi.tr("panel.pause") : pluginApi.tr("panel.resume"),
            "action": "toggle",
            "icon": mainInstance.pomodoroRunning ? "media-pause" : "media-play"
          });

          items.push({
            "label": pluginApi.tr("panel.skip"),
            "action": "skip",
            "icon": "player-skip-forward"
          });

          items.push({
            "label": pluginApi.tr("panel.reset"),
            "action": "reset",
            "icon": "refresh"
          });

          items.push({
            "label": pluginApi.tr("panel.reset-all"),
            "action": "reset-all",
            "icon": "rotate"
          });
        }
      }

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
          if (mainInstance.pomodoroRunning) {
            mainInstance.pomodoroPause();
          } else {
            mainInstance.pomodoroStart();
          }
        } else if (action === "reset") {
          mainInstance.pomodoroResetSession();
        } else if (action === "reset-all") {
          mainInstance.pomodoroResetAll();
        } else if (action === "skip") {
          mainInstance.pomodoroSkip();
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi) {
          pluginApi.openPanel(root.screen, root)
        }
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen);
      } else if (mouse.button === Qt.MiddleButton) {
        if (!mainInstance)
          return
        mainInstance.pomodoroRunning
          ? mainInstance.pomodoroPause()
          : mainInstance.pomodoroStart()
      }
    }
  }
}
