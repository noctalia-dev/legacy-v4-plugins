import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null
    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string editDisplayMode: cfg.displayMode ?? defaults.displayMode ?? "onhover"
    property string editConnectedColor: cfg.connectedColor ?? defaults.connectedColor ?? "primary"
    property string editDisconnectedColor: cfg.disconnectedColor ?? defaults.disconnectedColor ?? "none"
    property int editPollInterval: cfg.pollInterval ?? defaults.pollInterval ?? 5
    property bool editShowNotifications: cfg.showNotifications ?? defaults.showNotifications ?? true
    property bool editDefaultPersistent: cfg.defaultPersistent ?? defaults.defaultPersistent ?? true
    property bool editHideWhenInactive: cfg.hideWhenInactive ?? defaults.hideWhenInactive ?? false

    readonly property var displayModeModel: [{
        "key": "onhover",
        "name": pluginApi?.tr("settings.displayMode.onhover")
    }, {
        "key": "alwaysShow",
        "name": pluginApi?.tr("settings.displayMode.alwaysShow")
    }, {
        "key": "alwaysHide",
        "name": pluginApi?.tr("settings.displayMode.alwaysHide")
    }]

    readonly property var pollIntervalModel: [{
        "key": "2",
        "name": pluginApi?.tr("settings.pollInterval.2s")
    }, {
        "key": "5",
        "name": pluginApi?.tr("settings.pollInterval.5s")
    }, {
        "key": "10",
        "name": pluginApi?.tr("settings.pollInterval.10s")
    }, {
        "key": "30",
        "name": pluginApi?.tr("settings.pollInterval.30s")
    }]

    function saveSettings() {
        pluginApi.pluginSettings.displayMode = root.editDisplayMode
        pluginApi.pluginSettings.connectedColor = root.editConnectedColor
        pluginApi.pluginSettings.disconnectedColor = root.editDisconnectedColor
        pluginApi.pluginSettings.pollInterval = root.editPollInterval
        pluginApi.pluginSettings.showNotifications = root.editShowNotifications
        pluginApi.pluginSettings.defaultPersistent = root.editDefaultPersistent
        pluginApi.pluginSettings.hideWhenInactive = root.editHideWhenInactive
        pluginApi.saveSettings()
        Logger.i("OpenVPN3", "Settings saved")
    }

    NLabel {
        label: pluginApi?.tr("settings.bar.label")
        description: pluginApi?.tr("settings.bar.description")
        Layout.fillWidth: true
    }

    NComboBox {
        label: pluginApi?.tr("settings.displayMode.label")
        description: pluginApi?.tr("settings.displayMode.description")
        minimumWidth: 200
        model: root.displayModeModel
        currentKey: root.editDisplayMode
        onSelected: (key) => root.editDisplayMode = key
    }

    NLabel {
        label: pluginApi?.tr("settings.colors.label")
        description: pluginApi?.tr("settings.colors.description")
        Layout.fillWidth: true
    }

    NColorChoice {
        label: pluginApi?.tr("settings.colors.connected.label")
        description: pluginApi?.tr("settings.colors.connected.description")
        currentKey: root.editConnectedColor
        onSelected: (key) => root.editConnectedColor = key
    }

    NColorChoice {
        label: pluginApi?.tr("settings.colors.disconnected.label")
        description: pluginApi?.tr("settings.colors.disconnected.description")
        currentKey: root.editDisconnectedColor
        onSelected: (key) => root.editDisconnectedColor = key
    }

    NLabel {
        label: pluginApi?.tr("settings.behavior.label")
        description: pluginApi?.tr("settings.behavior.description")
        Layout.fillWidth: true
    }

    NComboBox {
        label: pluginApi?.tr("settings.pollInterval.label")
        description: pluginApi?.tr("settings.pollInterval.description")
        minimumWidth: 200
        model: root.pollIntervalModel
        currentKey: String(root.editPollInterval)
        defaultValue: "5"
        onSelected: (key) => root.editPollInterval = parseInt(key)
    }

    NToggle {
        label: pluginApi?.tr("settings.showNotifications.label")
        description: pluginApi?.tr("settings.showNotifications.description")
        checked: root.editShowNotifications
        onToggled: root.editShowNotifications = checked
    }

    NToggle {
        label: pluginApi?.tr("settings.defaultPersistent.label")
        description: pluginApi?.tr("settings.defaultPersistent.description")
        checked: root.editDefaultPersistent
        onToggled: root.editDefaultPersistent = checked
    }

    NToggle {
        label: pluginApi?.tr("settings.hideWhenInactive.label")
        description: pluginApi?.tr("settings.hideWhenInactive.description")
        checked: root.editHideWhenInactive
        onToggled: root.editHideWhenInactive = checked
    }
}