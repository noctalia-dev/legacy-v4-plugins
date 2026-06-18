import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property int valueRefreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 5000
    property string iconColor: cfg.iconColor ?? defaults.iconColor ?? "none"
    property string statusState: cfg.statusState ?? defaults.statusState ?? "all"
    property string activeColor: cfg.activeColor ?? defaults.activeColor ?? "success"
    property string inactiveColor: cfg.inactiveColor ?? defaults.inactiveColor ?? "error"

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("MiniDocker", "Cannot save settings: pluginApi is null");
            return ;
        }
        pluginApi.pluginSettings.refreshInterval = root.valueRefreshInterval;
        pluginApi.pluginSettings.iconColor = root.iconColor;
        pluginApi.pluginSettings.statusState = root.statusState;
        pluginApi.pluginSettings.activeColor = root.activeColor;
        pluginApi.pluginSettings.inactiveColor = root.inactiveColor;
        pluginApi.saveSettings();
        Logger.i("MiniDocker", "Settings saved successfully");
    }

    spacing: Style.marginM
    Component.onCompleted: {
        Logger.i("MiniDocker", "Settings UI loaded");
    }

    ListModel {
        id: intervalModel

        ListElement {
            name: "1 Second"
            key: "1000"
        }

        ListElement {
            name: "5 Seconds"
            key: "5000"
        }

        ListElement {
            name: "10 Seconds"
            key: "10000"
        }

        ListElement {
            name: "30 Seconds"
            key: "30000"
        }

    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: (pluginApi && pluginApi.tr) ? pluginApi.tr("settings.refresh_interval_label") : "Refresh Interval"
            description: (pluginApi && pluginApi.tr) ? pluginApi.tr("settings.refresh_interval_description") : "How often the plugin checks for container status changes"
        }

        NComboBox {
            Layout.fillWidth: true
            model: intervalModel
            currentKey: root.valueRefreshInterval.toString()
            onSelected: {
                root.valueRefreshInterval = parseInt(key);
            }
        }

        Text {
            text: ((pluginApi && pluginApi.tr) ? pluginApi.tr("settings.current_value") : "Selected: {value} ms").replace("{value}", root.valueRefreshInterval)
            color: Color.mOnSurfaceVariant
            font.pointSize: Style.fontSizeS
        }

    }

    NColorChoice {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.icon_color_label")
        description: pluginApi?.tr("settings.icon_color_description")
        currentKey: root.iconColor
        onSelected: key => root.iconColor = key
    }

    NColorChoice {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.active_color_label")
        description: pluginApi?.tr("settings.active_color_description")
        currentKey: root.activeColor
        onSelected: key => root.activeColor = key
    }

    NColorChoice {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.inactive_color_label")
        description: pluginApi?.tr("settings.inactive_color_description")
        currentKey: root.inactiveColor
        onSelected: key => root.inactiveColor = key
    }

    NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.status_state_label")
        description: pluginApi?.tr("settings.status_state_description")
        model: [
            {
                "key": "all",
                "name": pluginApi?.tr("settings.status_state_always")
            },
            {
                "key": "running-only",
                "name": pluginApi?.tr("settings.status_state_running_only")
            },
            {
                "key": "hidden",
                "name": pluginApi?.tr("settings.status_state_hidden")
            }
        ]
        currentKey: root.statusState
        onSelected: key => root.statusState = key
    }

}
