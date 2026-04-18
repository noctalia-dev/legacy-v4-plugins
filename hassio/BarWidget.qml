import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    property var main: pluginApi?.mainInstance ?? null

    // "Connected"     - authenticated and live
    // "Connecting"    - socket opening or authenticating (first attempt or after settings change)
    // "Disconnected"  - dropped after a successful connection; reconnect backoff in progress
    // "Unconfigured"  - no token set, nothing to attempt
    // "AuthFailed"    - token rejected by HA
    readonly property string _status: {
        if (!root.main)
            return "Unconfigured";
        if (root.main.haToken === "")
            return "Unconfigured";
        if (root.main.authFailed)
            return "AuthFailed";
        if (root.main.authenticated)
            return "Connected";
        // Not yet authenticated - distinguish first-time connect from a drop-and-retry
        if (root.main.isReconnecting)
            return "Disconnected";
        return "Connecting";
    }

    readonly property string _statusLabel: {
        switch (root._status) {
        case "Connected":
            return pluginApi?.tr("widget.status_connected");
        case "Disconnected":
            return pluginApi?.tr("widget.status_disconnected");
        case "Connecting":
            return pluginApi?.tr("widget.status_connecting");
        case "AuthFailed":
            return pluginApi?.tr("widget.status_auth_failed");
        case "Unconfigured":
            return pluginApi?.tr("widget.status_unconfigured");
        default:
            return pluginApi?.tr("widget.status_unconfigured");
        }
    }

    icon: "smart-home"
    colorFg: {
        switch (root._status) {
        case "Connected":
            return Color.mPrimary;
        case "Connecting":
            return Color.mOnError;
        case "Disconnected":
            return Color.mError;
        case "AuthFailed":
            return Color.mError;
        case "Unconfigured":
            return Color.mOnSurfaceVariant;
        default:
            return Color.mOnSurfaceVariant;
        }
    }

    colorBg: Color.mSurfaceVariant
    colorBgHover: Color.mHover
    colorFgHover: Color.mOnHover
    colorBorder: "transparent"
    colorBorderHover: "transparent"

    onClicked: pluginApi.togglePanel(root.screen, this)

    tooltipText: pluginApi?.tr("widget.tooltip", {
        status: root._statusLabel
    })

    implicitHeight: Style.barHeight

    // Pulse only when actively trying to connect (token present, socket live, not yet authed)
    SequentialAnimation on opacity {
        running: root._status === "Connecting"
        loops: Animation.Infinite
        NumberAnimation {
            to: 0.3
            duration: 600
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 1.0
            duration: 600
            easing.type: Easing.InOutSine
        }
    }

    // Snap back to full opacity when not connecting
    opacity: root._status !== "Connecting" ? 1.0 : opacity
}
