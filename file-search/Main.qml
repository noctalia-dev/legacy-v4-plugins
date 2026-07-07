import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  property var pluginApi: null

  Component.onCompleted: {
    if (pluginApi) {
      Logger.i("FileSearch", "Plugin initialized");
    }
  }

  IpcHandler {
    target: "plugin:file-search"

    // Toggle launcher in file search mode
    function toggle() {
      if (!pluginApi) return;

      pluginApi.withCurrentScreen(screen => {
        var searchText = PanelService.getLauncherSearchText(screen) || "";
        var isInFileMode = searchText.startsWith(">file");

        if (!PanelService.isLauncherOpen(screen)) {
          // Launcher closed - open with file search
          Logger.i("FileSearch", "Opening launcher in file search mode");
          PanelService.openLauncherWithSearch(screen, ">file ");
        } else if (isInFileMode) {
          // Already in file mode - close launcher
          Logger.i("FileSearch", "Closing launcher (toggle off)");
          PanelService.closeLauncher(screen);
        } else {
          // Launcher open but different mode - switch to file search
          Logger.i("FileSearch", "Switching to file search mode");
          PanelService.setLauncherSearchText(screen, ">file ");
        }
      });
    }

    // Open launcher with file search and specific query
    function search(query: string) {
      if (!pluginApi) return;

      pluginApi.withCurrentScreen(screen => {
        var searchQuery = query || "";
        Logger.i("FileSearch", "Opening launcher with search query:", searchQuery);

        PanelService.openLauncherWithSearch(screen, ">file " + searchQuery);
      });
    }
  }
}
