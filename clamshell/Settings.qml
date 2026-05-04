import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    readonly property var main: pluginApi ? pluginApi.mainInstance || ({}) : ({})
    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property bool editEnabled: cfg.enabled !== undefined
        ? cfg.enabled
        : (defaults.enabled !== undefined ? defaults.enabled : true)
    property bool editAlwaysShowBarWidget: cfg.alwaysShowBarWidget !== undefined
        ? cfg.alwaysShowBarWidget
        : (defaults.alwaysShowBarWidget !== undefined ? defaults.alwaysShowBarWidget : false)
    property bool editNotify: cfg.notify !== undefined
        ? cfg.notify
        : (defaults.notify !== undefined ? defaults.notify : true)
    property string editInternalConnectorRegex: cfg.internalConnectorRegex
        ?? defaults.internalConnectorRegex
        ?? "^(eDP|LVDS|DSI)"
    property string editInhibitorWho: cfg.inhibitorWho
        ?? defaults.inhibitorWho
        ?? "noctalia-clamshell"

    spacing: Style.marginL

    Component.onCompleted: {
        Logger.d("Clamshell", "Settings UI loaded");
    }

    ColumnLayout {
        spacing: Style.marginM
        Layout.fillWidth: true

        NToggle {
            label: pluginApi?.tr("settings.enabled") || "Enable clamshell mode"
            checked: root.editEnabled
            onToggled: checked => root.editEnabled = checked
        }

        NToggle {
            label: pluginApi?.tr("settings.alwaysShowBarWidget") || "Always show bar icon"
            checked: root.editAlwaysShowBarWidget
            onToggled: checked => root.editAlwaysShowBarWidget = checked
        }

        NToggle {
            label: pluginApi?.tr("settings.notify") || "Show notifications"
            checked: root.editNotify
            onToggled: checked => root.editNotify = checked
        }

        NTextInput {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.internalConnectorRegex") || "Internal connector pattern"
            placeholderText: "^(eDP|LVDS|DSI)"
            text: root.editInternalConnectorRegex
            onTextChanged: root.editInternalConnectorRegex = text
        }

        NTextInput {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.inhibitorWho") || "Inhibitor identifier"
            placeholderText: "noctalia-clamshell"
            text: root.editInhibitorWho
            onTextChanged: root.editInhibitorWho = text
        }
    }

    NText {
        visible: root.main.inhibitorAvailable === false
        Layout.fillWidth: true
        text: pluginApi?.tr("error.noInhibit") || "systemd-inhibit not found - plugin disabled"
        color: Color.mError
        pointSize: Style.fontSizeM
        wrapMode: Text.WordWrap
    }

    ColumnLayout {
        spacing: Style.marginS
        Layout.fillWidth: true

        NText {
            text: "Status"
            color: Color.mOnSurface
            pointSize: Style.fontSizeL
            font.weight: Font.DemiBold
        }

        NText {
            Layout.fillWidth: true
            text: "State: " + (root.main.stateLabel ? root.main.stateLabel() : "Unknown")
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
        }

        NText {
            Layout.fillWidth: true
            text: "Inhibitor PID: " + (root.main.inhibitorPid > 0 ? String(root.main.inhibitorPid) : "-")
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.main.outputs || []

            NText {
                Layout.fillWidth: true
                text: modelData.name + ": "
                    + (modelData.internal ? "internal" : "external")
                    + ", "
                    + (modelData.active ? "active" : (modelData.connected ? "connected" : "disconnected"))
                color: Color.mOnSurfaceVariant
                wrapMode: Text.WordWrap
            }
        }
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("Clamshell", "Cannot save settings: pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.enabled = root.editEnabled;
        pluginApi.pluginSettings.alwaysShowBarWidget = root.editAlwaysShowBarWidget;
        pluginApi.pluginSettings.notify = root.editNotify;
        pluginApi.pluginSettings.internalConnectorRegex = root.editInternalConnectorRegex;
        pluginApi.pluginSettings.inhibitorWho = root.editInhibitorWho;
        pluginApi.saveSettings();

        if (root.main.applySettings) {
            root.main.applySettings();
        }
        Logger.i("Clamshell", "Settings saved successfully");
    }
}
