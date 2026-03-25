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
    readonly property bool   automation:      pluginApi?.pluginSettings?.automation      ?? false
    readonly property string automationMode:  pluginApi?.pluginSettings?.automationMode  ?? pluginApi?.manifest?.metadata?.defaultSettings?.automationMode ?? ""
    readonly property real   automationTime:  pluginApi?.pluginSettings?.automationTime  ?? pluginApi?.manifest?.metadata?.defaultSettings?.automationTime ?? 0
    readonly property bool   monitorSpecific: pluginApi?.pluginSettings?.monitorSpecific ?? false

    signal random(screenName: var)
    signal nextWallpaper(screenName: var)

    /***************************
    * EVENTS
    ***************************/
    onAutomationChanged: {
        if(automation) {
            Logger.d("video-wallpaper", "Starting automation timer...");

            timer.restart();
        } else {
            Logger.d("video-wallpaper", "Stop automation timer...");

            timer.stop();
        }
    }
    
    onAutomationTimeChanged: {
        if(automation) {
            timer.restart();
        }
    }


    /***************************
    * COMPONENTS
    ***************************/
    Timer {
        id: timer
        interval: root.automationTime * 1000
        repeat: true

        onTriggered: {
            switch(root.automationMode) {
                case "random":
                    if(root.monitorSpecific) {
                        for(const screen of Quickshell.screens) {
                            root.random(screen.name);
                        }
                    } else {
                        root.random(undefined);
                    }
                    break;
                case "alphabetically":
                    if(root.monitorSpecific) {
                        for(const screen of Quickshell.screens) {
                            root.nextWallpaper(screen.name);
                        }
                    } else {
                        root.nextWallpaper(undefined);
                    }
                    break;
            }
        }
    }
}
