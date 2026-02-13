pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.Commons
import qs.Services.UI
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

    property bool      automation:           pluginApi?.pluginSettings?.automation           || false
    property list<int> automationCustomTime: pluginApi?.pluginSettings?.automationCustomTime || []
    property string    automationMode:       pluginApi?.pluginSettings?.automationMode       || pluginApi?.manifest?.metadata?.defaultSettings?.automationMode || ""
    property real      automationTime:       pluginApi?.pluginSettings?.automationTime       || pluginApi?.manifest?.metadata?.defaultSettings?.automationTime || 0


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
            id: timesLayout
            spacing: Style.marginS

            Repeater {
                model: [
                    5 * 60,
                    30 * 60,
                    60 * 60,
                    90 * 60,
                    120 * 60
                ]

                TimeButton {
                    required property var modelData
                    time: modelData
                }
            }

            NDivider {
                vertical: true
            }

            Repeater {
                id: customTimeRepeater
                model: root.automationCustomTime

                CustomTimeButton {
                    required property var modelData
                    time: modelData
                }
            }

            NIconButton {
                icon: "plus"
                tooltipText: root.pluginApi?.tr("settings.automation.time.custom.create.tooltip") || "Create a custom time."
                enabled: root.enabled && root.automation
                onClicked: createCustomTime.open();
            }

            component TimeButton: NButton {
                required property int time

                text: {
                    const hour = Math.floor(time / 3600.0);
                    const minute = Math.max(Math.floor(time / 60.0), 1) - (hour * 60);
                    const hourTranslation = root.pluginApi?.tr("settings.automation.time.h", {hour: hour}) || `${hour}h`;
                    const minuteTranslation = root.pluginApi?.tr("settings.automation.time.m", {minute: minute}) || `${minute}m`;

                    if (hour == 0) {
                        return minuteTranslation;
                    } else if (minute == 0) {
                        return hourTranslation;
                    } else {
                        return `${hourTranslation} ${minuteTranslation}`;
                    }
                }
                tooltipText: {
                    const hour = Math.floor(time / 3600.0);
                    const minute = Math.max(Math.floor(time / 60.0), 1) - (hour * 60);
                    const hourTranslation = root.pluginApi?.trp("settings.automation.time.hour", hour, "1 hour", "{count} hours") || "";
                    const minuteTranslation = root.pluginApi?.trp("settings.automation.time.minute", minute, "1 minute", "{count} minutes") || "";

                    if (hour == 0) {
                        return minuteTranslation;
                    } else if (minute == 0) {
                        return hourTranslation;
                    } else {
                        return `${hourTranslation} ${minuteTranslation}`;
                    }
                }
                enabled: root.enabled && root.automation
                onClicked: root.automationTime = time
                outlined: root.automationTime === time
            }

            component CustomTimeButton: TimeButton {
                id: timeButton

                onRightClicked: {
                    customTimeButtonMenu.selectedSeconds = time;
                    customTimeButtonMenu.openAtItem(timeButton, 0, timeButton.height);
                }
            }
        }
    }

    Popup {
        id: createCustomTime

        width: 400

        anchors.centerIn: Overlay.overlay
        padding: Style.marginL

        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Color.mSurfaceVariant
            radius: Style.iRadiusL
            border.color: Color.mOutline
            border.width: Style.borderS
        }

        function save() {
            // Check format of the text
            if (customTimeInput.isCorrectFormat()) {
                const times = customTimeInput.text.split(":");
                const hour = parseInt(times[0]);
                let minute = parseInt(times[1]);

                if (hour == 0) {
                    // Make sure that minute isn't 0
                    minute = Math.max(minute, 1);
                }

                const seconds = hour * 3600 + minute * 60;
                root.automationCustomTime.push(seconds);

                // Make sure no duplicates exist.
                let s = new Set(root.automationCustomTime);
                root.automationCustomTime = [...s];
                root.automationCustomTime.sort();

                // Reset the input
                customTimeInput.text = "";

                // Save the custom time to settings
                if (root.pluginApi == null) {
                    Logger.e("video-wallpaper", "Plugin API is null.");
                    return;
                }
                root.pluginApi.pluginSettings.automationCustomTime = root.automationCustomTime;
                root.pluginApi.saveSettings();

                createCustomTime.close();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Style.marginS

            NTextInput {
                id: customTimeInput
                label: root.pluginApi?.tr("settings.automation.time.custom.create.label") || "Add Custom Time"
                description: root.pluginApi?.tr("settings.automation.time.custom.create.description") || "Enter time as HH:MM, (e.g. 1:20)"
                placeholderText: root.pluginApi?.tr("settings.automation.time.custom.create.placeholder") || "Example, 1:15"
                Layout.fillWidth: true
                onEditingFinished: createCustomTime.save();

                function isCorrectFormat() {
                    // Check that : is included and that only one : is included
                    const times = customTimeInput.text.split(":");
                    if (times.length != 2) {
                        return false;
                    }

                    const isInteger = /^[0-9]+$/;
                    const isMinute = /^[0-5][0-9]$/;

                    // Check so that both sides are numbers and that the minute is in the range of [0-59]
                    if (!isInteger.test(times[0]) || !isInteger.test(times[1]) || !isMinute.test(times[1])) {
                        return false;
                    }

                    return true;
                }
            }

            RowLayout {
                spacing: Style.marginS
                layoutDirection: Qt.LeftToRight
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                NButton {
                    text: root.pluginApi?.tr("settings.automation.time.custom.create.cancel") || "Cancel"
                    onClicked: createCustomTime.close();
                }

                NButton {
                    text: root.pluginApi?.tr("settings.automation.time.custom.create.save") || "Save"
                    enabled: customTimeInput.isCorrectFormat();
                    onClicked: createCustomTime.save();
                }
            }
        }
    }

    NContextMenu {
        id: customTimeButtonMenu
        property int selectedSeconds: 0

        model: [
            {
                "label": root.pluginApi?.tr("settings.automation.time.custom.remove") || "Remove",
                "action": "remove",
                "icon": "x"
            },
        ]

        onTriggered: action => {
            close();

            switch(action) {
                case "remove":
                    const index = root.automationCustomTime.indexOf(selectedSeconds);
                    if(index !== -1) {
                        // Remove the element from the list
                        root.automationCustomTime.splice(index, 1);
                        root.pluginApi.pluginSettings.automationCustomTime = root.automationCustomTime;
                        root.pluginApi.saveSettings();
                    }
                    break;
                default:
                    Logger.e("video-wallpaper", "Error, action not found:", action);
            }
        }
    }

    Connections {
        target: root.pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.automation =           root.pluginApi?.pluginSettings?.automation           || false
            root.automationCustomTime = root.pluginApi?.pluginSettings?.automationCustomTime || []
            root.automationMode =       root.pluginApi?.pluginSettings?.automationMode       || root.pluginApi?.manifest?.metadata?.defaultSettings?.automationMode || ""
            root.automationTime =       root.pluginApi?.pluginSettings?.automationTime       || root.pluginApi?.manifest?.metadata?.defaultSettings?.automationTime || 0
        }
    }

    
    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if(pluginApi == null) {
            Logger.e("video-wallpaper", "Cannot save, pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.automation = automation;
        pluginApi.pluginSettings.automationCustomTime = automationCustomTime;
        pluginApi.pluginSettings.automationMode = automationMode;
        pluginApi.pluginSettings.automationTime = automationTime;
    }
}
