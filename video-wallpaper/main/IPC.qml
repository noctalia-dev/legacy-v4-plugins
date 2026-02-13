import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root
    required property var pluginApi


    /***************************
    * PROPERTIES
    ***************************/
    readonly property string currentWallpaper: pluginApi?.pluginSettings?.currentWallpaper || ""
    readonly property bool   enabled:          pluginApi?.pluginSettings?.enabled          || false
    readonly property bool   isMuted:          pluginApi?.pluginSettings?.isMuted          || false
    readonly property bool   isPlaying:        pluginApi?.pluginSettings?.isPlaying        || false
    readonly property double volume:           pluginApi?.pluginSettings?.volume           || pluginApi?.manifest?.metadata?.defaultSettings?.volume || 0

    required property var random
    required property var clear
    required property var setWallpaper

    /***************************
    * IPC HANDLER
    ***************************/
    IpcHandler {
        target: "plugin:videowallpaper"


        function random() {
            root.random();
        }

        function clear() {
            root.clear();
        }

        // Current wallpaper
        function setWallpaper(path: string) {
            root.setWallpaper(path);
        }

        function getWallpaper(): string {
            return root.currentWallpaper;
        }

        // Enabled
        function setEnabled(enabled: bool) {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.enabled = enabled;
            root.pluginApi.saveSettings();
        }

        function getEnabled(): bool {
            return root.enabled;
        }

        function toggleActive() {
            setEnabled(!root.enabled);
        }

        // Is playing
        function resume() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isPlaying = true;
            root.pluginApi.saveSettings();
        }

        function pause() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isPlaying = false;
            root.pluginApi.saveSettings();
        }

        function togglePlaying() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isPlaying = !root.isPlaying;
            root.pluginApi.saveSettings();
        }

        // Mute / unmute
        function mute() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isMuted = true;
            root.pluginApi.saveSettings();
        }

        function unmute() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isMuted = false;
            root.pluginApi.saveSettings();
        }

        function toggleMute() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isMuted = !root.isMuted;
            root.pluginApi.saveSettings();
        }

        // Volume
        function setVolume(volume: real) {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.volume = volume;
            root.pluginApi.saveSettings();
        }

        function increaseVolume() {
            setVolume(root.volume + Settings.data.audio.volumeStep);
        }

        function decreaseVolume() {
            setVolume(root.volume - Settings.data.audio.volumeStep);
        }

        // Panel
        function openPanel() {
            root.pluginApi.withCurrentScreen(screen => {
                root.pluginApi.openPanel(screen);
            });
        }
    }
}
