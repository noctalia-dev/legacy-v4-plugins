import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

RowLayout {
    id: root

    required property var pluginApi

    property bool enabled: true
    
    Layout.fillWidth: true

    readonly property bool isPlaying:
        pluginApi.pluginSettings.isPlaying ||
        false

    readonly property bool isMuted:
        pluginApi.pluginSettings.isMuted ||
        false


    NButton {
        enabled: root.enabled
        icon: "dice"
        text: root.pluginApi?.tr("common.tool_row.random.text") || "Random"
        tooltipText: root.pluginApi?.tr("common.tool_row.random.tooltip") || "Choose a random wallpaper from the wallpapers folder."
        onClicked: root.random()
    }

    NButton {
        enabled: root.enabled
        icon: "clear-all"
        text: root.pluginApi?.tr("common.tool_row.clear.text") || "Clear"
        tooltipText: root.pluginApi?.tr("common.tool_row.clear.tooltip") || "Clear the current wallpaper."
        onClicked: root.clear()
    }

    NButton {
        enabled: root.enabled
        icon: root.isPlaying ? "media-pause" : "media-play"
        text: root.isPlaying ? root.pluginApi?.tr("common.tool_row.pause.text") || "Pause" : root.pluginApi?.tr("common.tool_row.play.text") || "Play";
        tooltipText: root.isPlaying ? root.pluginApi?.tr("common.tool_row.pause.tooltip") || "Pause the video wallpaper." : root.pluginApi?.tr("common.tool_row.play.tooltip") || "Resume the video wallpaper.";
        onClicked: root.togglePlaying();
    }

    NButton {
        enabled: root.enabled
        icon: root.isMuted ? "volume-high" : "volume-mute"
        text: root.isMuted ? root.pluginApi?.tr("common.tool_row.unmute.text") || "Unmute" : root.pluginApi?.tr("common.tool_row.mute.text") || "Mute";
        tooltipText: root.isMuted ? root.pluginApi?.tr("common.tool_row.unmute.tooltip") || "Unmute the video wallpaper." : root.pluginApi?.tr("common.tool_row.mute.tooltip") || "Mute the video wallpaper.";
        onClicked: root.toggleMute()
    }


    /********************************
    * Button functionality
    ********************************/
    function random() {
        if(pluginApi?.mainInstance == null) {
            Logger.e("video-wallpaper", "Main instance isn't loaded");
            return;
        }

        pluginApi.mainInstance.random();
    }

    function clear() {
        if(pluginApi?.mainInstance == null) {
            Logger.e("video-wallpaper", "Main instance isn't loaded");
            return;
        }

        pluginApi.mainInstance.clear();
    }

    function togglePlaying() {
        if (pluginApi == null) return;

        pluginApi.pluginSettings.isPlaying = !root.isPlaying;
        pluginApi.saveSettings();
    }

    function toggleMute() {
        if(pluginApi == null) return;

        pluginApi.pluginSettings.isMuted = !root.isMuted;
        pluginApi.saveSettings();
    }
}
