import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "sources"

Item {
    id: root

    property var pluginApi: null
    property var wallpaperTask: null
    readonly property string homeDir: Quickshell.env("HOME") || ""

    function todayString() {
        return new Date().toISOString().slice(0, 10);
    }

    function normalizeLocale(rawLocale) {
        const locale = (rawLocale || "").trim().toLowerCase().replace("_", "-");
        return locale.length > 0 ? locale : "en-us";
    }

    function httpGet(url) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url, false);
        xhr.send();

        if (xhr.status >= 200 && xhr.status < 300) {
            return xhr.responseText;
        }

        throw new Error(`HTTP ${xhr.status} while fetching ${url}`);
    }

    BingSource {
        id: bingSource
    }

    NasaSource {
        id: nasaSource
    }

    IpcHandler {
        target: "plugin:daily-wallpaper"

        function refresh() {
            if (root.wallpaperTask) {
                Logger.d("DailyWallpaperPlugin", "Skipping refresh: wallpaper task already running");
                return;
            }
            root.checkAndFetchWallpaper();
        }
    }

    function runTaskCommand(command) {
        Logger.d("DailyWallpaperPlugin", "Running task command: " + command.join(" "));
        fetchWallpaper.exec({
            command: command
        });
    }

    function getTaskStepDefinition(task) {
        return {
            mkdir: {
                command: ["mkdir", "-p", task.wpDir],
                next: () => "checkExists"
            },
            checkExists: {
                command: ["test", "-f", task.wpFile],
                next: exitCode => exitCode === 0 ? "applyWallpaper" : "downloadPrimary"
            },
            downloadPrimary: {
                command: ["curl", "-fsSL", "-o", task.wpFile, task.primaryUrl],
                next: exitCode => {
                    if (exitCode === 0) {
                        task.downloaded = true;
                        return "applyWallpaper";
                    }
                    return task.fallbackUrl.length > 0 ? "downloadFallback" : "error:Primary wallpaper download failed";
                }
            },
            downloadFallback: {
                command: ["curl", "-fsSL", "-o", task.wpFile, task.fallbackUrl],
                next: exitCode => {
                    if (exitCode === 0) {
                        task.downloaded = true;
                        return "applyWallpaper";
                    }
                    return "error:Fallback wallpaper download failed";
                }
            },
            applyWallpaper: {
                command: ["qs", "-c", "noctalia-shell", "ipc", "call", "wallpaper", "set", task.wpFile],
                next: () => "cleanup"
            },
            cleanup: {
                command: ["find", task.wpDir, "-name", `${task.prefix}-*.jpg`, "-type", "f", "-mtime", "+5", "-delete"],
                next: () => "done"
            }
        }[task.step] || null;
    }

    function executeCurrentTaskCommand() {
        if (!root.wallpaperTask) {
            return;
        }

        const task = root.wallpaperTask;
        const stepDef = getTaskStepDefinition(task);
        if (!stepDef) {
            failWallpaperTask(`Unknown wallpaper task step: ${task.step}`);
            return;
        }
        runTaskCommand(stepDef.command);
    }

    function failWallpaperTask(message) {
        Logger.e("DailyWallpaperPlugin", message);
        root.wallpaperTask = null;
    }

    function finishWallpaperTask(exitCode) {
        if (exitCode === 0) {
            if (root.wallpaperTask?.downloaded) {
                Logger.i("DailyWallpaperPlugin", "Wallpaper fetched successfully");
            } else {
                Logger.i("DailyWallpaperPlugin", "Using cached wallpaper");
            }
        } else {
            Logger.e("DailyWallpaperPlugin", `Cleanup failed (exit ${exitCode})`);
        }
        root.wallpaperTask = null;
    }

    function handleWallpaperTaskExit(exitCode) {
        const task = root.wallpaperTask;
        if (!task) {
            return;
        }

        const stepDef = getTaskStepDefinition(task);
        if (!stepDef) {
            failWallpaperTask(`Unknown wallpaper task step: ${task.step}`);
            return;
        }

        const outcome = stepDef.next(exitCode);
        if (outcome === "done") {
            finishWallpaperTask(exitCode);
            return;
        }

        if (outcome.startsWith("error:")) {
            failWallpaperTask(outcome.slice(6));
            return;
        }

        task.step = outcome;
        executeCurrentTaskCommand();
    }

    function runWallpaperDownload(prefix, dateString, primaryUrl, fallbackUrl) {
        if (!homeDir) {
            throw new Error("HOME environment variable is not available");
        }

        const wpDir = `${homeDir}/.config/noctalia/plugins/daily-wallpaper/downloads`;
        const wpFile = `${wpDir}/${prefix}-${dateString}.jpg`;

        root.wallpaperTask = {
            prefix: prefix,
            wpDir: wpDir,
            wpFile: wpFile,
            primaryUrl: primaryUrl,
            fallbackUrl: fallbackUrl || "",
            downloaded: false,
            step: "mkdir"
        };

        executeCurrentTaskCommand();
    }

    function runSourceDownload(sourceKey, locale, dateString) {
        const sourceResolver = sourceKey === "nasa" ? nasaSource : bingSource;
        const resolved = sourceResolver.resolveDownload(locale, root.httpGet);
        runWallpaperDownload(
            resolved.prefix,
            dateString,
            resolved.primaryUrl,
            resolved.fallbackUrl
        );
    }

    function checkAndFetchWallpaper() {
        if (root.wallpaperTask) {
            Logger.d("DailyWallpaperPlugin", "Skipping check: wallpaper task already running");
            return;
        }

        Logger.i("DailyWallpaperPlugin", "Wallpaper check started");

        const cfg = pluginApi?.pluginSettings || ({});
        const defaults = pluginApi?.manifest?.metadata?.defaultSettings || ({});
        const source = cfg.source ?? defaults.source ?? "bing";
        const locale = normalizeLocale(cfg.locale ?? defaults.locale ?? Qt.locale().name);
        const dateString = todayString();

        try {
            runSourceDownload(source, locale, dateString);
        } catch (error) {
            Logger.e("DailyWallpaperPlugin", `Wallpaper fetch setup failed: ${error}`);
        }
    }

    Component.onCompleted: {
        Logger.d("DailyWallpaperPlugin", "Plugin started");
        startupDelay.start();
        periodicTimer.start();
    }

    Timer {
        id: startupDelay
        interval: 10000
        repeat: false
        onTriggered: root.checkAndFetchWallpaper()
    }

    Timer {
        id: periodicTimer
        interval: 10 * 60 * 1000
        repeat: true
        onTriggered: root.checkAndFetchWallpaper()
    }

    Process {
        id: fetchWallpaper
        running: false
        onExited: (exitCode, _exitStatus) => {
            if (!root.wallpaperTask) {
                if (exitCode === 0) {
                    Logger.i("DailyWallpaperPlugin", "Wallpaper check completed");
                } else {
                    Logger.e("DailyWallpaperPlugin", `Wallpaper fetch failed (exit ${exitCode})`);
                }
                return;
            }

            handleWallpaperTaskExit(exitCode);
        }
    }
}
