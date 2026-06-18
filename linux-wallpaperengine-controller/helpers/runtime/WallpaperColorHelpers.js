.pragma library

function normalizeWallpaperColorRequest(path, options, defaultScaling, fallbackScreenName, normalizePath) {
  const requestOptions = options || ({});
  const normalizedWallpaperPath = normalizePath(String(path || ""));
  return {
    path: normalizedWallpaperPath,
    screenName: String(requestOptions.screenName || fallbackScreenName || "").trim(),
    scaling: String(requestOptions.scaling || defaultScaling || "fill").trim(),
    notify: !!requestOptions.notify
  };
}

function buildActiveMonitorSyncRequest(screenName, screenConfig, defaultScaling, normalizePath) {
  const normalizedScreenName = String(screenName || "").trim();
  if (normalizedScreenName.length === 0) {
    return null;
  }

  const wallpaperPath = normalizePath(screenConfig && screenConfig.path || "");
  if (wallpaperPath.length === 0) {
    return null;
  }

  return {
    path: wallpaperPath,
    screenName: normalizedScreenName,
    scaling: String(screenConfig && screenConfig.scaling || defaultScaling || "fill").trim(),
    notify: false
  };
}

function buildScreenshotCacheEntry(screenshotPath, wallpaperPath, scaling) {
  return {
    path: String(screenshotPath || "").trim(),
    wallpaperPath: String(wallpaperPath || "").trim(),
    scaling: String(scaling || "fill").trim(),
    updatedAt: Date.now()
  };
}

function buildReuseCheckRequest(screenName, wallpaperPath, scaling, screenshotPath, notify) {
  return {
    wallpaperPath: String(wallpaperPath || "").trim(),
    screenName: String(screenName || "").trim(),
    scaling: String(scaling || "fill").trim(),
    screenshotPath: String(screenshotPath || "").trim(),
    notify: !!notify
  };
}

function buildCaptureCommand(scriptPath, screenshotPath, assetsDir, defaultFps, defaultClamp, targetScreenName, wallpaperPath, targetScaling, wallpaperProperties) {
  const command = [
    "bash",
    scriptPath,
    screenshotPath,
    "linux-wallpaperengine"
  ];

  const normalizedAssetsDir = String(assetsDir || "").trim();
  if (normalizedAssetsDir.length > 0) {
    command.push("--assets-dir");
    command.push(normalizedAssetsDir);
  }

  command.push("--fps");
  command.push(String(defaultFps));
  command.push("--clamp");
  command.push(String(defaultClamp || "clamp"));
  command.push("--screen-root");
  command.push(String(targetScreenName || "").trim());
  command.push("--bg");
  command.push(String(wallpaperPath || "").trim());
  command.push("--scaling");
  command.push(String(targetScaling || "fill").trim() || "fill");
  command.push("--screenshot");
  command.push(String(screenshotPath || "").trim());

  const customProperties = wallpaperProperties || ({});
  for (const propertyKey of Object.keys(customProperties)) {
    const propertyValue = customProperties[propertyKey];
    if (propertyValue === undefined || propertyValue === null || String(propertyKey || "").trim().length === 0) {
      continue;
    }
    command.push("--set-property");
    command.push(String(propertyKey) + "=" + String(propertyValue));
  }

  return command;
}
