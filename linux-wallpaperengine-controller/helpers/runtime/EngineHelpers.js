.pragma library

function extractRuntimeError(stderrText, messages) {
  const text = String(stderrText || "").trim();
  if (text.length === 0) {
    return "";
  }

  const errorMessages = messages || ({});
  const lower = text.toLowerCase();

  if (lower.indexOf("cannot find a valid assets folder") !== -1) {
    return String(errorMessages.assetsMissing || "");
  }

  if (lower.indexOf("at least one background id must be specified") !== -1) {
    return String(errorMessages.noBackground || "");
  }

  if (lower.indexOf("opengl") !== -1 || lower.indexOf("glfw") !== -1) {
    return String(errorMessages.opengl || "");
  }

  const lines = text.split(/\r?\n/)
    .map(line => String(line || "").trim())
    .filter(line => line.length > 0);

  if (lines.length === 0) {
    return "";
  }

  let summary = lines[0];
  for (const line of lines) {
    const normalized = line.toLowerCase();
    if (normalized.indexOf("error") !== -1 || normalized.indexOf("failed") !== -1) {
      summary = line;
      break;
    }
  }

  const maxLength = 220;
  if (summary.length > maxLength) {
    summary = summary.substring(0, maxLength) + "...";
  }

  return summary;
}

function buildEngineCommand(options) {
  const commandOptions = options || ({});
  const command = ["linux-wallpaperengine"];
  let firstPath = "";
  const appendedWallpaperIds = {};

  command.push("--fps");
  command.push(String(commandOptions.defaultFps));

  const runtimeClamp = String(commandOptions.defaultClamp || "clamp").trim();
  if (runtimeClamp.length > 0) {
    command.push("--clamp");
    command.push(runtimeClamp);
  }

  if (commandOptions.defaultMuted) {
    command.push("--silent");
  } else {
    command.push("--volume");
    command.push(String(commandOptions.defaultVolume));
  }

  if (!commandOptions.defaultAudioReactiveEffects) {
    command.push("--no-audio-processing");
  }

  if (commandOptions.defaultNoAutomute) {
    command.push("--noautomute");
  }

  if (commandOptions.defaultDisableMouse) {
    command.push("--disable-mouse");
  }

  if (commandOptions.defaultDisableParallax) {
    command.push("--disable-parallax");
  }

  if (commandOptions.defaultNoFullscreenPause) {
    command.push("--no-fullscreen-pause");
  }

  if (commandOptions.defaultFullscreenPauseOnlyActive) {
    command.push("--fullscreen-pause-only-active");
  }

  const normalizedAssetsDir = String(commandOptions.assetsDir || "").trim();
  if (normalizedAssetsDir.length > 0) {
    command.push("--assets-dir");
    command.push(normalizedAssetsDir);
  }

  const screens = commandOptions.screens || [];
  const getScreenConfig = commandOptions.getScreenConfig;
  const normalizePath = commandOptions.normalizePath;
  const wallpaperIdFromPath = commandOptions.wallpaperIdFromPath;
  const getWallpaperProperties = commandOptions.getWallpaperProperties;

  for (const screen of screens) {
    const screenName = String(screen && screen.name || "").trim();
    if (screenName.length === 0) {
      continue;
    }

    const screenCfg = getScreenConfig ? getScreenConfig(screenName) : ({});
    const path = normalizePath ? normalizePath(screenCfg.path) : String(screenCfg.path || "").trim();
    if (path.length === 0) {
      continue;
    }

    if (firstPath.length === 0) {
      firstPath = path;
    }

    command.push("--screen-root");
    command.push(screenName);
    command.push("--bg");
    command.push(path);
    command.push("--scaling");
    command.push(String(screenCfg.scaling || commandOptions.defaultScaling || "fill"));

    const wallpaperId = wallpaperIdFromPath ? wallpaperIdFromPath(path) : "";
    if (wallpaperId.length > 0 && !appendedWallpaperIds[wallpaperId]) {
      const customProperties = getWallpaperProperties ? getWallpaperProperties(path) : ({});
      for (const propertyKey of Object.keys(customProperties)) {
        const propertyValue = customProperties[propertyKey];
        if (propertyValue === undefined || propertyValue === null || String(propertyKey || "").trim().length === 0) {
          continue;
        }
        command.push("--set-property");
        command.push(String(propertyKey) + "=" + String(propertyValue));
      }
      appendedWallpaperIds[wallpaperId] = true;
    }
  }

  if (firstPath.length > 0) {
    command.push(firstPath);
  }

  return command;
}
