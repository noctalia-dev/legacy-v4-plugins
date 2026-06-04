import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property var hermesService: pluginApi?.mainInstance?.hermesService || null

  property ShellScreen screen
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 280 * Style.uiScaleRatio
  property real contentPreferredHeight: 200 * Style.uiScaleRatio
  readonly property bool allowAttach: true

  readonly property string status: hermesService?.status ?? "unknown"
  readonly property bool cliActive: hermesService?.cliActive ?? false
  readonly property int activeCliCount: hermesService?.activeCliCount ?? 0
  readonly property string gatewayPid: hermesService?.gatewayPid ?? ""
  readonly property string signalEvent: hermesService?.signalEvent ?? ""
  readonly property var platforms: hermesService?.platforms ?? ({})
  readonly property var usage: hermesService?.usage ?? ({})
  readonly property var processModel: hermesService?.processModel ?? null

  readonly property string statusText: {
    switch (status) {
      case "offline":    return pluginApi?.tr("status.offline");
      case "idle":       return pluginApi?.tr("status.idle");
      case "busy":       return pluginApi?.tr("status.busy");
      case "attention":  return pluginApi?.tr("status.attention");
      case "degraded":   return pluginApi?.tr("status.degraded");
      case "error":      return pluginApi?.tr("status.error");
      default:           return pluginApi?.tr("status.unknown");
    }
  }

  readonly property string statusIcon: {
    switch (status) {
      case "offline":    return "power";
      case "idle":       return "circle-check";
      case "busy":       return "loader";
      case "attention":  return "bell-ringing";
      case "degraded":   return "alert-circle";
      case "error":      return "alert-triangle";
      default:           return "help-circle";
    }
  }

  readonly property color statusColor: {
    switch (status) {
      case "offline":    return Color.mError;
      case "idle":       return Color.mPrimary;
      case "busy":       return Color.mPrimary;
      case "attention":  return "#f59e0b";
      case "degraded":   return "#f97316";
      case "error":      return Color.mError;
      default:           return Color.mOnSurface;
    }
  }

  readonly property string eventText: {
    var map = {
      "pre_llm_call": pluginApi?.tr("event.thinking"),
      "post_llm_call": pluginApi?.tr("event.processing"),
      "pre_tool_call": pluginApi?.tr("event.tool_call"),
      "post_tool_call": pluginApi?.tr("event.tool_done"),
      "pre_approval_request": pluginApi?.tr("event.awaiting_approval"),
      "on_session_start": pluginApi?.tr("event.started"),
      "on_session_end": pluginApi?.tr("event.ended"),
      "on_session_finalize": pluginApi?.tr("event.finalizing"),
      "on_session_reset": pluginApi?.tr("event.reset")
    };
    return map[signalEvent] || "";
  }

  function formatTokens(value) {
    var n = Number(value || 0);
    if (n >= 1000000) return (n / 1000000).toFixed(n >= 10000000 ? 0 : 1) + "M";
    if (n >= 1000) return (n / 1000).toFixed(n >= 100000 ? 0 : 1) + "k";
    return String(Math.round(n));
  }

  function formatCost(value) {
    if (value === undefined || value === null) return "";
    var n = Number(value);
    if (!isFinite(n) || n <= 0) return "";
    if (n < 0.0001) return "$" + n.toFixed(6);
    if (n < 0.01) return "$" + n.toFixed(4);
    return "$" + n.toFixed(2);
  }

  readonly property string tokensText: {
    if (!usage || !usage.available) return pluginApi?.tr("panel.none");
    return formatTokens(usage.total_tokens)
      + "  in " + formatTokens(usage.input_tokens)
      + " / out " + formatTokens(usage.output_tokens)
      + " / cache " + formatTokens(usage.cache_tokens);
  }

  readonly property string costText: {
    if (!usage || !usage.available) return pluginApi?.tr("panel.unknown");
    var actual = formatCost(usage.actual_cost_usd);
    if (actual !== "") return actual + " " + pluginApi?.tr("panel.actual");
    var estimated = formatCost(usage.estimated_cost_usd);
    if (estimated !== "") return estimated + " " + pluginApi?.tr("panel.estimated");
    return pluginApi?.tr("panel.unknown");
  }

  readonly property bool costIsUnknown: !usage || !usage.available || (!formatCost(usage.actual_cost_usd) && !formatCost(usage.estimated_cost_usd))

  // Process state → icon helper
  function processStateIcon(state) {
    switch (state) {
      case "busy":       return "loader";
      case "attention":  return "bell-ringing";
      case "idle":       return "circle-check";
      case "error":      return "alert-triangle";
      default:           return "help-circle";
    }
  }

  // Process state → color helper
  function processStateColor(state) {
    switch (state) {
      case "busy":       return Color.mPrimary;
      case "attention":  return "#f59e0b";
      case "idle":       return Color.mPrimary;
      case "error":      return Color.mError;
      default:           return Color.mOnSurface;
    }
  }

  // Source label (i18n)
  function sourceLabel(source) {
    switch (source) {
      case "gateway":    return pluginApi?.tr("panel.gw");
      case "cli":        return pluginApi?.tr("panel.cli");
      case "cron":       return pluginApi?.tr("panel.cron");
      default:           return "?";
    }
  }

  // Format short session id (first 8 chars)
  function shortSessionId(sid) {
    if (!sid) return "";
    if (sid.length <= 8) return sid;
    return sid.substring(0, 8) + "\u2026";
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    NBox {
      anchors.fill: parent
      anchors.margins: Style.marginS

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginXS

        // Row 1: icon + name + status
        RowLayout {
          spacing: Style.marginS

          NIcon {
            icon: root.statusIcon
            color: root.statusColor
            pointSize: Style.fontSizeM
          }

          NText {
            text: pluginApi?.tr("panel.hermes")
            font.weight: Font.Bold
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
          }

          NText {
            text: root.statusText
            pointSize: Style.fontSizeS
            color: root.statusColor
          }

          Item { Layout.fillWidth: true }

          NText {
            text: root.eventText
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
            opacity: 0.5
            visible: text !== ""
          }
        }

        // Separator
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: Color.mOutline
          opacity: 0.2
        }

        // Gateway row (always shown)
        RowLayout {
          spacing: Style.marginS

          NText {
            text: pluginApi?.tr("panel.gateway")
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
            opacity: 0.5
            Layout.preferredWidth: 60
          }

          NText {
            text: gatewayPid ? "PID " + gatewayPid : pluginApi?.tr("panel.stopped")
            pointSize: Style.fontSizeS
            color: gatewayPid ? Color.mOnSurface : Color.mError
          }
        }

        // Process list (non-gateway processes)
        Repeater {
          model: {
            if (!root.processModel) return [];
            var items = [];
            for (var i = 0; i < root.processModel.count; i++) {
              var p = root.processModel.get(i);
              if (p.source !== "gateway") {
                items.push(p);
              }
            }
            return items;
          }

          delegate: RowLayout {
            spacing: Style.marginS

            NIcon {
              icon: processStateIcon(modelData.state)
              color: processStateColor(modelData.state)
              pointSize: Style.fontSizeXS
            }

            NText {
              text: sourceLabel(modelData.source)
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
              opacity: 0.5
              Layout.preferredWidth: 24
            }

            NText {
              text: shortSessionId(modelData.sessionId) || ("PID " + modelData.pid)
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
              Layout.fillWidth: true
              elide: Text.ElideRight
            }

            NText {
              text: modelData.alive ? "" : pluginApi?.tr("panel.dead")
              pointSize: Style.fontSizeS
              color: Color.mError
              opacity: 0.6
            }
          }
        }

        // Separator before platforms
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: Color.mOutline
          opacity: 0.2
        }

        // Platforms
        Repeater {
          model: {
            var items = [];
            for (var key in root.platforms) {
              items.push({
                "name": key.charAt(0).toUpperCase() + key.slice(1),
                "ok": root.platforms[key]?.state === "connected"
              });
            }
            return items;
          }

          delegate: RowLayout {
            spacing: Style.marginS

            NText {
              text: modelData.name
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
              opacity: 0.5
              Layout.preferredWidth: 60
            }

            NText {
              text: modelData.ok ? pluginApi?.tr("panel.online") : pluginApi?.tr("panel.offline")
              pointSize: Style.fontSizeS
              color: modelData.ok ? Color.mPrimary : Color.mError
            }
          }
        }

        // Token usage (always visible below platforms)
        RowLayout {
          spacing: Style.marginS

          NText {
            text: pluginApi?.tr("panel.tokens")
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
            opacity: 0.5
            Layout.preferredWidth: 60
          }

          NText {
            text: root.tokensText
            pointSize: Style.fontSizeS
            color: Color.mPrimary
            opacity: 0.8
            Layout.fillWidth: true
            elide: Text.ElideRight
          }
        }

        // Cost
        RowLayout {
          spacing: Style.marginS

          NText {
            text: pluginApi?.tr("panel.cost")
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
            opacity: 0.5
            Layout.preferredWidth: 60
          }

          NText {
            text: root.costText
            pointSize: Style.fontSizeS
            color: root.costIsUnknown ? Color.mOnSurface : Color.mPrimary
            opacity: root.costIsUnknown ? 0.45 : 1.0
          }
        }
      }
    }
  }
}
