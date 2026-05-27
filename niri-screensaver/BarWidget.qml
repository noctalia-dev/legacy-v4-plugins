// BarWidget.qml - status-bar entry for niri-screensaver
//
// Click       → launch the screensaver immediately.
// Right-click → context menu: Trigger / Stop / Open Settings / Toggle enabled.
//
// Renders a custom monitor-with-image SVG (assets/screensaver.svg) recolored
// at runtime via MultiEffect so it follows the active Noctalia theme. The
// widget is hand-rolled rather than reusing NIconButton because that widget
// only renders Tabler font glyphs, and Tabler doesn't ship a "monitor
// displaying a picture" combination. The capsule background and border are
// driven by the same Style.* hooks Battery / Volume use, so the widget
// respects the user's bar.showCapsule and bar.showOutline preferences.
//
// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property bool hovering: false
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)

  // Reach back to Main.qml for centralized launcher/kill argv resolution
  readonly property var mainInstance: pluginApi?.mainInstance || null

  implicitWidth: capsuleHeight
  implicitHeight: capsuleHeight

  Rectangle {
    id: capsule
    anchors.fill: parent
    radius: Math.min(Style.radiusL, width / 2)
    color: root.hovering ? Color.mHover : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation { duration: Style.animationFast; easing.type: Easing.InOutQuad }
    }
  }

  Image {
    id: iconImage
    anchors.centerIn: parent
    width: Math.round(capsule.width * 0.66)
    height: width
    source: Qt.resolvedUrl("assets/screensaver.svg")
    sourceSize: Qt.size(width * 2, height * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
    layer.enabled: true
    layer.effect: MultiEffect {
      colorization: 1.0
      colorizationColor: root.hovering ? Color.mOnHover : Color.mOnSurface
    }
  }

  Process {
    id: launchProc
    onExited: function (code) {
      if (code !== 0) Logger.w("NiriScreensaver", "launch (bar) exited with code", code)
    }
  }
  Process {
    id: killProc
    onExited: function (code) {
      if (code !== 0) Logger.w("NiriScreensaver", "kill (bar) exited with code", code)
    }
  }

  function _runLaunch() {
    var argv = root.mainInstance ? root.mainInstance._launcherArgv()
                                 : ["niri-screensaver-launch", "launch"]
    launchProc.command = argv
    launchProc.running = true
  }
  function _runKill() {
    var argv = root.mainInstance ? root.mainInstance._killArgv()
                                 : ["niri-screensaver-launch", "kill"]
    killProc.command = argv
    killProc.running = true
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      { "label": pluginApi?.tr("barwidget.trigger"),  "action": "trigger",  "icon": "player-play" },
      { "label": pluginApi?.tr("barwidget.stop"),     "action": "stop",     "icon": "stop" },
      { "label": pluginApi?.tr("barwidget.toggle"),   "action": "toggle",   "icon": "power" },
      { "label": pluginApi?.tr("barwidget.settings"), "action": "settings", "icon": "settings" }
    ]
    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)

      if (action === "trigger") {
        root._runLaunch()
      } else if (action === "stop") {
        root._runKill()
      } else if (action === "toggle") {
        if (root.pluginApi) {
          var en = root.pluginApi.pluginSettings.enabled === true
          root.pluginApi.pluginSettings.enabled = !en
          root.pluginApi.saveSettings()
        }
      } else if (action === "settings") {
        if (root.pluginApi) {
          BarService.openPluginSettings(screen, root.pluginApi.manifest)
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onEntered: {
      root.hovering = true
      var tip = pluginApi?.tr("barwidget.tooltip")
      if (tip) {
        TooltipService.show(root, tip, BarService.getTooltipDirection(screen?.name))
      }
    }
    onExited: {
      root.hovering = false
      TooltipService.hide(root)
    }
    onClicked: mouse => {
      TooltipService.hide(root)
      if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen)
      } else {
        root._runLaunch()
      }
    }
  }
}
