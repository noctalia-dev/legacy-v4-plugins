import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property bool hovered: false

  // Bar positioning properties
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  property string currentIconName: pluginApi?.pluginSettings?.currentIconName || pluginApi?.manifest?.metadata?.defaultSettings?.currentIconName
  property bool hideOnZero: pluginApi?.pluginSettings.hideOnZero || pluginApi?.manifest?.metadata.defaultSettings?.hideOnZero
  readonly property bool isVisible: (root.pluginApi?.mainInstance?.updateCount > 0) || !root.hideOnZero
  visible: root.isVisible
  // also set opacity to zero when invisible as we use opacity to hide the barWidgetLoader
  opacity: root.isVisible ? 1.0 : 0.0

  readonly property real contentWidth: isVertical ? root.capsuleHeight : layout.implicitWidth + Style.marginS * 2
  readonly property real contentHeight: isVertical ? layout.implicitHeight + Style.marginS * 2 : root.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  //
  // ------ Widget ------
  //
  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: root.hovered ? Color.mHover : Style.capsuleColor
    radius: Style.radiusM
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Item {
      id: layout
      anchors.centerIn: parent

      implicitWidth: grid.implicitWidth
      implicitHeight: grid.implicitHeight

      GridLayout {
        id: grid
        columns: root.isVertical ? 1 : 2
        rowSpacing: Style.marginS
        columnSpacing: Style.marginS

        NIcon {
          Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
          icon: root.currentIconName
          color: root.hovered ? Color.mOnHover : Color.mOnSurface
        }

        NText {
          Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
          text: root.pluginApi?.mainInstance?.updateCount.toString()
          color: root.hovered ? Color.mOnHover : Color.mOnSurface
          pointSize: root.barFontSize
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: root.pluginApi?.mainInstance?.updateCount > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

    onEntered: {
      root.hovered = true;
      buildTooltip();
    }

    onExited: {
      root.hovered = false;
      TooltipService.hide();
    }

    onPressed: mouse => {
      TooltipService.hide();

      if (mouse.button == Qt.LeftButton && root.pluginApi?.mainInstance?.updateCount > 0)
        root.pluginApi?.mainInstance?.startDoSystemUpdate();
      else if (mouse.button == Qt.RightButton)
        PanelService.showContextMenu(contextMenu, root, screen);
    }

    NPopupContextMenu {
      id: contextMenu

      model: [
        {
          "label": "Update",
          "action": "run-update-cmd",
          "icon": "arrow-up-from-arc",
          "enabled": root.pluginApi?.mainInstance?.updateCount > 0
        },
        {
          "label": I18n.tr("actions.widget-settings"),
          "action": "widget-settings",
          "icon": "settings"
        },
      ]

      onTriggered: action => {
        contextMenu.close();
        PanelService.closeContextMenu(screen);

        if (action === "run-update-cmd")
          root.pluginApi?.mainInstance?.startDoSystemUpdate();
        else if (action === "widget-settings") {
          BarService.openPluginSettings(screen, pluginApi.manifest);
        }
      }
    }
  }

  function buildTooltip() {
    const updateCount = root.pluginApi?.mainInstance?.updateCount

    if (updateCount === 0) {
      TooltipService.show(root, pluginApi?.tr("tooltip.noUpdatesAvailable"), BarService.getTooltipDirection(root.screenName));
    } else {
      TooltipService.show(root, pluginApi?.tr("tooltip.updatesAvailable"), BarService.getTooltipDirection(root.screenName));
    }
  }
}
