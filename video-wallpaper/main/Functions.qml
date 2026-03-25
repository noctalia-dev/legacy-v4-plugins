import QtQuick
import Quickshell
import qs.Commons

import "../common"

Item {
    id: root
    required property var pluginApi


    /***************************
    * PROPERTIES
    ***************************/
    // Required properties
    required property FolderModel folderModel

    // Global properties
    readonly property bool   monitorSpecific:  pluginApi?.pluginSettings?.monitorSpecific  ?? false
    readonly property string wallpapersFolder: pluginApi?.pluginSettings?.wallpapersFolder ?? pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder ?? ""


    /***************************
    * FUNCTIONS
    ***************************/
    function random(screen) {
        if (wallpapersFolder === "") {
            Logger.e("video-wallpaper", "Wallpapers folder is empty!");
            return;
        }
        if (folderModel.count === 0) {
            Logger.e("video-wallpaper", "No valid video files found!");
            return;
        }

        const rand = Math.floor(Math.random() * folderModel.count);
        const url = folderModel.get(rand, "filePath");
        setWallpaper(url, screen);
    }

    function clear(screen) {
        setWallpaper("", screen);
    }

    function nextWallpaper(screen) {
        if (wallpapersFolder === "") {
            Logger.e("video-wallpaper", "Wallpapers folder is empty!");
            return;
        }
        if (folderModel.count === 0) {
            Logger.e("video-wallpaper", "No valid video files found!");
            return;
        }

        Logger.d("video-wallpaper", "Choosing next wallpaper...");

        // Even if the file is not in wallpapers folder, aka -1, it sets the nextIndex to 0 then
        const currentIndex = folderModel.indexOf(pluginApi?.pluginSettings?.[screen]?.currentWallpaper);
        const nextIndex = (currentIndex + 1) % folderModel.count;
        const url = folderModel.get(nextIndex);
        setWallpaper(url, screen);
    }

    function setWallpaper(path, screen) {
        if (root.pluginApi == null) {
            Logger.e("video-wallpaper", "Can't set the wallpaper because pluginApi is null.");
            return;
        }

        function createMonitorSettings(monitor) {
            if (pluginApi.pluginSettings[monitor] === undefined) {
                pluginApi.pluginSettings[monitor] = {};
            }
        }

        if(monitorSpecific) {
            createMonitorSettings(screen);
            pluginApi.pluginSettings[screen].currentWallpaper = path;
            pluginApi.pluginSettings[screen].isPlaying = true;
        } else {
            for(const screen of Quickshell.screens) {
                createMonitorSettings(screen.name);
                pluginApi.pluginSettings[screen.name].currentWallpaper = path;
                pluginApi.pluginSettings[screen.name].isPlaying = true;
            }
        }

        pluginApi.saveSettings();
    }
}
