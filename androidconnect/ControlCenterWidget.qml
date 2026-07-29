import QtQuick
import Quickshell
import qs.Widgets
import "./Services"

NIconButtonHot {
    property ShellScreen screen
    property var pluginApi: null

    function getTooltip(device) {
        const batteryLabel = pluginApi?.tr("panel.card.battery");
        const stateLabel = pluginApi?.tr("control_center.state-label");

        const batteryLine = (device !== null && device.reachable && device.paired && device.battery !== -1) ? (batteryLabel + ": " + device.battery + "%\n") : "";

        const stateKey = KDEConnectUtils.getConnectionStateKey(device, KDEConnect.daemonAvailable);
        const stateValue = pluginApi?.tr(stateKey);
        const stateLine = stateLabel + ": " + stateValue;

        return batteryLine + stateLine;
    }

    icon: KDEConnectUtils.getConnectionStateIcon(KDEConnect.mainDevice, KDEConnect.daemonAvailable)
    tooltipText: getTooltip(KDEConnect.mainDevice)

    onClicked: pluginApi?.togglePanel(screen, this)
}
