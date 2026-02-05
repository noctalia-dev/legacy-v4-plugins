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
    
    property string mpvSocket: 
        pluginApi?.pluginSettings?.mpvSocket ||
        pluginApi?.manifest?.metadata?.defaultSettings?.mpvSocket ||
        "/tmp/mpv-socket"


    // MPV Socket path
    ColumnLayout {
        spacing: Style.marginS

        NLabel {
            enabled: root.active
            label: pluginApi?.tr("settings.mpv_socket.title_label") || "Mpvpaper socket"
            description: pluginApi?.tr("settings.mpv_socket.title_description") || "The mpvpaper socket that noctalia connects to"
        }

        NTextInput {
            enabled: root.active
            Layout.fillWidth: true
            placeholderText: pluginApi?.tr("settings.mpv_socket.input_placeholder") || "Example: /tmp/mpv-socket"
            text: root.mpvSocket
            onTextChanged: root.mpvSocket = text
        }
    }

    Connections {
        target: pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.mpvSocket = root.pluginApi.pluginSettings.mpvSocket || "/tmp/mpv-socket";
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

        pluginApi.pluginSettings.mpvSocket = mpvSocket;
    }
}
