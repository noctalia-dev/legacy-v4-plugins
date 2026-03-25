import QtQuick
import QtQuick.Layouts

import Quickshell

import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginM
    Layout.fillWidth: true


    /***************************
    * PROPERTIES
    ***************************/
    // Required properties
    required property var    pluginApi
    required property bool   enabled
    required property string selectedMonitor

    // Monitor specific properties
    property bool   hardwareAcceleration: pluginApi?.pluginSettings?.[selectedMonitor]?.hardwareAcceleration ?? false
    property string profile:              pluginApi?.pluginSettings?.[selectedMonitor]?.profile              ?? pluginApi?.manifest?.metadata?.defaultSettings?.profile ?? ""

    // Global properties
    property string mpvSocket: pluginApi?.pluginSettings?.mpvSocket ?? pluginApi?.manifest?.metadata?.defaultSettings?.mpvSocket ?? ""

    // Signals
    signal saveMonitorProperty(key: string, value: var);


    /***************************
    * EVENTS
    ***************************/
    onSelectedMonitorChanged: {
        hardwareAcceleration = pluginApi?.pluginSettings?.[selectedMonitor]?.hardwareAcceleration ?? false
        profile =              pluginApi?.pluginSettings?.[selectedMonitor]?.profile              ?? pluginApi?.manifest?.metadata?.defaultSettings?.profile ?? ""
    }


    /***************************
    * COMPONENTS
    ***************************/
    // Profile
    NComboBox {
        enabled: root.enabled
        Layout.fillWidth: true
        label:       root.pluginApi?.tr("settings.advanced.profile.label")
        description: root.pluginApi?.tr("settings.advanced.profile.description")
        defaultValue: "default"
        model: [
            {
                "key": "default",
                "name": root.pluginApi?.tr("settings.advanced.profile.default")
            },
            {
                "key": "fast",
                "name": root.pluginApi?.tr("settings.advanced.profile.fast")
            },
            {
                "key": "high-quality",
                "name": root.pluginApi?.tr("settings.advanced.profile.high_quality")
            },
            {
                "key": "low-latency",
                "name": root.pluginApi?.tr("settings.advanced.profile.low_latency")
            }
        ]
        currentKey: root.profile
        onSelected: key => root.profile = key
    }

    // Hardware Acceleration
    NToggle {
        enabled: root.enabled
        Layout.fillWidth: true
        label:       root.pluginApi?.tr("settings.advanced.hardware_acceleration.label")
        description: root.pluginApi?.tr("settings.advanced.hardware_acceleration.description")
        checked: root.hardwareAcceleration
        onToggled: checked => root.hardwareAcceleration = checked
        defaultValue: false
    }

    // MPV Socket path
    NTextInput {
        enabled: root.enabled
        Layout.fillWidth: true
        label:           root.pluginApi?.tr("settings.advanced.mpv_socket.label")
        description:     root.pluginApi?.tr("settings.advanced.mpv_socket.description")
        placeholderText: root.pluginApi?.tr("settings.advanced.mpv_socket.input_placeholder")
        text: root.mpvSocket
        onTextChanged: root.mpvSocket = text
    }

    Connections {
        target: root.pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.hardwareAcceleration = root.pluginApi?.pluginSettings?.[root.selectedMonitor]?.hardwareAcceleration ?? false
            root.mpvSocket =            root.pluginApi?.pluginSettings?.mpvSocket                                    ?? root.pluginApi?.manifest?.metadata?.defaultSettings?.mpvSocket ?? ""
            root.profile =              root.pluginApi?.pluginSettings?.[root.selectedMonitor]?.profile              ?? root.pluginApi?.manifest?.metadata?.defaultSettings?.profile   ?? ""
        }
    }


    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if(pluginApi == null) {
            Logger.e("video-wallpaper", "Cannot save: pluginApi is null");
            return;
        }

        root.saveMonitorProperty("hardwareAcceleration", hardwareAcceleration);
        root.saveMonitorProperty("profile", profile);

        pluginApi.pluginSettings.mpvSocket = mpvSocket;
    }
}
