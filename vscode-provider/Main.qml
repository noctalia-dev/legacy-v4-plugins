import QtQuick
import Quickshell.Io

Item {
  property var pluginApi: null

  IpcHandler {
    target: "plugin:vscode-provider"
    function toggle() {
      pluginApi.withCurrentScreen(screen => {
        pluginApi.toggleLauncher(screen);
      });
    }
  }
}
