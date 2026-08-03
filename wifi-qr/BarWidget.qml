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

  // Bar positioning properties
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property real contentWidth: root.isVertical ? root.capsuleHeight : icon.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: root.capsuleHeight

  readonly property color contentColor: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurfaceVariant

  readonly property string tooltipText: pluginApi?.tr("bar_widget.tooltip") || "Show Wi-Fi QR code"

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  // Visual capsule - pixel-perfect centered
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
      id: icon
      anchors.centerIn: parent
      icon: "qrcode"
      color: root.contentColor
      applyUiScale: false
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: function (mouse) {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi) {
          Logger.i("WifiQR", "Opening Wi-Fi QR panel");
          pluginApi.openPanel(root.screen, root);
        }
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen);
      }
    }
    onEntered: {
      TooltipService.show(root, tooltipText, BarService.getTooltipDirection(root.screen?.name));
    }
    onExited: {
      TooltipService.hide();
    }
  }

  // Right-click context menu
  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("bar_widget.open_panel") || "Open Panel",
        "action": "open-panel",
        "icon": "qrcode"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "open-panel") {
                     if (pluginApi) {
                       pluginApi.openPanel(root.screen, root);
                     }
                   }
                 }
  }
}
