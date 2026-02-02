pragma ComponentBehavior: Bound
import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null

    readonly property bool active: 
        pluginApi.pluginSettings.active || 
        false

    readonly property string wallpapersFolder: 
        pluginApi.pluginSettings.wallpapersFolder || 
        pluginApi.manifest.metadata.defaultSettings.wallpapersFolder || 
        "~/Pictures/Wallpapers"

    readonly property string currentWallpaper: 
        pluginApi.pluginSettings.currentWallpaper || 
        ""

    readonly property string mpvSocket: 
        pluginApi.pluginSettings.mpvSocket || 
        pluginApi.manifest.metadata.defaultSettings.mpvSocket || 
        "/tmp/mpv-socket"

    // Thumbnail variables
    property bool thumbCacheReady: false
    property int _thumbGenIndex: 0

    function random() {
        if (wallpapersFolder === "" || folderModel.count === 0) {
            Logger.e("mpvpaper", "Empty wallpapers folder or no files found!");
            return;
        }

        const rand = Math.floor(Math.random() * folderModel.count);
        const url = folderModel.get(rand, "filePath");
        setWallpaper(url);
    }

    function clear() {
        setWallpaper("");
    }

    function setWallpaper(path) {
        if (root.pluginApi == null) {
            Logger.e("mpvpaper", "Can't set the wallpaper because pluginApi is null.");
            return;
        }

        pluginApi.pluginSettings.currentWallpaper = path;
        pluginApi.saveSettings();
    }

    function setActive(isActive) {
        if(root.pluginApi == null) {
            Logger.e("mpvpaper", "Can't change active state because pluginApi is null.");
            return;
        }

        pluginApi.pluginSettings.active = isActive;
        pluginApi.saveSettings();
    }

    function thumbRegenerate() {
        root.thumbCacheReady = false;
        thumbProc.command = ["sh", "-c", `rm -rf ${thumbCacheFolder} && mkdir -p ${thumbCacheFolder}`]
        thumbProc.running = true;
    }

    function thumbGeneration() {
        while(root._thumbGenIndex < folderModel.count) {
            const videoUrl = folderModel.get(root._thumbGenIndex, "fileUrl");
            const thumbUrl = root.getThumbUrl(videoUrl);
            root._thumbGenIndex++;
            // Check if file already exists, otherwise create it with ffmpeg
            if (thumbFolderModel.indexOf(thumbUrl) === -1) {
                Logger.d("mpvpaper", `Creating thumbnail for video: ${videoUrl}`);

                thumbProc.command = ["sh", "-c", `ffmpeg -y -i ${videoUrl} -vf "scale=1080:-1" -vframes:v 1 ${thumbUrl}`]
                thumbProc.running = true;
                return;
            }
        }

        // The thumbnail generation has looped over every video and finished the generation.
        root._thumbGenIndex = 0;
        root.thumbCacheReady = true;
    }

    /* HELPER FUNCTIONALITY */
    readonly property string thumbCacheFolder: ImageCacheService.wpThumbDir + "mpvpaper"

    function getThumbPath(videoPath: string): string {
        const file = videoPath.split('/').pop();

        return `${thumbCacheFolder}/${file}.bmp`
    }

    // Get thumbnail url based on video name
    function getThumbUrl(videoPath: string): string {
        return `file://${getThumbPath(videoPath)}`;
    }

    onWallpapersFolderChanged: {
        // Reset variables
        root._thumbGenIndex = 0;
        
        root.thumbRegenerate();
    }

    onCurrentWallpaperChanged: {
        if (!root.active)
            return;

        if (root.currentWallpaper != "") {
            Logger.d("mpvpaper", "Changing current wallpaper:", root.currentWallpaper);

            if(mpvProc.running) {
                // If mpvpaper is already running
                socket.connected = true;
                socket.path = mpvSocket;
                socket.write(`loadfile "${root.currentWallpaper}"\n`);
                socket.flush();
            } else {
                // Start mpvpaper
                mpvProc.command = ["sh", "-c", `mpvpaper -o "input-ipc-server=${root.mpvSocket} loop no-audio" ALL ${root.currentWallpaper}` ]
                mpvProc.running = true;
            }
        } else if(mpvProc.running) {
            Logger.d("mpvpaper", "Current wallpaper is empty, turning mpvpaper off.");

            socket.connected = false;
            mpvProc.running = false;
        }
    }

    onActiveChanged: {
        if(root.active && !mpvProc.running && root.currentWallpaper != "") {
            Logger.d("mpvpaper", "Turning mpvpaper on.");

            mpvProc.command = ["sh", "-c", `mpvpaper -o "input-ipc-server=${root.mpvSocket} loop no-audio" ALL ${root.currentWallpaper}` ]
            mpvProc.running = true;
        } else if(!root.active) {
            Logger.d("mpvpaper", "Turning mpvpaper off.");

            mpvProc.running = false;
        }
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + root.wallpapersFolder
        nameFilters: ["*.mp4", "*.avi", "*.mov"]
        showDirs: false
    }

    Process {
        id: mpvProc
    }

    Socket {
        id: socket
        path: root.mpvSocket
    }

    FolderListModel {
        id: thumbFolderModel
        folder: "file://" + root.thumbCacheFolder
        nameFilters: ["*.bmp"]
        showDirs: false
    }

    Process {
        id: thumbProc
        onRunningChanged: {
            if (running)
                return;

            // Try to create the thumbnails if they don't exist.
            root.thumbGeneration();
        }
    }

    // IPC Handler
    IpcHandler {
        target: "plugin:mpvpaper"

        function random() {
            root.random();
        }

        function clear() {
            root.clear();
        }

        function setWallpaper(path: string) {
            root.setWallpaper(path);
        }

        function getWallpaper(): string {
            return root.currentWallpaper;
        }

        function setActive(isActive: bool) {
            root.setActive(isActive);
        }

        function getActive(): bool {
            return root.active;
        }

        function toggleActive() {
            root.setActive(!root.active);
        }
    }
}
