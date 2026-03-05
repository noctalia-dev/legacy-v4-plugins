import QtQuick
import Quickshell.Io
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property var preferredBuiltInModes: ["file", "cmd", "win", "settings", "emoji", "clip"]

  function detectMode(searchText) {
    const text = searchText || "";
    const match = text.match(/^>(\S+)/);
    if (match && match[1])
      return match[1];
    return "";
  }

  function modeIndex(modeId, modes) {
    for (var i = 0; i < modes.length; i++) {
      if (modes[i] === modeId)
        return i;
    }
    return -1;
  }

  function normalizePrefix(prefix) {
    if (!prefix)
      return "";

    var normalized = ("" + prefix).trim();
    if (normalized.startsWith(">"))
      normalized = normalized.slice(1);
    if (!normalized)
      return "";
    if (/\s/.test(normalized))
      return "";
    return normalized;
  }

  function parseModeList(value) {
    var input = value;
    if (input === undefined || input === null)
      return [];

    var items = [];
    if (Array.isArray(input)) {
      items = input;
    } else if (typeof input === "string") {
      items = input.split(",");
    } else {
      return [];
    }

    var result = [];
    var seen = {};
    for (var i = 0; i < items.length; i++) {
      var mode = normalizePrefix(items[i]);
      if (!mode || seen[mode])
        continue;
      seen[mode] = true;
      result.push(mode);
    }
    return result;
  }

  function getAdditionalModes() {
    var value = cfg.additionalModes;
    if (value === undefined)
      value = defaults.additionalModes;
    return parseModeList(value);
  }

  function getExcludedModes() {
    var value = cfg.excludeModes;
    if (value === undefined)
      value = defaults.excludeModes;
    return parseModeList(value);
  }

  function getAvailableModes() {
    var result = [];
    var seen = {};

    function addMode(prefix) {
      var mode = normalizePrefix(prefix);
      if (!mode)
        return;
      if (seen[mode])
        return;
      seen[mode] = true;
      result.push(mode);
    }

    for (var i = 0; i < preferredBuiltInModes.length; i++) {
      addMode(preferredBuiltInModes[i]);
    }

    var pluginModes = [];
    var providerIds = LauncherProviderRegistry.getPluginProviders() || [];
    for (var j = 0; j < providerIds.length; j++) {
      var providerId = providerIds[j];
      var metadata = LauncherProviderRegistry.getProviderMetadata(providerId) || {};
      var pluginId = providerId.startsWith("plugin:") ? providerId.slice(7) : providerId;
      var prefix = metadata.commandPrefix || pluginId;
      prefix = normalizePrefix(prefix);
      if (prefix)
        pluginModes.push(prefix);
    }

    pluginModes.sort();
    for (var k = 0; k < pluginModes.length; k++) {
      addMode(pluginModes[k]);
    }

    var additionalModes = getAdditionalModes();
    for (var m = 0; m < additionalModes.length; m++) {
      addMode(additionalModes[m]);
    }

    var excludedModes = getExcludedModes();
    if (excludedModes.length === 0)
      return result;

    var excluded = {};
    for (var n = 0; n < excludedModes.length; n++) {
      excluded[excludedModes[n]] = true;
    }

    return result.filter(function (mode) {
      return !excluded[mode];
    });
  }

  function cycle(step) {
    if (!pluginApi)
      return;

    pluginApi.withCurrentScreen(function (screen) {
      if (!screen)
        return;

      const isOpen = PanelService.isLauncherOpen(screen);
      const currentSearch = PanelService.getLauncherSearchText(screen) || "";
      const currentMode = detectMode(currentSearch);
      const modeOrder = getAvailableModes();
      const count = modeOrder.length;
      if (count === 0)
        return;

      var nextIndex = 0;
      if (isOpen) {
        const currentIndex = modeIndex(currentMode, modeOrder);
        if (currentIndex >= 0)
          nextIndex = ((currentIndex + step) % count + count) % count;
      }

      const nextSearch = ">" + modeOrder[nextIndex] + " ";

      if (isOpen)
        PanelService.setLauncherSearchText(screen, nextSearch);
      else
        PanelService.openLauncherWithSearch(screen, nextSearch);
    });
  }

  IpcHandler {
    target: "plugin:launcher-cycle"

    function next() {
      root.cycle(1);
    }

    function previous() {
      root.cycle(-1);
    }
  }
}
