import QtQuick
import Quickshell
import qs.Commons

Item {
  id: root
  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings ?? ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  readonly property bool vibrantEnabled: cfg.enabled ?? defaults.enabled ?? false
  readonly property int vibranceValue: cfg.vibranceValue ?? defaults.vibranceValue ?? 512
  // stored 1-based (1 = port 0), converted on use
  readonly property int displayIndex: (cfg.displayIndex ?? defaults.displayIndex ?? 1) - 1

  function buildCmd(value) {
    var parts = ["nvibrant"]
    for (var i = 0; i < root.displayIndex; i++)
      parts.push("0")
    parts.push(value.toString())
    return ["bash", "-lc", parts.join(" ")]
  }

  function applyVibrance(value) {
    Quickshell.execDetached(buildCmd(value))
  }

  function toggle() {
    if (pluginApi) {
      var newEnabled = !vibrantEnabled
      pluginApi.pluginSettings.enabled = newEnabled
      pluginApi.saveSettings()
      applyVibrance(newEnabled ? vibranceValue : 0)
    }
  }

  IpcHandler {
    target: "plugin:nvibrant"
    function toggle() { root.toggle() }
  }
}
