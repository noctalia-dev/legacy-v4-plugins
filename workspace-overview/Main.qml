import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root 
    
    property var pluginApi: null

    IpcHandler {
        target: "plugin:workspace-overview"

        function toggle() {
            root.showOverview();
        }
    }

    // This function will be exposed
    function showOverview() {
        Logger.i("Workspace Overview", "-> Received command to open the Overview");
        if (pluginApi) {
            pluginApi.withCurrentScreen(screen => {
                pluginApi.togglePanel(screen);
            });
        }
    }

    Component.onCompleted: {
        Logger.i("Workspace Overview", "-> [Main] Workspace Overview is ready and listening.");
    }
}
