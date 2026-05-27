import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    property string name: "Obsidian Vaults"
    property var launcher: null
    property bool handleSearch: false
    property string supportedLayouts: "list"
    property bool supportsAutoPaste: false
    property bool ignoreDensity: false

    property int maxResults: 50

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string configPath: ""
    property var database: []
    property bool loaded: false
    property bool loading: false

    FileView {
        id: configFile
        onTextChanged: root.parseConfig()
        onLoadFailed: (err) => {
            Logger.e("ObsidianProvider", "Failed to load config:", err);
            root.loading = false;
            root.loaded = false;
        }
    }

    function init() {
        Logger.i("ObsidianProvider", "init, pluginDir:", pluginApi?.pluginDir);
        handleSearch = cfg.includeInSearch ?? defaults.includeInSearch;
        let p = cfg.obsidianConfigPath ?? defaults.obsidianConfigPath;
        configPath = p.replace(/~/g, Quickshell.env("HOME"));
        loading = true;
        loaded = false;
        configFile.path = configPath;
    }

    function parseConfig() {
        try {
            const raw = configFile.text();
            if (!raw) { return; }
            const data = JSON.parse(raw);
            const vaults = data.vaults || {};
            const entries = [];
            for (const id in vaults) {
                const v = vaults[id];
                if (!v || !v.path) continue;
                const path = v.path;
                const name = path.split('/').filter(s => !!s).pop() || path;
                entries.push({
                    id: id,
                    path: path,
                    displayName: name,
                    ts: v.ts || 0,
                    isOpen: !!v.open
                });
            }
            entries.sort((a, b) => b.ts - a.ts);
            root.database = entries;
            loaded = true;
            loading = false;
            Logger.i("ObsidianProvider", "Loaded", entries.length, "vaults");
            if (launcher && launcher.activeProvider == root) {
                launcher.updateResults();
            }
        } catch (e) {
            Logger.e("ObsidianProvider", "Parse error:", e);
            loading = false;
            loaded = false;
        }
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">obs");
    }

    function commands() {
        return [{
            "name": ">obs",
            "description": pluginApi?.tr("launcher.command.description"),
            "icon": "obsidian",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function() {
                launcher.setSearchText(">obs ");
            }
        }];
    }

    function getResults(searchText: string): list<var> {
        const trimmed = searchText.trim();
        const isCommandMode = trimmed.startsWith(">obs");
        if (isCommandMode) {
            if (loading) {
                return [{
                    "name": pluginApi?.tr("launcher.loading.name"),
                    "description": pluginApi?.tr("launcher.loading.description"),
                    "icon": "refresh",
                    "isTablerIcon": true,
                    "isImage": false,
                    "onActivate": function() {}
                }];
            }
            if (!loaded) {
                return [{
                    "name": pluginApi?.tr("launcher.error.name"),
                    "description": pluginApi?.tr("launcher.error.description"),
                    "icon": "alert-circle",
                    "isTablerIcon": true,
                    "isImage": false,
                    "onActivate": function() { root.init(); }
                }];
            }
            const query = trimmed.slice(4).trim().toLowerCase();
            if (!!query) {
                return doSearch(query);
            }
            return database.map(formatEntry);
        } else {
            if (!trimmed || trimmed.length < 2 || loading || !loaded) {
                return [];
            }
            return doSearch(trimmed);
        }
    }

    function doSearch(query: string): list<var> {
        return FuzzySort.go(query, database, {
            limit: maxResults,
            key: "displayName"
        }).map(r => formatEntry(r.obj));
    }

    function formatEntry(entry) {
        return {
            "name": entry.displayName,
            "description": entry.path,
            "icon": "obsidian",
            "isTablerIcon": false,
            "isImage": false,
            "hideIcon": false,
            "badgeIcon": entry.isOpen ? "circle-dot" : "",
            "singleLine": false,
            "provider": root,
            "onActivate": function() {
                root.activateEntry(entry);
                launcher.close();
            }
        };
    }

    function activateEntry(entry) {
        const uri = "obsidian://open?vault=" + encodeURIComponent(entry.displayName);
        Logger.i("ObsidianProvider", "Opening vault:", uri);
        Quickshell.execDetached(["xdg-open", uri]);
    }
}
