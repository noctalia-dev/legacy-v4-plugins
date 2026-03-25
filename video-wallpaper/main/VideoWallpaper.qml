
import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import QtMultimedia

import qs.Commons
import qs.Services.UI

PanelWindow {
    id: root
    required property var pluginApi


    /***************************
    * REQUIRED PROPERTIES
    ***************************/
    // Required properties
    required property var    screenData
    required property string screenName
    required property int    screenWidth
    required property int    screenHeight

    // Monitor specific properties
    readonly property string currentWallpaper: pluginApi?.pluginSettings?.[screenName]?.currentWallpaper ?? ""
    readonly property string fillMode:         pluginApi?.pluginSettings?.[screenName]?.fillMode         ?? pluginApi?.manifest?.metadata?.defaultSettings?.fillMode ?? ""
    readonly property bool   isMuted:          pluginApi?.pluginSettings?.[screenName]?.isMuted          ?? false
    readonly property bool   isPlaying:        pluginApi?.pluginSettings?.[screenName]?.isPlaying        ?? false
    readonly property int    orientation:      pluginApi?.pluginSettings?.[screenName]?.orientation      ?? 0
    readonly property double volume:           pluginApi?.pluginSettings?.[screenName]?.volume           ?? pluginApi?.manifest?.metadata?.defaultSettings?.volume ?? 0

    // Global properties
    readonly property bool enabled: pluginApi?.pluginSettings?.enabled ?? false


    /***************************
    * PROPERTIES
    ***************************/
    screen: screenData
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: screenWidth
    implicitHeight: screenHeight
    visible: enabled && currentWallpaper != ""

    WlrLayershell.namespace: `noctalia-wallpaper-video-${screenName}`
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        right: true
        left: true
    }

    color: "transparent"


    /***************************
    * COMPONENTS
    ***************************/
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
            source: Qt.resolvedUrl(root.currentWallpaper)
            volume: root.volume

            onErrorOccurred: (error, errorString) => {
                Logger.e("video-wallpaper", errorString);
            }
        }
    }
}
