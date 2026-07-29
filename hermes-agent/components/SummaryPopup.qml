import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

PopupWindow {
  id: root

  property var pluginApi: null
  property var state: ({})
  property ShellScreen screen: null
  property var anchorItem: null

  readonly property var bridge: state.bridge || ({})
  readonly property var hermes: state.hermes || ({})
  readonly property var session: state.session || ({})
  readonly property var approval: state.approval || ({})
  readonly property var summary: state.summary || ({})
  readonly property var model: summary.model || ({})
  readonly property var mcp: summary.mcp || ({})
  readonly property var cron: summary.cron || ({})
  readonly property var cronJobs: cron.jobs || []
  readonly property var activity: summary.activity || ({})
  readonly property var gateway: summary.gateway || ({})
  readonly property string hermesIconPath: pluginApi?.pluginDir ? "file://" + pluginApi.pluginDir + "/assets/hermes-icon.png" : ""
  readonly property string bridgeStatus: bridge.status || "offline"
  readonly property string hermesStatus: bridgeStatus === "online" ? (hermes.status || "unknown") : "offline"
  readonly property string statusLabel: statusText(hermesStatus)
  readonly property string modelLabel: {
    var provider = model.provider || hermes.provider || "";
    var name = model.name || hermes.model || "";
    if (provider && name) return provider + " / " + name;
    return name || provider || (pluginApi?.tr("summary.notSet"));
  }
  readonly property string cronLabel: String(cron.active || 0) + " active / " + String(cron.total || 0) + " total"
  readonly property string mcpLabel: {
    if ((mcp.total || 0) === 0) return (pluginApi?.tr("summary.noMcpServers"));
    return String(mcp.enabled || 0) + " enabled / " + String(mcp.total || 0) + " total";
  }
  readonly property string activityLabel: {
    var count = activity.tool_events || 0;
    if (count === 0) return (pluginApi?.tr("summary.noBackgroundActions"));
    var running = activity.running_tools || 0;
    if (running > 0) return String(running) + " running";
    return String(count) + " background actions";
  }
  readonly property string gatewayLabel: {
    var platforms = gateway.platforms || ({});
    var names = Object.keys(platforms);
    if (names.length === 0) return gateway.status || (pluginApi?.tr("summary.unknown"));
    return names.map(function(name) { return name + ": " + platforms[name]; }).join(", ");
  }
  readonly property bool hasError: (bridge.error || "") !== ""
  readonly property bool hasApproval: approval.pending === true

  signal openPanel()
  signal newSession()
  signal interrupt()
  signal refresh()
  signal settings()

  implicitWidth: 400 * Style.uiScaleRatio
  implicitHeight: popupContent.implicitHeight
  visible: false
  color: "transparent"

  anchor.item: anchorItem
  anchor.rect.x: {
    if (!anchorItem || !screen) return 0;
    var barPosition = Settings.getBarPositionForScreen(screen.name);
    if (barPosition === "right") return -implicitWidth - Style.marginM;
    if (barPosition === "left") return anchorItem.width + Style.marginM;
    var anchorGlobal = anchorItem.mapToItem(null, 0, 0);
    var centered = (anchorItem.width / 2) - (implicitWidth / 2);
    var screenX = anchorGlobal.x + centered;
    if (screenX < Style.marginM) return centered + (Style.marginM - screenX);
    if (screenX + implicitWidth > screen.width - Style.marginM) {
      return centered - ((screenX + implicitWidth) - (screen.width - Style.marginM));
    }
    return centered;
  }
  anchor.rect.y: {
    if (!anchorItem || !screen) return 0;
    var barPosition = Settings.getBarPositionForScreen(screen.name);
    var barHeight = Style.getBarHeightForScreen(screen.name);
    if (barPosition === "bottom") return -implicitHeight - Style.marginS;
    if (barPosition === "top") {
      var anchorGlobal = anchorItem.mapToItem(null, 0, 0);
      return barHeight + Style.marginS - anchorGlobal.y;
    }
    return Math.max(Style.marginM, (screen.height - implicitHeight) / 2) - anchorItem.mapToItem(null, 0, 0).y;
  }

  function statusText(status) {
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

  function statusColor(status) {
    switch (status) {
      case "offline": return Color.mError;
      case "busy": return Color.mPrimary;
      case "attention": return "#f59e0b";
      case "degraded": return "#f97316";
      case "error": return Color.mError;
      default: return Color.mPrimary;
    }
  }

  function toggleAt(item, itemScreen) {
    anchorItem = item;
    screen = itemScreen || null;
    visible = !visible;
    if (visible) {
      Qt.callLater(function() { root.anchor.updateAnchor(); });
    }
  }

  function close() {
    visible = false;
  }

  Rectangle {
    id: popupContent
    width: root.implicitWidth
    implicitHeight: layout.implicitHeight + Style.margin2M
    color: Color.mSurface
    border.color: Color.mOutline
    border.width: Style.borderS
    radius: Style.radiusM

    ColumnLayout {
      id: layout
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        margins: Style.marginM
      }
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Item {
          Layout.preferredWidth: Style.fontSizeXXL
          Layout.preferredHeight: Style.fontSizeXXL
          Layout.alignment: Qt.AlignVCenter

          HermesAvatar {
            anchors.fill: parent
            iconPath: root.hermesIconPath
            fallbackIcon: root.hermesStatus === "busy" ? "loader" : "sparkles"
            statusColor: root.statusColor(root.hermesStatus)
            iconSize: Style.fontSizeXL
            dotSize: 8 * Style.uiScaleRatio
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            text: (pluginApi?.tr("summary.hermes"))
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NText {
            text: root.statusLabel
            pointSize: Style.fontSizeS
            color: root.statusColor(root.hermesStatus)
            Layout.fillWidth: true
            elide: Text.ElideRight
          }
        }

        NButton {
          text: pluginApi?.tr("bar.openPanel")
          icon: "message-circle"
          onClicked: {
            root.close();
            root.openPanel();
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Color.mOutline
        opacity: 0.5
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.marginM
        rowSpacing: Style.marginS

          NText {
          text: (pluginApi?.tr("summary.model"))
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }

        NText {
          text: root.modelLabel
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        NText {
          text: (pluginApi?.tr("summary.cron"))
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }

        NText {
          text: root.cronLabel
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        NText {
          text: (pluginApi?.tr("summary.mcp"))
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }

        NText {
          text: root.mcpLabel
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        NText {
          text: (pluginApi?.tr("summary.gateway"))
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }

        NText {
          text: root.gatewayLabel
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        NText {
          text: (pluginApi?.tr("summary.activity"))
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }

        NText {
          text: root.activityLabel
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }

      ColumnLayout {
        visible: root.cronJobs.length > 0
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          text: pluginApi?.tr("bar.cronJobs")
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightSemiBold
          color: Color.mOnSurface
          Layout.fillWidth: true
        }

        Repeater {
          model: root.cronJobs

          delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: modelData.active ? "circle-check" : "circle-off"
              pointSize: Style.fontSizeS
              color: modelData.active ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              NText {
                text: modelData.name || (pluginApi?.tr("summary.unnamedJob"))
                pointSize: Style.fontSizeS
                color: Color.mOnSurface
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              NText {
                text: (modelData.next_run || modelData.schedule || modelData.state || "").replace("T", " ")
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }

            NText {
              text: modelData.last_status || modelData.state || ""
              pointSize: Style.fontSizeXS
              color: modelData.active ? Color.mPrimary : Color.mOnSurfaceVariant
              elide: Text.ElideRight
            }
          }
        }
      }

      Rectangle {
        visible: root.hasApproval || root.hasError
        Layout.fillWidth: true
        implicitHeight: alertRow.implicitHeight + Style.margin2S
        radius: Style.radiusS
        color: root.hasApproval ? Qt.rgba(0.96, 0.62, 0.04, 0.16) : Qt.rgba(0.94, 0.18, 0.18, 0.16)

        RowLayout {
          id: alertRow
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Style.marginS
            rightMargin: Style.marginS
          }
          spacing: Style.marginS

          NIcon {
            icon: root.hasApproval ? "bell-ringing" : "alert-triangle"
            pointSize: Style.fontSizeS
            color: root.hasApproval ? "#f59e0b" : Color.mError
          }

          NText {
            text: root.hasApproval ? (approval.message || (pluginApi?.tr("summary.approvalRequired"))) : bridge.error
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NButton {
          text: pluginApi?.tr("bar.newSession")
          icon: "plus"
          Layout.fillWidth: true
          onClicked: {
            root.close();
            root.newSession();
          }
        }

        NButton {
          text: pluginApi?.tr("bar.interrupt")
          icon: "octagon"
          enabled: session.running || root.hermesStatus === "busy"
          Layout.fillWidth: true
          onClicked: root.interrupt()
        }

        NButton {
          text: pluginApi?.tr("bar.refresh")
          icon: "refresh"
          Layout.fillWidth: true
          onClicked: root.refresh()
        }
      }

      NButton {
        text: pluginApi?.tr("settings.title")
        icon: "settings"
        Layout.fillWidth: true
        onClicked: {
          root.close();
          root.settings();
        }
      }
    }
  }
}
