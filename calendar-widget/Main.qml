import QtQuick
import Quickshell

Item {
    id: root
    
    property var pluginApi: null

    // This is the crucial part that hooks into Noctalia's UI
    Component.onCompleted: {
        if (pluginApi && pluginApi.registerDesktopWidget) {
            pluginApi.registerDesktopWidget(
                "calendar-widget",      // Unique ID for the widget
                "Monthly Calendar",     // Display Name in the UI
                "calendar-month",       // Icon name
                Qt.resolvedUrl("Desktop.qml") // Path to the visual file
            );
            console.log("Calendar widget registered to DesktopRegistry");
        } else {
            console.log("Failed to register: pluginApi.registerDesktopWidget not found");
        }
    }
}
