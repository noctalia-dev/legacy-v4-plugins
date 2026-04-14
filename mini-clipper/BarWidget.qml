import QtQuick
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
  readonly property string iconColorKey: cfg.iconColor ?? defaults.iconColor ?? "none"
  readonly property bool showItemCount: cfg.showItemCount ?? defaults.showItemCount ?? true
  readonly property int itemCount: pluginApi?.mainInstance?.items?.length ?? 0

  icon: "clipboard"
  tooltipText: pluginApi?.tr("widget.tooltip")
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: Color.resolveColorKey(iconColorKey)
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  onClicked: {
    if (pluginApi) {
      pluginApi.mainInstance?.refreshOnPanelOpen();
      pluginApi.openPanel(root.screen, this);
    }
  }

  // Item count badge
  Rectangle {
    visible: root.showItemCount && root.itemCount > 0
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: -Style.marginXS
    anchors.rightMargin: -Style.marginXS
    width: badgeText.implicitWidth + Style.marginS * 2
    height: badgeText.implicitHeight + Style.marginXS
    radius: height / 2
    color: Color.mPrimary

    NText {
      id: badgeText
      anchors.centerIn: parent
      text: root.itemCount > 99 ? "99+" : String(root.itemCount)
      font.pointSize: Style.fontSizeXS
      color: Color.mOnPrimary
    }
  }

  // Context menu
  NPopupContextMenu {
    id: contextMenu
    model: [
      { "label": pluginApi?.tr("menu.settings"), "action": "settings", "icon": "settings" }
    ]
    onTriggered: function(action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
