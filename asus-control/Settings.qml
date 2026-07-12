import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string editIconColor: cfg.iconColor ?? defaults.iconColor ?? "none"
    property bool editPollingEnabled: cfg.pollingEnabled ?? defaults.pollingEnabled ?? false
    property int editPollingIntervalMs: cfg.pollingIntervalMs ?? defaults.pollingIntervalMs ?? 5000
    property bool editSyncPowerProfiles: cfg.syncPowerProfiles ?? defaults.syncPowerProfiles ?? true
    property bool editSyncAuraColor: cfg.syncAuraColor ?? defaults.syncAuraColor ?? false
    property string editAuraColorSource: cfg.auraColorSource ?? defaults.auraColorSource ?? "primary"

    spacing: Style.marginL

    // Status section
    NText {
        Layout.fillWidth: true
        text: {
            var main = pluginApi?.mainInstance;
            if (!main || !main.isAvailable) {
                return pluginApi?.tr("settings.not-available") || "asusctl is not installed or not in PATH.";
            }
            return (pluginApi?.tr("settings.detected") || "Detected:") + " " +
                   main.asusctlVersion + " — " + main.productFamily + " (" + main.boardName + ")";
        }
        pointSize: Style.fontSizeM
        color: (pluginApi?.mainInstance?.isAvailable ?? false) ? Color.mOnSurface : Color.mError
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Color.mOutline
        opacity: 0.3
    }

    NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.iconColor.label") || "Icon Color"
        description: pluginApi?.tr("settings.iconColor.desc") || "Color of the bar widget icon."
        model: [
            { "key": "none", "name": "Default" },
            { "key": "primary", "name": "Primary" },
            { "key": "secondary", "name": "Secondary" },
            { "key": "tertiary", "name": "Tertiary" },
            { "key": "error", "name": "Error" }
        ]
        currentKey: root.editIconColor
        onSelected: key => root.editIconColor = key
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.pollingEnabled.label") || "Polling"
        description: pluginApi?.tr("settings.pollingEnabled.desc") || "Periodically poll asusctl for status updates."
        checked: root.editPollingEnabled
        onToggled: function(checked) {
            root.editPollingEnabled = checked;
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.editPollingEnabled
        spacing: 4

        NText {
            text: (pluginApi?.tr("settings.pollingInterval.label") || "Polling Interval") + ": " + root.editPollingIntervalMs + "ms"
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
        }

        NSlider {
            Layout.fillWidth: true
            from: 1000
            to: 30000
            stepSize: 500
            value: root.editPollingIntervalMs
            onMoved: root.editPollingIntervalMs = Math.round(value)
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.syncPowerProfiles.label") || "Sync Power Profiles"
        description: pluginApi?.tr("settings.syncPowerProfiles.desc") || "When you change an ASUS profile, also switch the Noctalia power profile (and vice versa)."
        checked: root.editSyncPowerProfiles
        onToggled: function(checked) {
            root.editSyncPowerProfiles = checked;
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.syncAuraColor.label") || "Sync Keyboard Color"
        description: pluginApi?.tr("settings.syncAuraColor.desc") || "Automatically set the keyboard aura color from the current Noctalia theme."
        checked: root.editSyncAuraColor
        onToggled: function(checked) {
            root.editSyncAuraColor = checked;
        }
    }

    NComboBox {
        Layout.fillWidth: true
        visible: root.editSyncAuraColor
        label: pluginApi?.tr("settings.auraColorSource.label") || "Color Source"
        description: pluginApi?.tr("settings.auraColorSource.desc") || "Which Noctalia theme color to apply to the keyboard."
        model: [
            { "key": "primary", "name": "Primary" },
            { "key": "secondary", "name": "Secondary" },
            { "key": "tertiary", "name": "Tertiary" }
        ]
        currentKey: root.editAuraColorSource
        onSelected: key => root.editAuraColorSource = key
    }

    Item { Layout.fillHeight: true }

    function saveSettings() {
        if (!pluginApi) return;
        pluginApi.pluginSettings.iconColor = root.editIconColor;
        pluginApi.pluginSettings.pollingEnabled = root.editPollingEnabled;
        pluginApi.pluginSettings.pollingIntervalMs = root.editPollingIntervalMs;
        pluginApi.pluginSettings.syncPowerProfiles = root.editSyncPowerProfiles;
        pluginApi.pluginSettings.syncAuraColor = root.editSyncAuraColor;
        pluginApi.pluginSettings.auraColorSource = root.editAuraColorSource;
        pluginApi.saveSettings();
    }
}
