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

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string iconColorKey: cfg.iconColor ?? defaults.iconColor ?? "none"

  icon: "brand-google-fit"
  tooltipText: {
    if (!mainInstance) return pluginApi?.tr("widget.tooltip");

    const lines = [];
    lines.push(pluginApi?.tr("widget.tooltip"));
    lines.push(mainInstance.remindersPaused ? pluginApi?.tr("panel.paused") : pluginApi?.tr("panel.running"));

    if (mainInstance.sedentaryEnabled) {
      lines.push(pluginApi?.tr("widget.sedentaryStatus", { "time": mainInstance.formatDuration(mainInstance.sedentaryRemainingSeconds) }));
    }

    if (mainInstance.hydrationEnabled) {
      lines.push(pluginApi?.tr("widget.hydrationStatus", { "time": mainInstance.formatDuration(mainInstance.hydrationRemainingSeconds) }));
    }

    return lines.join("\n");
  }
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
      pluginApi.openPanel(root.screen, this);
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": mainInstance?.remindersPaused ? pluginApi?.tr("panel.resume") : pluginApi?.tr("panel.pause"),
        "action": "toggle-pause",
        "icon": mainInstance?.remindersPaused ? "media-play" : "media-pause"
      },
      {
        "label": pluginApi?.tr("panel.testSedentary"),
        "action": "test-sedentary",
        "icon": "armchair"
      },
      {
        "label": pluginApi?.tr("panel.testHydration"),
        "action": "test-hydration",
        "icon": "bottle"
      },
      {
        "label": pluginApi?.tr("menu.settings"),
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
        return;
      }

      if (!mainInstance) return;

      if (action === "toggle-pause") {
        mainInstance.setPaused(!mainInstance.remindersPaused);
      } else if (action === "test-sedentary") {
        mainInstance.sendSedentaryReminder(true);
      } else if (action === "test-hydration") {
        mainInstance.sendHydrationReminder(true);
      }
    }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
