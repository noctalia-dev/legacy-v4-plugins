import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginM
    Layout.fillWidth: true

    required property var pluginApi
    required property bool active
    
    property bool hardwareAcceleration:
        pluginApi?.pluginSettings?.hardwareAcceleration ||
        false

    property string mpvSocket: 
        pluginApi?.pluginSettings?.mpvSocket ||
        pluginApi?.manifest?.metadata?.defaultSettings?.mpvSocket ||
        "/tmp/mpv-socket"

    property string profile:
        pluginApi?.pluginSettings?.profile ||
        pluginApi?.manifest?.metadata?.defaultSettings?.profile ||
        "default"
    
    property string fillMode:
        pluginApi?.pluginSettings?.fillMode ||
        pluginApi?.manifest?.metadata?.defaultSettings?.fillMode ||
        "fit"

    // Profile
    NComboBox {
        enabled: root.active
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.profile.label") || "Profile"
        description: pluginApi?.tr("settings.profile.description") || "The profile that mpv uses. Use fast for better performance.";
        defaultValue: "default"
        model: [
            {
                "key": "default",
                "name": pluginApi?.tr("settings.profile.default") || "Default"
            },
            {
                "key": "fast",
                "name": pluginApi?.tr("settings.profile.fast") || "Fast"
            },
            {
                "key": "high-quality",
                "name": pluginApi?.tr("settings.profile.high_quality") || "High Quality"
            },
            {
                "key": "low-latency",
                "name": pluginApi?.tr("settings.profile.low_latency") || "Low Latency"
            }
        ]
        currentKey: root.profile
        onSelected: key => root.profile = key
    }

    // Fill Mode
    NComboBox {
        enabled: root.active
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.fill_mode.label") || "Fill mode"
        description: pluginApi?.tr("settings.fill_mode.description") || "The fill mode that mpv uses.";
        defaultValue: "fit"
        model: [
            {
                "key": "fit",
                "name": pluginApi?.tr("settings.fill_mode.fit") || "Fit"
            },
            {
                "key": "crop",
                "name": pluginApi?.tr("settings.fill_mode.crop") || "Crop"
            },
            {
                "key": "stretch",
                "name": pluginApi?.tr("settings.fill_mode.stretch") || "Stretch"

            }
        ]
        currentKey: root.fillMode
        onSelected: key => root.fillMode = key
    }

    // Hardware Acceleration
    NToggle {
        enabled: root.active
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.hardware_acceleration.label") || "Hardware Acceleration"
        description: pluginApi?.tr("settings.hardware_acceleration.description") || "Offloads video decoding from cpu to gpu / dedicated hardware.";
        checked: root.hardwareAcceleration
        onToggled: checked => root.hardwareAcceleration = checked
        defaultValue: false
    }

    // MPV Socket path
    NTextInput {
        enabled: root.active
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.mpv_socket.title_label") || "Mpvpaper socket"
        description: pluginApi?.tr("settings.mpv_socket.title_description") || "The mpvpaper socket that noctalia connects to"
        placeholderText: pluginApi?.tr("settings.mpv_socket.input_placeholder") || "Example: /tmp/mpv-socket"
        text: root.mpvSocket
        onTextChanged: root.mpvSocket = text
    }

    Connections {
        target: pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.hardwareAcceleration = root.pluginApi.pluginSettings.hardwareAcceleration || false
            root.mpvSocket = root.pluginApi.pluginSettings.mpvSocket || "/tmp/mpv-socket";
            root.profile = root.pluginApi.pluginSettings.profile || pluginApi?.manifest?.metadata?.defaultSettings?.profile || "default"
            root.fillMode = root.pluginApi.pluginSettings.fillMode || pluginApi?.manifest?.metadata?.defaultSettings?.fillMode || "fit"
        }
    }


    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if(!pluginApi) {
            Logger.e("mpvpaper", "Cannot save: pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.hardwareAcceleration = hardwareAcceleration;
        pluginApi.pluginSettings.mpvSocket = mpvSocket;
        pluginApi.pluginSettings.profile = profile;
        pluginApi.pluginSettings.fillMode = fillMode;
    }
}
