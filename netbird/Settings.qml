import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property int editRefreshInterval: pluginApi?.pluginSettings?.refreshInterval || pluginApi?.manifest?.metadata?.defaultSettings?.refreshInterval || 5000

    property bool editCompactMode: pluginApi?.pluginSettings?.compactMode ?? pluginApi?.manifest?.metadata?.defaultSettings?.compactMode ?? false

    property bool editShowIpAddress: pluginApi?.pluginSettings?.showIpAddress ?? pluginApi?.manifest?.metadata?.defaultSettings?.showIpAddress ?? true

    property bool editHideDisconnected: pluginApi?.pluginSettings?.hideDisconnected ?? pluginApi?.manifest?.metadata?.defaultSettings?.hideDisconnected ?? false

    property bool editShowPing: pluginApi?.pluginSettings?.showPing ?? pluginApi?.manifest?.metadata?.defaultSettings?.showPing ?? false

    property int editPingCount: pluginApi?.pluginSettings?.pingCount || pluginApi?.manifest?.metadata?.defaultSettings?.pingCount || 5

    property string editDefaultPeerAction: pluginApi?.pluginSettings?.defaultPeerAction || pluginApi?.manifest?.metadata?.defaultSettings?.defaultPeerAction || "copy-ip"

    spacing: Style.marginM

    NText {
        text: pluginApi?.tr("settings.title") || "NetBird Settings"
        font.pointSize: Style.fontSizeXL
        font.bold: true
    }

    NText {
        text: pluginApi?.tr("settings.description") || "Configure NetBird VPN status display and behavior"
        color: Color.mSecondary
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        Layout.bottomMargin: Style.marginM
    }

    NLabel {
        label: pluginApi?.tr("settings.refresh-interval") || "Refresh Interval"
        description: (pluginApi?.tr("settings.refresh-interval-desc") || "How often to check NetBird status") + " (" + root.editRefreshInterval + " ms)"
    }

    NSlider {
        Layout.fillWidth: true
        from: 1000
        to: 60000
        stepSize: 1000
        value: root.editRefreshInterval
        onValueChanged: root.editRefreshInterval = value
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        Layout.bottomMargin: Style.marginM
    }

    NLabel {
        label: pluginApi?.tr("settings.display-options") || "Display Options"
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.compact-mode") || "Compact Mode"
        description: pluginApi?.tr("settings.compact-mode-desc") || "Show only icon in the bar"
        checked: root.editCompactMode
        onToggled: checked => {
            root.editCompactMode = checked;
            if (checked) {
                root.editShowIpAddress = false;
            }
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.show-ip") || "Show IP Address"
        description: pluginApi?.tr("settings.show-ip-desc") || "Display NetBird IP in the bar widget"
        checked: root.editShowIpAddress
        enabled: !root.editCompactMode
        onToggled: checked => {
            root.editShowIpAddress = checked;
            if (checked) {
                root.editCompactMode = false;
            } else {
                root.editCompactMode = true;
            }
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.hide-disconnected") || "Hide Disconnected Peers"
        description: pluginApi?.tr("settings.hide-disconnected-desc") || "Only show online peers in the panel"
        checked: root.editHideDisconnected
        onToggled: checked => root.editHideDisconnected = checked
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.show-ping") || "Show Ping Latency"
        description: pluginApi?.tr("settings.show-ping-desc") || "Ping all connected peers and display latency (ms). Refreshes at the same interval as status."
        checked: root.editShowPing
        onToggled: checked => root.editShowPing = checked
    }

    NText {
        visible: root.editShowPing
        Layout.fillWidth: true
        text: "⚠ " + (pluginApi?.tr("settings.show-ping-warning") || "This feature sends ICMP packets to each connected peer at every refresh interval. It may increase network usage and CPU load.")
        pointSize: Style.fontSizeXS
        color: Color.mError
        wrapMode: Text.Wrap
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        Layout.bottomMargin: Style.marginM
    }

    NLabel {
        label: pluginApi?.tr("settings.terminal") || "Terminal Configuration"
    }

    NText {
        Layout.fillWidth: true
        text: {
            var detected = pluginApi?.mainInstance?.detectedTerminal || "";
            if (detected !== "") {
                return (pluginApi?.tr("settings.terminal-detected") || "Auto-detected terminal") + ": " + detected;
            } else {
                return pluginApi?.tr("settings.terminal-none") || "No terminal emulator detected";
            }
        }
        color: {
            var detected = pluginApi?.mainInstance?.detectedTerminal || "";
            return detected !== "" ? Color.mPrimary : Color.mError;
        }
        pointSize: Style.fontSizeS
        wrapMode: Text.Wrap
    }

    NLabel {
        label: pluginApi?.tr("settings.ping-count") || "Ping Count"
        description: (pluginApi?.tr("settings.ping-count-desc") || "Number of ping packets to send when testing connectivity") + " (" + root.editPingCount + ")"
    }

    NSlider {
        Layout.fillWidth: true
        from: 1
        to: 20
        stepSize: 1
        value: root.editPingCount
        onValueChanged: root.editPingCount = value
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        Layout.bottomMargin: Style.marginM
    }

    NLabel {
        label: pluginApi?.tr("settings.peer-action") || "Peer Click Action"
    }

    NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.default-peer-action") || "Default Action"
        description: pluginApi?.tr("settings.default-peer-action-desc") || "Action when clicking on a peer in the panel"

        model: [
            {
                key: "copy-ip",
                name: pluginApi?.tr("context.copy-ip") || "Copy IP"
            },
            {
                key: "ssh",
                name: pluginApi?.tr("context.ssh") || "SSH to host"
            },
            {
                key: "ping",
                name: pluginApi?.tr("context.ping") || "Ping host"
            }
        ]

        currentKey: root.editDefaultPeerAction
        onSelected: key => root.editDefaultPeerAction = key
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("NetBird", "Cannot save: pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval;
        pluginApi.pluginSettings.compactMode = root.editCompactMode;
        pluginApi.pluginSettings.showIpAddress = root.editShowIpAddress;
        pluginApi.pluginSettings.hideDisconnected = root.editHideDisconnected;
        pluginApi.pluginSettings.showPing = root.editShowPing;
        pluginApi.pluginSettings.pingCount = root.editPingCount;
        pluginApi.pluginSettings.defaultPeerAction = root.editDefaultPeerAction;

        pluginApi.saveSettings();

        Logger.i("NetBird", "Settings saved successfully");
    }
}
