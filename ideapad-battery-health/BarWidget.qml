import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string iconColorKey: cfg.iconColor ?? defaults.iconColor

  readonly property var service: pluginApi?.mainInstance?.service
  readonly property var preservationMode: service?.currentPreservation ?? pluginApi?.pluginSettings?.preservationMode

  icon: root.preservationMode == 1 ? "battery-vertical-eco" : "battery-vertical-charging"
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: Color.resolveColorKey(iconColorKey)

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  onClicked: {
    if (pluginApi) {
      pluginApi.openPanel(root.screen, this);
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("menu.settings"),
        "action": "settings",
        "icon": "settings"
      },
    ]

    onTriggered: function (action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }
  }
}
