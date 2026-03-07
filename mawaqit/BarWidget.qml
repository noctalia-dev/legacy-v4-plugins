import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  readonly property string screenName:   screen?.name ?? ""
  readonly property string barPosition:  Settings.getBarPositionForScreen(screenName)
  readonly property bool   isVertical:   barPosition === "left" || barPosition === "right"
  readonly property real   capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real   barFontSize:  Style.getBarFontSizeForScreen(screenName)

  property var cfg:      pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property bool showCountdown: cfg.showCountdown ?? defaults.showCountdown ?? true
  readonly property bool use12h:        Settings.data.location.use12hourFormat

  readonly property var    mainInstance:   pluginApi?.mainInstance
  readonly property var    prayerTimings:  mainInstance?.prayerTimings  ?? null
  readonly property bool   isRamadan:      mainInstance?.isRamadan      ?? false
  readonly property bool   isLoading:      mainInstance?.isLoading      ?? false
  readonly property bool   hasError:       mainInstance?.hasError       ?? false
  readonly property int    secondsToNext: mainInstance?.secondsToNext ?? -1
  readonly property string nextPrayerName: mainInstance?.nextPrayerName ?? ""
  readonly property bool   azanPlaying:    mainInstance?.azanPlaying    ?? false

  // Per-second update only in last hour
  Timer {
    interval: 1000
    running: secondsToNext > 0 && secondsToNext <= 3600
    repeat: true
    onTriggered: mainInstance?.updateCountdown()
  }

  readonly property string nextPrayerLabel: {
    if (!nextPrayerName) return ""
    return nextPrayerName
  }

  readonly property string nextPrayerTimeStr: {
    if (!prayerTimings || !nextPrayerName) return "--:--"
    const raw = prayerTimings[nextPrayerName]
    if (!raw) return "--:--"
    if (!use12h) return raw
    const parts = raw.split(":")
    let h = parseInt(parts[0])
    const m = parts[1]
    const ampm = h >= 12 ? "PM" : "AM"
    h = h % 12 || 12
    return `${h}:${m} ${ampm}`
  }

  readonly property string countdownStr: {
    if (secondsToNext <= 0) return ""
    const h = Math.floor(secondsToNext / 3600)
    const m = Math.floor((secondsToNext % 3600) / 60)
    if (h > 0) return `${h}h ${m}m`
    if (m > 0) return `${m}m`
    return pluginApi?.tr("widget.soon") || "soon"
  }

  readonly property string displayText: {
    if (isLoading && !prayerTimings) return "..."
    if (hasError) return "!"
    if (!prayerTimings || !nextPrayerName) return "—"
    if (showCountdown && secondsToNext > 0) return `${nextPrayerLabel} ${countdownStr}`
    return `${nextPrayerLabel} ${nextPrayerTimeStr}`
  }

  readonly property string tooltipText: {
    if (!prayerTimings) return pluginApi?.tr("widget.tooltip.noData") || "No prayer data"
    return `${nextPrayerLabel}: ${nextPrayerTimeStr}\n${pluginApi?.tr("widget.tooltip.countdown") || "Time remaining"}: ${countdownStr}`
  }

  readonly property real iconSize: Style.toOdd(capsuleHeight * 0.55)

  readonly property real contentWidth: {
    if (isVertical) return capsuleHeight
    let w = iconSize + Style.marginS + labelText.implicitWidth + Style.marginM * 2
    if (azanPlaying) w += Style.marginS + iconSize + Style.marginS + iconSize
    return w
  }
  readonly property real contentHeight: isVertical
    ? capsuleHeight + Style.marginM * 2
    : capsuleHeight

  implicitWidth:  contentWidth
  implicitHeight: contentHeight

  // ── Visual capsule ────────────────────────────────────────────────────────

  Rectangle {
    id: capsule
    x: Style.pixelAlignCenter(parent.width,  width)
    y: Style.pixelAlignCenter(parent.height, height)
    width:  root.contentWidth
    height: root.contentHeight
    radius: Style.radiusL
    color:        mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    border.color: azanPlaying ? Color.mPrimary : Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Behavior on color        { ColorAnimation { duration: Style.animationFast } }
    Behavior on border.color { ColorAnimation { duration: Style.animationFast } }

    // ── Horizontal layout ─────────────────────────────────────────────
    RowLayout {
      id: hLayout
      anchors.fill: parent
      anchors.leftMargin:  Style.marginM
      anchors.rightMargin: Style.marginM
      spacing: Style.marginS
      visible: !isVertical

      NIcon {
        icon: "building-mosque"
        pointSize: root.iconSize
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mPrimary
        Layout.alignment: Qt.AlignVCenter
      }

      // Volume icon — pulsing right after mosque when azan playing
      NIcon {
        icon: "volume"
        pointSize: root.iconSize
        color: Color.mPrimary
        visible: azanPlaying
        Layout.alignment: Qt.AlignVCenter
        SequentialAnimation on opacity {
          running: azanPlaying
          loops: Animation.Infinite
          NumberAnimation { to: 0.3; duration: 600 }
          NumberAnimation { to: 1.0; duration: 600 }
        }
      }

      NText {
        id: labelText
        text: root.displayText
        pointSize: root.barFontSize
        applyUiScale: false
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        Layout.alignment: Qt.AlignVCenter
      }

      // Stop icon
      NIcon {
        id: stopIconH
        icon: "player-stop-filled"
        pointSize: root.iconSize
        color: stopAreaH.containsMouse ? Color.mError : Color.mOnSurface
        visible: azanPlaying
        Layout.alignment: Qt.AlignVCenter
      }
    }

    // ── Vertical layout ───────────────────────────────────────────────
    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.marginXS
      visible: isVertical

      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.marginXS

        NIcon {
          icon: "building-mosque"
          pointSize: Style.toOdd(root.capsuleHeight * 0.45)
          color: mouseArea.containsMouse ? Color.mOnHover : Color.mPrimary
        }

        NIcon {
          icon: "volume"
          pointSize: Style.toOdd(root.capsuleHeight * 0.38)
          color: Color.mPrimary
          visible: azanPlaying
          SequentialAnimation on opacity {
            running: azanPlaying
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 600 }
            NumberAnimation { to: 1.0; duration: 600 }
          }
        }
      }

      NText {
        text: {
          var parts = root.displayText.split(" ");
          return parts[0] + "\n" + parts.slice(1).join(" ");
        }
        pointSize: root.barFontSize * 0.65
        applyUiScale: false
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
      }

      NIcon {
        id: stopIconV
        icon: "player-stop-filled"
        pointSize: root.iconSize
        color: stopAreaV.containsMouse ? Color.mError : Color.mOnSurface
        visible: azanPlaying
        Layout.alignment: Qt.AlignHCenter
      }
    }

    // ── Main click — opens panel (blocked when azan playing) ──────────
    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onClicked: mouse => {
        if (azanPlaying) return
        if (mouse.button === Qt.LeftButton) {
          if (pluginApi) pluginApi.openPanel(root.screen, root)
        } else if (mouse.button === Qt.RightButton) {
          PanelService.showContextMenu(contextMenu, root, screen)
        }
      }

      onEntered: TooltipService.show(root, tooltipText, BarService.getTooltipDirection(root.screen?.name))
      onExited:  TooltipService.hide()
    }

    // ── Stop area horizontal — declared after mouseArea to win ────────
    MouseArea {
      id: stopAreaH
      visible: azanPlaying && !isVertical
      // Cover stop icon area
      x: stopIconH.x + hLayout.x
      y: 0
      width:  stopIconH.width + Style.marginM
      height: parent.height
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: mouse => {
        mouse.accepted = true
        mainInstance?.stopAzanFile()
      }
      onEntered: TooltipService.show(stopIconH, pluginApi?.tr("widget.stopAzan") || "Stop Azan", BarService.getTooltipDirection(root.screen?.name))
      onExited:  TooltipService.hide()
    }

    // ── Stop area vertical — declared after mouseArea to win ──────────
    MouseArea {
      id: stopAreaV
      visible: azanPlaying && isVertical
      x: stopIconV.x
      y: stopIconV.y
      width:  stopIconV.width
      height: stopIconV.height
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: mouse => {
        mouse.accepted = true
        mainInstance?.stopAzanFile()
      }
      onEntered: TooltipService.show(stopIconV, pluginApi?.tr("widget.stopAzan") || "Stop Azan", BarService.getTooltipDirection(root.screen?.name))
      onExited:  TooltipService.hide()
    }
  }

  // ── Context menu ──────────────────────────────────────────────────────────

  NPopupContextMenu {
    id: contextMenu
    model: [
      {
        "label": pluginApi?.tr("menu.openPanel") || "Open Prayer Times",
        "action": "open",
        "icon": "building-mosque"
      },
      {
        "label": pluginApi?.tr("menu.settings") || "Widget Settings",
        "action": "settings",
        "icon": "settings"
      }
    ]
    onTriggered: function(action) {
      contextMenu.close()
      PanelService.closeContextMenu(screen)
      if (action === "open") {
        pluginApi.openPanel(root.screen, root)
      } else if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest)
      }
    }
  }
}
