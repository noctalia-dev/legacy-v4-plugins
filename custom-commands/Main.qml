import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  property var pluginApi: null

  IpcHandler {
    target: "plugin:custom-commands"
    function toggle() {
      pluginApi.withCurrentScreen(screen => {
                                              var searchText = PanelService.getLauncherSearchText(screen);
                                              var isInCmdMode = searchText.startsWith(">run");
                                              if (!PanelService.isLauncherOpen(screen)) {
                                                PanelService.openLauncherWithSearch(screen, ">run ");
                                              } else if (isInCmdMode) {
                                                PanelService.closeLauncher(screen);
                                              } else {
                                                PanelService.setLauncherSearchText(screen, ">run ");
                                              }
                                            }, Settings.data.appLauncher.overviewLayer);
    }
  }
}
