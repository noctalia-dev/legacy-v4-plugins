import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons
import qs.Services.UI

Item {
    id: root
    required property var pluginApi


    /***************************
    * PROPERTIES
    ***************************/
    required property string currentWallpaper
    required property var oldWallpapers

    required property Thumbnails thumbnails


    /***************************
    * FUNCTIONS
    ***************************/
    function saveOldWallpapers() {
        Logger.d("mpvpaper", "Saving old wallpapers.");
 
        let changed = false;
        let wallpapers = {};
        const oldWallpapers = WallpaperService.currentWallpapers;
        for(let screenName in oldWallpapers) {
            // Only save the old wallpapers if it isn't the current video wallpaper.
            if(oldWallpapers[screenName] != thumbnails.getThumbPath(root.currentWallpaper)) {
                wallpapers[screenName] = oldWallpapers[screenName];
                changed = true;
            }
        }

        if(changed) {
            pluginApi.pluginSettings.oldWallpapers = wallpapers;
            pluginApi.saveSettings();
        }
    }

    function applyOldWallpapers() {
        Logger.d("mpvpaper", "Applying the old wallpapers.");

        let changed = false;
        for (let screenName in oldWallpapers) {
            WallpaperService.changeWallpaper(oldWallpapers[screenName], screenName);
            changed = true;
        }

        if(!changed) {
            WallpaperService.changeWallpaper(WallpaperService.noctaliaDefaultWallpaper, undefined);
        }
    }
}
