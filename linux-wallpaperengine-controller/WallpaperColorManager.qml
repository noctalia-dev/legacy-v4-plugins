import QtQuick
import Quickshell
import Quickshell.Io

import "helpers/shared/ColorCacheHelpers.js" as ColorCacheHelpers
import "helpers/runtime/WallpaperColorHelpers.js" as WallpaperColorHelpers

import qs.Commons
import qs.Services.UI
import qs.Services.Theming

Item {
  id: root

  // Dependencies from parent.
  required property var pluginApi
  required property var cfg
  required property var defaults
  required property bool engineAvailable
  required property int defaultFps
  required property string defaultClamp
  required property string defaultScaling
  required property var normalizedPathFn
  required property var wallpaperIdFromPathFn
  required property var getWallpaperPropertiesFn
  required property var getScreenConfigFn

  // Public state.
  property bool applyingWallpaperColors: false
  readonly property string activeColorMonitor: String(Settings.data.colorSchemes.monitorForColors || Quickshell.screens[0]?.name || "")
  readonly property bool wallpaperColorsEnabled: !!Settings.data.colorSchemes.useWallpaperColors
  readonly property bool wallpaperColorDarkMode: !!Settings.data.colorSchemes.darkMode
  readonly property string wallpaperColorGenerationMethod: String(Settings.data.colorSchemes.generationMethod || "")

  // Internal state.
  property var pendingWallpaperColorRequest: null
  property var pendingWallpaperColorReuseRequest: null
  property string wallpaperColorScreenName: ""
  property string wallpaperColorScaling: "fill"
  property string wallpaperColorRequestPath: ""
  property string wallpaperColorScreenshotPath: ""
  property bool wallpaperColorNotify: false

  // Timer intervals (named constants).
  readonly property int colorStartDelay: 1500
  readonly property int colorSyncDelay: 250
  readonly property int startupResyncDelay: 2200

  // Public API.
  function scheduleStartupResync() {
    startupWallpaperColorResyncTimer.restart();
  }

  function currentWallpaperColorMode() {
    return Settings.data.colorSchemes.darkMode ? "dark" : "light";
  }

  function applyWallpaperColorsFromScreenshot(screenshotPath) {
    if (String(screenshotPath || "").trim().length === 0) {
      return;
    }

    TemplateProcessor.processWallpaperColors(screenshotPath, currentWallpaperColorMode());
  }

  function screenshotPathForWallpaper(path, screenName = "") {
    const pluginId = pluginApi?.manifest?.id || pluginApi?.pluginId || "linux-wallpaperengine-controller";
    return ColorCacheHelpers.screenshotPathForWallpaper(Settings.cacheDir, pluginId, wallpaperIdFromPathFn(path), screenName);
  }

  function wallpaperColorScreenshotEntry(screenName) {
    return ColorCacheHelpers.cachedScreenshotEntry(pluginApi?.pluginSettings?.wallpaperColorScreenshots, screenName);
  }

  function canReuseWallpaperColorScreenshot(screenName, wallpaperPath, scaling) {
    return ColorCacheHelpers.canReuseScreenshot(
      pluginApi?.pluginSettings?.wallpaperColorScreenshots,
      screenName,
      wallpaperPath,
      scaling,
      normalizedPathFn,
      defaultScaling
    );
  }

  function startWallpaperColorCapture(wallpaperPath, targetScreenName, targetScaling, notify = false) {
    const screenshotPath = screenshotPathForWallpaper(wallpaperPath, targetScreenName);
    const pluginDir = pluginApi?.pluginDir || "";
    const scriptPath = pluginDir + "/scripts/capture-wallpaper-colors.sh";
    const wallpaperProperties = getWallpaperPropertiesFn(wallpaperPath);
    const resolvedScaling = targetScaling.length > 0 ? targetScaling : "fill";
    const command = WallpaperColorHelpers.buildCaptureCommand(
      scriptPath,
      screenshotPath,
      "",
      defaultFps,
      defaultClamp,
      targetScreenName,
      wallpaperPath,
      resolvedScaling,
      wallpaperProperties
    );

    applyingWallpaperColors = true;
    wallpaperColorRequestPath = wallpaperPath;
    wallpaperColorScreenshotPath = screenshotPath;
    wallpaperColorScreenName = targetScreenName;
    wallpaperColorScaling = resolvedScaling;
    wallpaperColorNotify = !!notify;
    wallpaperColorProcess.command = command;
    wallpaperColorProcess.running = true;

    Logger.i("LWEController", "Generating screenshot for wallpaper color extraction", "path=", wallpaperPath, "screen=", targetScreenName, "scaling=", wallpaperColorScaling, "output=", screenshotPath);
  }

  function saveWallpaperColorScreenshot(screenName, screenshotPath, wallpaperPath, scaling) {
    if (!pluginApi || screenName.length === 0 || screenshotPath.length === 0) {
      return;
    }

    pluginApi.pluginSettings.wallpaperColorScreenshots[screenName] = WallpaperColorHelpers.buildScreenshotCacheEntry(
      screenshotPath,
      wallpaperPath,
      scaling
    );
    pluginApi.saveSettings();

    const pluginDir = pluginApi?.pluginDir || "";
    const scriptPath = pluginDir + "/scripts/update-noctalia-wallpapers-cache.sh";
    Quickshell.execDetached(["bash", scriptPath, screenName, screenshotPath]);
  }

  function scheduleCachedWallpaperColorsForMonitor(reason = "") {
    if (!wallpaperColorsEnabled) {
      return;
    }

    const screenName = activeColorMonitor;
    if (screenName.length === 0) {
      return;
    }

    const screenCfg = getScreenConfigFn(screenName);
    const request = WallpaperColorHelpers.buildActiveMonitorSyncRequest(screenName, screenCfg, defaultScaling, normalizedPathFn);
    if (!request) {
      Logger.d("LWEController", "Skip wallpaper color sync: no configured wallpaper for active monitor", "screen=", screenName, "reason=", reason);
      return;
    }

    Logger.d("LWEController", "Scheduling wallpaper color sync for current active monitor wallpaper", "screen=", request.screenName, "path=", request.path, "scaling=", request.scaling, "reason=", reason);
    scheduleWallpaperColorsFromPath(request.path, request);
  }

  function applyWallpaperColorsFromPath(path, options = null) {
    const request = WallpaperColorHelpers.normalizeWallpaperColorRequest(
      path,
      options,
      defaultScaling,
      Quickshell.screens[0]?.name || "",
      normalizedPathFn
    );
    const wallpaperPath = request.path;
    const targetScreenName = request.screenName;
    const targetScaling = request.scaling;
    const notify = request.notify;
    if (!engineAvailable) {
      if (notify) {
        ToastService.showWarning(pluginApi?.tr("panel.title"), pluginApi?.tr("toast.wallpaperColorsEngineUnavailable"), "alert-circle");
      }
      return;
    }

    if (wallpaperPath.length === 0) {
      if (notify) {
        ToastService.showWarning(pluginApi?.tr("panel.title"), pluginApi?.tr("toast.wallpaperColorsNoSelection"), "alert-circle");
      }
      return;
    }

    if (targetScreenName.length === 0) {
      if (notify) {
        ToastService.showError(pluginApi?.tr("panel.title"), pluginApi?.tr("toast.wallpaperColorsFailed"), "alert-circle");
      }
      return;
    }

    if (applyingWallpaperColors) {
      return;
    }

    if (canReuseWallpaperColorScreenshot(targetScreenName, wallpaperPath, targetScaling)) {
      const entry = wallpaperColorScreenshotEntry(targetScreenName);
      const cachedPath = normalizedPathFn(entry?.path || "");
      const pluginDir = pluginApi?.pluginDir || "";
      const scriptPath = pluginDir + "/scripts/check-file-exists.sh";
      pendingWallpaperColorReuseRequest = WallpaperColorHelpers.buildReuseCheckRequest(
        targetScreenName,
        wallpaperPath,
        targetScaling,
        cachedPath,
        notify
      );
      reusedWallpaperColorCheckProcess.command = ["bash", scriptPath, cachedPath];
      reusedWallpaperColorCheckProcess.running = true;
      return;
    }
    startWallpaperColorCapture(wallpaperPath, targetScreenName, targetScaling, notify);
  }

  function scheduleWallpaperColorsFromPath(path, options = null) {
    const request = WallpaperColorHelpers.normalizeWallpaperColorRequest(
      path,
      options,
      defaultScaling,
      Quickshell.screens[0]?.name || "",
      normalizedPathFn
    );
    if (request.path.length === 0) {
      return;
    }

    pendingWallpaperColorRequest = request;
    wallpaperColorStartTimer.restart();
    Logger.d("LWEController", "Scheduled wallpaper color extraction", "path=", pendingWallpaperColorRequest.path, "screen=", pendingWallpaperColorRequest.screenName, "scaling=", pendingWallpaperColorRequest.scaling);
  }

  // Processes.
  Process {
    id: wallpaperColorProcess
    running: false

    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      const requestPath = root.wallpaperColorRequestPath;
      const screenshotPath = root.wallpaperColorScreenshotPath;
      const screenName = root.wallpaperColorScreenName;
      const appliedScaling = root.wallpaperColorScaling;
      const notify = root.wallpaperColorNotify;
      const stderrText = String(stderr.text || "").trim();

      root.applyingWallpaperColors = false;
      root.wallpaperColorRequestPath = "";
      root.wallpaperColorScreenshotPath = "";
      root.wallpaperColorScreenName = "";
      root.wallpaperColorScaling = "fill";
      root.wallpaperColorNotify = false;

      if (exitCode !== 0) {
        const msg = stderrText.length > 0 ? "Wallpaper screenshot generation failed, stderr=" + stderrText : "Wallpaper screenshot generation failed";
        Logger.w("LWEController", msg, "path=", requestPath, "screen=", screenName, "exitCode=", exitCode);
        if (notify) {
          ToastService.showError(root.pluginApi?.tr("panel.title"), root.pluginApi?.tr("toast.wallpaperColorsFailed"), "alert-circle");
        }
        return;
      }

      root.saveWallpaperColorScreenshot(screenName, screenshotPath, requestPath, appliedScaling);

      if (root.wallpaperColorsEnabled && screenName === root.activeColorMonitor) {
        root.applyWallpaperColorsFromScreenshot(screenshotPath);
        Logger.i("LWEController", "Wallpaper screenshot generated and applied for active color monitor", "path=", requestPath, "screen=", screenName, "screenshot=", screenshotPath);
        if (notify) {
          ToastService.showNotice(root.pluginApi?.tr("panel.title"), root.pluginApi?.tr("toast.wallpaperColorsApplied"), "palette");
        }
        return;
      }

      Logger.i("LWEController", "Wallpaper screenshot cached for color extraction", "path=", requestPath, "screen=", screenName, "screenshot=", screenshotPath);
      if (notify) {
        ToastService.showNotice(root.pluginApi?.tr("panel.title"), root.pluginApi?.tr("toast.wallpaperColorsCached"), "palette");
      }
    }
  }

  Process {
    id: reusedWallpaperColorCheckProcess
    running: false

    onExited: function (exitCode) {
      const request = root.pendingWallpaperColorReuseRequest;
      root.pendingWallpaperColorReuseRequest = null;
      if (!request) {
        return;
      }

      if (exitCode === 0) {
        Logger.i("LWEController", "Reusing cached wallpaper color screenshot", "path=", request.wallpaperPath, "screen=", request.screenName, "scaling=", request.scaling, "screenshot=", request.screenshotPath);

        if (root.wallpaperColorsEnabled && request.screenName === root.activeColorMonitor) {
          root.applyWallpaperColorsFromScreenshot(request.screenshotPath);
          if (request.notify) {
            ToastService.showNotice(root.pluginApi?.tr("panel.title"), root.pluginApi?.tr("toast.wallpaperColorsApplied"), "palette");
          }
        } else if (request.notify) {
          ToastService.showNotice(root.pluginApi?.tr("panel.title"), root.pluginApi?.tr("toast.wallpaperColorsCached"), "palette");
        }
        return;
      }

      Logger.w("LWEController", "Cached wallpaper color screenshot missing; regenerating", "path=", request.wallpaperPath, "screen=", request.screenName, "scaling=", request.scaling, "screenshot=", request.screenshotPath);
      root.startWallpaperColorCapture(request.wallpaperPath, request.screenName, request.scaling, !!request.notify);
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Timers.
  Timer {
    id: wallpaperColorStartTimer
    interval: root.colorStartDelay

    onTriggered: {
      const request = root.pendingWallpaperColorRequest;
      root.pendingWallpaperColorRequest = null;
      if (!request || String(request.path || "").length === 0) {
        return;
      }
      root.applyWallpaperColorsFromPath(request.path, request);
    }
  }

  Timer {
    id: startupWallpaperColorResyncTimer
    interval: root.startupResyncDelay
    repeat: false

    onTriggered: {
      root.scheduleCachedWallpaperColorsForMonitor("startup-final-resync");
    }
  }

  // React to settings changes.
  onActiveColorMonitorChanged: scheduleCachedWallpaperColorsForMonitor("monitor-changed")
  onWallpaperColorsEnabledChanged: scheduleCachedWallpaperColorsForMonitor("wallpaper-colors-toggled")
  onWallpaperColorDarkModeChanged: scheduleCachedWallpaperColorsForMonitor("dark-mode-changed")
  onWallpaperColorGenerationMethodChanged: scheduleCachedWallpaperColorsForMonitor("generation-method-changed")

  // Cleanup.
  Component.onDestruction: {
    wallpaperColorProcess.running = false;
    reusedWallpaperColorCheckProcess.running = false;
    wallpaperColorStartTimer.stop();
    startupWallpaperColorResyncTimer.stop();
    applyingWallpaperColors = false;
  }
}
