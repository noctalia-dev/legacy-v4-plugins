import QtQuick
import Quickshell.Io
import "./Services"

Item {
  property var pluginApi: null

  onPluginApiChanged: {
    KDEConnect.setMainDevice(pluginApi?.pluginSettings?.mainDeviceId || "")
  }

  IpcHandler {
    target: "plugin:androidconnect"
    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => {
          pluginApi.openPanel(screen);
        });
      }
    }
  }
}
