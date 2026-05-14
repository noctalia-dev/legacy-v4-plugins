import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property var main: pluginApi ? pluginApi.mainInstance : null
    readonly property bool active: main ? main.running : false
    readonly property string activeId: main ? main.activeServerId : ""
    readonly property var servers: main ? main.servers : []
    readonly property int latencyMs: main ? main.healthLatencyMs : -1
    readonly property string degraded: main ? main.healthStatus : "ok"
    readonly property bool showPing: main ? main.showPingInBar : true
    readonly property bool showTraffic: main ? main.showTrafficInBar : false

    readonly property string serverName: {
        if (!active) return ""
        const list = servers || []
        for (let i = 0; i < list.length; ++i)
            if (list[i].id === activeId) return list[i].name || ""
        return ""
    }

    readonly property color tintColor: {
        if (!active) return Color.mOnSurfaceVariant
        if (degraded === "failed" || degraded === "error") return Color.mError
        if (degraded === "degraded") return Color.mSecondary
        return Color.mPrimary
    }

    implicitWidth: row.implicitWidth + Style.margin2M
    implicitHeight: parent ? parent.height : Style.barHeight

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Style.marginS

        NIcon {
            icon: root.active ? "lock" : "lock-open"
            color: root.tintColor
            pointSize: Style.fontSizeM

            Behavior on color { ColorAnimation { duration: Style.animationFast } }
        }

        NText {
            text: root.active
                  ? (root.serverName.length ? root.serverName : "VPN")
                  : "VPN"
            color: root.tintColor
            pointSize: Style.barFontSize !== undefined ? Style.barFontSize : Style.fontSizeM

            Behavior on color { ColorAnimation { duration: Style.animationFast } }
        }

        // Ping pip: small dot + ms when running and we have a latency
        Item {
            visible: root.showPing && root.active && root.latencyMs > 0
            Layout.preferredWidth: pingRow.implicitWidth
            Layout.preferredHeight: pingRow.implicitHeight

            RowLayout {
                id: pingRow
                anchors.centerIn: parent
                spacing: Style.marginXXS

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: root.main ? root.main.pingColor(root.latencyMs) : Color.mPrimary
                }
                NText {
                    text: root.latencyMs + "ms"
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    font.family: "JetBrains Mono, monospace"
                }
            }
        }

        // Traffic speed: down/up in compact form
        NText {
            visible: root.showTraffic && root.active && root.main !== null
            text: root.main
                  ? "↓ " + root.main.formatBytes(root.main.trafficRecv)
                    + " ↑ " + root.main.formatBytes(root.main.trafficSent)
                  : ""
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
            font.family: "JetBrains Mono, monospace"
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (pluginApi) pluginApi.openPanel(root.screen, root)
    }
}
