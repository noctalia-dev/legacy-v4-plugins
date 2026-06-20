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

  readonly property var cfg: pluginApi?.pluginSettings ?? ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  readonly property bool vibrantEnabled: cfg.enabled ?? defaults.enabled ?? false
  readonly property int vibranceValue: cfg.vibranceValue ?? defaults.vibranceValue ?? 512
  readonly property int displayIndex: (cfg.displayIndex ?? defaults.displayIndex ?? 1) - 1

  readonly property real contentWidth: Style.capsuleHeight
  readonly property real contentHeight: Style.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  function buildCmd(value) {
    var parts = ["nvibrant"]
    for (var i = 0; i < root.displayIndex; i++)
      parts.push("0")
    parts.push(value.toString())
    return ["bash", "-lc", parts.join(" ")]
  }

  function applyVibrance(value) {
    Quickshell.execDetached(buildCmd(value))
  }

  function toggle() {
    if (pluginApi) {
      var newEnabled = !vibrantEnabled
      pluginApi.pluginSettings.enabled = newEnabled
      pluginApi.saveSettings()
      applyVibrance(newEnabled ? vibranceValue : 0)
    }
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusL
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    NIcon {
      anchors.centerIn: parent
      icon: "contrast"
      applyUiScale: false
      color: root.vibrantEnabled
        ? Color.mPrimary
        : (mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface)
    }
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      {
        "label": root.vibrantEnabled
          ? pluginApi?.tr("panel.disable-vibrance")
          : pluginApi?.tr("panel.enable-vibrance"),
        "action": "toggle",
        "icon": root.vibrantEnabled ? "eye-off" : "eye"
      },
      {
        "label": pluginApi?.tr("panel.settings"),
        "action": "widget-settings",
        "icon": "settings"
      }
    ]
    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)
      if (action === "toggle") {
        root.toggle()
      } else if (action === "widget-settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest)
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
        root.toggle()
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen)
      }
    }
  }
}
