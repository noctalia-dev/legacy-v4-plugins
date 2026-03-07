import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    // Plugin API provided by PluginService
    property var pluginApi: null

    // Provider metadata
    property string name: "Visual Studio Code workspaces"
    property var launcher: null
    property bool handleSearch: false
    property string supportedLayouts: "list"
    property bool supportsAutoPaste: false
    property bool ignoreDensity: false

    // Constants
    property int maxResults: 50

    // Config
    property string command
    property string workspaceDir

    // Database
    property var database: null
    property bool loaded: false
    property bool loading: false

    Process {
        id: workspaceDirLoader
        command: ["sh", "-c", "placeholder"]
        stdout: StdioCollector {
        }
        stderr: StdioCollector {
        }
        onExited: (exitCode) => root.parseWorkspaceDataFiles(exitCode)
    }

    Component {
        id: workspaceFileParser

        FileView {
            id: fileView

            JsonAdapter {
                property string folder
                property string workspace
            }
        }
    }


    // Load database on init
    function init() {
        Logger.i("VSCodeProvider", "init called, pluginDir:", pluginApi?.pluginDir);
        name = pluginApi.tr("launcher.title");
        handleSearch = pluginApi.pluginSettings.includeInSearch ?? pluginApi.manifest.metadata.defaultSettings.includeInSearch;
        command = pluginApi?.pluginSettings?.command || pluginApi?.manifest.metadata.defaultSettings.command;
        fetchSessionFiles()
    }

    function getWorkspacesDir() {
        const configName = pluginApi?.pluginSettings?.configName || pluginApi?.manifest.metadata.defaultSettings.configName;
        const baseConfig = Quickshell.env('XDG_CONFIG_HOME') ?? Quickshell.env('HOME') + "/.config";
        const workspaceDir = baseConfig.concat('/', configName, '/User/workspaceStorage');
        return workspaceDir;
    }

    function fetchSessionFiles() {
        if(workspaceDirLoader.running) {
            Logger.w("VSCodeProvider", "Already fetching workspace files!");
            return;
        }
        Logger.i("VSCodeProvider", "Fetching workspace files");
        loaded = false;
        loading = true;
        workspaceDir = getWorkspacesDir();
        workspaceDirLoader.command[2] = "ls -1t " + enquote(workspaceDir) + "/*/workspace.json";
        workspaceDirLoader.running = true;
    }

    function parseWorkspaceDataFiles(exitCode: int) {
        if( exitCode != 0 ) {
            Logger.e("VSCodeProvider", "Error listing WorkspaceData files: ", workspaceDirLoader.stderr.text);
        }

        try {
            let fileList = workspaceDirLoader.stdout.text.split('\n');
            root.database = fileList
                .filter((filename) => !!filename.trim())
                .map((filename) => {
                const entry = {
                    fullPath: filename,
                    displayName: "",
                    isWorkspace: false,
                    loaded: false
                };

                const loader = workspaceFileParser.createObject(root);
                // Connect the signal handler before setting the path to avoid race condition
                //Logger.d("VSCodeProvider", Object.entries(loader));
                loader.textChanged.connect( () => root.workspaceFileLoaded(entry, loader.adapter) );
                loader.path = filename;

                return entry;
            });
        } catch (e) {
            Logger.e("VSCodeProvider", "Error parsing workspace files: ", e);
        }
    }

    function displayNameFromFolder(fullname: string): string {
        const finalPart = fullname.split('/').pop();
        if(fullname.startsWith("vscode-remote://")) {
            const tail = fullname.slice(16);
            const [type, path] = tail.split('+');
            Logger.i("VSCodeProvider", tail);
            switch(type) {
                case 'ssh-remote':
                    const host = path.slice(0, path.indexOf('/'));
                    return finalPart + ` [SSH: ${host}]`;
                default:
                    return finalPart + ` [${deslugify(type)}]`;
            }
        } else {
            return finalPart;
        }
    }

    function deslugify(slug: string): string {
        const words = slug.split('-');
        for(let i = 0; i < words.length; i++) {
            words[i] = words[i][0].toUpperCase() + words[i].slice(1);
        }
        return words.join(" ");
    }

    function displayNameFromWorkspace(fullname: string): string {
        return fullname.split('/').pop().replace(/.code-workspace$/, '') + " (Workspace)";
    }

    function workspaceFileLoaded(entry, workspaceJson) {
        if(!!workspaceJson.workspace) {
            entry.uri = workspaceJson.workspace;
            entry.detail = decodeURIComponent(entry.uri).replace(/^file:\/\//, "");
            entry.displayName = displayNameFromWorkspace(entry.detail);
            entry.isWorkspace = true;
        } else if(!!workspaceJson.folder) {
            entry.uri = workspaceJson.folder;
            entry.detail = decodeURIComponent(entry.uri).replace(/^file:\/\//, "");
            entry.displayName = displayNameFromFolder(entry.detail);
            entry.isWorkspace = false;
        } else {
            Logger.w("VSCodeProvider", "Couldn't parse workspace definition for", entry.fullPath);
            database.splice(database.indexOf(entry), 1); // Remove the unparseable entry from the database
        }
        entry.loaded = true;

        // Check to see if we've finished loading all the workspace files
        for(let e of database) {
            if(!e.loaded) {
                return;
            }
        }

        loaded = true;
        loading = false;
        Logger.i("VSCodeProvider", "Finished loading workspace files");
        if (launcher && launcher.activeProvider == root) {
            launcher.updateResults();
        }
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">vsc");
    }

    // Return available commands when user types ">"
    function commands() {
        return [{
            "name": ">vsc",
            "description": pluginApi.tr("launcher.description"),
            "icon": "brand-vscode",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function() {
                launcher.setSearchText(">vsc ");
            }
        }];
    }

    // Get search results
    function getResults(searchText: string): list<var> {

        const trimmed = searchText.trim();
        // Handle command mode: ">vsc" or ">vsc <search>"
        const isCommandMode = trimmed.startsWith(">vsc");
        if (isCommandMode) {

            if (loading) {
              return [{
                "name": pluginApi.tr("launcher.loading.title"),
                "description": pluginApi.tr("launcher.loading.description"),
                "icon": "refresh",
                "isTablerIcon": true,
                "isImage": false,
                "onActivate": function() {}
              }];
            }

            if (!loaded) {
              return [{
                "name": pluginApi.tr("launcher.error.title"),
                "description": pluginApi.tr("launcher.error.description"),
                "icon": "alert-circle",
                "isTablerIcon": true,
                "isImage": false,
                "onActivate": function() {
                  root.init();
                }
              }];
            }

            let query = trimmed.slice(6).trim().toLowerCase();
            if(!!query) {
                return doSearch(query);
            } else {
                // Database is already sorted by most recently updated workspace
                return database.map(formatEntry); 
            }

        } else {
            // Regular search mode - require at least 2 chars
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
          // Display
          "name": entry.displayName,           // Main text
          "description": entry.detail || "",   // Secondary text (optional)

          // Icon options (choose one)
          "icon": root.command,                   // Icon name
          "isTablerIcon": false,             // Use Tabler icon set
          "isImage": false,                 // Is this an image?
          "hideIcon": false,                // Hide the icon entirely
          "badgeIcon": "folder-open",

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

    function activateEntry(entry) {
        Logger.i("VSCodeProvider", "Opening workspace:", entry.fullPath );
        
        const option = entry.isWorkspace ? "--file-uri" : "--folder-uri";
        Quickshell.execDetached([command, option, entry.uri]);
    }

    function enquote(text: string): string {
        return "'" + text.replace(/'/g, "'\\''") + "'";
    }

}

