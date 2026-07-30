import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Dank Material Shell plugin entry point
PluginComponent {
    id: root

    Carousel {
        id: carousel
        anchors.fill: parent

        wlrNamespace: "dms:plugins:wallpaperCarousel"
        cfg: pluginData ?? {}
        getFocusedScreen: () => CompositorService.getFocusedScreen()

        defaultWallpaperFolder: {
            const p = SessionData.wallpaperPath;
            if (!p || p.startsWith("#"))
                return Paths.strip(Paths.pictures);
            const lastSlash = p.lastIndexOf('/');
            return lastSlash > 0 ? p.substring(0, lastSlash) : Paths.strip(Paths.pictures);
        }

        currentWallpaperPath: {
            if (SessionData.perMonitorWallpaper && carousel.overlayScreen)
                return SessionData.getMonitorWallpaper(carousel.overlayScreen.name) ?? SessionData.wallpaperPath ?? "";
            return SessionData.wallpaperPath ?? "";
        }

        hasWallpaperConfigured: {
            const p = SessionData.wallpaperPath;
            return !(!p || p.startsWith("#"));
        }

        shellSettingsHint: "Open DankMaterialShell Settings → Wallpaper,\nenable DMS wallpaper management and select a wallpaper."

        onWallpaperPicked: (fullPath, screenName) => {
            if (SessionData.perMonitorWallpaper && screenName)
                SessionData.setMonitorWallpaper(screenName, fullPath);
            else
                SessionData.setWallpaper(fullPath);
        }
    }

    Component.onCompleted: {
        console.info("WallpaperCarousel: daemon loaded — use 'dms ipc call wallpaperCarousel toggle' to open");
    }
}
