pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

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

    required property var    getThumbPath
    required property string thumbCacheFolderPath

    required property FolderModel folderModel
    required property FolderModel thumbFolderModel

    // Screen specific properties
    readonly property string currentWallpaper: pluginApi?.pluginSettings?.[screenName]?.currentWallpaper ?? ""

    // Global properties
    readonly property bool   enabled:          pluginApi?.pluginSettings?.enabled          ?? false
    readonly property bool   thumbCacheReady:  pluginApi?.pluginSettings?.thumbCacheReady  ?? false
    readonly property string wallpapersFolder: pluginApi?.pluginSettings?.wallpapersFolder ?? pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder ?? ""

    // Local properties
    property bool oldWallpapersSaved: false
    property int  _thumbGenIndex: 0


    /***************************
    * FUNCTIONS
    ***************************/
    function startColorGen() {
        // If the folder model isn't ready, or we are still regenerating a thumbnail, or the old wallpapers haven't saved yet, try in a bit
        if(!thumbFolderModel.ready || proc.running || !oldWallpapersSaved){
            Qt.callLater(startColorGen);
            return;
        }

        const thumbPath = root.getThumbPath(currentWallpaper);
        if (thumbFolderModel.indexOf(thumbPath) !== -1) {
            Logger.d("video-wallpaper", "Generating color scheme based on video wallpaper!");
            WallpaperService.changeWallpaper(thumbPath, screenName);
        } else {
            // Try to create the thumbnail again
            // just a fail safe if the current wallpaper isn't included in the wallpapers folder
            Logger.d("video-wallpaper", "Thumbnail not found:", thumbPath);
            proc.command = ["sh", "-c", `ffmpeg -y -i "${currentWallpaper}" -vframes:v 1 "${thumbPath}"`]
            proc.running = true;
            return;
        }

        // Reset the flag
        oldWallpapersSaved = false;
    }


    /***************************
    * EVENTS
    ***************************/
    onCurrentWallpaperChanged: {
        if (root.enabled && root.currentWallpaper != "") {
            root.startColorGen();
        }
    }

    onEnabledChanged: {
        if (root.enabled && root.currentWallpaper != "") {
            root.startColorGen();
        }
    }


    /***************************
    * COMPONENTS
    ***************************/

    Process {
        id: proc
        onExited: {
            // When finished recreating the thumbnail, try to apply the colors again
            root.startColorGen();
        }
    }
}
