import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "components" as Components

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var state: mainInstance?.state || ({})
  readonly property var bridge: state.bridge || ({})
  readonly property var hermes: state.hermes || ({})
  readonly property var session: state.session || ({})
  readonly property var summary: state.summary || ({})
  readonly property string gatewayStatus: (summary.gateway && summary.gateway.status) || "unknown"
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property bool clientOnlyMode: cfg.clientOnlyMode ?? defaults.clientOnlyMode ?? false
  readonly property string hermesIconPath: pluginApi?.pluginDir ? "file://" + pluginApi.pluginDir + "/assets/hermes-icon.png" : ""

  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property bool hideWhenIdle: cfg.hideWhenIdle ?? defaults.hideWhenIdle ?? false
  readonly property string bridgeStatus: bridge.status || "offline"
  readonly property string hermesStatus: hermes.status || "unknown"
  readonly property bool bridgeOnline: bridgeStatus === "online"
  // When the bridge is online but Hermes has not reported a lifecycle status yet
  // (no session run / status hook), fall back to the gateway: running gateway = idle.
  readonly property string status: !bridgeOnline ? "offline"
    : (hermesStatus !== "unknown" ? hermesStatus
       : (gatewayStatus === "running" ? "idle" : "unknown"))
  readonly property bool shouldHide: hideWhenIdle && status === "idle"

  readonly property string statusIcon: {
    switch (status) {
      case "offline": return "power";
      case "idle": return "circle-check";
      case "busy": return "loader";
      case "attention": return "bell-ringing";
      case "degraded": return "alert-circle";
      case "error": return "alert-triangle";
      default: return "sparkles";
    }
  }

  readonly property color statusColor: {
    switch (status) {
      case "offline": return Color.mError;
      case "idle": return Color.mPrimary;
      case "busy": return Color.mPrimary;
      case "attention": return "#f59e0b";
      case "degraded": return "#f97316";
      case "error": return Color.mError;
      default: return Color.mOnSurface;
    }
  }

  readonly property string statusText: {
    switch (status) {
      case "offline": return pluginApi?.tr("status.offline");
      case "idle": return pluginApi?.tr("status.idle");
      case "busy": return pluginApi?.tr("status.busy");
      case "attention": return pluginApi?.tr("status.attention");
      case "degraded": return pluginApi?.tr("status.degraded");
      case "error": return pluginApi?.tr("status.error");
      default: return pluginApi?.tr("status.unknown");
    }
  }

  readonly property string displayText: {
    if (isBarVertical) return "";
    if (status === "idle") return "";
    if (status === "unknown") return "";
    if (status === "attention") return "!";
    return statusText;
  }

  readonly property string tooltipText: {
    var model = hermes.model ? " · " + hermes.model : "";
    var err = bridge.error ? "\n" + bridge.error : "";
    return "Hermes: " + statusText + model + err;
  }

  function openHermesPanel() {
    if (mainInstance && typeof mainInstance.openPreferredPanel === "function") {
      mainInstance.openPreferredPanel(root.screen, root);
      return;
    }
    pluginApi?.openPanel(root.screen, root);
  }

  readonly property real contentWidth: {
    if (shouldHide) return 0;
    return isBarVertical ? capsuleHeight : content.implicitWidth + Style.marginM * 2;
  }
  readonly property real contentHeight: {
    if (shouldHide) return 0;
    return isBarVertical ? content.implicitHeight + Style.marginM * 2 : capsuleHeight;
  }

  implicitWidth: contentWidth
  implicitHeight: contentHeight
  visible: !shouldHide

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

    Item {
      id: content
      anchors.centerIn: parent
      implicitWidth: rowLayout.visible ? rowLayout.implicitWidth : colLayout.implicitWidth
      implicitHeight: rowLayout.visible ? rowLayout.implicitHeight : colLayout.implicitHeight

      RowLayout {
        id: rowLayout
        visible: !root.isBarVertical
        spacing: Style.marginS

        Item {
          Layout.preferredWidth: root.barFontSize + 6
          Layout.preferredHeight: root.barFontSize + 6
          Layout.alignment: Qt.AlignVCenter

          Components.HermesAvatar {
            anchors.fill: parent
            iconPath: root.hermesIconPath
            fallbackIcon: root.statusIcon
            statusColor: root.statusColor
            iconSize: root.barFontSize
            dotSize: 7 * Style.uiScaleRatio
          }
        }

        NText {
          visible: root.displayText !== ""
          text: root.displayText
          pointSize: root.barFontSize
          applyUiScale: false
          font.weight: Style.fontWeightSemiBold
          color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
          Layout.alignment: Qt.AlignVCenter
        }
      }

      ColumnLayout {
        id: colLayout
        visible: root.isBarVertical
        spacing: Style.marginXS

        Item {
          Layout.preferredWidth: root.barFontSize + 8
          Layout.preferredHeight: root.barFontSize + 8
          Layout.alignment: Qt.AlignHCenter

          Components.HermesAvatar {
            anchors.fill: parent
            iconPath: root.hermesIconPath
            fallbackIcon: root.statusIcon
            statusColor: root.statusColor
            iconSize: root.barFontSize
            dotSize: 7 * Style.uiScaleRatio
          }
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) {
        summaryPopup.toggleAt(root, root.screen);
      } else if (mouse.button === Qt.RightButton) {
        summaryPopup.close();
        PanelService.showContextMenu(contextMenu, root, screen);
      }
    }

    onEntered: TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screenName))
    onExited: TooltipService.hide()
  }

  NPopupContextMenu {
    id: contextMenu
    screen: root.screen

    model: {
      var items = [
        { "label": pluginApi?.tr("bar.openPanel"), "action": "open", "icon": "message-circle" },
        { "label": pluginApi?.tr("bar.newSession"), "action": "new-session", "icon": "plus" },
        { "label": pluginApi?.tr("bar.interrupt"), "action": "interrupt", "icon": "octagon" },
        { "label": pluginApi?.tr("bar.refresh"), "action": "refresh", "icon": "refresh" }
      ];
      if (!root.clientOnlyMode && (root.status === "offline" || root.status === "unknown")) {
        items.push({ "label": pluginApi?.tr("bar.startGateway"), "action": "start-gateway", "icon": "power" });
      }
      items.push({ "label": pluginApi?.tr("settings.title"), "action": "settings", "icon": "settings" });
      return items;
    }

    onTriggered: function(action) {
      contextMenu.close();
      PanelService.closeContextMenu(root.screen);
      if (action === "open") {
        root.openHermesPanel();
      } else if (action === "new-session") {
        mainInstance?.createSession();
        root.openHermesPanel();
      } else if (action === "interrupt") {
        mainInstance?.interrupt();
      } else if (action === "refresh") {
        mainInstance?.refreshState();
      } else if (action === "start-gateway") {
        mainInstance?.startGateway();
      } else if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi?.manifest);
      }
    }
  }

  Components.SummaryPopup {
    id: summaryPopup
    pluginApi: root.pluginApi
    state: root.state
    screen: root.screen

    onOpenPanel: root.openHermesPanel()
    onNewSession: {
      mainInstance?.createSession();
      root.openHermesPanel();
    }
    onInterrupt: mainInstance?.interrupt()
    onRefresh: mainInstance?.refreshState()
    onSettings: BarService.openPluginSettings(root.screen, pluginApi?.manifest)
  }
}
