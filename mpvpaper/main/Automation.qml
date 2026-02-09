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
    required property bool automation
    required property string automationMode
    required property real automationTime
    
    required property var random
    required property var nextWallpaper


    /***************************
    * EVENTS
    ***************************/
    onAutomationChanged: {
        if(automation) {
            Logger.d("mpvpaper", "Starting automation timer...");

            timer.restart();
        } else {
            Logger.d("mpvpaper", "Stop automation timer...");

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
        interval: automationTime * 1000
        repeat: true

        onTriggered: {
            switch(root.automationMode) {
                case "random":
                    root.random();
                    break;
                case "alphabetically":
                    root.nextWallpaper();
                    break;
            }
        }
    }
}
