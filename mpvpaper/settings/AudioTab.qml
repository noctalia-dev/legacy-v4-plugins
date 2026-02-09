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

    readonly property bool isMuted:
        pluginApi.pluginSettings.isMuted ||
        false

    readonly property real volume:
        pluginApi.pluginSettings.volume ||
        100


    // Volume
    NValueSlider {
        enabled: root.active && !root.isMuted
        from: 0
        to: 100
        value: root.volume
        stepSize: Settings.data.audio.volumeStep
        label: pluginApi?.tr("settings.volume.label") || "Volume"
        description: pluginApi?.tr("settings.volume.description") || "The volume of the video wallpaper playing."
        onPressedChanged: (pressed, value) => {
            if(pluginApi == null) {
                Logger.e("mpvpaper", "Plugin API is null.");
                return;
            }

            // When slider is let go
            if(!pressed) {
                pluginApi.pluginSettings.volume = value;
                pluginApi.saveSettings();
            }
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
    }
}
