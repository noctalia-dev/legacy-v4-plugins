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

  readonly property string barPosition: Settings.data.bar.position
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"

  property string currentIconName: pluginApi?.pluginSettings?.currentIconName || pluginApi?.manifest?.metadata?.defaultSettings?.currentIconName
  property bool hideOnZero: pluginApi?.pluginSettings.hideOnZero || pluginApi?.manifest?.metadata.defaultSettings?.hideOnZero
  readonly property bool isVisible: (root.pluginApi?.mainInstance?.updateCount > 0) || !root.hideOnZero
  visible: root.isVisible
  // also set opacity to zero when invisible as we use opacity to hide the barWidgetLoader
  opacity: root.isVisible ? 1.0 : 0.0

  readonly property real contentWidth: isVertical ? Style.capsuleHeight : layout.implicitWidth + Style.marginS * 2
  readonly property real contentHeight: isVertical ? layout.implicitHeight + Style.marginS * 2 : Style.capsuleHeight

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
          pointSize: Style.barFontSize
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.pluginApi?.mainInstance?.updateCount > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

    onClicked: {
      if (root.pluginApi?.mainInstance?.updateCount > 0)
        root.pluginApi?.mainInstance?.startDoSystemUpdate();
    }

    onEntered: {
      root.hovered = true;
      buildTooltip();
    }

    onExited: {
      root.hovered = false;
      TooltipService.hide();
    }
  }

  function buildTooltip() {
    const updateCount = root.pluginApi?.mainInstance?.updateCount

    if (updateCount === 0) {
      TooltipService.show(root, pluginApi?.tr("tooltip.noUpdatesAvailable"), BarService.getTooltipDirection());
    } else {
      TooltipService.show(root, pluginApi?.tr("tooltip.updatesAvailable"), BarService.getTooltipDirection());
    }
  }
}
