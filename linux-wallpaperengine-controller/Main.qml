import QtQuick
import Quickshell
import Quickshell.Io

import "helpers/runtime/EngineHelpers.js" as EngineHelpers

import qs.Commons
import qs.Services.UI

Item {
  id: root

  // Shared plugin API and runtime state.
  property var pluginApi: null

  property bool checkingEngine: true
  property bool engineAvailable: false
  property bool isApplying: false
  property bool wallpaperScanShowToast: false
  property bool stopRequested: false
  property bool recoveryInProgress: false
  property string lastError: ""
  property string lastErrorDetails: ""
  property string lastRuntimeErrorKey: ""
  readonly property bool engineRunning: engineProcess.running || isApplying || pendingCommand.length > 0
  property string lastScreenSetSignature: ""
  property bool scanningWallpapers: false
  property bool wallpapersFolderAccessible: true
  property var cachedWallpaperItems: []
  property double lastWallpaperScanAt: 0

  property var pendingCommand: []

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Named timer intervals.
  readonly property int stableRunDelay: 2500
  readonly property int screenTopologyDebounceDelay: 800

  // Convenience aliases for external consumers.
  readonly property bool applyingWallpaperColors: colorManager.applyingWallpaperColors

  // Pass-through for Panel.qml to reach the color manager.
  function scheduleWallpaperColorsFromPath(path, options) {
    colorManager.scheduleWallpaperColorsFromPath(path, options);
  }

  function applyWallpaperColorsFromPath(path, options) {
    colorManager.applyWallpaperColorsFromPath(path, options);
  }

  // Wallpaper color extraction subsystem.
  WallpaperColorManager {
    id: colorManager
    pluginApi: root.pluginApi
    cfg: root.cfg
    defaults: root.defaults
    engineAvailable: root.engineAvailable
    defaultFps: root.defaultFps
    defaultClamp: root.defaultClamp
    defaultScaling: root.defaultScaling
    normalizedPathFn: root.normalizedPath
    wallpaperIdFromPathFn: root.wallpaperIdFromPath
    getWallpaperPropertiesFn: root.getWallpaperProperties
    getScreenConfigFn: root.getScreenConfig
  }

  // Initialization.
  Component.onCompleted: {
    Logger.i("LWEController", "Main initialized");
    ensureSettingsRoot();

    // Clean up leftover processes from previous sessions.
    startupCleanupProcess.running = true;

    lastScreenSetSignature = currentScreenSetSignature();
    colorManager.scheduleStartupResync();
  }

  // Settings persistence and recovery snapshots.
  function ensureSettingsRoot() {
    if (!pluginApi) {
      return;
    }

    if (pluginApi.pluginSettings.screens === undefined || pluginApi.pluginSettings.screens === null) {
      pluginApi.pluginSettings.screens = {};
    }

    if (pluginApi.pluginSettings.lastKnownGoodScreens === undefined || pluginApi.pluginSettings.lastKnownGoodScreens === null) {
      pluginApi.pluginSettings.lastKnownGoodScreens = {};
    }

    if (pluginApi.pluginSettings.wallpaperProperties === undefined || pluginApi.pluginSettings.wallpaperProperties === null) {
      pluginApi.pluginSettings.wallpaperProperties = {};
    }

    if (pluginApi.pluginSettings.runtimeRecoveryPending === undefined || pluginApi.pluginSettings.runtimeRecoveryPending === null) {
      pluginApi.pluginSettings.runtimeRecoveryPending = false;
    }

    if (pluginApi.pluginSettings.wallpaperColorScreenshots === undefined || pluginApi.pluginSettings.wallpaperColorScreenshots === null) {
      pluginApi.pluginSettings.wallpaperColorScreenshots = {};
    }
  }

  function cloneValue(value) {
    return JSON.parse(JSON.stringify(value || ({})));
  }

  function currentWallpaperPathForScreen(screenName) {
    return normalizedPath(getScreenConfig(screenName).path || "");
  }

  function hasAnyScreenPathFrom(sourceScreens) {
    const screens = sourceScreens || ({});
    const keys = Object.keys(screens);
    for (const key of keys) {
      const screenCfg = screens[key] || ({});
      const path = normalizedPath(screenCfg.path || "");
      if (path.length > 0) {
        return true;
      }
    }
    return false;
  }

  function markRuntimeRecoveryPending(value, flushToDisk = true) {
    if (!pluginApi) {
      return;
    }

    const nextValue = !!value;
    if (pluginApi.pluginSettings.runtimeRecoveryPending === nextValue) {
      return;
    }

    pluginApi.pluginSettings.runtimeRecoveryPending = nextValue;
    if (flushToDisk) {
      pluginApi.saveSettings();
    }
  }

  function saveCurrentLayoutAsLastKnownGood(reason) {
    if (!pluginApi) {
      return false;
    }

    const currentScreens = cloneValue(pluginApi.pluginSettings.screens || ({}));
    if (!hasAnyScreenPathFrom(currentScreens)) {
      Logger.d("LWEController", "Skip last-known-good snapshot: no configured paths", "reason=", reason);
      return false;
    }

    pluginApi.pluginSettings.lastKnownGoodScreens = currentScreens;
    pluginApi.pluginSettings.runtimeRecoveryPending = false;
    pluginApi.saveSettings();

    Logger.d("LWEController", "Saved last-known-good layout", "reason=", reason);
    return true;
  }

  function restoreLastKnownGoodLayout(reason) {
    if (!pluginApi) {
      return false;
    }

    const snapshot = pluginApi.pluginSettings.lastKnownGoodScreens || ({});
    if (!hasAnyScreenPathFrom(snapshot)) {
      Logger.w("LWEController", "No restorable last-known-good layout", "reason=", reason);
      return false;
    }

    pluginApi.pluginSettings.screens = cloneValue(snapshot);
    pluginApi.pluginSettings.runtimeRecoveryPending = false;
    pluginApi.saveSettings();

    Logger.d("LWEController", "Restored last-known-good layout", "reason=", reason);
    return true;
  }

  function tryAutoRecoverFromRuntimeError(reason) {
    if (!pluginApi || recoveryInProgress) {
      return false;
    }

    if (!restoreLastKnownGoodLayout(reason)) {
      markRuntimeRecoveryPending(true);
      return false;
    }

    markErrorAsRecovered();
    recoveryInProgress = true;
    if (engineAvailable && hasAnyConfiguredWallpaper()) {
      restartEngine();
    }

    return true;
  }

  function recoverPendingLayoutOnStartup() {
    if (!pluginApi) {
      return false;
    }

    const pending = !!pluginApi.pluginSettings.runtimeRecoveryPending;
    if (!pending) {
      return false;
    }

    const restored = restoreLastKnownGoodLayout("startup-pending-recovery");
    if (!restored) {
      markRuntimeRecoveryPending(false);
      return false;
    }

    Logger.i("LWEController", "Startup recovery applied from pending marker");
    return true;
  }

  // Runtime defaults derived from settings.
  readonly property string defaultScaling: cfg.defaultScaling ?? defaults.defaultScaling ?? "fill"
  readonly property string defaultClamp: cfg.defaultClamp ?? defaults.defaultClamp ?? "clamp"
  readonly property int defaultFps: cfg.defaultFps ?? defaults.defaultFps ?? 30

  readonly property int defaultVolume: {
    const value = Number(cfg.defaultVolume ?? defaults.defaultVolume ?? 100);
    if (isNaN(value)) {
      return 100;
    }
    return Math.max(0, Math.min(100, Math.floor(value)));
  }

  readonly property bool defaultMuted: cfg.defaultMuted ?? defaults.defaultMuted ?? true
  readonly property bool defaultAudioReactiveEffects: cfg.defaultAudioReactiveEffects ?? defaults.defaultAudioReactiveEffects ?? true
  readonly property bool defaultNoAutomute: cfg.defaultNoAutomute ?? defaults.defaultNoAutomute ?? false
  readonly property bool defaultDisableMouse: cfg.defaultDisableMouse ?? defaults.defaultDisableMouse ?? false
  readonly property bool defaultDisableParallax: cfg.defaultDisableParallax ?? defaults.defaultDisableParallax ?? false
  readonly property bool defaultNoFullscreenPause: cfg.defaultNoFullscreenPause ?? defaults.defaultNoFullscreenPause ?? false
  readonly property bool defaultFullscreenPauseOnlyActive: cfg.defaultFullscreenPauseOnlyActive ?? defaults.defaultFullscreenPauseOnlyActive ?? false
  readonly property bool defaultAutoApply: cfg.autoApplyOnStartup ?? defaults.autoApplyOnStartup ?? true
  
  readonly property int wallpaperScanCacheMinutes: {
    const value = Number(cfg.wallpaperScanCacheMinutes ?? defaults.wallpaperScanCacheMinutes ?? 10);
    if (isNaN(value)) {
      return 10;
    }
    return Math.max(0, Math.floor(value));
  }


  // Screen topology, path normalization, and persisted wallpaper accessors.
  function normalizedPath(path) {
    return Settings.preprocessPath(String(path || ""));
  }

  function currentScreenSetSignature() {
    return Quickshell.screens
      .map(screen => String(screen.name || ""))
      .sort()
      .join("|");
  }

  function wallpaperScanCacheValid() {
    if (wallpaperScanCacheMinutes <= 0) {
      return false;
    }

    if (!cachedWallpaperItems || cachedWallpaperItems.length === 0) {
      return false;
    }

    if (lastWallpaperScanAt <= 0) {
      return false;
    }

    const ageMs = Date.now() - lastWallpaperScanAt;
    return ageMs < wallpaperScanCacheMinutes * 60 * 1000;
  }

  function handleScreenTopologyChanged() {
    const nextSignature = currentScreenSetSignature();
    if (nextSignature === lastScreenSetSignature) {
      return;
    }

    const previousSignature = lastScreenSetSignature;
    lastScreenSetSignature = nextSignature;
    Logger.i("LWEController", "Screen topology changed", "from=", previousSignature, "to=", nextSignature);

    screenTopologyRestartDebounce.restart();
  }

  function getScreenConfig(screenName) {
    const screenConfigs = cfg.screens || ({});
    const raw = screenConfigs[screenName] || ({});

    return {
      path: raw.path ?? "",
      scaling: raw.scaling ?? defaultScaling,
      clamp: raw.clamp ?? defaultClamp
    };
  }

  function hasAnyConfiguredWallpaper() {
    for (const screen of Quickshell.screens) {
      const screenCfg = getScreenConfig(screen.name);
      if (screenCfg.path && screenCfg.path.length > 0) {
        return true;
      }
    }
    return false;
  }

  function wallpaperIdFromPath(path) {
    const raw = normalizedPath(path);
    if (raw.length === 0) {
      return "";
    }

    const parts = raw.split("/");
    return parts.length > 0 ? String(parts[parts.length - 1] || "") : "";
  }

  // Wallpaper property storage helpers.
  function cloneWallpaperProperties(source) {
    const cloned = {};
    const raw = source || ({});
    for (const key of Object.keys(raw)) {
      const value = raw[key];
      if (value !== undefined) {
        cloned[key] = value;
      }
    }
    return cloned;
  }

  function setWallpaperProperties(path, properties) {
    if (!pluginApi) {
      return;
    }

    const wallpaperId = wallpaperIdFromPath(path);
    if (wallpaperId.length === 0) {
      return;
    }

    pluginApi.pluginSettings.wallpaperProperties[wallpaperId] = cloneWallpaperProperties(properties);
  }

  function getWallpaperProperties(path) {
    const wallpaperId = wallpaperIdFromPath(path);
    if (wallpaperId.length === 0) {
      return {};
    }

    const raw = cfg.wallpaperProperties || ({});
    return cloneWallpaperProperties(raw[wallpaperId] || ({}));
  }

  function setScreenWallpaper(screenName, path) {
    setScreenWallpaperWithOptions(screenName, path, ({}));
  }

  function clearLegacyScreenRuntimeOptions(screenName) {
    const screenConfig = pluginApi?.pluginSettings?.screens?.[screenName];
    if (!screenConfig) {
      return;
    }

    delete screenConfig.clamp;
    delete screenConfig.volume;
    delete screenConfig.muted;
    delete screenConfig.audioReactiveEffects;
    delete screenConfig.noAutomute;
    delete screenConfig.disableMouse;
    delete screenConfig.disableParallax;
  }

  function clearLegacyRuntimeOptionsForAllScreens() {
    for (const screen of Quickshell.screens) {
      clearLegacyScreenRuntimeOptions(screen.name);
    }
  }

  // Wallpaper source scanning and cache refresh.
  function refreshWallpaperCache(force = false, showToast = false) {
    const folderPath = Settings.preprocessPath(String(cfg.wallpapersFolder ?? defaults.wallpapersFolder ?? "")).trim();

    if (scanningWallpapers && !wallpaperScanProcess.running) {
      Logger.w("LWEController", "Reset stale wallpaper scanning state before refresh");
      scanningWallpapers = false;
    }

    if (folderPath.length === 0) {
      cachedWallpaperItems = [];
      wallpapersFolderAccessible = false;
      scanningWallpapers = false;
      lastWallpaperScanAt = 0;
      if (showToast) {
        ToastService.showWarning(pluginApi?.tr("panel.title"), pluginApi?.tr("toast.refreshSkippedNoFolder"), "alert-circle");
      }
      Logger.w("LWEController", "Wallpaper refresh skipped: wallpapers folder is empty");
      return;
    }

    if (wallpaperScanProcess.running) {
      Logger.d("LWEController", "Wallpaper scan already in progress");
      return;
    }

    if (!force && wallpaperScanCacheValid()) {
      scanningWallpapers = false;
      wallpaperScanShowToast = false;
      Logger.d("LWEController", "Wallpaper cache reused", "count=", cachedWallpaperItems.length, "ageMs=", Date.now() - lastWallpaperScanAt);
      return;
    }

    const pluginDir = pluginApi?.pluginDir || "";
    const scriptPath = pluginDir + "/scripts/scan-wallpapers.sh";

    Logger.i("LWEController", force ? "Refreshing wallpaper cache" : "Scanning wallpapers for cache", folderPath);
    scanningWallpapers = true;
    wallpaperScanShowToast = showToast;
    // Mode is no longer passed as argument since we eliminated multi-mode.
    wallpaperScanProcess.command = ["bash", scriptPath, folderPath];
    wallpaperScanProcess.running = true;
  }

  // Wallpaper application and persisted runtime option updates.
  function setScreenWallpaperWithOptions(screenName, path, options) {
    if (!pluginApi) {
      return;
    }

    Logger.i("LWEController", "Set wallpaper requested", screenName, path, JSON.stringify(options || ({})));

    if (pluginApi.pluginSettings.screens[screenName] === undefined) {
      pluginApi.pluginSettings.screens[screenName] = {};
    }

    pluginApi.pluginSettings.screens[screenName].path = path;

    const resolvedScaling = (options?.scaling || "").trim();
    const resolvedClamp = (options?.clamp || "").trim();
    if (resolvedScaling.length > 0) {
      pluginApi.pluginSettings.screens[screenName].scaling = resolvedScaling;
    }
    if (resolvedClamp.length > 0) {
      pluginApi.pluginSettings.screens[screenName].clamp = resolvedClamp;
    }

    if (options?.volume !== undefined) {
      const rawVolume = Number(options.volume);
      if (!isNaN(rawVolume)) {
        pluginApi.pluginSettings.defaultVolume = Math.max(0, Math.min(100, Math.floor(rawVolume)));
      }
    }

    if (options?.muted !== undefined) {
      pluginApi.pluginSettings.defaultMuted = !!options.muted;
    }

    if (options?.audioReactiveEffects !== undefined) {
      pluginApi.pluginSettings.defaultAudioReactiveEffects = !!options.audioReactiveEffects;
    }

    if (options?.noAutomute !== undefined) {
      pluginApi.pluginSettings.defaultNoAutomute = !!options.noAutomute;
    }

    if (options?.disableMouse !== undefined) {
      pluginApi.pluginSettings.defaultDisableMouse = !!options.disableMouse;
    }

    if (options?.disableParallax !== undefined) {
      pluginApi.pluginSettings.defaultDisableParallax = !!options.disableParallax;
    }

    clearLegacyScreenRuntimeOptions(screenName);

    if (options?.customProperties !== undefined) {
      setWallpaperProperties(path, options.customProperties);
    }

    pluginApi.saveSettings();

    restartEngine(resolveRuntimeOverrides(options));
  }

  function clearScreenWallpaper(screenName) {
    if (!pluginApi) {
      return;
    }

    Logger.i("LWEController", "Clear wallpaper requested", screenName);

    if (pluginApi.pluginSettings.screens[screenName] === undefined) {
      pluginApi.pluginSettings.screens[screenName] = {};
    }

    pluginApi.pluginSettings.screens[screenName].path = "";
    pluginApi.saveSettings();

    restartEngine();
  }

  function setAllScreensWallpaper(path) {
    setAllScreensWallpaperWithOptions(path, ({}));
  }

  function setAllScreensWallpaperWithOptions(path, options) {
    if (!pluginApi || !path || path.length === 0) {
      return;
    }

    Logger.i("LWEController", "Set wallpaper for all screens", path, JSON.stringify(options || ({})));

    const resolvedScaling = (options?.scaling || "").trim();
    const resolvedClamp = (options?.clamp || "").trim();
    const resolvedVolumeRaw = Number(options?.volume);
    const hasResolvedVolume = !isNaN(resolvedVolumeRaw);
    const resolvedVolume = hasResolvedVolume ? Math.max(0, Math.min(100, Math.floor(resolvedVolumeRaw))) : 0;
    const hasMuted = options?.muted !== undefined;
    const hasAudioReactive = options?.audioReactiveEffects !== undefined;
    const hasNoAutomute = options?.noAutomute !== undefined;
    const hasDisableMouse = options?.disableMouse !== undefined;
    const hasDisableParallax = options?.disableParallax !== undefined;

    for (const screen of Quickshell.screens) {
      if (pluginApi.pluginSettings.screens[screen.name] === undefined) {
        pluginApi.pluginSettings.screens[screen.name] = {};
      }

      pluginApi.pluginSettings.screens[screen.name].path = path;
      if (resolvedScaling.length > 0) {
        pluginApi.pluginSettings.screens[screen.name].scaling = resolvedScaling;
      }
      if (resolvedClamp.length > 0) {
        pluginApi.pluginSettings.screens[screen.name].clamp = resolvedClamp;
      }
      if (options?.customProperties !== undefined) {
        setWallpaperProperties(path, options.customProperties);
      }
    }

    if (hasResolvedVolume) {
      pluginApi.pluginSettings.defaultVolume = resolvedVolume;
    }
    if (hasMuted) {
      pluginApi.pluginSettings.defaultMuted = !!options.muted;
    }
    if (hasAudioReactive) {
      pluginApi.pluginSettings.defaultAudioReactiveEffects = !!options.audioReactiveEffects;
    }
    if (hasNoAutomute) {
      pluginApi.pluginSettings.defaultNoAutomute = !!options.noAutomute;
    }
    if (hasDisableMouse) {
      pluginApi.pluginSettings.defaultDisableMouse = !!options.disableMouse;
    }
    if (hasDisableParallax) {
      pluginApi.pluginSettings.defaultDisableParallax = !!options.disableParallax;
    }

    clearLegacyRuntimeOptionsForAllScreens();

    pluginApi.saveSettings();
    restartEngine(resolveRuntimeOverrides(options));
  }

  // Runtime error capture and recovery hints.
  function extractRuntimeError(stderrText) {
    return EngineHelpers.extractRuntimeError(stderrText, {
      assetsMissing: pluginApi?.tr("main.error.assetsMissing"),
      noBackground: pluginApi?.tr("main.error.noBackground"),
      opengl: pluginApi?.tr("main.error.opengl")
    });
  }

  function setRuntimeErrorFromStderr(stderrText) {
    const raw = (stderrText || "").trim();
    if (raw.length === 0) {
      return false;
    }

    const summary = extractRuntimeError(raw);
    if (summary.length === 0) {
      return false;
    }

    lastError = summary;
    lastErrorDetails = raw;
    return true;
  }

  function clearRuntimeErrorState() {
    lastError = "";
    lastErrorDetails = "";
    lastRuntimeErrorKey = "";
  }

  function logCapturedRuntimeError(stage, exitCode = null, exitStatus = null) {
    const summary = String(lastError || "").trim();
    const details = String(lastErrorDetails || "").trim();
    if (summary.length === 0 && details.length === 0) {
      return false;
    }

    const logKey = stage + "|" + summary + "|" + details;
    if (logKey === lastRuntimeErrorKey) {
      return true;
    }

    lastRuntimeErrorKey = logKey;
    Logger.e(
      "LWEController",
      "runtime-error",
      "stage=", stage,
      "exitCode=", exitCode === null ? "-" : exitCode,
      "exitStatus=", exitStatus === null ? "-" : exitStatus,
      "summary=", summary
    );
    return true;
  }

  function markErrorAsRecovered() {
    const hintRaw = pluginApi?.tr("main.error.autoRecovered");
    if (hintRaw === undefined || hintRaw === null) {
      return;
    }

    const hint = hintRaw.trim();
    const current = (lastError || "").trim();
    if (hint.length === 0 || current.length === 0) {
      return;
    }

    if (current.indexOf(hint) !== -1) {
      return;
    }

    lastError = current + " (" + hint + ")";
  }

  // Engine command construction and lifecycle orchestration.
  function buildCommand(runtimeOverrides = null) {
    const overrides = runtimeOverrides || ({});
    return EngineHelpers.buildEngineCommand({
      defaultFps: defaultFps,
      defaultClamp: overrides.defaultClamp ?? defaultClamp,
      defaultVolume: overrides.defaultVolume ?? defaultVolume,
      defaultMuted: overrides.defaultMuted ?? defaultMuted,
      defaultAudioReactiveEffects: overrides.defaultAudioReactiveEffects ?? defaultAudioReactiveEffects,
      defaultNoAutomute: overrides.defaultNoAutomute ?? defaultNoAutomute,
      defaultDisableMouse: overrides.defaultDisableMouse ?? defaultDisableMouse,
      defaultDisableParallax: overrides.defaultDisableParallax ?? defaultDisableParallax,
      defaultNoFullscreenPause: defaultNoFullscreenPause,
      defaultFullscreenPauseOnlyActive: defaultFullscreenPauseOnlyActive,
      defaultScaling: defaultScaling,
      screens: Quickshell.screens,
      getScreenConfig: getScreenConfig,
      normalizePath: normalizedPath,
      wallpaperIdFromPath: wallpaperIdFromPath,
      getWallpaperProperties: getWallpaperProperties
    });
  }

  function resolveRuntimeOverrides(options = null) {
    const opts = options || ({});
    const resolvedVolumeRaw = Number(opts.volume);
    return {
      defaultClamp: String(opts.clamp || defaultClamp),
      defaultVolume: isNaN(resolvedVolumeRaw) ? defaultVolume : Math.max(0, Math.min(100, Math.floor(resolvedVolumeRaw))),
      defaultMuted: opts.muted === undefined ? defaultMuted : !!opts.muted,
      defaultAudioReactiveEffects: opts.audioReactiveEffects === undefined ? defaultAudioReactiveEffects : !!opts.audioReactiveEffects,
      defaultNoAutomute: opts.noAutomute === undefined ? defaultNoAutomute : !!opts.noAutomute,
      defaultDisableMouse: opts.disableMouse === undefined ? defaultDisableMouse : !!opts.disableMouse,
      defaultDisableParallax: opts.disableParallax === undefined ? defaultDisableParallax : !!opts.disableParallax
    };
  }

  function stopAll(showToast = false) {
    Logger.i("LWEController", "Stopping engine process");
    pendingCommand = [];

    if (engineProcess.running) {
      stopRequested = true;
      engineProcess.running = false;
    } else {
      stopRequested = false;
    }

    // Always run terminate command to stop detached processes too.
    if (!forceStopProcess.running) {
      forceStopProcess.running = true;
    }

    isApplying = false;
    if (showToast) {
      ToastService.showNotice(pluginApi?.tr("panel.title"), pluginApi?.tr("toast.stopped"), "player-stop");
    }
  }

  function startEngineWithCommand(command) {
    if (!engineAvailable) {
      Logger.d("LWEController", "Skip start: engine unavailable");
      return;
    }

    if (!command || command.length <= 1) {
      Logger.d("LWEController", "Skip start: empty command");
      stopAll();
      return;
    }

    Logger.d("LWEController", "Starting engine command", JSON.stringify(command));

    if (!recoveryInProgress) {
      clearRuntimeErrorState();
    }
    isApplying = true;

    engineProcess.command = command;
    engineProcess.running = true;
    stableRunTimer.restart();
  }

  function restartEngine(runtimeOverrides = null) {
    if (!engineAvailable) {
      Logger.d("LWEController", "Skip restart: engine unavailable");
      return;
    }

    if (!hasAnyConfiguredWallpaper()) {
      Logger.d("LWEController", "Skip restart: no configured wallpaper; stopping engine");
      stopAll();
      return;
    }

    const command = buildCommand(runtimeOverrides);
    if (!command || command.length <= 1) {
      Logger.d("LWEController", "Restart resolved to empty command; stopping engine");
      stopAll();
      return;
    }

    if (engineProcess.running) {
      Logger.d("LWEController", "Engine already running; queue restart command");
      pendingCommand = command;
      stopRequested = true;
      engineProcess.running = false;

      // Ensure termination also reaches detached processes before restart.
      if (!forceStopProcess.running) {
        forceStopProcess.running = true;
      }
      return;
    }

    startEngineWithCommand(command);
  }

  function reload(showToast = false) {
    if (!hasAnyConfiguredWallpaper()) {
      clearRuntimeErrorState();
      Logger.d("LWEController", "Reload skipped: no configured wallpaper paths");
      if (showToast) {
        ToastService.showWarning(pluginApi?.tr("panel.title"), pluginApi?.tr("toast.reloadSkippedNoWallpaper"), "alert-circle");
      }
      return;
    }

    restartEngine();
    if (showToast) {
      ToastService.showNotice(pluginApi?.tr("panel.title"), pluginApi?.tr("toast.reloaded"), "refresh");
    }
  }

  // External processes.
  Process {
    id: wallpaperScanProcess

    onExited: function (exitCode) {
      const parsed = [];
      const lines = String(stdout.text || "").split("\n");
      const stderrText = String(stderr.text || "").trim();

      root.wallpapersFolderAccessible = (exitCode === 0);

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.length === 0) {
          continue;
        }

        const parts = line.split("\t");
        const path = parts.length > 0 ? parts[0] : "";
        const name = parts.length > 1 && parts[1].length > 0 ? parts[1] : String(path || "").split("/").pop();
        const thumb = parts.length > 2 ? parts[2] : "";
        const motionPreview = parts.length > 3 ? parts[3] : "";
        const dynamic = parts.length > 4 ? parts[4] === "1" : false;
        const id = parts.length > 5 ? parts[5] : String(path || "").split("/").pop();
        const type = parts.length > 6 ? parts[6] : "unknown";
        const resolution = parts.length > 7 ? parts[7] : "unknown";
        const hasEmbeddedAudio = parts.length > 8 ? parts[8] === "1" : false;
        const hasAudioReactive = parts.length > 9 ? parts[9] === "1" : false;
        const sizeMtime = parts.length > 10 ? parts[10] : "0:0";
        const sizeParts = String(sizeMtime).split(":");
        const bytes = sizeParts.length > 0 ? Number(sizeParts[0]) : 0;
        const mtime = sizeParts.length > 1 ? Number(sizeParts[1]) : 0;
        const approved = parts.length > 11 ? parts[11] === "1" : false;
        const description = parts.length > 12 ? String(parts[12] || "") : "";

        if (path.length > 0) {
          parsed.push({
            path: path,
            name: name,
            thumb: thumb,
            motionPreview: motionPreview,
            dynamic: dynamic,
            hasEmbeddedAudio: hasEmbeddedAudio,
            hasAudioReactive: hasAudioReactive,
            id: id,
            type: type,
            resolution: resolution,
            bytes: bytes,
            mtime: mtime,
            approved: approved,
            description: description
          });
        }
      }

      root.cachedWallpaperItems = parsed;
      root.scanningWallpapers = false;
      root.lastWallpaperScanAt = exitCode === 0 ? Date.now() : 0;

      if (root.wallpaperScanShowToast && exitCode === 0) {
        ToastService.showNotice(
          pluginApi?.tr("panel.title"),
          pluginApi?.tr("toast.refreshedWallpapers", { count: parsed.length }),
          "refresh"
        );
      }
      root.wallpaperScanShowToast = false;

      if (!root.wallpapersFolderAccessible) {
        const msg = stderrText.length > 0 ? "Wallpaper scan failed, stderr=" + stderrText : "Wallpaper scan failed";
        Logger.e("LWEController", msg, "exitCode=", exitCode);
      }

      Logger.i("LWEController", "Wallpaper cache updated", "count=", parsed.length, "exitCode=", exitCode);
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Process {
    id: engineCheck
    running: true
    command: ["sh", "-c", "command -v linux-wallpaperengine >/dev/null 2>&1"]

    onExited: function (exitCode) {
      root.engineAvailable = (exitCode === 0);
      root.checkingEngine = false;

      Logger.i("LWEController", "Engine check finished", "exitCode=", exitCode, "available=", root.engineAvailable);

      if (!root.engineAvailable) {
        root.lastError = root.pluginApi?.tr("main.error.notInstalled");
        root.lastErrorDetails = "";
        root.lastRuntimeErrorKey = "";
        Logger.e("LWEController", "linux-wallpaperengine binary not found in PATH");
        return;
      }

      root.refreshWallpaperCache(false, false);

      root.recoverPendingLayoutOnStartup();

      if (root.defaultAutoApply && root.hasAnyConfiguredWallpaper()) {
        Logger.i("LWEController", "Auto apply enabled with configured wallpapers; restarting engine");
        root.restartEngine();
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Process {
    id: engineProcess

    onExited: function (exitCode, exitStatus) {
      root.isApplying = false;
      stableRunTimer.stop();

      Logger.i("LWEController", "Engine process exited", "exitCode=", exitCode, "exitStatus=", exitStatus, "stopRequested=", root.stopRequested);

      if (root.stopRequested) {
        root.stopRequested = false;
        root.recoveryInProgress = false;

        if (root.pendingCommand.length > 0) {
          const nextCommand = root.pendingCommand;
          root.pendingCommand = [];
          Logger.d("LWEController", "Applying pending command after stop");
          root.startEngineWithCommand(nextCommand);
          return;
        }

        return;
      }

      if (exitCode !== 0 || exitStatus !== Process.NormalExit) {
        if (root.setRuntimeErrorFromStderr(stderr.text)) {
          root.logCapturedRuntimeError("engine-exit", exitCode, exitStatus);
        }
        root.tryAutoRecoverFromRuntimeError("runtime-crash");
      } else {
        root.recoveryInProgress = false;
      }
    }

    stdout: StdioCollector {}

    stderr: StdioCollector {
      onStreamFinished: {
        if (root.stopRequested) {
          return;
        }

        root.setRuntimeErrorFromStderr(text);
      }
    }
  }

  Process {
    id: forceStopProcess
    running: false
    command: {
      const pluginDir = root.pluginApi?.pluginDir || "";
      const scriptPath = pluginDir + "/scripts/force-stop-engine.sh";
      return ["bash", scriptPath];
    }

    onExited: function (exitCode) {
      Logger.d("LWEController", "Force stop command finished", "exitCode=", exitCode);
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Startup cleanup: kill any orphaned wallpaper engine processes from previous sessions.
  Process {
    id: startupCleanupProcess
    running: false

    command: {
      const pluginDir = root.pluginApi?.pluginDir || "";
      const scriptPath = pluginDir + "/scripts/force-stop-engine.sh";
      return ["bash", scriptPath];
    }

    onExited: function (exitCode) {
      Logger.d("LWEController", "Startup cleanup finished", "exitCode=", exitCode);
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // IPC entrypoints.
  IpcHandler {
    target: "plugin:linux-wallpaperengine-controller"

    function toggle() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => {
          root.pluginApi.togglePanel(screen);
        });
      }
    }

    function apply(screenName: string, bgPath: string) {
      if (!screenName || !bgPath) {
        Logger.w("LWEController", "IPC apply ignored due to invalid args", "screenName=", screenName, "bgPath=", bgPath);
        return;
      }

      Logger.i("LWEController", "IPC apply", "screenName=", screenName, "bgPath=", bgPath);

      root.setScreenWallpaper(screenName, bgPath);
    }

    function stop(screenName: string) {
      if (!screenName || screenName === "all") {
        Logger.i("LWEController", "IPC stop all");
        root.stopAll();
        return;
      }

      Logger.i("LWEController", "IPC stop screen", screenName);

      root.clearScreenWallpaper(screenName);
    }

    function reload() {
      root.reload();
    }

    function refreshWallpapers() {
      root.refreshWallpaperCache(true, true);
    }
  }

  // Shell event connections.
  Connections {
    target: Quickshell

    function onScreensChanged() {
      root.handleScreenTopologyChanged();
    }
  }

  Connections {
    target: root

    function onPluginApiChanged() {
      if (root.pluginApi) {
        root.ensureSettingsRoot();
      }
    }
  }

  // Stability and topology debounce timers.
  Timer {
    id: stableRunTimer
    interval: root.stableRunDelay
    repeat: false

    onTriggered: {
      if (!engineProcess.running || stopRequested) {
        return;
      }

      if (saveCurrentLayoutAsLastKnownGood("stable-run")) {
        recoveryInProgress = false;
      }
    }
  }

  Timer {
    id: screenTopologyRestartDebounce
    interval: root.screenTopologyDebounceDelay
    repeat: false

    onTriggered: {
      if (!root.engineAvailable) {
        return;
      }

      if (!root.hasAnyConfiguredWallpaper()) {
        return;
      }

      Logger.i("LWEController", "Reapplying wallpapers after screen topology change");
      root.restartEngine();
    }
  }

  // Cleanup on shell shutdown.
  Component.onDestruction: {
    Logger.i("LWEController", "Shell shutting down, cleaning up wallpaper engine processes");

    pendingCommand = [];
    stopRequested = true;

    if (engineProcess.running)
      engineProcess.running = false;

    if (wallpaperScanProcess.running)
      wallpaperScanProcess.running = false;

    if (!forceStopProcess.running)
      forceStopProcess.running = true;

    stableRunTimer.stop();
    screenTopologyRestartDebounce.stop();

    isApplying = false;
    scanningWallpapers = false;

    Logger.i("LWEController", "Cleanup complete");
  }
}
