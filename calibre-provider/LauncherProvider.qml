import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    // Plugin API provided by PluginService
    property var pluginApi: null

    // Provider metadata
    property string name: "Calibre"
    property var launcher: null
    property bool handleSearch: false
    property bool supportsAutoPaste: false

    property string supportedLayouts: "both"
    property real preferredGridColumns: 4
    property real preferredGridCellRatio: 1.5 // Standard eBook ratio size
    property bool ignoreDensity: false

    // Constants
    property int maxResults: 50

    // Database
    property string databaseRoot: ""
    property var database: null
    property bool loaded: false
    property bool loading: false

    Process {
        id: calibreDbLoader
        command: ["python3", "placeholder"]
        stdout: StdioCollector {
        }
        stderr: StdioCollector {
        }
        onExited: (exitCode) => root.parseDb(exitCode)
    }

     FileView {
        id: calibreConfigFile
        onLoaded: root.calibreConfigLoaded(text())
    }

    FileView {
        id: calibreDbFile
        watchChanges: true
        onFileChanged: root.reloadDb()
    }


    // Load database on init
    function init() {
        Logger.i("CalibreProvider", "init called, pluginDir:", pluginApi?.pluginDir);
        calibreDbLoader.command[1] = pluginApi.pluginDir + "/load_calibre_db.py"
        findCalibreLibrary()
    }

    function findCalibreLibrary() {
        const config = Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config";
        const calibreConfig = config + "/calibre/global.py";
        calibreConfigFile.path = calibreConfig;
        calibreConfigFile.reload();
    }

    function calibreConfigLoaded(text: string) {
        const search = /library_path = u'(.*)'/;
        const matches = text.match(search);
        if( !!matches && matches.length >= 2) {
            databaseRoot = matches[1]
            calibreDbFile.path = databaseRoot + '/metadata.db';
            reloadDb();
        } else {
            Logger.e("CalibreProvider", "Could not find calibre library location");
        }
    }

    function reloadDb() {
        if(calibreDbLoader.running) {
            Logger.w("CalibreProvider", "Already reloading db!");
            return;
        }
        Logger.i("CalibreProvider", "Reloading db");
        loading = true;
        calibreDbLoader.running = true;
    }

    function parseDb(exitCode: int) {
        if( exitCode != 0 ) {
            Logger.e("CalibreProvider", "Error loading Calibre db: ", calibreDbLoader.stderr.text);
        }

        try {
            const punct = /[^a-z0-9 ]/gi
            var rawdb = Array.from(JSON.parse(calibreDbLoader.stdout.text));
            database = {}
            rawdb.forEach((entry) => {
                    database[entry.id] = {
                        id: entry.id,
                        title: entry.title,
                        description: entry.format + " • " + entry.authors,
                        cover: entry.cover,
                        file: entry.file,
                        authorSearch: FuzzySort.prepare(entry.authors),
                        titleSearch: FuzzySort.prepare(entry.title)
                    };
            });
            loaded = true;
            Logger.i("CalibreProvider", "Finished loading db");
        } catch (e) {
            Logger.e("CalibreProvider", "Error parsing Calibre db: ", e);
        }

        loading = false;
        if (launcher && launcher.activeProvider == root) {
            launcher.updateResults();
        }
    }

    function onOpened() {
        if( pluginApi?.pluginSettings?.forceGrid ) {
            supportedLayouts = "grid";
        } else {
            supportedLayouts = "both";
        }
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">cb ");
    }

    // Return available commands when user types ">"
    function commands() {
        return [{
            "name": ">cb",
            "description": "Search for books in your Calibre library",
            "icon": "books",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function() {
                launcher.setSearchText(">cb ");
            }
        }];
    }

    // Get search results
    function getResults(searchText) {

        if (loading) {
          return [{
            "name": "Loading...",
            "description": "Loading calibre database...",
            "icon": "refresh",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function() {}
          }];
        }

        if (!loaded) {
          return [{
            "name": "Database not loaded",
            "description": "Check your log for error messages",
            "icon": "alert-circle",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function() {
              root.init();
            }
          }];
        }

        if (!searchText.startsWith(">cb")) {
            return [];
        }

        var query = searchText.slice(4).trim().toLowerCase();
        if(!!query) {
            return FuzzySort.go(query, Object.values(database), {
                limit: maxResults,
                keys: ["titleSearch", "authorSearch"]
            }).map(r => formatEntry(r.obj));
        } else {
            return pluginApi?.pluginSettings?.recentlyOpenedFiles
            ?.filter(id => id in database)
            .map(id => formatEntry(database[id])) ?? [];
        }

    }

    function formatEntry(entry) {
        const hasCover = !!entry.cover;
        return {
          // Display
          "name": entry.title,           // Main text
          "description": entry.description || "",   // Secondary text (optional)

          // Icon options (choose one)
          "icon": hasCover ? entry.cover : "book",                   // Icon name
          "isTablerIcon": !hasCover,             // Use Tabler icon set
          "isImage": hasCover,                 // Is this an image?
          "hideIcon": false,                // Hide the icon entirely

          // Layout
          "singleLine": false,              // Clip to single line height

          // Reference
          "provider": root,                 // Reference to provider (for actions)

          // Callbacks
          "onActivate": function() {        // Called when result is selected
              root.activateEntry(entry);
              launcher.close();
          },
        }
    }

    function getImageUrl(modelData) {
        if( modelData.isImage) {
            return modelData.icon;
        } else {
            return null;
        }
    }

    function activateEntry(entry) {
        updateRecentlyOpened(entry);
        Logger.i("CalibreProvider", "Opening file:", entry.file );
        Quickshell.execDetached([ pluginApi?.pluginSettings?.launcher || "xdg-open", entry.file]);
    }

    function updateRecentlyOpened(entry) {

        if( !pluginApi?.pluginSettings) {
            Logger.w("CalibreProvider", "PluginSettings not available when updating recently opened.")
            return;
        }

        const oldMru = pluginApi.pluginSettings.recentlyOpenedFiles ?? [];
        if(oldMru.length > 0 && oldMru[0] == entry.id) {
            // This is already the most recent file, do nothing
            return;
        }
        const newMru = new Array(oldMru.length+1);

        let foundLatestEntry = false;
        for(let i = 0; i < newMru.length; i++) {
            // For the first entry, put the one that we just selected
            if(i == 0) {
                newMru[i] = entry.id;
                continue;
            }

            // If the next entry we would have copied over is the one we just opened,
            // then skip it
            if(!foundLatestEntry && oldMru[i-1] == entry.id) {
                foundLatestEntry = true;
            }

            if(!foundLatestEntry) {
                // If we haven't encountered the new file in the old list yet,
                // copy the next entry from the old list, bumped down a place
                newMru[i] = oldMru[i-1];
            } else {
                // If we've already found and skipped the entry we've just opened,
                // then just copy the list over, they are in alignment again
                newMru[i] = oldMru[i];
            }
        }

        // The file we opened was already on the list, so we don't need to grow the list
        if(foundLatestEntry) {
            newMru.pop();
        }

        newMru.length = Math.min(newMru.length, pluginApi.pluginSettings.recentlyOpenedMax ?? 36);

        pluginApi.pluginSettings.recentlyOpenedFiles = newMru;
        pluginApi.saveSettings();
    }
}

