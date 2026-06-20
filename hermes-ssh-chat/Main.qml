import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
  id: root
  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string shortcutName: cfg.toggleShortcutName ?? defaults.toggleShortcutName ?? "hermes-toggle"

  function togglePanel() {
    if (root.pluginApi)
      root.pluginApi.withCurrentScreen(screen => root.pluginApi.togglePanel(screen))
  }

  IpcHandler {
    target: "plugin:hermes-ssh-chat"

    function toggle() {
      root.togglePanel()
    }
    function open() {
      if (root.pluginApi)
        root.pluginApi.withCurrentScreen(screen => root.pluginApi.openPanel(screen))
    }
    function close() {
      if (root.pluginApi)
        root.pluginApi.closePanel()
    }
  }

  // Hyprland global shortcut. The physical key combo is bound in the
  // compositor config to `noctalia:<name>`; only the name is set here.
  // Other compositors fall back to the IPC command (see README).
  GlobalShortcut {
    appid: "noctalia"
    name: root.shortcutName
    description: "Toggle the Hermes SSH terminal panel"
    onPressed: root.togglePanel()
  }
}
