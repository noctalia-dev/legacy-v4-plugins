import QtQuick
import Quickshell.Io

Item {
  property var pluginApi: null

  IpcHandler {
    target: "plugin:clipmask"

    function toggle() {
      if (!pluginApi) return
      pluginApi.withCurrentScreen(function(s) {
        pluginApi.togglePanel(s)
      })
    }

    function open() {
      if (!pluginApi) return
      pluginApi.withCurrentScreen(function(s) {
        pluginApi.openPanel(s)
      })
    }

    function close() {
      if (!pluginApi) return
      pluginApi.withCurrentScreen(function(s) {
        pluginApi.closePanel(s)
      })
    }

    function setMask(mode) {
      if (!pluginApi || !pluginApi.pluginSettings) return
      if (mode === "on") {
        pluginApi.pluginSettings.masked = true
      } else if (mode === "off") {
        pluginApi.pluginSettings.masked = false
      } else if (mode === "toggle") {
        pluginApi.pluginSettings.masked = !pluginApi.pluginSettings.masked
      }
      pluginApi.saveSettings()
    }
  }
}
