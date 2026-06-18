import QtQuick
import Quickshell.Io

Item {
  property var pluginApi: null

  IpcHandler {
    target: "plugin:launcher-pass"

    function toggle() {
      if (!pluginApi) return;
      pluginApi.withCurrentScreen(screen => {
        pluginApi.toggleLauncher(screen);
      });
    }
  }
}
