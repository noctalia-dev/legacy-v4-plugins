// BarWidget.qml - status-bar entry for niri-screensaver
//
// Click       → smart toggle: launch if stopped, stop if already running.
// Right-click → context menu: Trigger / Stop / Quit / Reload / Toggle / Settings.
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

  // Smart left-click: probe running state, then stop if running else launch.
  // The probe (`niri-screensaver-launch is-running`) exits 0 when running, so
  // we branch in onExited. Falling back to launch on a probe error keeps the
  // click useful even if the status command is somehow unavailable.
  Process {
    id: statusProbe
    onExited: function (code) {
      if (code === 0) root._runKill()
      else root._runLaunch()
    }
  }
  function _smartToggle() {
    var argv = root.mainInstance ? root.mainInstance._statusArgv()
                                 : ["niri-screensaver-launch", "is-running"]
    statusProbe.command = argv
    statusProbe.running = true
  }

  // Quit: stop the screensaver AND disable it, so Noctalia's idle won't
  // relaunch it until it's re-enabled (Toggle enabled, or Reload).
  function _runQuit() {
    root._runKill()
    if (root.pluginApi) {
      root.pluginApi.pluginSettings.enabled = false
      root.pluginApi.saveSettings()
    }
  }

  // Reload: full fresh-start. Stop the screensaver, restart the Noctalia shell
  // (so the systray reappears), and leave the screensaver enabled. The work runs
  // detached via setsid because `qs kill` tears down this widget's own host
  // process — the detached child outlives it and brings the shell back up.
  Process {
    id: reloadProc
    onExited: function (code) {
      if (code !== 0) Logger.w("NiriScreensaver", "reload (bar) exited with code", code)
    }
  }
  function _runReload() {
    if (root.pluginApi) {
      root.pluginApi.pluginSettings.enabled = true
      root.pluginApi.saveSettings()
    }
    reloadProc.command = ["sh", "-c",
      "setsid sh -c 'niri-screensaver-launch kill; "
      + "rm -f \"$HOME/.config/niri-screensaver/disabled\"; "
      + "sleep 0.3; qs kill; sleep 0.6; exec qs -c noctalia-shell' "
      + "</dev/null >/dev/null 2>&1 &"]
    reloadProc.running = true
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      { "label": pluginApi?.tr("barwidget.trigger"),  "action": "trigger",  "icon": "player-play" },
      { "label": pluginApi?.tr("barwidget.stop"),     "action": "stop",     "icon": "player-stop" },
      { "label": pluginApi?.tr("barwidget.quit"),     "action": "quit",     "icon": "logout" },
      { "label": pluginApi?.tr("barwidget.reload"),   "action": "reload",   "icon": "refresh" },
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
      } else if (action === "quit") {
        root._runQuit()
      } else if (action === "reload") {
        root._runReload()
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
        root._smartToggle()
      }
    }
  }
}
