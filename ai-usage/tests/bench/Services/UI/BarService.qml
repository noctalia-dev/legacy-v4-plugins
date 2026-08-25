pragma Singleton
import QtQuick

// BarService stub — right-click settings opener only.
QtObject {
  function openPluginSettings(screen, manifest) {
    console.log("[stub] BarService.openPluginSettings");
  }
}
