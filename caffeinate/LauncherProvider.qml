import QtQuick
import qs.Commons
import "DurationLanguage.js" as DurationLanguage
import "LauncherModel.js" as LauncherModel

Item {
  id: root

  property var pluginApi: null
  property string name: pluginApi?.tr("provider.name") ?? ""
  property var launcher: null
  property bool handleSearch: false
  property string supportedLayouts: "list"
  property bool supportsAutoPaste: false
  property bool ignoreDensity: false
  property bool trackUsage: false

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property string iconMode: Settings.data.appLauncher.iconMode ?? "tabler"

  onIconModeChanged: refreshResults()

  function init() {
  }

  function onOpened() {
    refreshResults();
  }

  function commandAlias() {
    return LauncherModel.validateAlias(cfg.alias ?? defaults.alias ?? "", "caffeinate").normalized
        ?? "";
  }

  function configuredPresets() {
    return cfg.presets ?? defaults.presets ?? [];
  }

  function includesIndefinitePreset() {
    return cfg.includeIndefinitePreset ?? defaults.includeIndefinitePreset ?? true;
  }

  function handleCommand(searchText) {
    return LauncherModel.matchCommand(searchText, "caffeinate", commandAlias()).matched;
  }

  function commands() {
    const entries = [
            {
              "name": ">caffeinate",
              "description": pluginApi?.tr("provider.description"),
              "icon": launcherIcon("coffee", "appointment-soon"),
              "isTablerIcon": true,
              "isImage": false,
              "provider": root,
              "onActivate": function () {
                launcher.setSearchText(">caffeinate ");
              }
            }
          ];

    const alias = commandAlias();
    if (alias !== "") {
      entries.push({
                     "name": ">" + alias,
                     "description": pluginApi?.tr("provider.aliasDescription"),
                     "icon": launcherIcon("coffee", "appointment-soon"),
                     "isTablerIcon": true,
                     "isImage": false,
                     "provider": root,
                     "onActivate": function () {
                       launcher.setSearchText(">" + alias + " ");
                     }
                   });
    }

    return entries;
  }

  function getResults(searchText) {
    const match = LauncherModel.matchCommand(searchText, "caffeinate", commandAlias());
    if (!match.matched)
      return [];

    const session = mainInstance ? mainInstance.sessionSnapshot() : {
                                     "active": false
                                   };
    const descriptors = LauncherModel.actionsFor(match.expression, session, configuredPresets(),
                                                 includesIndefinitePreset(),
                                                 DurationLanguage.parse);

    return descriptors.map(formatEntry);
  }

  function formatEntry(descriptor) {
    if (descriptor.kind === "status")
      return statusEntry(descriptor);
    if (descriptor.kind === "incomplete")
      return feedbackEntry("incomplete", descriptor.code);
    if (descriptor.kind === "invalid")
      return feedbackEntry("invalid", descriptor.code);
    return actionEntry(descriptor);
  }

  function launcherIcon(tablerIcon, nativeIcon) {
    return iconMode === "tabler" ? tablerIcon : nativeIcon;
  }

  function noAction() {
  }

  function baseEntry(name, description, tablerIcon, nativeIcon, activate) {
    return {
      "name": name,
      "description": description,
      "icon": launcherIcon(tablerIcon, nativeIcon),
      "isTablerIcon": true,
      "isImage": false,
      "hideIcon": false,
      "singleLine": false,
      "provider": root,
      "onActivate": activate
    };
  }

  function statusEntry(descriptor) {
    if (descriptor.mode === "finite") {
      const duration = DurationLanguage.formatDuration(descriptor.seconds);
      return baseEntry(pluginApi?.tr("status.finite", {
                                       "duration": duration
                                     }), pluginApi?.tr("status.finiteDescription"), "coffee",
                       "appointment-soon", noAction);
    }

    if (descriptor.mode === "indefinite") {
      return baseEntry(pluginApi?.tr("status.indefinite"), pluginApi?.tr(
                         "status.indefiniteDescription"), "coffee", "system-lock-screen", noAction);
    }

    return baseEntry(pluginApi?.tr("status.off"), pluginApi?.tr("status.offDescription"),
                     "coffee-off", "process-stop", noAction);
  }

  function feedbackEntry(state, code) {
    const knownCode = code || "invalid-expression";
    return baseEntry(pluginApi?.tr("feedback." + state + ".title"), pluginApi?.tr("feedback."
                                                                                  + state + "."
                                                                                  + knownCode),
                     state === "invalid" ? "alert-circle" : "info-circle", state === "invalid"
                     ? "dialog-warning" : "dialog-information", noAction);
  }

  function actionEntry(descriptor) {
    if (descriptor.action === "end-session") {
      return baseEntry(pluginApi?.tr("action.end"), pluginApi?.tr("action.endDescription"),
                       "coffee-off", "process-stop", function () {
                         if (mainInstance && mainInstance.endSession())
                           launcher.close();
                       });
    }

    if (descriptor.action === "start-indefinite") {
      return baseEntry(pluginApi?.tr(descriptor.replacing ? "action.replaceIndefinite" :
                                                            "action.startIndefinite"), pluginApi?.tr(
                         descriptor.replacing ? "action.replaceIndefiniteDescription" :
                                                "action.startIndefiniteDescription"), "infinity",
                       "system-lock-screen", function () {
                         if (mainInstance && mainInstance.startIndefinite())
                           launcher.close();
                       });
    }

    return baseEntry(pluginApi?.tr(descriptor.replacing ? "action.replaceFinite" :
                                                          "action.startFinite", {
                                     "duration": descriptor.normalized
                                   }), pluginApi?.tr(descriptor.replacing
                                                     ? "action.replaceFiniteDescription" :
                                                       "action.startFiniteDescription"), "clock",
                     "appointment-soon", function () {
                       if (mainInstance && mainInstance.startFinite(descriptor.seconds))
                         launcher.close();
                     });
  }

  function refreshResults() {
    if (launcher && launcher.isOpen && launcher.activeProvider === root)
      launcher.updateResults();
  }

  Connections {
    target: root.mainInstance
    ignoreUnknownSignals: true

    function onSessionActiveChanged() {
      root.refreshResults();
    }

    function onRemainingSecondsChanged() {
      root.refreshResults();
    }
  }
}
