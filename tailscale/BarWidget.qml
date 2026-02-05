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

  readonly property bool pillDirection: BarService.getPillDirection(root)

  readonly property var mainInstance: pluginApi?.mainInstance

  readonly property bool barIsVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"

  readonly property real contentWidth: {
    if ((mainInstance?.compactMode ?? false) || !(mainInstance?.tailscaleRunning ?? false)) {
      return Style.capsuleHeight
    }
    return contentRow.implicitWidth + Style.marginM * 2
  }
  readonly property real contentHeight: Style.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL

    RowLayout {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.marginS
      layoutDirection: Qt.LeftToRight

      TailscaleIcon {
        pointSize: Style.fontSizeL
        applyUiScale: false
        crossed: !(mainInstance?.tailscaleRunning ?? false)
        color: {
          if (mainInstance?.tailscaleRunning ?? false) return Color.mPrimary
          return mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        }
        opacity: (mainInstance?.isRefreshing ?? false) ? 0.5 : 1.0
      }

      // Show details when not in compact mode and there's something to show
      ColumnLayout {
        visible: !(mainInstance?.compactMode ?? false) && (mainInstance?.tailscaleRunning ?? false) && ((mainInstance?.showIpAddress ?? false) || (mainInstance?.showPeerCount ?? false))
        spacing: 2
        Layout.leftMargin: Style.marginXS
        Layout.rightMargin: Style.marginS

        // IP Address
        NText {
          visible: (mainInstance?.showIpAddress ?? false) && (mainInstance?.tailscaleIp ?? false)
          text: mainInstance?.tailscaleIp || ""
          pointSize: Style.fontSizeXS
          color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
          font.family: Settings.data.ui.fontFixed
        }

        // Peer count
        NText {
          visible: mainInstance?.showPeerCount ?? false
          text: (mainInstance?.peerCount || 0) + " " + (pluginApi?.tr("panel.peers") || "peers")
          pointSize: Style.fontSizeXS
          color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        }
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": (mainInstance?.tailscaleRunning ?? false)
          ? (pluginApi?.tr("context.disconnect") || "Disconnect")
          : (pluginApi?.tr("context.connect") || "Connect"),
        "action": "toggle-tailscale",
        "icon": (mainInstance?.tailscaleRunning ?? false) ? "plug-x" : "plug",
        "enabled": mainInstance?.tailscaleInstalled ?? false
      },
      {
        "label": pluginApi?.tr("actions.widget-settings") || "Widget Settings",
        "action": "widget-settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)

      if (action === "widget-settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest)
      } else if (action === "toggle-tailscale") {
        if (mainInstance) {
          mainInstance.toggleTailscale()
        }
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
        if (pluginApi) {
          pluginApi.openPanel(root.screen, root)
        }
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen)
      }
    }
  }
}
