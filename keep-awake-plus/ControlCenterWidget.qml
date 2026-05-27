import QtQuick
import Quickshell
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen
  property var pluginApi: null

  readonly property var main: pluginApi?.mainInstance ?? null
  readonly property bool active: main?.active ?? false
  readonly property string scope: main?.scope ?? ""
  readonly property string remainingText: main ? main.formatRemaining() : ""

  function buildTooltip() {
    if (!active) return pluginApi?.tr("tooltip.off");
    const tgKey = (main && main.thermalGuardActive)
      ? "tooltip.thermal-guard-on"
      : "tooltip.thermal-guard-off";
    return pluginApi?.tr("tooltip.active", {
      scope: scope,
      remaining: remainingText,
      tg: pluginApi?.tr(tgKey)
    });
  }

  icon:        active ? "coffee" : "coffee-off"
  hot:         active
  tooltipText: buildTooltip()

  // Match Option B click semantics: left opens the full panel (scope picker,
  // duration menu, thermal guard), right toggles inhibit off.
  onClicked:      pluginApi?.openPanel(screen, this)
  onRightClicked: { if (main) main.off(); }
}
