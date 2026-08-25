// ControlCenterWidget.qml v2 — CC shortcuts tile: gauge icon + active
// provider status in the tooltip. Left click toggles the panel,
// right click opens the plugin settings.
import QtQuick
import Quickshell
import qs.Services.UI
import qs.Widgets
import "Logic.js" as Logic

NIconButtonHot {
  id: root

  property ShellScreen screen
  property var pluginApi: null

  readonly property var mainInstance: pluginApi ? pluginApi.mainInstance : null
  readonly property var activeEntry: mainInstance ? mainInstance.activeEntry : null
  readonly property int leftPct: mainInstance && activeEntry ? mainInstance.leftPercent(activeEntry) : -1

  icon: "gauge"

  tooltipText: {
    if (!pluginApi || !mainInstance || mainInstance.providers.length === 0)
      return pluginApi ? pluginApi.tr("settings.title") : "";
    var label = mainInstance.displayLabel(mainInstance.activeProvider);
    // surface fetch errors even when a cached entry exists
    if (mainInstance.activeError !== "")
      return label + " · ⚠ " + Logic.safeText(mainInstance.activeError, 80);
    if (activeEntry) {
      var h = mainInstance.headlineSection(activeEntry);
      if (h && h.resetAt > 0) {
        var dur = Logic.formatDuration(Logic.remainingMs(h.resetAt, mainInstance.now), pluginApi.tr("units.h"), pluginApi.tr("units.m"));
        return label + " · " + pluginApi.tr("bar_widget.tooltip").replace("{percent}", String(leftPct)).replace("{duration}", dur);
      }
      if (h && h.value !== "")
        return label + " · " + h.value;
    }
    return label;
  }

  onClicked: {
    if (pluginApi)
      pluginApi.togglePanel(root.screen, root);
  }

  onRightClicked: {
    BarService.openPluginSettings(root.screen, pluginApi.manifest);
  }
}
