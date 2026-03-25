import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

QtObject {
    id: root

    property var pluginApi: null

    property var vpnList: []
    property real connectedCount: 0

    property var _pending: ({})

    // Needed only to detect disconnection not initiated by the user
    property var _pollTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    property var _lines: []

    property var _listProc: Process {
        command: ["nmcli", "-t", "-f", "NAME,TYPE,STATE,UUID", "connection", "show"]
        running: true

        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() !== "")
                    root._lines.push(line)
            }
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                const parsed = []
                const newPending = Object.assign({}, root._pending)
                for (const line of root._lines) {
                    const parts = line.split(":")
                    if (parts.length >= 4) {
                        const name  = parts[0]
                        const type  = parts[1]
                        const state = parts[2]
                        const uuid = parts[3]
                        if (type === "vpn" || type === "wireguard") {
                            if (newPending[uuid]) {
                                const wasConnecting = newPending[uuid] === "connect"
                                if (wasConnecting && state === "activated")
                                    delete newPending[uuid]
                                else if (!wasConnecting && state !== "activated")
                                    delete newPending[uuid]
                            }
                            parsed.push({
                                name,
                                type,
                                connected: state === "activated",
                                isLoading: !!newPending[uuid],
                                uuid
                            })
                        }
                    }
                }
                root._pending = newPending
                root.vpnList = parsed
                root.connectedCount = parsed.filter(v => v.connected).length
            }
            root._lines = []
        }
    }

    property var _connectProc: Process {
        property string targetName: ""
        property string targetUuid: ""
        command: ["nmcli", "connection", "up", "uuid", targetUuid]
        onExited: (exitCode) => {
            if (exitCode === 0)
                ToastService.showNotice(t("toast.connectedTo", { name: targetName }))
            else
                ToastService.showError(t("toast.connectionError", { name: targetName }))
            root.refresh()
        }
    }

    property var _disconnectProc: Process {
        property string targetName: ""
        property string targetUuid: ""
        command: ["nmcli", "connection", "down", "uuid", targetUuid]
        onExited: (exitCode) => {
            if (exitCode === 0)
                ToastService.showNotice(t("toast.disconnectedFrom", { name: targetName }))
            else
                ToastService.showError(t("toast.disconnectionError", { name: targetName }))
            root.refresh()
        }
    }

    property var _addProc: Process {
        property string targetType: ""

        command: ["nm-connection-editor", "--create", "--type", targetType]
        onExited: (exitCode) => {
            root.refresh();
        }
    }

    property var _editProc: Process {
        property string targetName: ""
        property string targetUuid: ""

        command: ["nm-connection-editor", "--edit", targetUuid]
        onExited: (exitCode) => {
            root.refresh();
        }
    }

    property var _removeProc: Process {
        property string targetName: ""
        property string targetUuid: ""

        command: ["nmcli", "connection", "delete", "uuid", targetUuid]
        onExited: (exitCode) => {
            if (exitCode === 0)
                ToastService.showNotice(t("toast.vpnRemoved", { "name": targetName }));
            else
                ToastService.showError(t("toast.vpnRemoveError", { "name": targetName }));
            root.refresh();
        }
    }

    function t(key: string, data) {
        if (!pluginApi)
            return null;

        return pluginApi.tr(key, data);
    }

    function refresh() {
        _listProc.running = true
    }

    function connectTo(uuid) {
        const p = Object.assign({}, _pending)
        p[uuid] = "connect"
        _pending = p
        let name = ""
        vpnList = vpnList.map(v => {
            if (v.uuid !== uuid) {
                return v
            }
            
            name = v.name
            return Object.assign({}, v, { isLoading: true })
        })
        _connectProc.targetName = name
        _connectProc.targetUuid = uuid
        _connectProc.running = true
    }

    function disconnectFrom(uuid) {
        const p = Object.assign({}, _pending)
        p[uuid] = "disconnect"
        _pending = p
        let name = ""
        vpnList = vpnList.map(v => {
            if (v.uuid !== uuid) {
                return v
            }
            
            name = v.name
            return Object.assign({}, v, { isLoading: true })
        })
        _disconnectProc.targetName = name
        _disconnectProc.targetUuid = uuid
        _disconnectProc.running = true
    }

    function addConnection(type) {
        _addProc.targetType = type || "vpn";
        _addProc.running = true;
    }

    function editConnection(uuid) {
        const vpn = vpnList.find((v) => {
            return v.uuid === uuid;
        });
        _editProc.targetName = vpn ? vpn.name : uuid;
        _editProc.targetUuid = uuid;
        _editProc.running = true;
    }

    function removeConnection(uuid) {
        const vpn = vpnList.find((v) => {
            return v.uuid === uuid;
        });
        _removeProc.targetName = vpn ? vpn.name : uuid;
        _removeProc.targetUuid = uuid;
        _removeProc.running = true;
    }

    Component.onCompleted: {
        Logger.i("NetworkManagerVPN", "Started")
    }
}
