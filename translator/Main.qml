import QtQuick
import Quickshell.Io
import qs.Services.UI
import "translatorUtils.js" as TranslatorUtils

Item {
  property var pluginApi: null

  IpcHandler {
    target: "plugin:translator"
    function toggle(language: string, text: string) {
      if (!pluginApi) return;

      pluginApi.withCurrentScreen(screen => {
        var searchText = PanelService.getLauncherSearchText(screen);
        var isInTranslateMode = searchText.startsWith(">translate");

        var newSearchText = ">translate ";
        if (language && language.trim() !== "") {
          var langCode = TranslatorUtils.getLanguageCode(language);
          if (langCode) {
            newSearchText += langCode + " ";
          }
        }

        if (text) {
            newSearchText += text;
        }

        if (!PanelService.isLauncherOpen(screen)) {
          PanelService.openLauncherWithSearch(screen, newSearchText);
        } else if (isInTranslateMode) {
          PanelService.closeLauncher(screen);
        } else {
          PanelService.setLauncherSearchText(screen, newSearchText);
        }
      });
    }
  }
}
