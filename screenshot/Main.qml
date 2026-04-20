import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Services.Noctalia
import "."

Item {
    id: root

    property var pluginApi: null

    ScreenshotHelper {
        id: helper
        pluginApi: root.pluginApi
    }

    IpcHandler {
        target: "plugin:screenshot"

        function takeScreenshot(mode: string): bool {
            return helper.takeScreenshot(mode);
        }
    }
}
