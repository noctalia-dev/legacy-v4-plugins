import QtQuick
import Quickshell.Io
import qs.Services.UI

Item {
  property var pluginApi: null

  Component.onCompleted: {
    if (pluginApi) {
      // Initialize settings if they don't exist
      if (pluginApi.pluginSettings.scratchpadContent === undefined) {
        pluginApi.pluginSettings.scratchpadContent = "";
        pluginApi.saveSettings();
      }
      if (pluginApi.pluginSettings.panelWidth === undefined) {
        pluginApi.pluginSettings.panelWidth = 600;
        pluginApi.saveSettings();
      }
      if (pluginApi.pluginSettings.panelHeight === undefined) {
        pluginApi.pluginSettings.panelHeight = 400;
        pluginApi.saveSettings();
      }
      if (pluginApi.pluginSettings.fontSize === undefined) {
        pluginApi.pluginSettings.fontSize = 14;
        pluginApi.saveSettings();
      }
    }
  }

  IpcHandler {
    target: "plugin:notes-scratchpad"
    function togglePanel() { 
      pluginApi?.withCurrentScreen(s => pluginApi.togglePanel(s)) 
    }
  }
}
