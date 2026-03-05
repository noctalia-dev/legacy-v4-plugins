import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string editAdditionalModesText: modeListToText(cfg.additionalModes !== undefined ? cfg.additionalModes : defaults.additionalModes)
  property string editExcludeModesText: modeListToText(cfg.excludeModes !== undefined ? cfg.excludeModes : defaults.excludeModes)

  spacing: Style.marginL

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

  function parseModeInput(value) {
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

  function modeListToText(value) {
    return parseModeInput(value).map(function (mode) {
      return ">" + mode;
    }).join(", ");
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Additional modes"
    description: "Extra top-level modes to append to cycling (comma-separated, e.g. >todo, >git)"
    placeholderText: ">todo, >calc"
    text: root.editAdditionalModesText
    onTextChanged: root.editAdditionalModesText = text
  }

  NDivider {
    Layout.fillWidth: true
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Exclude modes"
    description: "Top-level modes to remove from cycling (comma-separated, e.g. >cmd, >clip)"
    placeholderText: ">cmd, >clip"
    text: root.editExcludeModesText
    onTextChanged: root.editExcludeModesText = text
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("LauncherCycle", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.additionalModes = parseModeInput(root.editAdditionalModesText);
    pluginApi.pluginSettings.excludeModes = parseModeInput(root.editExcludeModesText);
    pluginApi.saveSettings();
  }
}
