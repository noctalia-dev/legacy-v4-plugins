import QtQuick
import Quickshell
import qs.Commons

Item {
    id: root

    // Plugin API provided by PluginService
    property var pluginApi: null

    // Provider metadata
    property string name: "Custom Commands"
    property var launcher: null
    property bool handleSearch: true
    property string supportedLayouts: "list"
    property bool supportsAutoPaste: false
    property bool ignoreDensity: false
    property bool trackUsage: true // Track usage frequency for "most used" sorting

    // Constants
    property int maxResults: 50

    // Command database
    property var commandList: []

    function init() {
        loadCommands();
    }

    function onOpened() {
        loadCommands();
    }

    function loadCommands() {
        var src = pluginApi?.pluginSettings?.commands ?? pluginApi?.manifest?.metadata?.defaultSettings?.commands ?? [];
        var cmds = [];
        for (var i = 0; i < src.length; i++) {
            if (src[i].command && src[i].command.trim() !== "") {
                cmds.push({
                    "name": src[i].name || "",
                    "command": src[i].command || "",
                    "icon": src[i].icon || "terminal-2"
                });
            }
        }
        commandList = cmds;
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">run");
    }

    function commands() {
        return [{
            "name": pluginApi.tr("launcher.command.name"),
            "description": pluginApi.tr("launcher.command.description"),
            "icon": "terminal-2",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function() {
                launcher.setSearchText(">run ");
            }
        }];
    }

    function getResults(searchText) {
        var trimmed = searchText.trim();
        var isCommandMode = trimmed.startsWith(">run");

        if (isCommandMode) {
            var query = trimmed.slice(4).trim();
            if (query.length > 0) {
                return doSearch(query);
            } else {
                return commandList.map(formatEntry);
            }
        } else {
            if (!trimmed || trimmed.length < 2) {
                return [];
            }
            return doSearch(trimmed);
        }
    }

    function doSearch(query) {
        return FuzzySort.go(query, commandList, {
            limit: maxResults,
            keys: ["name", "command"]
        }).map(r => formatEntry(r.obj, r.score));
    }

    function formatEntry(cmd, score) {
        return {
            "usageKey": cmd.command,
            "name": cmd.name,
            "description": cmd.command,
            "_score": (score !== undefined ? score : 0),
            "icon": cmd.icon || "terminal-2",
            "isTablerIcon": true,
            "badgeIcon": "terminal-2",
            "isImage": false,
            "hideIcon": false,
            "singleLine": false,
            "provider": root,
            "onActivate": function() {
                Quickshell.execDetached(["sh", "-lc", cmd.command]);
                launcher.close();
            }
        };
    }
}
