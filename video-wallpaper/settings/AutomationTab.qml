pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginM
    Layout.fillWidth: true


    /***************************
    * PROPERTIES
    ***************************/
    required property var pluginApi
    required property bool enabled

    property bool   automation:     pluginApi.pluginSettings.automation     || false
    property string automationMode: pluginApi.pluginSettings.automationMode || "random"
    property real   automationTime: pluginApi.pluginSettings.automationTime || 5 * 60


    /***************************
    * COMPONENTS
    ***************************/
    // Automation Toggle
    NToggle {
        enabled: root.enabled
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.automation.toggle.label") || "Automation"
        description: root.pluginApi?.tr("settings.automation.toggle.description") || "Schedule automatic wallpaper change."
        checked: root.automation
        onToggled: checked => root.automation = checked
    }

    // Automation Mode
    NComboBox {
        enabled: root.enabled && root.automation
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.automation.mode.label") || "Change mode"
        description: root.pluginApi?.tr("settings.automation.mode.description") || "The mode to select the new wallpaper."
        defaultValue: "random"
        model: [
            {
                "key": "random",
                "name": root.pluginApi?.tr("settings.automation.mode.random") || "Random"
            },
            {
                "key": "alphabetically",
                "name": root.pluginApi?.tr("settings.automation.mode.alphabetically") || "Alphabetically"
            }
        ]
        currentKey: root.automationMode
        onSelected: key => root.automationMode = key
    }

    ColumnLayout {
        NLabel {
            enabled: root.enabled && root.automation
            label: root.pluginApi?.tr("settings.automation.time.label") || "Time"
            description: root.pluginApi?.tr("settings.automation.time.description") || "How long it should take to switch the wallpaper."
        }

        RowLayout {
            spacing: Style.marginS


            Repeater {
                model: [
                    {
                        "text": root.pluginApi?.tr("settings.automation.time.5m") || "5m",
                        "time": 5 * 60
                    },
                    {
                        "text": root.pluginApi?.tr("settings.automation.time.10m") || "10m",
                        "time": 10 * 60
                    },
                    {
                        "text": root.pluginApi?.tr("settings.automation.time.30m") || "30m",
                        "time": 30 * 60
                    },
                    {
                        "text": root.pluginApi?.tr("settings.automation.time.1h") || "1h",
                        "time": 60 * 60
                    },
                    {
                        "text": root.pluginApi?.tr("settings.automation.time.1h30m") || "1h 30m",
                        "time": 90 * 60
                    },
                    {
                        "text": root.pluginApi?.tr("settings.automation.time.2h") || "2h",
                        "time": 120 * 60
                    },
                ]

                NButton {
                    required property var modelData
                    enabled: root.enabled && root.automation

                    text: modelData.text
                    onClicked: root.automationTime = modelData.time
                    outlined: root.automationTime === modelData.time
                }
            }
        }
    }

    Connections {
        target: root.pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.automation = root.pluginApi?.pluginSettings?.automation || false
            root.automationMode = root.pluginApi?.pluginSettings?.automationMode || "random"
            root.automationTime = root.pluginApi?.pluginSettings?.automationTime || 60
        }
    }

    
    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if(!pluginApi) {
            Logger.e("video-wallpaper", "Cannot save, pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.automation = automation;
        pluginApi.pluginSettings.automationMode = automationMode;
        pluginApi.pluginSettings.automationTime = automationTime;
    }
}
