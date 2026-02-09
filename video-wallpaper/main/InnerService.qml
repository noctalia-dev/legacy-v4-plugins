import QtQuick

import qs.Commons
import qs.Services.UI

import "../common"

Item {
    id: root
    required property var pluginApi


    /***************************
    * PROPERTIES
    ***************************/
    readonly property string    currentWallpaper:   pluginApi.pluginSettings.currentWallpaper   || ""
    readonly property bool      enabled:            pluginApi.pluginSettings.enabled            || false
    readonly property var       oldWallpapers:      pluginApi.pluginSettings.oldWallpapers      || ({})

    required property var getThumbPath
    required property FolderModel thumbFolderModel

    signal oldWallpapersSaved


    /***************************
    * FUNCTIONS
    ***************************/
    function saveOldWallpapers() {
        Logger.d("video-wallpaper", "Saving old wallpapers.");

        let changed = false;
        let wallpapers = {};
        const oldWallpapers = WallpaperService.currentWallpapers;
        for(let screenName in oldWallpapers) {
            const thumbPath = getThumbPath(root.currentWallpaper);
            const oldWallpaper = oldWallpapers[screenName];
            // Only save the old wallpapers if it isn't the current video wallpaper, and if the thumbnail folder doesn't know of it.
            if(oldWallpaper != thumbPath && thumbFolderModel.indexOf(oldWallpaper) === -1) {
                wallpapers[screenName] = oldWallpapers[screenName];
            }
        }

        if(Object.keys(wallpapers).length != 0) {
            pluginApi.pluginSettings.oldWallpapers = wallpapers;
            pluginApi.saveSettings();
        }

        oldWallpapersSaved();
    }

    function applyOldWallpapers() {
        Logger.d("video-wallpaper", "Applying the old wallpapers.");

        for (let screenName in oldWallpapers) {
            WallpaperService.changeWallpaper(oldWallpapers[screenName], screenName);
        }
    }


    /***************************
    * EVENTS
    ***************************/
    onCurrentWallpaperChanged: {
        if (root.enabled && root.currentWallpaper != "") {
            saveOldWallpapers();
        } else {
            applyOldWallpapers();
        }
    }
    onEnabledChanged: {
        if (root.enabled && root.currentWallpaper != "") {
            saveOldWallpapers();
        } else {
            applyOldWallpapers();
        }
    }

    Component.onDestruction: {
        applyOldWallpapers();
    }
}
