import QtQuick
import qs.Commons

Item {
    id: root
    
    property var pluginApi: null
    property var launcher: null
    property string name: "Web Search"

    property bool handleSearch: true 
    property string supportedLayouts: "list"

    property var suggestions: []
    property string lastQuery: ""

    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property string engineName: cfg.search_engine ?? defaults.search_engine ?? "Google"
    readonly property bool showSuggestions: cfg.show_suggestions ?? defaults.show_suggestions ?? true
    readonly property int maxResults: cfg.max_results ?? defaults.max_results ?? 5
    readonly property bool directUrl: cfg.direct_url ?? defaults.direct_url ?? true

    readonly property var engine: {
        if (engineName === "DuckDuckGo") {
            return { "search": "https://duckduckgo.com/?q=", "suggest": "https://duckduckgo.com/ac/?q=" };
        } else if (engineName === "Bing") {
            return { "search": "https://www.bing.com/search?q=", "suggest": "https://www.bing.com/osjson.aspx?query=" };
        } else if (engineName === "Brave") {
            return { "search": "https://search.brave.com/search?q=", "suggest": "https://search.brave.com/api/suggest?q=" };
        } else if (engineName === "Yandex") {
            return { "search": "https://yandex.com/search/?text=", "suggest": "https://suggest.yandex.com/suggest-ya.cgi?v=4&part=" };
        } else {
            return { "search": "https://www.google.com/search?q=", "suggest": "https://suggestqueries.google.com/complete/search?client=chrome&q=" };
        }
    }

    function isUrl(text) {
        if (!text || text.includes(" ")) return false;

        const protocolPattern = /^[a-z0-9]+:\/\/\S+/i;
        if (protocolPattern.test(text)) return true;

        const localhostPattern = /^localhost(\/\S*)?$/i;
        const ipPattern = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(:[0-9]+)?(\/\S*)?$/;
        const domainPattern = /^([a-zA-Z0-9-]{1,63}\.)+[a-zA-Z]{2,}(:[0-9]+)?(\/\S*)?$/i;
        const hostPortPattern = /^[a-zA-Z0-9-]+:[0-9]+(\/\S*)?$/i;

        return localhostPattern.test(text) || ipPattern.test(text) || domainPattern.test(text) || hostPortPattern.test(text);
    }

    function normalizeUrl(text) {
        text = text.trim();
        if (!text) return "";

        const protocolPattern = /^[a-z0-9]+:\/\/\S+/i;
        if (protocolPattern.test(text)) return text;

        const localhostPattern = /^localhost(\/\S*)?$/i;
        const ipPattern = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(:[0-9]+)?(\/\S*)?$/;
        const hostPortPattern = /^[a-zA-Z0-9-]+:[0-9]+(\/\S*)?$/i;
        
        if (localhostPattern.test(text) || ipPattern.test(text) || hostPortPattern.test(text)) {
            return "http://" + text;
        }

        return "https://" + text;
    }

    function getResults(searchText) {
        let results = [];
        let rawText = searchText.trim();
        let isCommand = rawText.startsWith(">web");
        let query = rawText;

        if (isCommand) {
            query = rawText.slice(5).trim();
        }

        if (query === "" && !isCommand) return [];
        if (rawText.startsWith(">") && !isCommand) return [];
        
        if (isCommand && query === "") {
            return [{
                "name": pluginApi?.tr("launcher.typeSomething"),
                "description": pluginApi?.tr("launcher.searchInternet", { engine: engineName }),
                "icon": "search",
                "isTablerIcon": true
            }];
        }

        if (directUrl && isUrl(query)) {
            let url = normalizeUrl(query);
            results.push({
                "name": pluginApi?.tr("launcher.openUrl", { url: url }),
                "description": pluginApi?.tr("launcher.openUrlDescription"),
                "icon": "link",
                "isTablerIcon": true,
                "_score": isCommand ? 1000 : -4,
                "onActivate": function() {
                    Qt.openUrlExternally(url);
                    if (launcher) launcher.close();
                }
            });
        }

        results.push({
            "name": pluginApi?.tr("launcher.search", { query: query }),
            "description": pluginApi?.tr("launcher.openIn", { engine: engineName }),
            "icon": "world",
            "isTablerIcon": true,
            "_score": isCommand ? 999 : -5,
            "onActivate": function() {
                Qt.openUrlExternally(engine.search + encodeURIComponent(query));
                if (launcher) launcher.close();
            }
        });

        if (showSuggestions && query !== lastQuery && query.length > 1) {
            lastQuery = query;
            suggestions = [];
            if (launcher) launcher.updateResults();
            fetchSuggestions(query, engine.suggest, maxResults);
        }

        if (suggestions.length > 0) {
            for (let i = 0; i < suggestions.length; i++) {
                let s = suggestions[i];
                results.push({
                    "name": s,
                    "description": pluginApi?.tr("launcher.suggestion", { engine: engineName }),
                    "icon": "search",
                    "isTablerIcon": true,
                    "_score": isCommand ? (900 - i) : (-10 - i),
                    "onActivate": function() {
                        Qt.openUrlExternally(engine.search + encodeURIComponent(s));
                        if (launcher) launcher.close();
                    }
                });
            }
        }

        return results;
    }

    function fetchSuggestions(query, url, maxResults) {
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    if (query !== lastQuery) return;
                    try {
                        let data = JSON.parse(xhr.responseText);
                        
                        if (Array.isArray(data) && data.length > 0) {
                            // Format DDG: [{"phrase": "s1"}, ...]
                            if (typeof data[0] === 'object' && data[0].phrase !== undefined) {
                                suggestions = data.map(item => item.phrase).slice(0, maxResults);
                                if (launcher) launcher.updateResults();
                            }
                            // Format Others: ["keyword", ["s1", "s2"]]
                            else if (data.length > 1 && Array.isArray(data[1])) {
                                suggestions = data[1].slice(0, maxResults);
                                if (launcher) launcher.updateResults();
                            }
                        }
                    } catch (e) {
                        Logger.e("WebSearch", "JSON Parse error");
                    }
                }
            }
        }
        xhr.open("GET", url + encodeURIComponent(query));
        xhr.send();
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">web");
    }

    function commands() {
        return [{
            "name": ">web",
            "description": pluginApi?.tr("launcher.command.description"),
            "icon": "world",
            "isTablerIcon": true,
            "onActivate": function() {
                launcher.setSearchText(">web "); 
            }
        }];
    }
}