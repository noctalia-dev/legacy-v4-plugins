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
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string screenName: screen?.name ?? ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property int runningCount: mainInstance?.runningCount ?? 0
  readonly property bool hideWhenEmpty: pluginApi?.pluginSettings?.hideWhenEmpty ?? pluginApi?.manifest?.metadata?.defaultSettings?.hideWhenEmpty ?? false

  readonly property real contentWidth: capsuleRow.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: capsuleHeight

  implicitWidth: isBarVertical ? capsuleHeight : contentWidth
  implicitHeight: isBarVertical ? contentHeight : capsuleHeight
  visible: !(hideWhenEmpty && runningCount === 0)

  NPopupContextMenu {
    id: contextMenu
    model: [
      { "label": pluginApi?.tr("menu.refresh"), "action": "refresh", "icon": "refresh" },
      { "label": pluginApi?.tr("menu.restart"), "action": "restart", "icon": "reload" },
      { "label": pluginApi?.tr("menu.settings"), "action": "settings", "icon": "settings" }
    ]
    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)
      if (action === "refresh") {
        root.mainInstance?.refreshAndPrune()
      } else if (action === "restart") {
        root.mainInstance?.restartService()
      } else if (action === "settings" && pluginApi) {
        BarService.openPluginSettings(screen, pluginApi.manifest)
      }
    }
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    RowLayout {
      id: capsuleRow
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        icon: root.runningCount > 0 ? "bot" : "bot-off"
        color: mouseArea.containsMouse ? Color.mOnHover : (root.runningCount > 0 ? Color.mPrimary : Color.mOnSurfaceVariant)
        applyUiScale: true
      }

      NText {
        text: root.runningCount.toString()
        color: mouseArea.containsMouse ? Color.mOnHover : (root.runningCount > 0 ? Color.mPrimary : Color.mOnSurfaceVariant)
        pointSize: root.barFontSize
        applyUiScale: false
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true

    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi) pluginApi.togglePanel(root.screen, root)
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen)
      } else if (mouse.button === Qt.MiddleButton) {
        root.mainInstance?.refreshAndPrune()
      }
    }

    onEntered: {
      TooltipService.show(root, pluginApi?.tr("bar.tooltip", { count: root.runningCount }), BarService.getTooltipDirection())
    }

    onExited: TooltipService.hide()
  }
}
