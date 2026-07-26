import QtQuick
import Quickshell.Io
import qs.Services.UI

Item {
  property var pluginApi: null

  IpcHandler {
    target: "plugin:simple-notes"
    function togglePanel() {
      pluginApi?.withCurrentScreen(s => pluginApi.togglePanel(s))
    }
  }
}
