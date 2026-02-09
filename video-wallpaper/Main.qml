import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

import "./common"
import "./main"

Item {
    id: root
    property var pluginApi: null


    /***************************
    * PROPERTIES
    ***************************/
    readonly property string currentWallpaper: pluginApi.pluginSettings.currentWallpaper || ""
    readonly property string wallpapersFolder: pluginApi.pluginSettings.wallpapersFolder || "~/Pictures/Wallpapers"

    readonly property string thumbCacheFolderPath: ImageCacheService.wpThumbDir + "video-wallpaper"


    /***************************
    * WALLPAPER FUNCTIONALITY
    ***************************/
    function random() {
        if (wallpapersFolder === "") {
            Logger.e("video-wallpaper", "Wallpapers folder is empty!");
            return;
        }
        if (rootFolderModel.count === 0) {
            Logger.e("video-wallpaper", "No valid video files found!");
            return;
        }

        const rand = Math.floor(Math.random() * rootFolderModel.count);
        const url = rootFolderModel.get(rand, "filePath");
        setWallpaper(url);
    }

    function clear() {
        setWallpaper("");
    }

    function nextWallpaper() {
        if (wallpapersFolder === "") {
            Logger.e("video-wallpaper", "Wallpapers folder is empty!");
            return;
        }
        if (rootFolderModel.count === 0) {
            Logger.e("video-wallpaper", "No valid video files found!");
            return;
        }

        Logger.d("video-wallpaper", "Choosing next wallpaper...");

        // Even if the file is not in wallpapers folder, aka -1, it sets the nextIndex to 0 then
        const currentIndex = rootFolderModel.indexOf(root.currentWallpaper);
        const nextIndex = (currentIndex + 1) % rootFolderModel.count;
        const url = rootFolderModel.get(nextIndex);
        setWallpaper(url);
    }

    function setWallpaper(path) {
        if (root.pluginApi == null) {
            Logger.e("video-wallpaper", "Can't set the wallpaper because pluginApi is null.");
            return;
        }

        pluginApi.pluginSettings.currentWallpaper = path;
        pluginApi.saveSettings();
    }


    /***************************
    * HELPER FUNCTIONALITY
    ***************************/
    function getThumbPath(videoPath: string): string {
        const file = videoPath.split('/').pop();

        return `${thumbCacheFolderPath}/${file}.bmp`
    }

    function thumbRegenerate() {
        thumbnails.thumbRegenerate();
    }


    /***************************
    * COMPONENTS
    ***************************/
    VideoWallpaper {
        id: wallpaper
        pluginApi: root.pluginApi
    }

    Thumbnails {
        id: thumbnails
        pluginApi: root.pluginApi

        getThumbPath: root.getThumbPath
        thumbCacheFolderPath: root.thumbCacheFolderPath

        folderModel: rootFolderModel
        thumbFolderModel: rootThumbFolderModel
    }

    InnerService {
        id: innerService
        pluginApi: root.pluginApi

        getThumbPath: root.getThumbPath
        thumbFolderModel: rootThumbFolderModel

        onOldWallpapersSaved: {
            // When the old wallpapers are saved and done, inform the color gen.
            thumbnails.oldWallpapersSaved = true;
        }
    }

    Automation {
        id: automation
        pluginApi: root.pluginApi

        random: root.random
        nextWallpaper: root.nextWallpaper
    }

    FolderModel {
        id: rootFolderModel
        folder: root.wallpapersFolder
        filters: ["*.mp4", "*.avi", "*.mov"]
    }

    FolderModel {
        id: rootThumbFolderModel
        folder: root.thumbCacheFolderPath
        filters: ["*.bmp"]
    }

    // IPC Handler
    IPC {
        id: ipcHandler
        pluginApi: root.pluginApi
    }
}
