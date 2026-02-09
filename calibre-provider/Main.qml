import QtQuick
import Quickshell.Io
import qs.Services.UI

Item {
  property var pluginApi: null

  IpcHandler {
    target: "plugin:calibre-provider"
    function toggle() {
      pluginApi.withCurrentScreen(screen => {
        var launcherPanel = PanelService.getPanel("launcherPanel", screen);
        if (!launcherPanel)
          return;
        var searchText = launcherPanel.searchText || "";
        var isInCalibreMode = searchText.startsWith(">cb");
        if (!launcherPanel.isPanelOpen) {
          launcherPanel.open();
          launcherPanel.setSearchText(">cb ");
        } else if (isInCalibreMode) {
          launcherPanel.close();
        } else {
          launcherPanel.setSearchText(">cb ");
        }
      });
    }
  }
}
