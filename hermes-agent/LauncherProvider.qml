import QtQuick
import qs.Commons

Item {
  id: root

  property var pluginApi: null
  property var launcher: null
  property string name: "Hermes"
  property bool handleSearch: false
  property string supportedLayouts: "list"

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string prefix: cfg.launcherPrefix ?? defaults.launcherPrefix ?? ">hermes"

  function handleCommand(searchText) {
    return searchText.startsWith(prefix);
  }

  function commands() {
    return [{
      "name": prefix,
      "description": pluginApi?.tr("launcher.commandDescription"),
      "icon": "sparkles",
      "isTablerIcon": true,
      "isImage": false,
      "onActivate": function() {
        if (launcher) launcher.setSearchText(prefix + " ");
      }
    }];
  }

  function closeLauncher() {
    if (launcher) launcher.close();
  }

  function openPanel() {
    if (mainInstance && typeof mainInstance.openPreferredPanel === "function") {
      mainInstance.openPreferredPanel(null, null);
    } else {
      pluginApi?.openPanel(pluginApi?.panelOpenScreen);
    }
    closeLauncher();
  }

  function getResults(searchText) {
    if (!searchText.startsWith(prefix)) return [];

    var content = searchText.slice(prefix.length).replace(/^\s+/, "");
    var results = [];

    if (content.length > 0) {
      results.push({
        "name": pluginApi?.tr("launcher.ask"),
        "description": content,
        "icon": "send",
        "isTablerIcon": true,
        "isImage": false,
        "_score": 1000,
        "onActivate": function() {
          mainInstance?.oneShot(content);
          root.openPanel();
        }
      });
    } else {
      results.push({
        "name": pluginApi?.tr("launcher.typePrompt"),
        "description": prefix + " plan the next change",
        "icon": "message-circle",
        "isTablerIcon": true,
        "isImage": false,
        "_score": 1000,
        "onActivate": function() {}
      });
    }

    results.push({
      "name": pluginApi?.tr("launcher.openPanel"),
      "description": pluginApi?.tr("launcher.openPanelDescription"),
      "icon": "panel-right-open",
      "isTablerIcon": true,
      "isImage": false,
      "_score": 950,
      "onActivate": root.openPanel
    });

    results.push({
      "name": pluginApi?.tr("launcher.newSession"),
      "description": pluginApi?.tr("launcher.newSessionDescription"),
      "icon": "plus",
      "isTablerIcon": true,
      "isImage": false,
      "_score": 900,
      "onActivate": function() {
        mainInstance?.createSession();
        root.openPanel();
      }
    });

    results.push({
      "name": pluginApi?.tr("launcher.resumeLatest"),
      "description": pluginApi?.tr("launcher.resumeLatestDescription"),
      "icon": "history",
      "isTablerIcon": true,
      "isImage": false,
      "_score": 850,
      "onActivate": function() {
        var storedId = ((mainInstance?.state || {}).session || {}).stored_id || "";
        if (storedId !== "") mainInstance?.resumeSession(storedId);
        root.openPanel();
      }
    });

    return results;
  }
}
