import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var cfg: pluginApi?.pluginSettings
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings
    property var pluginApi: null
    property string valuePlatform: cfg.platform ?? defaults.platform
    property string valueRepo: cfg.repo ?? defaults.repo ?? ""
    property string valueGroup: cfg.group ?? defaults.group ?? ""
    property int valueRefreshInterval: cfg.refreshInterval ?? defaults.refreshInterval

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("Git Companion", "Cannot save settings: pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.platform = root.valuePlatform;
        pluginApi.pluginSettings.repo = root.valueRepo;
        pluginApi.pluginSettings.group = root.valueGroup;
        pluginApi.pluginSettings.refreshInterval = root.valueRefreshInterval;
        pluginApi.saveSettings();

        Logger.d("Git Companion", "Settings saved successfully");
    }

    spacing: Style.marginL

    Component.onCompleted: {
        Logger.d("Git Companion", "Settings UI loaded");
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NComboBox {
            currentKey: root.valuePlatform
            description: pluginApi?.tr("settings.platform.desc")
            label: pluginApi?.tr("settings.platform.label")
            model: [
                {
                    "key": "github",
                    "name": "GitHub"
                },
                {
                    "key": "gitlab",
                    "name": "GitLab"
                }
            ]

            onSelected: key => {
                root.valuePlatform = key;
                pluginApi.pluginSettings.platform = key;
                pluginApi.saveSettings();
            }
        }
        NTextInput {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.repo.label")
            description: pluginApi?.tr("settings.repo.desc")
            placeholderText: "owner/repo"
            text: root.valueRepo

            onTextChanged: {
                root.valueRepo = text;
                pluginApi.pluginSettings.repo = text;
                pluginApi.saveSettings();
            }
        }
        NTextInput {
            Layout.fillWidth: true
            label: pluginApi?.tr(root.valuePlatform === 'gitlab' ? "settings.group.label" : "settings.org.label")
            description: pluginApi?.tr(root.valuePlatform === 'gitlab' ? "settings.group.desc" : "settings.org.desc")
            placeholderText: root.valuePlatform === 'gitlab' ? "my-group" : "my-org"
            text: root.valueGroup

            onTextChanged: {
                root.valueGroup = text;
                pluginApi.pluginSettings.group = text;
                pluginApi.saveSettings();
            }
        }
        NSpinBox {
            description: pluginApi?.tr("settings.refreshInterval.desc")
            label: pluginApi?.tr("settings.refreshInterval.label")
            stepSize: 1
            from: 30
            to: 90
            value: root.valueRefreshInterval

            onValueChanged: {
                root.valueRefreshInterval = value;
                pluginApi.pluginSettings.refreshInterval = value;
                pluginApi.saveSettings();
            }
        }
    }
}
