import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings ?? ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  readonly property bool saveWidgets: cfg.saveWidgets ?? defaults.saveWidgets ?? true
  readonly property bool loadWidgets: cfg.loadWidgets ?? defaults.loadWidgets ?? true

  // { wallpaper: monitorWidgets }
  property var wallpaperMonitorWidgets: cfg.monitorWidgets ?? ({})

  property bool loading: false

  // Save widgets
  Connections {
    id: saveConnection
    enabled: root.saveWidgets && !root.loading
    target: Settings.data.desktopWidgets

    property string previousMonitorWidgets

    Component.onCompleted: previousMonitorWidgets = JSON.stringify(Settings.data.desktopWidgets.monitorWidgets)

    function onMonitorWidgetsChanged() {
      // Guard for when the settings changes to other stuff than monitorWidgets
      if (previousMonitorWidgets === JSON.stringify(Settings.data.desktopWidgets.monitorWidgets)) return;
      previousMonitorWidgets = JSON.stringify(Settings.data.desktopWidgets.monitorWidgets);

      Logger.d("SavedDesktopWidgets", "Saving the desktop widgets...");

      // The monitor widgets have changed
      for (let screen of Quickshell.screens) {
        let wallpaper = WallpaperService.getWallpaper(screen.name);
        let monitorWidgetsIndex = Settings.data.desktopWidgets.monitorWidgets.findIndex((m) => m.name === screen.name);

        Logger.d("SavedDesktopWidgets", "Saving for wallpaper:", wallpaper);

        // The monitor widgets for this specific screen, create a deep copy to remove any references
        let monitorWidgets = JSON.parse(JSON.stringify(Settings.data.desktopWidgets.monitorWidgets[monitorWidgetsIndex]));

        if (root.wallpaperMonitorWidgets[wallpaper] === undefined) {
          // Create the list as in the shell and add the monitorWidgets
          root.wallpaperMonitorWidgets[wallpaper] = [];

          root.wallpaperMonitorWidgets[wallpaper].push(monitorWidgets);
        } else {
          // Check if this wallpaperMonitorWidgets[wallpaper] has a screen with these widgets.
          let widgetScreenIndex = root.wallpaperMonitorWidgets[wallpaper].findIndex((m) => m.name === screen.name);
          if (widgetScreenIndex === -1) {
            root.wallpaperMonitorWidgets[wallpaper].push(monitorWidgets);
          } else {
            root.wallpaperMonitorWidgets[wallpaper][widgetScreenIndex] = monitorWidgets;
          }
        }
      }

      // Lastly save the changes to disk
      if (root.pluginApi?.pluginSettings == undefined) {
        Logger.e("SavedDesktopWidgets", "Could not save, pluginApi is null!");
        return;
      }
      root.pluginApi.pluginSettings.monitorWidgets = root.wallpaperMonitorWidgets;
      root.pluginApi.saveSettings();
    }
  }

  // Load widgets
  Connections {
    enabled: root.loadWidgets
    target: WallpaperService
    function onWallpaperChanged(screenName: string, path: string) {
      // Guard to not set off the save when loading
      root.loading = true;

      // Check if the wallpaperMonitorWidgets includes the current wallpaper being set
      if (root.wallpaperMonitorWidgets[path] !== undefined) {
        Logger.d("SavedDesktopWidgets", "Loading widgets on screen:", screenName, ", for wallpaper:", path);

        let screenIndex = Settings.data.desktopWidgets.monitorWidgets.findIndex((m) => m.name === screenName);
        let widgetScreenIndex = root.wallpaperMonitorWidgets[path].findIndex((m) => m.name === screenName);

        if (widgetScreenIndex !== -1) {
          // Create a deep copy to remove any references
          let widget = JSON.parse(JSON.stringify(root.wallpaperMonitorWidgets[path][widgetScreenIndex]));

          if (screenIndex === -1) {
            // If the monitorWidgets do not have widgets with this monitor name
            Settings.data.desktopWidgets.monitorWidgets.push(widget);
          } else {
            // Replace the monitorWidget specific index since it already exists.
            Settings.data.desktopWidgets.monitorWidgets[screenIndex] = widget;
          }
        }
      }

      // Update the save cached property
      saveConnection.previousMonitorWidgets = JSON.stringify(Settings.data.desktopWidgets.monitorWidgets);

      root.loading = false;
    }
  }
}
