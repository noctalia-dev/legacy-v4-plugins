import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root
    required property var pluginApi


    /***************************
    * PROPERTIES
    ***************************/
    readonly property bool enabled: pluginApi?.pluginSettings?.enabled ?? false

    required property var random
    required property var clear
    required property var setWallpaper


    /***************************
    * FUNCTIONS
    ***************************/
    function deltaChangeMonitorProperty(key: string, delta: double, screen: string): void {
        function createMonitorSettings(monitor) {
            // Check if the monitor settings exist and create it if it doesn't exist
            if (pluginApi.pluginSettings[monitor] === undefined) {
                pluginApi.pluginSettings[monitor] = {};
            }
        }

        if(pluginApi == null) {
            Logger.e("video-wallpaper", "PluginAPI is null.");
            return;
        }

        if (screen === "") {
            for (const screen of Quickshell.screens) {
                createMonitorSettings(screen.name);
                const currentValue = pluginApi.pluginSettings[screen.name][key];
                if (typeof currentValue === "number") {
                    pluginApi.pluginSettings[screen.name][key] = currentValue + delta;
                }
            }
        } else {
            createMonitorSettings(screen);
            const currentValue = pluginApi.pluginSettings[screen][key];
            if (typeof currentValue === "number") {
                pluginApi.pluginSettings[screen.name][key] = currentValue + delta;
            }
        }

        pluginApi.saveSettings();
    }

    function toggleMonitorProperty(key: string, screen: string): void {
        function createMonitorSettings(monitor) {
            // Check if the monitor settings exist and create it if it doesn't exist
            if (pluginApi.pluginSettings[monitor] === undefined) {
                pluginApi.pluginSettings[monitor] = {};
            }
        }

        if(pluginApi == null) {
            Logger.e("video-wallpaper", "PluginAPI is null.");
            return;
        }

        if (screen === "") {
            for (const screen of Quickshell.screens) {
                createMonitorSettings(screen.name);
                const currentValue = pluginApi.pluginSettings[screen.name][key];
                if (typeof currentValue === "boolean") {
                    pluginApi.pluginSettings[screen.name][key] = !currentValue;
                }
            }
        } else {
            createMonitorSettings(screen);
            const currentValue = pluginApi.pluginSettings[screen][key];
            if (typeof currentValue === "boolean") {
                pluginApi.pluginSettings[screen.name][key] = !currentValue;
            }
        }

        pluginApi.saveSettings();
    }

    function saveMonitorProperty(key: string, value: var, screen: string): void {
        function createMonitorSettings(monitor) {
            // Check if the monitor settings exist and create it if it doesn't exist
            if (pluginApi.pluginSettings[monitor] === undefined) {
                pluginApi.pluginSettings[monitor] = {};
            }
        }

        if(pluginApi == null) {
            Logger.e("video-wallpaper", "PluginAPI is null.");
            return;
        }

        if (screen === "") {
            for (const screen of Quickshell.screens) {
                createMonitorSettings(screen.name);
                pluginApi.pluginSettings[screen.name][key] = value;
            }
        } else {
            createMonitorSettings(screen);
            pluginApi.pluginSettings[screen][key] = value;
        }

        pluginApi.saveSettings();
    }

    function getMonitorProperty(key: string, screen: string): string {
        if(pluginApi == null) {
            Logger.e("video-wallpaper", "PluginAPI is null.");
            return;
        }

        if (screen === "") {
            let values = [];
            for (const screen of Quickshell.screens) {
                if (root.pluginApi?.pluginSettings?.[screen.name]?.[key] !== undefined) {
                    values.push(`${screen.name}: ${root.pluginApi.pluginSettings[screen.name][key]}\n`);
                }
            }

            return values.join(", ");
        } else {
            return pluginApi?.pluginSettings?.[screen]?.[key] || "";
        }
    }


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
        function setWallpaper(path: string, screen: string) {
            root.saveMonitorProperty("currentWallpaper", path, screen);
        }

        function getWallpaper(screen: string): string {
            return root.getMonitorProperty("currentWallpaper", screen);
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

        function toggleEnabled() {
            setEnabled(!root.enabled);
        }

        // Is playing
        function resume(screen: string) {
            root.saveMonitorProperty("isPlaying", true, screen);
        }

        function pause(screen: string) {
            root.saveMonitorProperty("isPlaying", false, screen);
        }

        function togglePlaying(screen: string) {
            root.toggleMonitorProperty("isPlaying", screen);
        }

        // Mute / unmute
        function mute(screen: string) {
            root.saveMonitorProperty("isMuted", true, screen);
        }

        function unmute(screen: string) {
            root.saveMonitorProperty("isMuted", false, screen);
        }

        function toggleMute(screen: string) {
            root.toggleMonitorProperty("isMuted", screen);
        }

        // Volume
        function setVolume(volume: real, screen: string) {
            root.saveMonitorProperty("volume", volume, screen);
        }

        function increaseVolume(screen: string) {
            root.deltaChangeMonitorProperty("volume", Settings.data.audio.volumeStep, screen);
        }

        function decreaseVolume(screen: string) {
            root.deltaChangeMonitorProperty("volume", -Settings.data.audio.volumeStep, screen);
        }

        // Panel
        function openPanel() {
            root.pluginApi.withCurrentScreen(screen => {
                root.pluginApi.openPanel(screen);
            });
        }
    }
}
