import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null
    property bool isOpen: false

    IpcHandler {
        target: "plugin:somnus"
        function toggle() {
            var screen = null
            try { var screens = Quickshell.screens; if (screens && screens.length > 0) screen = screens[0] }
            catch (e) {}
            if (!screen && pluginApi?.panelOpenScreen) screen = pluginApi.panelOpenScreen
            Logger.i("Somnus", "IPC toggle: screen=" + (screen?.name ?? "null") + ", type=" + typeof screen + ", screens.len=" + (Quickshell.screens?.length ?? -1))
            root.togglePanel(screen)
        }
    }

    function togglePanel(screen) {
        if (isOpen) closePanel()
        else openPanel(screen)
    }

    function openPanel(screen) {
        if (windowLoader.active) return
        Logger.i("Somnus", "openPanel called, screen=" + (screen?.name ?? "null") + ", pluginApi=" + (root.pluginApi !== null))
        windowLoader.setSource("SomnusWindow.qml", {
            "screenRef": screen,
            "pluginApi": root.pluginApi
        })
        windowLoader.active = true
        isOpen = true
    }

    function closePanel() {
        windowLoader.active = false
        isOpen = false
    }

    Loader {
        id: windowLoader
        active: false
        asynchronous: false

        onLoaded: {
            Logger.i("Somnus", "Loader onLoaded fired, item=" + (item !== null) + ", item.width=" + (item?.width ?? -1))
            item.closeRequested.connect(root.closePanel)
        }
        onStatusChanged: {
            Logger.i("Somnus", "Loader status=" + status + " (Loaded=" + Loader.Loaded + ")")
        }
    }
}