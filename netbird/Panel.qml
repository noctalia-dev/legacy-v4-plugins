import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    readonly property var mainInstance: pluginApi?.mainInstance

    function copyToClipboard(text) {
        var escaped = text.replace(/'/g, "'\\''");
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"]);
    }

    property var selectedPeer: null
    property var selectedPeerDelegate: null

    function openPeerContextMenu(peer, delegate, mouseX, mouseY) {
        selectedPeer = peer;
        selectedPeerDelegate = delegate;
        peerContextMenu.openAtItem(delegate, mouseX, mouseY);
    }

    function getHostname(peer) {
        if (!peer)
            return "Unknown";
        if (peer.fqdn) {
            var parts = peer.fqdn.split(".");
            if (parts.length > 0)
                return parts[0];
        }
        return peer.netbirdIp || "Unknown";
    }

    function getConnectionIcon(connType) {
        if (!connType)
            return "circle-check";
        switch (connType.toLowerCase()) {
        case "p2p":
            return "arrows-exchange";
        case "relayed":
            return "cloud";
        default:
            return "circle-check";
        }
    }

    function requireTerminal() {
        if (!isTerminalConfigured) {
            ToastService.showError(pluginApi?.tr("toast.terminal-not-configured.title") || "Terminal Not Configured", pluginApi?.tr("toast.terminal-not-configured.message") || "Please set a terminal command in plugin settings", "alert-circle");
            return false;
        }
        return true;
    }

    function copySelectedPeerIp() {
        if (selectedPeer && selectedPeer.netbirdIp) {
            copyToClipboard(selectedPeer.netbirdIp);
            ToastService.showNotice(pluginApi?.tr("toast.ip-copied.title") || "IP Copied", selectedPeer.netbirdIp, "clipboard");
        }
    }

    function sshToSelectedPeer() {
        if (!requireTerminal())
            return;
        if (selectedPeer && selectedPeer.netbirdIp) {
            Quickshell.execDetached([root.terminalCommand, "-e", "ssh", selectedPeer.netbirdIp]);
        }
    }

    function pingSelectedPeer() {
        if (!requireTerminal())
            return;
        if (selectedPeer && selectedPeer.netbirdIp) {
            Quickshell.execDetached([root.terminalCommand, "-e", "ping", "-c", root.pingCount.toString(), selectedPeer.netbirdIp]);
        }
    }

    function executePeerAction(action, peer) {
        selectedPeer = peer;
        switch (action) {
        case "copy-ip":
            copySelectedPeerIp();
            break;
        case "ssh":
            sshToSelectedPeer();
            break;
        case "ping":
            pingSelectedPeer();
            break;
        }
    }

    NContextMenu {
        id: peerContextMenu
        model: [
            {
                label: pluginApi?.tr("context.copy-ip") || "Copy IP",
                action: "copy-ip",
                icon: "clipboard"
            },
            {
                label: pluginApi?.tr("context.ssh") || "SSH to host",
                action: "ssh",
                icon: "terminal",
                enabled: (root.selectedPeer?.status === "Connected" || false) && root.isTerminalConfigured
            },
            {
                label: pluginApi?.tr("context.ping") || "Ping host",
                action: "ping",
                icon: "activity",
                enabled: root.isTerminalConfigured
            }
        ]
        onTriggered: function (action) {
            switch (action) {
            case "copy-ip":
                root.copySelectedPeerIp();
                break;
            case "ssh":
                root.sshToSelectedPeer();
                break;
            case "ping":
                root.pingSelectedPeer();
                break;
            }
        }
    }

    onPluginApiChanged: {
        if (pluginApi && pluginApi.mainInstance) {
            mainInstanceChanged();
        }
    }

    readonly property bool panelReady: pluginApi !== null && mainInstance !== null && mainInstance !== undefined

    readonly property bool hideDisconnected: pluginApi?.pluginSettings?.hideDisconnected ?? pluginApi?.manifest?.metadata?.defaultSettings?.hideDisconnected ?? false

    readonly property string terminalCommand: mainInstance?.detectedTerminal || ""

    readonly property int pingCount: pluginApi?.pluginSettings?.pingCount || pluginApi?.manifest?.metadata?.defaultSettings?.pingCount || 5

    readonly property string defaultPeerAction: pluginApi?.pluginSettings?.defaultPeerAction || pluginApi?.manifest?.metadata?.defaultSettings?.defaultPeerAction || "copy-ip"

    readonly property bool isTerminalConfigured: terminalCommand !== ""

    readonly property var sortedPeerList: {
        if (!mainInstance?.peerList)
            return [];
        var peers = mainInstance.peerList.slice();

        if (hideDisconnected) {
            peers = peers.filter(function (peer) {
                return peer.status === "Connected";
            });
        }

        peers.sort(function (a, b) {
            var aConnected = a.status === "Connected";
            var bConnected = b.status === "Connected";
            if (aConnected && !bConnected)
                return -1;
            if (!aConnected && bConnected)
                return 1;

            var nameA = getHostname(a).toLowerCase();
            var nameB = getHostname(b).toLowerCase();
            return nameA.localeCompare(nameB);
        });
        return peers;
    }

    property real contentPreferredWidth: panelReady ? 400 * Style.uiScaleRatio : 0
    property real contentPreferredHeight: panelReady ? Math.min(500, 100 + (mainInstance?.peerList?.length || 0) * 60) * Style.uiScaleRatio : 0

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"
        visible: panelReady

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginM
            }
            spacing: Style.marginL

            NBox {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM
                    clip: true

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        NIcon {
                            icon: "network"
                            pointSize: Style.fontSizeL
                            color: Color.mPrimary
                        }

                        NText {
                            text: pluginApi?.tr("panel.title") || "NetBird Network"
                            pointSize: Style.fontSizeL
                            font.weight: Style.fontWeightBold
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            text: mainInstance?.netbirdRunning ? (mainInstance?.peerConnected || 0) + "/" + (mainInstance?.peerCount || 0) + " " + (pluginApi?.tr("panel.peers") || "peers") : (pluginApi?.tr("panel.not-connected") || "Not connected")
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurfaceVariant
                        }
                    }

                    NText {
                        Layout.fillWidth: true
                        text: mainInstance?.netbirdIp || ""
                        visible: (mainInstance?.netbirdRunning ?? false) && (mainInstance?.netbirdIp ?? false)
                        pointSize: Style.fontSizeS
                        color: mainIpMouseArea.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
                        font.family: Settings.data.ui.fontFixed

                        MouseArea {
                            id: mainIpMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function () {
                                if (mainInstance?.netbirdIp) {
                                    root.copyToClipboard(mainInstance.netbirdIp);
                                    ToastService.showNotice(pluginApi?.tr("toast.ip-copied.title") || "IP Copied", mainInstance.netbirdIp, "clipboard");
                                }
                            }
                        }
                    }

                    NText {
                        Layout.fillWidth: true
                        text: mainInstance?.netbirdFqdn || ""
                        visible: (mainInstance?.netbirdRunning ?? false) && (mainInstance?.netbirdFqdn ?? false)
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        font.family: Settings.data.ui.fontFixed
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: connectionStatusLayout.implicitHeight + Style.marginS * 2
                        visible: (mainInstance?.netbirdRunning ?? false)
                        color: Qt.alpha(Color.mPrimary, 0.1)
                        radius: Style.radiusS
                        border.width: 1
                        border.color: Qt.alpha(Color.mPrimary, 0.3)

                        RowLayout {
                            id: connectionStatusLayout
                            anchors.fill: parent
                            anchors.margins: Style.marginS
                            spacing: Style.marginM

                            RowLayout {
                                spacing: Style.marginXS

                                NIcon {
                                    icon: "server"
                                    pointSize: Style.fontSizeXS
                                    color: (mainInstance?.managementConnected ?? false) ? Color.mPrimary : Color.mError
                                }

                                NText {
                                    text: pluginApi?.tr("panel.management") || "Management"
                                    pointSize: Style.fontSizeXS
                                    color: Color.mOnSurfaceVariant
                                }
                            }

                            RowLayout {
                                spacing: Style.marginXS

                                NIcon {
                                    icon: "antenna-bars-5"
                                    pointSize: Style.fontSizeXS
                                    color: (mainInstance?.signalConnected ?? false) ? Color.mPrimary : Color.mError
                                }

                                NText {
                                    text: pluginApi?.tr("panel.signal") || "Signal"
                                    pointSize: Style.fontSizeXS
                                    color: Color.mOnSurfaceVariant
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.alpha(Color.mOnSurface, 0.1)
                        visible: (mainInstance?.netbirdRunning ?? false) && (mainInstance?.peerList?.length ?? 0) > 0
                    }

                    Flickable {
                        id: peerFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: peerListColumn.height
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        pressDelay: 0

                        ColumnLayout {
                            id: peerListColumn
                            width: peerFlickable.width
                            spacing: Style.marginS

                            Repeater {
                                model: sortedPeerList

                                delegate: ItemDelegate {
                                    id: peerDelegate
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: peerFlickable.width
                                    implicitWidth: peerFlickable.width
                                    height: 48
                                    topPadding: Style.marginS
                                    bottomPadding: Style.marginS
                                    leftPadding: Style.marginL
                                    rightPadding: Style.marginL

                                    readonly property var peerData: modelData
                                    readonly property string peerIp: peerData.netbirdIp || ""
                                    readonly property string peerHostname: root.getHostname(peerData)
                                    readonly property bool peerConnected: peerData.status === "Connected"

                                    background: Rectangle {
                                        anchors.fill: parent
                                        color: peerDelegate.hovered ? Qt.alpha(Color.mPrimary, 0.1) : "transparent"
                                        radius: Style.radiusM
                                        border.width: peerDelegate.hovered ? 1 : 0
                                        border.color: Qt.alpha(Color.mPrimary, 0.3)
                                    }

                                    contentItem: RowLayout {
                                        spacing: Style.marginM

                                        NIcon {
                                            icon: root.getConnectionIcon(peerDelegate.peerData.connectionType)
                                            pointSize: Style.fontSizeM
                                            color: peerDelegate.peerConnected ? Color.mPrimary : Color.mOnSurfaceVariant
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            NText {
                                                text: peerDelegate.peerHostname
                                                color: Color.mOnSurface
                                                font.weight: Style.fontWeightMedium
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            NText {
                                                visible: peerDelegate.peerData.connectionType !== ""
                                                text: peerDelegate.peerData.connectionType || ""
                                                pointSize: Style.fontSizeXS
                                                color: Color.mOnSurfaceVariant
                                            }
                                        }

                                        ColumnLayout {
                                            visible: peerDelegate.peerIp !== ""
                                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                            spacing: 1

                                            NText {
                                                text: peerDelegate.peerIp
                                                pointSize: Style.fontSizeS
                                                color: Color.mOnSurfaceVariant
                                                font.family: Settings.data.ui.fontFixed
                                                Layout.alignment: Qt.AlignRight
                                            }

                                            NText {
                                                visible: (mainInstance?.showPing ?? false) && peerDelegate.peerConnected
                                                Layout.alignment: Qt.AlignRight
                                                pointSize: Style.fontSizeXS
                                                font.family: Settings.data.ui.fontFixed
                                                text: {
                                                    var pingVal = mainInstance?.peerPings?.[peerDelegate.peerIp] ?? "";
                                                    if (pingVal === "")
                                                        return "...";
                                                    if (pingVal === "timeout")
                                                        return "timeout";
                                                    return pingVal + " ms";
                                                }
                                                color: {
                                                    var pingVal = mainInstance?.peerPings?.[peerDelegate.peerIp] ?? "";
                                                    if (pingVal === "" || pingVal === "timeout")
                                                        return Color.mError;
                                                    var ms = parseFloat(pingVal);
                                                    if (ms < 50)
                                                        return Color.mPrimary;
                                                    if (ms < 150)
                                                        return Color.mWarning || "#FF9800";
                                                    return Color.mError;
                                                }
                                            }
                                        }
                                    }

                                    onClicked: {
                                        if (peerDelegate.peerIp) {
                                            root.executePeerAction(root.defaultPeerAction, peerDelegate.peerData);
                                        }
                                    }

                                    TapHandler {
                                        acceptedButtons: Qt.RightButton
                                        onTapped: root.openPeerContextMenu(peerDelegate.peerData, peerDelegate, point.position.x, point.position.y)
                                    }
                                }
                            }

                            NText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: Style.marginL
                                text: pluginApi?.tr("panel.no-peers") || "No connected peers"
                                visible: !(mainInstance?.netbirdRunning ?? false) || (mainInstance?.peerList?.length ?? 0) === 0
                                pointSize: Style.fontSizeM
                                color: Color.mOnSurfaceVariant
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }

            NButton {
                Layout.fillWidth: true
                visible: mainInstance?.netbirdRunning ?? false
                text: pluginApi?.tr("panel.admin-console") || "Admin Console"
                icon: "external-link"
                onClicked: {
                    Qt.openUrlExternally("https://app.netbird.io/");
                }
            }

            NButton {
                Layout.fillWidth: true
                text: mainInstance?.netbirdRunning ? (pluginApi?.tr("context.disconnect") || "Disconnect") : (pluginApi?.tr("context.connect") || "Connect")
                icon: mainInstance?.netbirdRunning ? "plug-x" : "plug"
                backgroundColor: mainInstance?.netbirdRunning ? Color.mError : Color.mPrimary
                textColor: mainInstance?.netbirdRunning ? Color.mOnError : Color.mOnPrimary
                enabled: mainInstance?.netbirdInstalled ?? false
                onClicked: {
                    if (mainInstance) {
                        mainInstance.toggleNetbird();
                    }
                }
            }
        }
    }
}
