import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  // ============================================
  // IPC Handlers
  // ============================================
  // The IpcHandler target "plugin:wifi-qr" makes the following commands available:
  //   qs -c noctalia-shell ipc call plugin:wifi-qr toggle
  //   qs -c noctalia-shell ipc call plugin:wifi-qr open
  //   qs -c noctalia-shell ipc call plugin:wifi-qr close
  // This lets you bind a global hotkey, e.g. in Hyprland:
  //   bind = SUPER, Q, exec, qs -c noctalia-shell ipc call plugin:wifi-qr toggle

  IpcHandler {
    target: "plugin:wifi-qr"

    // Toggle the plugin panel on the screen the cursor is currently on
    function toggle() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => {
          root.pluginApi.togglePanel(screen);
        });
      }
    }

    // Open the plugin panel on the screen the cursor is currently on
    function open() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => {
          root.pluginApi.openPanel(screen);
        });
      }
    }

    // Close the plugin panel if it is open
    function close() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => {
          root.pluginApi.closePanel(screen);
        });
      }
    }
  }
}
