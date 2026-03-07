import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

import "./common"
import "./main"
import "./migrations"

Item {
    id: root
    property var pluginApi: null


    /***************************
    * PROPERTIES
    ***************************/
    readonly property string wallpapersFolder: pluginApi?.pluginSettings?.wallpapersFolder || pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder || ""

    readonly property string thumbCacheFolderPath: ImageCacheService.wpThumbDir + "video-wallpaper"


    /***************************
    * WALLPAPER FUNCTIONALITY
    ***************************/
    function random(screen) {
        functions.random(screen);
    }

    function clear(screen) {
        functions.clear(screen);
    }

    function nextWallpaper(screen) {
        functions.nextWallpaper(screen);
    }

    function setWallpaper(path, screen) {
        functions.setWallpaper(path, screen);
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
    Variants {
        model: Quickshell.screens

        Item {
            id: screenItem
            required property var modelData

            readonly property string name:      modelData.name
            readonly property int screenWidth:  modelData.width
            readonly property int screenHeight: modelData.height

            readonly property string activeBackend: root.pluginApi?.pluginSettings?.activeBackend || root.pluginApi?.manifest?.metadata?.defaultSettings?.activeBackend || ""

            /***************************
            * FUNCTIONALITY
            ***************************/
            function reloadWallpaperLoader() {
                wallpaperLoader.active = false;
                wallpaperLoader.active = true;
            }


            /***************************
            * EVENTS
            ***************************/
            onActiveBackendChanged: {
                reloadWallpaperLoader();
            }


            /***************************
            * BACKEND COMPONENTS
            ***************************/
            Timer {
                id: wallpaperLoaderStartupTimer
                interval: 500
                running: true

                onTriggered: {
                    screenItem.reloadWallpaperLoader();
                }
            }

            Loader {
                id: wallpaperLoader
                active: false
                asynchronous: true

                sourceComponent: {
                    switch (screenItem.activeBackend) {
                        case "mpvpaper":
                            return mpvpaper;
                        case "qt6-multimedia":
                            return qtmultimedia;
                        default:
                            Logger.e("video-wallpaper", "No active backend.");
                    }
                }

                onStatusChanged: {
                    // Most likely if status is error and active backend is qt6-multimedia, is that qt6-multimedia wasn't found.
                    if (status === Loader.Error && screenItem.activeBackend === "qt6-multimedia") {
                        ToastService.showError(root.pluginApi?.tr("main.no_backend_found", {"backend": "Qt6-multimedia"}) || "Qt6-multimedia wasn't found!");
                    }
                }
            }

            Component {
                id: qtmultimedia

                VideoWallpaper {
                    pluginApi: root.pluginApi

                    screenData:   screenItem.modelData
                    screenName:   screenItem.name
                    screenWidth:  screenItem.screenWidth
                    screenHeight: screenItem.screenHeight
                }
            }

            Component {
                id: mpvpaper

                Mpvpaper {
                    pluginApi: root.pluginApi

                    screenData:   screenItem.modelData
                    screenName:   screenItem.name
                    screenWidth:  screenItem.screenWidth
                    screenHeight: screenItem.screenHeight
                }
            }


            /***************************
            * COLOR GENERATION
            ***************************/
            ColorGeneration {
                id: colorgen
                pluginApi: root.pluginApi

                screenName: screenItem.name

                getThumbPath:         root.getThumbPath
                thumbCacheFolderPath: root.thumbCacheFolderPath

                folderModel:      rootFolderModel
                thumbFolderModel: rootThumbFolderModel
            }


            /***************************
            * NOCTALIA WALLPAPER
            ***************************/
            InnerService {
                pluginApi: root.pluginApi

                screenName: screenItem.name

                getThumbPath:     root.getThumbPath
                thumbFolderModel: rootThumbFolderModel

                onOldWallpapersSaved: {
                    // When the old wallpapers are saved and done, inform the color gen.
                    colorgen.oldWallpapersSaved = true;
                }
            }
        }
    }

    Thumbnails {
        id: thumbnails
        pluginApi: root.pluginApi

        getThumbPath:         root.getThumbPath
        thumbCacheFolderPath: root.thumbCacheFolderPath

        folderModel:      rootFolderModel
        thumbFolderModel: rootThumbFolderModel
    }

    Automation {
        id: automation
        pluginApi: root.pluginApi

        onRandom:        (screen) => root.random(screen);
        onNextWallpaper: (screen) => root.nextWallpaper(screen);
    }

    Migrations {
        id: migrations
        pluginApi: root.pluginApi
    }

    Functions {
        id: functions
        pluginApi: root.pluginApi

        folderModel: rootFolderModel
    }

    // Folder models
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

        random: root.random
        clear: root.clear
        setWallpaper: root.setWallpaper
    }
}
