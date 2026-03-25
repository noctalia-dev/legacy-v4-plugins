/*********************************
* MIGRATION FOR VERSION 2.0.0
*********************************/
import QtQuick
import Quickshell
import qs.Commons

Item {
    id: root
    required property var pluginApi


    /***************************
    * PROPERTIES
    ***************************/
    readonly property var currentWallpaper:     pluginApi?.pluginSettings?.currentWallpaper     ?? ""
    readonly property var hardwareAcceleration: pluginApi?.pluginSettings?.hardwareAcceleration ?? pluginApi?.manifest?.metadata?.defaultSettings?.hardwareAcceleration ?? false
    readonly property var fillMode:             pluginApi?.pluginSettings?.fillMode             ?? pluginApi?.manifest?.metadata?.defaultSettings?.fillMode             ?? ""
    readonly property var isMuted:              pluginApi?.pluginSettings?.isMuted              ?? false
    readonly property var isPlaying:            pluginApi?.pluginSettings?.isPlaying            ?? false
    readonly property var orientation:          pluginApi?.pluginSettings?.orientation          ?? 0
    readonly property var profile:              pluginApi?.pluginSettings?.profile              ?? pluginApi?.manifest?.metadata?.defaultSettings?.profile ?? ""
    readonly property var volume:               pluginApi?.pluginSettings?.volume               ?? pluginApi?.manifest?.metadata?.defaultSettings?.volume  ?? 0

    property bool migrationDone: false

    /***************************
    * MIGRATION FUNCTIONALITY
    ***************************/
    onPluginApiChanged: {
        if(pluginApi == null) {
            return;
        }

        let migrations = [];

        if(typeof currentWallpaper == "string") {
            migrations.push("currentWallpaper");
        }

        if(typeof hardwareAcceleration == "boolean") {
            migrations.push("hardwareAcceleration");
        }

        if(typeof fillMode == "string") {
            migrations.push("fillMode");
        }

        if(typeof isMuted == "boolean") {
            migrations.push("isMuted");
        }

        if(typeof isPlaying == "boolean") {
            migrations.push("isPlaying");
        }

        if(typeof orientation == "number") {
            migrations.push("orientation");
        }

        if(typeof profile == "string") {
            migrations.push("profile");
        }

        if(typeof thumbCacheReady == "boolean") {
            migrations.push("thumbCacheReady");
        }

        if(typeof volume == "number") {
            migrations.push("volume");
        }

        for(const screen of Quickshell.screens) {
            pluginApi.pluginSettings[screen.name] = ({});
            Logger.e("video-wallpaper", "TEST");
            for(const property of migrations) {
                Logger.d("video-wallpaper", `Migrating "${property}" property.`);
                const temp = pluginApi.pluginSettings[property];
                pluginApi.pluginSettings[screen.name][property] = temp;
            }
        }

        pluginApi.saveSettings();

        migrationDone = true;
    }
}
