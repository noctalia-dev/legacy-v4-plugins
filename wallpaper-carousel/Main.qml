import QtQuick
import qs.Commons
import qs.Services.UI
import qs.Services.Compositor

// Noctalia entry point
Item {
    id: root

    property var pluginApi: null

    Carousel {
        id: carousel
        anchors.fill: parent

        wlrNamespace: "noctalia:plugins:wallpaperCarousel"
        cfg: pluginApi?.pluginSettings ?? {}
        getFocusedScreen: () => CompositorService.getFocusedScreen()

        defaultWallpaperFolder: {
            const screenName = carousel.overlayScreen?.name ?? "";
            const monDir = screenName ? WallpaperService.getMonitorDirectory(screenName) : "";
            if (monDir) return monDir;
            const globalDir = Settings.data.wallpaper.directory;
            if (globalDir) return Settings.preprocessPath(globalDir);
            return Settings.defaultWallpapersDirectory;
        }

        currentWallpaperPath: {
            const screenName = carousel.overlayScreen?.name ?? "";
            return WallpaperService.getWallpaper(screenName) ?? "";
        }

        extraDirectories: {
            if (!Settings.data.wallpaper.enableMultiMonitorDirectories) return [];
            var dirs = [];
            var monDirs = Settings.data.wallpaper.monitorDirectories;
            for (var i = 0; i < (monDirs ? monDirs.length : 0); i++) {
                var d = monDirs[i].directory;
                if (d) {
                    var resolved = Settings.preprocessPath(d);
                    if (resolved !== carousel.wallpaperFolder && dirs.indexOf(resolved) < 0)
                        dirs.push(resolved);
                }
            }
            return dirs;
        }

        hasWallpaperConfigured: {
            const dir = Settings.data.wallpaper.directory;
            return !(!dir || Settings.data.wallpaper.useSolidColor);
        }

        shellSettingsHint: "Open Noctalia Settings → Wallpaper,\nand select a wallpaper directory."

        onWallpaperPicked: (fullPath, screenName) => {
            if (Settings.data.wallpaper.enableMultiMonitorDirectories && screenName)
                WallpaperService.changeWallpaper(fullPath, screenName);
            else
                WallpaperService.changeWallpaper(fullPath);
        }
    }

    Component.onCompleted: {
        console.info("WallpaperCarousel: plugin loaded — use 'qs -c noctalia-shell ipc call wallpaperCarousel toggle' to open");
    }
}
