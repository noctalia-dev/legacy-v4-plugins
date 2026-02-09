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
    property string supportedLayouts: "both"
    property bool supportsAutoPaste: false
    property int preferredGridColumns: 3

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
            database = []
            rawdb.forEach((entry) => {
                    database.push({
                        title: entry.title,
                        description: entry.format + " • " + entry.authors,
                        cover: entry.cover,
                        file: entry.file,
                        authorSearch: FuzzySort.prepare(entry.authors),
                        titleSearch: FuzzySort.prepare(entry.title)
                    });
            });
            loaded = true;
            Logger.i("CalibreProvider", "Finished loading db");
        } catch (e) {
            Logger.e("CalibreProvider", "Error parsing Calibre db: ", e);
        }

        loading = false;
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
        var results = FuzzySort.go(query, database, {
            limit: maxResults,
            keys: ["titleSearch", "authorSearch"]
        }).map(r => formatEntry(r.obj));

        return results;
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
        Logger.i("CalibreProvider", "Opening file:", entry.file );
        Quickshell.execDetached([ pluginApi?.pluginSettings?.launcher || "xdg-open", entry.file]);
    }
}
