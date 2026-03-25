import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    // Plugin API provided by PluginService
    property var pluginApi: null

    // Provider metadata
    property string name: "Kagi Quick Search"
    property var launcher: null
    property bool handleSearch: false
    property string supportedLayouts: "single"
    property bool supportsAutoPaste: false
    property string emptyBrowsingMessage: "Enter a query"
    
    // State
    property string answer: ""
    property string answeredQuery: ""  // The query that the current answer is for
    property string pendingQuery: ""

    // Settings
    property string kagiSessionToken: pluginApi?.pluginSettings?.kagiSessionToken ?? ""
    property int debounceMs: pluginApi?.pluginSettings?.debounceMs ?? 500

    function handleCommand(searchText) {
        return searchText.startsWith(">kagi");
    }

    function commands() {
        return [
            {
                "name": ">kagi",
                "description": "Get a quick answer to a query from Kagi",
                "icon": "search",
                "isTablerIcon": true,
                "isImage": false,
                "onActivate": function () {
                    launcher.setSearchText(">kagi ");
                }
            }
        ];
    }

    function fetchKagiAnswer(query: string, callback: var): void {
        internal.pendingCallback = callback
        internal.pendingQuery = query
        internal.collectedOutput = ""
        internal.process.running = true
    }

    Timer {
        id: debounceTimer
        interval: root.debounceMs
        repeat: false
        
        onTriggered: {
            const query = root.pendingQuery
            if (query.length > 10) {
                Logger.i("Kagi Quick Search", `Searching for ${query}`)
                
                fetchKagiAnswer(query, function(error, result) {
                    if (error) {
                        Logger.e("Kagi Quick Search", error)
                        root.answer = "Error: " + error
                    } else {
                        Logger.i("Kagi Quick Search", `Got answer: ${result.substring(0, 100)}...`)
                        root.answer = result
                    }
                    root.answeredQuery = query
                    
                    // Force refresh by appending and removing a space
                    if (root.launcher) {
                        const originalText = ">kagi " + query
                        root.launcher.setSearchText(originalText + " ")
                        root.launcher.setSearchText(originalText)
                    }
                })
            }
        }
    }

    QtObject {
        id: internal
        
        property string pendingQuery: ""
        property var pendingCallback: null
        property string collectedOutput: ""

        property Process process: Process {
            running: false

            command: [
                "bash", "-c",
                `curl -s 'https://kagi.com/mother/context?q=${encodeURIComponent(internal.pendingQuery)}' \
                    -X 'POST' \
                    -H 'accept: application/vnd.kagi.stream' \
                    -H 'accept-language: en-US,en;q=0.9' \
                    -H 'content-length: 0' \
                    -b 'kagi_session=${root.kagiSessionToken}' \
                    -H 'origin: https://kagi.com' \
                    -H 'referer: https://kagi.com/search?q=${encodeURIComponent(internal.pendingQuery)}' \
                    -H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36' \
                    -H 'x-kagi-authorization: ${root.kagiSessionToken}' \
                    --output - | tail -1 | cut -d: -f2- | jq -r '.md' | sed 's/\\[\\^[0-9]*\\]//g; s/ \\././g'`
            ]

            stdout: SplitParser {
                onRead: data => {
                    internal.collectedOutput += data + "\n"
                }
            }

            onExited: function(exitCode, exitStatus) {
                Logger.i("Kagi Quick Search", "Search completed with exit code: " + exitCode)
                
                const result = internal.collectedOutput.trim()
                
                if (internal.pendingCallback) {
                    if (exitCode === 0) {
                        internal.pendingCallback(null, result)
                    } else {
                        internal.pendingCallback("Search failed with exit code: " + exitCode, null)
                    }
                    internal.pendingCallback = null
                }
            }
        }
    }

    function getResults(searchText) {
        if (!kagiSessionToken || kagiSessionToken === "") {
            return [
                {
                    "name": "Kagi Session Token not provided or invalid",
                    "description": "Please provide Kagi Session Token in the plugin settings",
                    "icon": "alert-circle",
                    "isTablerIcon": true,
                    "isImage": false
                }
            ];
        }

        if (!searchText.startsWith(">kagi")) {
            debounceTimer.stop()
            return [];
        }

        const query = searchText.slice(5).trim();

        // If we have an answer for this exact query, show it
        if (root.answer && root.answeredQuery === query) {
            return [
                {
                    "name": "Kagi Answer",
                    "description": root.answer,
                    "icon": "message-circle",
                    "isTablerIcon": true,
                    "isImage": false
                }
            ];
        }

        // Queue up a search if query changed
        if (query.length > 10 && query !== root.pendingQuery) {
            root.pendingQuery = query
            debounceTimer.restart()
        }

        return [];
    }
}