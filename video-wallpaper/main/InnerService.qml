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
    // Required properties
    required property string screenName

    required property var         getThumbPath
    required property FolderModel thumbFolderModel

    // Monitor specific properties
    readonly property string currentWallpaper:  pluginApi?.pluginSettings?.[screenName]?.currentWallpaper  ?? ""
    readonly property string noctaliaWallpaper: pluginApi?.pluginSettings?.[screenName]?.noctaliaWallpaper ?? ""

    // Global properties
    readonly property bool enabled:         pluginApi?.pluginSettings?.enabled         ?? false
    readonly property bool thumbCacheReady: pluginApi?.pluginSettings?.thumbCacheReady ?? false

    // Signals
    signal oldWallpapersSaved


    /***************************
    * FUNCTIONS
    ***************************/
    function saveOldWallpapers() {
        if (pluginApi == null || saveTimer.running) return;

        if (!thumbCacheReady || !thumbFolderModel.ready) {
            Qt.callLater(saveOldWallpapers);
            return;
        }

        const noctaliaWallpaper = WallpaperService.currentWallpapers[root.screenName];

        // Check if the wallpaper name is VERY similar to how the thumbnail generation works,
        // aka if the last characters are ".extension.bmp", in that case just don't do anything, just as a fail safe.
        const videoExtension = currentWallpaper.split(".").pop();
        const isSimilarToThumbnailGen = noctaliaWallpaper.slice(-8) === `.${videoExtension}.bmp`;

        if (thumbFolderModel.indexOf(noctaliaWallpaper) === -1 && !isSimilarToThumbnailGen) {
            saveTimer.save("noctaliaWallpaper", noctaliaWallpaper);
        }

        oldWallpapersSaved();
    }

    function applyOldWallpapers() {
        WallpaperService.changeWallpaper(noctaliaWallpaper, screenName);
        Logger.d("video-wallpaper", "Applying the old wallpapers...");
    }


    /***************************
    * EVENTS
    ***************************/
    onCurrentWallpaperChanged: {
        if (pluginApi == null) return;

        if (root.enabled && root.currentWallpaper != "") {
            root.saveOldWallpapers();
        } else {
            root.applyOldWallpapers();
        }
    }

    onEnabledChanged: {
        if (pluginApi == null) return;

        if (root.enabled && root.currentWallpaper != "") {
            root.saveOldWallpapers();
        } else {
            root.applyOldWallpapers();
        }
    }

    Component.onDestruction: {
        applyOldWallpapers();
    }

    /***************************
    * COMPONENTS
    ***************************/
    SaveTimer {
        id: saveTimer
        pluginApi: root.pluginApi
        screenName: root.screenName
    }
}
