.pragma library

function sanitizeCachePathSegment(value, fallbackValue) {
  const trimmedValue = String(value || "").trim();
  const normalizedValue = trimmedValue.length > 0 ? trimmedValue : String(fallbackValue || "");
  return normalizedValue.replace(/[^A-Za-z0-9._-]+/g, "_");
}

function screenCacheKey(screenName) {
  return sanitizeCachePathSegment(screenName, "screen");
}

function pluginCacheDir(cacheDir, pluginId) {
  const normalizedCacheDir = String(cacheDir || "").trim();
  const cacheRoot = normalizedCacheDir.length > 0
    ? normalizedCacheDir.replace(/\/+$/, "") + "/"
    : "";
  const pluginCacheId = sanitizeCachePathSegment(pluginId, "plugin");
  return cacheRoot + "plugins/" + pluginCacheId;
}

function screenshotPathForWallpaper(cacheDir, pluginId, wallpaperId, screenName) {
  const fileId = sanitizeCachePathSegment(wallpaperId, "wallpaper");
  const screenId = screenCacheKey(screenName);
  return pluginCacheDir(cacheDir, pluginId) + "/" + screenId + "-" + fileId + "-theme-shot.png";
}

function cachedScreenshotEntry(entries, screenName) {
  return entries && entries[screenName] || null;
}

function canReuseScreenshot(entries, screenName, wallpaperPath, scaling, normalizePath, fallbackScaling) {
  const entry = cachedScreenshotEntry(entries, screenName);
  const cachedPath = normalizePath(entry && entry.path || "");
  const cachedWallpaperPath = normalizePath(entry && entry.wallpaperPath || "");
  const cachedScaling = String(entry && entry.scaling || fallbackScaling || "fill").trim();
  const nextScaling = String(scaling || fallbackScaling || "fill").trim();

  if (cachedPath.length === 0 || cachedWallpaperPath.length === 0) {
    return false;
  }

  return cachedWallpaperPath === normalizePath(wallpaperPath) && cachedScaling === nextScaling;
}

function formatBytes(bytesValue, fallbackText) {
  const value = Number(bytesValue || 0);
  if (isNaN(value) || value < 0) {
    return fallbackText || "Unknown";
  }

  if (value < 1024) {
    return value + " B";
  }

  const units = ["KB", "MB", "GB", "TB"];
  let current = value / 1024;
  let unitIndex = 0;
  while (current >= 1024 && unitIndex < units.length - 1) {
    current /= 1024;
    unitIndex += 1;
  }

  return current.toFixed(current >= 10 || unitIndex === 0 ? 1 : 2) + " " + units[unitIndex];
}

function preservedEntriesForScreens(entries, screens) {
  const preserved = {};
  const screenshotEntries = entries || ({});
  const screenList = screens || [];

  for (let i = 0; i < screenList.length; i++) {
    const screen = screenList[i];
    const screenName = String(screen && screen.name || "").trim();
    if (screenName.length === 0) {
      continue;
    }

    const entry = screenshotEntries[screenName];
    const path = String(entry && entry.path || "").trim();
    if (path.length === 0) {
      continue;
    }

    preserved[screenName] = entry;
  }

  return preserved;
}

function clearCacheCommand(pluginDir, cacheDir, preservedEntries) {
  const scriptPath = String(pluginDir || "") + "/scripts/clear-color-cache.sh";
  const command = ["bash", scriptPath, cacheDir];
  const entries = preservedEntries || ({});
  const screenNames = Object.keys(entries);
  for (let i = 0; i < screenNames.length; i++) {
    const path = String(entries[screenNames[i]] && entries[screenNames[i]].path || "").trim();
    if (path.length > 0) {
      command.push(path);
    }
  }
  return command;
}
