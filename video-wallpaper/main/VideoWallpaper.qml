
import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import QtMultimedia

import qs.Commons
import qs.Services.UI

Variants {
    id: root
    required property var pluginApi


    /***************************
    * PROPERTIES
    ***************************/
    readonly property string currentWallpaper: pluginApi?.pluginSettings?.currentWallpaper || ""
    readonly property bool   enabled:          pluginApi?.pluginSettings?.enabled          || false
    readonly property string fillMode:         pluginApi?.pluginSettings?.fillMode         || pluginApi?.manifest?.metadata?.defaultSettings?.fillMode || ""
    readonly property bool   isMuted:          pluginApi?.pluginSettings?.isMuted          || false
    readonly property bool   isPlaying:        pluginApi?.pluginSettings?.isPlaying        || false
    readonly property int    orientation:      pluginApi?.pluginSettings?.orientation      || 0
    readonly property double volume:           pluginApi?.pluginSettings?.volume           || pluginApi?.manifest?.metadata?.defaultSettings?.volume || 0


    /***************************
    * EVENTS
    ***************************/
    onCurrentWallpaperChanged: {
        if (root.enabled && root.currentWallpaper != "") {
            // Set the isPlaying flag to true.
            pluginApi.pluginSettings.isPlaying = true;
            pluginApi.saveSettings();
        }
    }

    onEnabledChanged: {
        if (root.enabled && root.currentWallpaper != "") {
            // Set the isPlaying flag to true.
            pluginApi.pluginSettings.isPlaying = true;
            pluginApi.saveSettings();
        }
    }


    /***************************
    * COMPONENTS
    ***************************/
    model: Quickshell.screens
    PanelWindow {
        required property var modelData
        screen: modelData
        exclusionMode: ExclusionMode.Ignore

        implicitWidth: modelData.width
        implicitHeight: modelData.height
        visible: root.enabled && root.currentWallpaper != ""

        WlrLayershell.namespace: `noctalia-wallpaper-video-${modelData.name}`
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            right: true
            left: true
        }

        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "black"

            Video {
                id: videoWallpaper
                anchors.fill: parent
                autoPlay: true
                fillMode: {
                    if      (root.fillMode == "fit")     return VideoOutput.PreserveAspectFit;
                    else if (root.fillMode == "crop")    return VideoOutput.PreserveAspectCrop;
                    else if (root.fillMode == "stretch") return VideoOutput.Stretch;
                    else {
                        Logger.e("video-wallpaper", "Unsupported fill mode detected:", root.fillMode);
                    }
                }
                loops: MediaPlayer.Infinite
                muted: root.isMuted
                orientation: root.orientation
                playbackRate: {
                    if(root.isPlaying) return 1.0
                    // Pausing is the same as putting the speed to veryyyyyyy tiny amount
                    else return 0.00000001
                }
                source: {
                    // Make sure to use the correct format
                    if      (root.currentWallpaper == "")                 return ""
                    else if (root.currentWallpaper.startsWith("file://")) return root.currentWallpaper
                    else                                                  return `file://${root.currentWallpaper}`
                }
                volume: root.volume

                onErrorOccurred: (error, errorString) => {
                    Logger.e("video-wallpaper", errorString);
                }
            }
        }
    }
}
