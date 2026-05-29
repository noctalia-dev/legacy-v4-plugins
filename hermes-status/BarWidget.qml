import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property var hermesService: pluginApi?.mainInstance?.hermesService || null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: 0
  property int sectionWidgetsCount: 1

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property bool hideWhenIdle: cfg.hideWhenIdle ?? defaults.hideWhenIdle ?? false
  readonly property string status: hermesService?.status ?? "loading"
  readonly property var usage: hermesService?.usage ?? ({})

  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)

  // ── Traffic light: icon + color per status ──
  readonly property string currentIcon: {
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

  readonly property color iconColor: {
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

  readonly property string displayText: {
    if (status === "attention") return "!";
    if (status === "degraded") return "!";
    // Conversation ended / idle: keep the green status icon, but hide stale
    // token usage from the previous turn/session.
    if (status === "idle") return "";
    return root.usageText;
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

  readonly property string usageText: {
    if (!usage || !usage.available || !usage.total_tokens) return "";
    var text = formatTokens(usage.total_tokens) + " tok";
    var cost = formatCost(usage.actual_cost_usd ?? usage.estimated_cost_usd);
    if (cost !== "") text += " · " + cost;
    return text;
  }

  readonly property bool shouldHide: hideWhenIdle && status === "idle"

  implicitWidth: shouldHide ? 0 : pill.width
  implicitHeight: shouldHide ? 0 : pill.height
  visible: !shouldHide

  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: root.currentIcon
    text: root.displayText
    forceOpen: root.displayText !== ""
    autoHide: true
    customTextIconColor: root.iconColor

    onClicked: {
      if (pluginApi) {
        if (hermesService && hermesService.needsAttention) {
          hermesService.clearAttention();
        }
        pluginApi.openPanel(root.screen, root);
      }
    }

    onRightClicked: {
      PanelService.showContextMenu(contextMenu, root, screen);
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("menu.refresh") ?? "Refresh",
        "action": "refresh",
        "icon": "refresh"
      },
      {
        "label": pluginApi?.tr("menu.clear-attention") ?? "Clear Attention",
        "action": "clear-attention",
        "icon": "bell-off"
      }
    ]

    onTriggered: function(action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "refresh") {
        hermesService?.refresh();
      } else if (action === "clear-attention") {
        hermesService?.clearAttention();
      }
    }
  }
}
