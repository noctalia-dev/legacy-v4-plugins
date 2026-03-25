import QtQuick
import Quickshell
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen
  property var pluginApi: null

  readonly property var main: pluginApi?.mainInstance ?? null

  function getTooltip(device) {
    var batteryLabel = pluginApi?.tr("panel.card.battery")
    var stateLabel   = pluginApi?.tr("control_center.state-label")

    var batteryLine = (device !== null && device !== undefined && device.isReachable && device.isPaired && device.batteryCharge !== -1)
      ? (batteryLabel + ": " + device.batteryCharge + "%\n")
      : ""

    var stateKey   = main?.getConnectionStateKey(device, main?.daemonAvailable ?? false) ?? "control_center.state.unavailable"
    var stateValue = pluginApi?.tr(stateKey)
    var stateLine  = stateLabel + ": " + stateValue

    return batteryLine + stateLine
  }

  icon:        main?.getConnectionStateIcon(main?.mainDevice ?? null, main?.daemonAvailable ?? false) ?? "exclamation-circle"
  tooltipText: getTooltip(main?.mainDevice ?? null)

  onClicked: pluginApi?.togglePanel(screen, this)
}
