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
    required property bool thumbCacheReady
    required property FolderListModel folderModel

    readonly property string thumbCacheFolder: ImageCacheService.wpThumbDir + "mpvpaper"
    property int _thumbGenIndex: 0


    /***************************
    * FUNCTIONS
    ***************************/
    function clearThumbCacheReady() {
        if(pluginApi != null && thumbCacheReady) {
            pluginApi.pluginSettings.thumbCacheReady = false;
            pluginApi.saveSettings();
        }
    }

    function setThumbCacheReady() {
        if(pluginApi != null && !thumbCacheReady) {
            pluginApi.pluginSettings.thumbCacheReady = true;
            pluginApi.saveSettings();
        }
    }


    function getThumbPath(videoPath: string): string {
        const file = videoPath.split('/').pop();

        return `${thumbCacheFolder}/${file}.bmp`
    }

    // Get thumbnail url based on video name
    function getThumbUrl(videoPath: string): string {
        return `file://${getThumbPath(videoPath)}`;
    }


    function startColorGen() {
        thumbColorGenTimer.start();
    }


    function thumbGeneration() {
        if(pluginApi == null) return;

        // Reset the state of thumbCacheReady
        clearThumbCacheReady();

        while(root._thumbGenIndex < folderModel.count) {
            const videoUrl = folderModel.get(root._thumbGenIndex, "fileUrl");
            const thumbUrl = root.getThumbUrl(videoUrl);
            root._thumbGenIndex++;
            // Check if file already exists, otherwise create it with ffmpeg
            if (thumbFolderModel.indexOf(thumbUrl) === -1) {
                Logger.d("mpvpaper", `Creating thumbnail for video: ${videoUrl}`);

                // With scale
                //thumbProc.command = ["sh", "-c", `ffmpeg -y -i ${videoUrl} -vf "scale=1080:-1" -vframes:v 1 ${thumbUrl}`]
                thumbProc.command = ["sh", "-c", `ffmpeg -y -i ${videoUrl} -vframes:v 1 ${thumbUrl}`]
                thumbProc.running = true;
                return;
            }
        }

        // The thumbnail generation has looped over every video and finished the generation.
        root._thumbGenIndex = 0;
        setThumbCacheReady();
    }

    function thumbRegenerate() {
        if(pluginApi == null) return;

        pluginApi.pluginSettings.thumbCacheReady = false;
        pluginApi.saveSettings();

        thumbProc.command = ["sh", "-c", `rm -rf ${thumbCacheFolder} && mkdir -p ${thumbCacheFolder}`]
        thumbProc.running = true;
    }


    /***************************
    * COMPONENTS
    ***************************/
    Process {
        id: thumbProc
        onRunningChanged: {
            if (thumbProc.running)
                return;

            // Try to create the thumbnails if they don't exist.
            root.thumbGeneration();
        }
    }

    FolderListModel {
        id: thumbFolderModel
        folder: "file://" + root.thumbCacheFolder
        nameFilters: ["*.bmp"]
        showDirs: false
    }

    Timer {
        id: thumbColorGenTimer
        interval: 50
        repeat: false
        running: false
        triggeredOnStart: false

        onTriggered: {
            if(thumbFolderModel.status == FolderListModel.Ready) {
                root.pluginApi.withCurrentScreen(screen => {
                    const thumbPath = root.getThumbPath(root.currentWallpaper);
                    if(thumbFolderModel.indexOf("file://" + thumbPath) !== -1) {
                        Logger.d("mpvpaper", "Generating color scheme based on video wallpaper!");
                        WallpaperService.changeWallpaper(thumbPath);
                    } else {
                        // Try to create the thumbnail again
                        // just a fail safe if the current wallpaper isn't included in the wallpapers folder
                        const videoUrl = folderModel.get(root._thumbGenIndex, "fileUrl");
                        const thumbUrl = root.getThumbUrl(videoUrl);

                        Logger.d("mpvpaper", "Thumbnail not found:", thumbPath);
                        thumbColorGenTimerProc.command = ["sh", "-c", `ffmpeg -y -i ${videoUrl} -vframes:v 1 ${thumbUrl}`]
                        thumbColorGenTimerProc.running = true;
                    }
                });
            } else {
                thumbColorGenTimer.restart();
            }
        }
    }

    Process {
        id: thumbColorGenTimerProc
        onExited: thumbColorGenTimer.start();
    }

    // Process to create the thumbnail folder
    Process {
        id: thumbInit
        command: ["sh", "-c", `mkdir -p ${root.thumbCacheFolder}`]
        running: true
    }
}
