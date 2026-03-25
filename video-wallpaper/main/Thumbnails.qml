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
    required property var    getThumbPath
    required property string thumbCacheFolderPath

    required property FolderModel folderModel
    required property FolderModel thumbFolderModel

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

    function thumbGeneration() {
        if(pluginApi == null) return;

        // Try to start in a bit since the folder models aren't ready yet
        if (!folderModel.ready || !thumbFolderModel.ready) {
            Qt.callLater(thumbGeneration);
            return;
        }

        // Reset the state of thumbCacheReady
        clearThumbCacheReady();

        while(root._thumbGenIndex < folderModel.count) {
            const videoPath = folderModel.get(root._thumbGenIndex);
            const thumbPath = root.getThumbPath(videoPath);
            root._thumbGenIndex++;
            // Check if file already exists, otherwise create it with ffmpeg
            if (thumbFolderModel.indexOf(thumbPath) === -1) {
                Logger.d("video-wallpaper", `Creating thumbnail for video: ${videoPath}`);

                // With scale
                //thumbProc.command = ["sh", "-c", `ffmpeg -y -i ${videoUrl} -vf "scale=1080:-1" -vframes:v 1 ${thumbUrl}`]
                thumbGenerationProc.command = ["sh", "-c", `ffmpeg -y -i "${videoPath}" -vframes:v 1 "${thumbPath}"`]
                thumbGenerationProc.running = true;
                return;
            }
        }

        // The thumbnail generation has looped over every video and finished the generation
        // Update the thumbnail folder
        thumbFolderModel.forceReload();

        root._thumbGenIndex = 0;
        setThumbCacheReady();
    }

    function thumbRegenerate() {
        if(pluginApi == null) return;

        clearThumbCacheReady();

        thumbRegenerationProc.command = ["sh", "-c", `rm -rf ${thumbCacheFolderPath} && mkdir -p ${thumbCacheFolderPath}`]
        thumbRegenerationProc.running = true;
    }


    /***************************
    * EVENTS
    ***************************/
    onWallpapersFolderChanged: {
        root.thumbGeneration();
    }


    /***************************
    * COMPONENTS
    ***************************/

    Process {
        // Process to create the thumbnail folder
        id: thumbInit
        command: ["sh", "-c", `mkdir -p ${root.thumbCacheFolderPath}`]
        running: true
    }

    Process {
        id: thumbGenerationProc

        // When exiting run the thumbGenerate
        onExited: root.thumbGeneration();
    }

    Process {
        id: thumbRegenerationProc
        onExited: {
            // Reload the thumbFolder first
            root.folderModel.forceReload();
            root.thumbFolderModel.forceReload();
            root.thumbGeneration();
        }
    }
}
