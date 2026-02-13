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

    property bool   hardwareAcceleration: pluginApi?.pluginSettings?.hardwareAcceleration || false
    property string mpvSocket:            pluginApi?.pluginSettings?.mpvSocket            || pluginApi?.manifest?.metadata?.defaultSettings?.mpvSocket || ""
    property string profile:              pluginApi?.pluginSettings?.profile              || pluginApi?.manifest?.metadata?.defaultSettings?.profile   || ""


    /***************************
    * COMPONENTS
    ***************************/
    // Profile
    NComboBox {
        enabled: root.enabled
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.advanced.profile.label") || "Profile"
        description: root.pluginApi?.tr("settings.advanced.profile.description") || "The profile that mpv uses. Use fast for better performance.";
        defaultValue: "default"
        model: [
            {
                "key": "default",
                "name": root.pluginApi?.tr("settings.advanced.profile.default") || "Default"
            },
            {
                "key": "fast",
                "name": root.pluginApi?.tr("settings.advanced.profile.fast") || "Fast"
            },
            {
                "key": "high-quality",
                "name": root.pluginApi?.tr("settings.advanced.profile.high_quality") || "High Quality"
            },
            {
                "key": "low-latency",
                "name": root.pluginApi?.tr("settings.advanced.profile.low_latency") || "Low Latency"
            }
        ]
        currentKey: root.profile
        onSelected: key => root.profile = key
    }

    // Hardware Acceleration
    NToggle {
        enabled: root.enabled
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.advanced.hardware_acceleration.label") || "Hardware Acceleration"
        description: root.pluginApi?.tr("settings.advanced.hardware_acceleration.description") || "Offloads video decoding from cpu to gpu / dedicated hardware.";
        checked: root.hardwareAcceleration
        onToggled: checked => root.hardwareAcceleration = checked
        defaultValue: false
    }

    // MPV Socket path
    NTextInput {
        enabled: root.enabled
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.advanced.mpv_socket.label") || "Mpvpaper Socket"
        description: root.pluginApi?.tr("settings.advanced.mpv_socket.description") || "The mpvpaper socket that noctalia connects to"
        placeholderText: root.pluginApi?.tr("settings.advanced.mpv_socket.input_placeholder") || "Example: /tmp/mpv-socket"
        text: root.mpvSocket
        onTextChanged: root.mpvSocket = text
    }

    Connections {
        target: root.pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.hardwareAcceleration = root.pluginApi?.pluginSettings?.hardwareAcceleration || false
            root.mpvSocket =            root.pluginApi?.pluginSettings?.mpvSocket            || root.pluginApi?.manifest?.metadata?.defaultSettings?.mpvSocket || ""
            root.profile =              root.pluginApi?.pluginSettings?.profile              || root.pluginApi?.manifest?.metadata?.defaultSettings?.profile   || ""
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

        pluginApi.pluginSettings.hardwareAcceleration = hardwareAcceleration;
        pluginApi.pluginSettings.mpvSocket = mpvSocket;
        pluginApi.pluginSettings.profile = profile;
    }
}
