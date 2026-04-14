import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginM

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    // Edit copies
    property string editServerUrl: cfg.serverUrl ?? defaults.serverUrl ?? "https://ntfy.sh"
    property string editTopics: cfg.topics ?? defaults.topics ?? ""
    property string editAuthMethod: cfg.authMethod ?? defaults.authMethod ?? "none"
    property string editAuthToken: cfg.authToken ?? defaults.authToken ?? ""
    property string editAuthUsername: cfg.authUsername ?? defaults.authUsername ?? ""
    property string editAuthPassword: cfg.authPassword ?? defaults.authPassword ?? ""
    property int editPollInterval: cfg.pollInterval ?? defaults.pollInterval ?? 30
    property bool editEnableToasts: cfg.enableToasts ?? defaults.enableToasts ?? true
    property int editMaxMessages: cfg.maxMessages ?? defaults.maxMessages ?? 100

    function saveSettings() {
        if (!pluginApi) return;
        pluginApi.pluginSettings.serverUrl = editServerUrl;
        pluginApi.pluginSettings.topics = editTopics;
        pluginApi.pluginSettings.authMethod = editAuthMethod;
        pluginApi.pluginSettings.authToken = editAuthToken;
        pluginApi.pluginSettings.authUsername = editAuthUsername;
        pluginApi.pluginSettings.authPassword = editAuthPassword;
        pluginApi.pluginSettings.pollInterval = editPollInterval;
        pluginApi.pluginSettings.enableToasts = editEnableToasts;
        pluginApi.pluginSettings.maxMessages = editMaxMessages;
        pluginApi.saveSettings();
    }

    // --- Server URL ---
    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.server.label")
        description: pluginApi?.tr("settings.server.desc")
        text: root.editServerUrl
        onEditingFinished: {
            root.editServerUrl = text;
            root.saveSettings();
        }
    }

    // --- Topics ---
    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.topics.label")
        description: pluginApi?.tr("settings.topics.desc")
        text: root.editTopics
        onEditingFinished: {
            root.editTopics = text;
            root.saveSettings();
        }
    }

    // --- Auth Method ---
    NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.auth.label")
        description: pluginApi?.tr("settings.auth.desc")
        minimumWidth: 200
        model: [
            { "key": "none", "name": pluginApi?.tr("settings.auth.none") },
            { "key": "token", "name": pluginApi?.tr("settings.auth.token") },
            { "key": "basic", "name": pluginApi?.tr("settings.auth.basic") }
        ]
        currentKey: root.editAuthMethod
        onSelected: key => {
            root.editAuthMethod = key;
            root.saveSettings();
        }
    }

    // --- Token (visible when auth = token) ---
    NTextInput {
        Layout.fillWidth: true
        visible: root.editAuthMethod === "token"
        label: pluginApi?.tr("settings.token.label")
        description: pluginApi?.tr("settings.token.desc")
        text: root.editAuthToken
        onEditingFinished: {
            root.editAuthToken = text;
            root.saveSettings();
        }
    }

    // --- Username (visible when auth = basic) ---
    NTextInput {
        Layout.fillWidth: true
        visible: root.editAuthMethod === "basic"
        label: pluginApi?.tr("settings.username.label")
        description: pluginApi?.tr("settings.username.desc")
        text: root.editAuthUsername
        onEditingFinished: {
            root.editAuthUsername = text;
            root.saveSettings();
        }
    }

    // --- Password (visible when auth = basic) ---
    NTextInput {
        Layout.fillWidth: true
        visible: root.editAuthMethod === "basic"
        label: pluginApi?.tr("settings.password.label")
        description: pluginApi?.tr("settings.password.desc")
        text: root.editAuthPassword
        onEditingFinished: {
            root.editAuthPassword = text;
            root.saveSettings();
        }
    }

    // --- Poll Interval ---
    NSpinBox {
        label: pluginApi?.tr("settings.pollInterval.label")
        description: pluginApi?.tr("settings.pollInterval.desc")
        from: 15
        to: 3600
        stepSize: 15
        value: root.editPollInterval
        onValueChanged: {
            root.editPollInterval = value;
            root.saveSettings();
        }
    }

    // --- Enable Toasts ---
    NToggle {
        label: pluginApi?.tr("settings.enableToasts.label")
        description: pluginApi?.tr("settings.enableToasts.desc")
        checked: root.editEnableToasts
        onCheckedChanged: {
            root.editEnableToasts = checked;
            root.saveSettings();
        }
    }

    // --- Max Messages ---
    NSpinBox {
        label: pluginApi?.tr("settings.maxMessages.label")
        description: pluginApi?.tr("settings.maxMessages.desc")
        from: 10
        to: 500
        stepSize: 10
        value: root.editMaxMessages
        onValueChanged: {
            root.editMaxMessages = value;
            root.saveSettings();
        }
    }
}
