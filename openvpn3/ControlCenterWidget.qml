import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Custom control-center button so we can use the OpenVPN brand icon
// (NIconButtonHot only accepts built-in icon names)
Item {
    id: root

    property ShellScreen screen
    property var pluginApi: null

    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property var main: pluginApi?.mainInstance ?? ({})
    readonly property real connectedCount: main.connectedCount ?? 0
    readonly property bool isLoading: main.isLoading ?? false
    readonly property int configCount: (main.configList ?? []).length
    readonly property bool hasConfigs: configCount > 0
    readonly property bool isConnected: connectedCount > 0
    readonly property var sessionList: main.sessionList ?? []
    readonly property string connectedColor: cfg.connectedColor ?? defaults.connectedColor ?? "primary"
    readonly property string disconnectedColor: cfg.disconnectedColor ?? defaults.disconnectedColor ?? "none"

    readonly property color iconColor: {
        const key = isConnected ? connectedColor : disconnectedColor
        if (!key || key === "none")
            return mouseArea.containsMouse ? Color.mOnHover : Color.mPrimary
        return Color.resolveColorKeyOptional(key) ?? Color.mPrimary
    }

    function tipText() {
        if (isLoading)
            return pluginApi?.tr("bar.connecting")
        if (!isConnected) {
            if (!hasConfigs)
                return pluginApi?.tr("bar.noConfigs")
            return pluginApi?.tr("bar.disconnected")
        }

        const list = sessionList
        if (!list || list.length === 0)
            return pluginApi?.tr("bar.tooltipDisconnected")

        const lines = []
        for (let i = 0; i < list.length; i++) {
            const s = list[i]
            const name = (s?.name && s.name.length > 0) ? s.name : (s?.sessionPath || "session")
            let statusLabel = pluginApi?.tr("status.connected")
            if (s?.isPaused)
                statusLabel = pluginApi?.tr("status.paused")
            else if (s?.status && s.status.length > 0)
                statusLabel = s.status
            lines.push(name)
        }
        return lines.join("\n")
    }

    implicitWidth: Style.baseWidgetSize
    implicitHeight: Style.baseWidgetSize

    Rectangle {
        anchors.fill: parent
        radius: Style.radiusM
        color: mouseArea.containsMouse ? Color.mHover : "transparent"

        OpenVpnIcon {
            anchors.centerIn: parent
            pointSize: Style.fontSizeXXL
            applyUiScale: false
            color: root.iconColor
            opacity: root.isLoading ? 0.5 : 1.0
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            TooltipService.hide()
            pluginApi?.togglePanel(screen, root)
        }
        onEntered: TooltipService.show(root, root.tipText())
        onExited: TooltipService.hide()
    }
}
