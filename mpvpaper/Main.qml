import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons
import qs.Services.UI

import "./main"

Item {
    id: root
    property var pluginApi: null

    readonly property bool active: 
        pluginApi.pluginSettings.active || 
        false

    readonly property bool automation:
        pluginApi.pluginSettings.automation ||
        false

    readonly property string automationMode:
        pluginApi.pluginSettings.automationMode ||
        "random"

    readonly property real automationTime:
        pluginApi.pluginSettings.automationTime ||
        5 * 60

    readonly property string currentWallpaper: 
        pluginApi.pluginSettings.currentWallpaper || 
        ""

    readonly property bool hardwareAcceleration:
        pluginApi.pluginSettings.hardwareAcceleration ||
        false

    readonly property bool isMuted:
        pluginApi.pluginSettings.isMuted ||
        false

    readonly property bool isPlaying:
        pluginApi.pluginSettings.isPlaying ||
        false

    readonly property string mpvSocket: 
        pluginApi.pluginSettings.mpvSocket || 
        pluginApi.manifest.metadata.defaultSettings.mpvSocket || 
        "/tmp/mpv-socket"

    readonly property var oldWallpapers:
        pluginApi.pluginSettings.oldWallpapers || 
        ({})

    readonly property string profile:
        pluginApi.pluginSettings.profile ||
        pluginApi.manifest.metadata.defaultSettings.profile ||
        "default"

    readonly property string fillMode:
        pluginApi.pluginSettings.fillMode ||
        pluginApi.manifest.metadata.defaultSettings.fillMode ||
        "fit"
    

    readonly property bool thumbCacheReady:
        pluginApi.pluginSettings.thumbCacheReady ||
        false

    readonly property real volume:
        pluginApi.pluginSettings.volume ||
        100

    readonly property string wallpapersFolder: 
        pluginApi.pluginSettings.wallpapersFolder || 
        pluginApi.manifest.metadata.defaultSettings.wallpapersFolder || 
        "~/Pictures/Wallpapers"


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

    function nextWallpaper() {
        if (wallpapersFolder === "" || folderModel.count === 0) {
            Logger.e("mpvpaper", "Empty wallpapers folder or no files found!");
            return;
        }

        Logger.d("mpvpaper", "Choosing next wallpaper...");

        // Even if the file is not in wallpapers folder, aka -1, it sets the nextIndex to 0 then
        const currentIndex = folderModel.indexOf(root.currentWallpaper);
        const nextIndex = (currentIndex + 1) % folderModel.count;
        const url = folderModel.get(nextIndex, "filePath");
        setWallpaper(url);
    }

    function setWallpaper(path) {
        if (root.pluginApi == null) {
            Logger.e("mpvpaper", "Can't set the wallpaper because pluginApi is null.");
            return;
        }

        pluginApi.pluginSettings.currentWallpaper = path;
        pluginApi.saveSettings();
    }


    /***************************
    * HELPER FUNCTIONALITY
    ***************************/
    function getThumbPath(videoPath: string): string {
        return thumbnails.getThumbPath(videoPath);
    }

    // Get thumbnail url based on video name
    function getThumbUrl(videoPath: string): string {
        return thumbnails.getThumbUrl(videoPath);
    }

    function thumbRegenerate() {
        thumbnails.thumbRegenerate();
    }


    /***************************
    * COMPONENTS
    ***************************/
    Mpvpaper {
        // Contains all the mpvpaper specific functionality
        id: mpvpaper
        pluginApi: root.pluginApi

        active: root.active
        currentWallpaper: root.currentWallpaper
        hardwareAcceleration: root.hardwareAcceleration
        isMuted: root.isMuted
        isPlaying: root.isPlaying
        mpvSocket: root.mpvSocket
        profile: root.profile
        fillMode: root.fillMode
        volume: root.volume

        thumbnails: thumbnails
        innerService: innerService
    }

    Thumbnails {
        // Contains all the thumbnail specific functionality
        id: thumbnails
        pluginApi: root.pluginApi

        currentWallpaper: root.currentWallpaper
        thumbCacheReady: root.thumbCacheReady

        folderModel: folderModel
    }

    InnerService {
        // Contains all the save / load functionality for this to work with noctalia
        id: innerService
        pluginApi: root.pluginApi

        currentWallpaper: root.currentWallpaper
        oldWallpapers: root.oldWallpapers

        thumbnails: thumbnails
    }

    Automation {
        id: automation
        pluginApi: root.pluginApi

        automation: root.automation
        automationMode: root.automationMode
        automationTime: root.automationTime

        random: root.random
        nextWallpaper: root.nextWallpaper
    }


    FolderListModel {
        id: folderModel
        folder: root.pluginApi == null ? "" : "file://" + root.wallpapersFolder
        nameFilters: ["*.mp4", "*.avi", "*.mov"]
        showDirs: false

        onStatusChanged: {
            if (folderModel.status == FolderListModel.Ready) {
                // Generate all the thumbnails for the folder
                thumbnails.thumbGeneration();
            }
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

        // Current wallpaper
        function setWallpaper(path: string) {
            root.setWallpaper(path);
        }

        function getWallpaper(): string {
            return root.currentWallpaper;
        }

        // Active
        function setActive(isActive: bool) {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.active = isActive;
            root.pluginApi.saveSettings();
        }

        function getActive(): bool {
            return root.active;
        }

        function toggleActive() {
            setActive(!root.active);
        }

        // Is playing
        function resume() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isPlaying = true;
            root.pluginApi.saveSettings();
        }

        function pause() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isPlaying = false;
            root.pluginApi.saveSettings();
        }

        function togglePlaying() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isPlaying = !root.isPlaying;
            root.pluginApi.saveSettings();
        }

        // Mute / unmute
        function mute() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isMuted = true;
            root.pluginApi.saveSettings();
        }

        function unmute() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isMuted = false;
            root.pluginApi.saveSettings();
        }

        function toggleMute() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isMuted = !root.isMuted;
            root.pluginApi.saveSettings();
        }

        // Volume
        function setVolume(volume: real) {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.volume = volume;
            root.pluginApi.saveSettings();
        }

        function increaseVolume() {
            setVolume(root.volume + Settings.data.audio.volumeStep);
        }

        function decreaseVolume() {
            setVolume(root.volume - Settings.data.audio.volumeStep);
        }

        // Hardware acceleration
        function setHardwareAcceleration(active: bool) {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.hardwareAcceleration = active;
            root.pluginApi.saveSettings();
        }

        function toggleHardwareAcceleration() {
            setHardwareAcceleration(!root.hardwareAcceleration);
        }
    }
}
