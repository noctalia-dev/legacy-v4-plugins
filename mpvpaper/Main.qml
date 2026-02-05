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

    readonly property bool isPlaying:
        pluginApi.pluginSettings.isPlaying ||
        false

    readonly property bool isMuted:
        pluginApi.pluginSettings.isMuted ||
        false

    readonly property real volume:
        pluginApi.pluginSettings.volume ||
        100

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

    readonly property var oldWallpapers:
        pluginApi.pluginSettings.oldWallpapers || 
        ({})

    // Thumbnail variables
    property bool thumbCacheReady: false
    property int _thumbGenIndex: 0


    /***************************
    * WALLPAPER FUNCTIONALITY
    ***************************/
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


    /***************************
    * PLAYBACK FUNCTIONALITY
    ***************************/
    function resume() {
        if (pluginApi == null) return;

        pluginApi.pluginSettings.isPlaying = true;
        pluginApi.saveSettings();
    }

    function pause() {
        if (pluginApi == null) return;

        pluginApi.pluginSettings.isPlaying = false;
        pluginApi.saveSettings();
    }

    function togglePlaying() {
        if (pluginApi == null) return;

        pluginApi.pluginSettings.isPlaying = !root.isPlaying;
        pluginApi.saveSettings();
    }


    /***************************
    * AUDIO FUNCTIONALITY
    ***************************/
    function mute() {
        if (pluginApi == null) return;

        pluginApi.pluginSettings.isMuted = true;
        pluginApi.saveSettings();
    }

    function unmute() {
        if (pluginApi == null) return;

        pluginApi.pluginSettings.isMuted = false;
        pluginApi.saveSettings();
    }

    function toggleMute() {
        if (pluginApi == null) return;

        pluginApi.pluginSettings.isMuted = !root.isMuted;
        pluginApi.saveSettings();
    }

    function setVolume(volume) {
        if (pluginApi == null) return;

        pluginApi.pluginSettings.volume = volume;
        pluginApi.saveSettings();
    }

    function increaseVolume() {
        if (pluginApi == null) return;

        setVolume(root.volume + Settings.data.audio.volumeStep);
    }

    function decreaseVolume() {
        if (pluginApi == null) return;

        setVolume(root.volume - Settings.data.audio.volumeStep);
    }


    /***************************
    * THUMBNAIL FUNCTIONALITY
    ***************************/
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

                // With scale
                //thumbProc.command = ["sh", "-c", `ffmpeg -y -i ${videoUrl} -vf "scale=1080:-1" -vframes:v 1 ${thumbUrl}`]
                thumbProc.command = ["sh", "-c", `ffmpeg -y -i ${videoUrl} -vframes:v 1 ${thumbUrl}`]
                thumbProc.running = true;
                return;
            }
        }

        // The thumbnail generation has looped over every video and finished the generation.
        root._thumbGenIndex = 0;
        root.thumbCacheReady = true;
    }


    /***************************
    * WALLPAPER SERVICE
    ***************************/
    function saveOldWallpapers() {
        Logger.d("mpvpaper", "Saving old wallpapers.");
 
        let changed = false;
        let wallpapers = {};
        const oldWallpapers = WallpaperService.currentWallpapers;
        for(let screenName in oldWallpapers) {
            // Only save the old wallpapers if it isn't the current video wallpaper.
            if(oldWallpapers[screenName] != getThumbPath(root.currentWallpaper)) {
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


    /***************************
    * HELPER FUNCTIONALITY
    ***************************/
    readonly property string thumbCacheFolder: ImageCacheService.wpThumbDir + "mpvpaper"

    function getThumbPath(videoPath: string): string {
        const file = videoPath.split('/').pop();

        return `${thumbCacheFolder}/${file}.bmp`
    }

    // Get thumbnail url based on video name
    function getThumbUrl(videoPath: string): string {
        return `file://${getThumbPath(videoPath)}`;
    }

    function activateMpvpaper() {
        Logger.d("mpvpaper", "Activating mpvpaper...");

        // Save the old wallpapers of the user.
        saveOldWallpapers();

        mpvProc.command = ["sh", "-c", `mpvpaper -o "input-ipc-server=${root.mpvSocket} loop ${isMuted ? "no-audio" : ""}" ALL ${root.currentWallpaper}` ]
        mpvProc.running = true;

        pluginApi.pluginSettings.isPlaying = true;
        pluginApi.saveSettings();
    }

    function deactivateMpvpaper() {
        Logger.d("mpvpaper", "Deactivating mpvpaper...");

        // Apply the old wallpapers back
        applyOldWallpapers();

        socket.connected = false;
        mpvProc.running = false;
    }

    function sendCommandToMPV(command: string) {
        socket.connected = true;
        socket.path = mpvSocket;
        socket.write(`${command}\n`);
        socket.flush();
    }


    /***************************
    * EVENTS
    ***************************/
    onIsPlayingChanged: {
        if (!mpvProc.running) {
            Logger.d("mpvpaper", "No wallpaper is running!");
            return;
        }

        // Pause or unpause the video
        if(isPlaying) {
            sendCommandToMPV("set pause no");
        } else {
            sendCommandToMPV("set pause yes");
        }
    }

    onIsMutedChanged: {
        if (!mpvProc.running) {
            Logger.d("mpvpaper", "No wallpaper is running!");
            return;
        }

        // This sets the audio id to null or to auto
        if (isMuted) {
            sendCommandToMPV("no-osd set aid no");
        } else {
            sendCommandToMPV("no-osd set aid auto");
        }
    }

    onVolumeChanged: {
        if(!mpvProc.running) {
            return;
        }

        // Mpv has volume from 0 to 100 instead of 0 to 1
        const v = Math.min(Math.max(volume, 0), 100);

        sendCommandToMPV(`no-osd set volume ${v}`)

        // Clamp the volume
        if(v != volume) {
            pluginApi.pluginSettings.volume = v;
            pluginApi.saveSettings();
        }
    }

    onCurrentWallpaperChanged: {
        if (!root.active)
            return;

        if (root.currentWallpaper != "") {
            Logger.d("mpvpaper", "Changing current wallpaper:", root.currentWallpaper);

            if(mpvProc.running) {
                // If mpvpaper is already running
                sendCommandToMPV(`loadfile "${root.currentWallpaper}"`);
            } else {
                // Start mpvpaper
                activateMpvpaper();
            }

            thumbColorGenTimer.start();
        } else if(mpvProc.running) {
            Logger.d("mpvpaper", "Current wallpaper is empty, turning mpvpaper off.");

            deactivateMpvpaper();
        }
    }

    onActiveChanged: {
        if(root.active && !mpvProc.running && root.currentWallpaper != "") {
            Logger.d("mpvpaper", "Turning mpvpaper on.");

            activateMpvpaper();
            thumbColorGenTimer.start();
        } else if(!root.active) {
            Logger.d("mpvpaper", "Turning mpvpaper off.");

            deactivateMpvpaper();
        }
    }


    /***************************
    * COMPONENTS
    ***************************/
    FolderListModel {
        id: folderModel
        folder: root.pluginApi == null ? "" : "file://" + root.wallpapersFolder
        nameFilters: ["*.mp4", "*.avi", "*.mov"]
        showDirs: false

        onStatusChanged: {
            root._thumbGenIndex = 0;
            root.thumbCacheReady = false;
            if (folderModel.status == FolderListModel.Ready) {
                // Generate all the thumbnails for the folder
                root.thumbGeneration();
            }
        }
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

    Timer {
        id: thumbColorGenTimer
        interval: 50
        repeat: false
        running: false
        triggeredOnStart: false

        onTriggered: {
            if(thumbFolderModel.status == FolderListModel.Ready) {
                pluginApi.withCurrentScreen(screen => {
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

    Process {
        id: thumbProc
        onRunningChanged: {
            if (running)
                return;

            // Try to create the thumbnails if they don't exist.
            root.thumbGeneration();
        }
    }

    // Process to create the thumbnail folder
    Process {
        id: thumbInit
        command: ["sh", "-c", `mkdir -p ${root.thumbCacheFolder}`]
        running: true
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

        function resume() {
            root.resume();
        }

        function pause() {
            root.pause();
        }

        function togglePlaying() {
            root.togglePlaying();
        }

        function mute() {
            root.mute();
        }

        function unmute() {
            root.unmute();
        }

        function toggleMute() {
            root.toggleMute();
        }

        function setVolume(volume: real) {
            root.setVolume(volume);
        }

        function increaseVolume() {
            root.increaseVolume();
        }

        function decreaseVolume() {
            root.decreaseVolume();
        }
    }
}
