import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    // ── Inline state object ──
    property QtObject state: QtObject {
        property int sessionId: 0
        property var items: []
        property string prompt: ""
        property bool allowCustomInput: false
        property bool closeOnSelect: true
        property string resultFile: "/tmp/noctalia-dmenu-result"
        property string resultFormat: "plain"
        property string callbackCmd: ""
        property var altActions: ({})
        property int maxResults: 200
        property bool active: false
    }

    // Signals for the provider to react to
    signal itemsChanged()
    signal sessionStarted(int sid)
    signal sessionEnded(int sid)

    // ── Deferred launcher open ──
    // When openPanel is called shortly after a closePanel (chaining),
    // we defer it to let the close animation finish.
    property real lastCloseTimestamp: 0
    readonly property int chainDelay: 350  // ms to wait after close before reopen

    Timer {
        id: launcherOpenTimer
        interval: root.chainDelay
        repeat: false
        onTriggered: {
            if (pluginApi && state.active) {
                pluginApi.withCurrentScreen(function(screen) {
                    pluginApi.openPanel(screen);
                });
            }
        }
    }

    // Smart open: if the panel is already showing (rapid replacement), just
    // let onItemsChanged refresh it. If we recently closed (chaining), defer.
    // Otherwise open immediately.
    function openPanelSmart() {
        if (!pluginApi) return;

        var now = Date.now();
        var elapsed = now - lastCloseTimestamp;

        // If we recently called closePanel (chaining), the panel is in its
        // close animation and panelOpenScreen hasn't cleared yet.
        // Defer the open to let the animation finish.
        if (elapsed < chainDelay) {
            launcherOpenTimer.interval = chainDelay - elapsed + 50;
            launcherOpenTimer.restart();
            Logger.d("DmenuProvider", "Deferring panel open by " + launcherOpenTimer.interval + "ms");
            return;
        }

        // No recent close — if the panel is still open (rapid replacement),
        // just let onItemsChanged refresh it in place.
        if (pluginApi.panelOpenScreen) {
            Logger.d("DmenuProvider", "Panel already open, refreshing in place");
            return;
        }

        // Panel is closed and no recent close — open immediately
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.openPanel(screen);
        });
    }

    // Set to true during beginSession when replacing an old session.
    // The Panel checks this to avoid closing during rapid replacement.
    property bool replacingSession: false

    // ── Session management ──
    function beginSession(config) {
        if (state.active) {
            var oldSid = state.sessionId;
            replacingSession = true;
            state.active = false;
            sessionEnded(oldSid);
            replacingSession = false;
        }

        state.sessionId++;
        var newSid = state.sessionId;

        state.items = config.items || [];
        state.prompt = config.prompt || "";
        state.allowCustomInput = config.allowCustomInput !== undefined
            ? config.allowCustomInput : false;
        state.closeOnSelect = config.closeOnSelect !== undefined
            ? config.closeOnSelect : true;
        state.resultFile = config.resultFile || "/tmp/noctalia-dmenu-result";
        state.resultFormat = config.resultFormat || "plain";
        state.callbackCmd = config.callbackCmd || "";
        state.altActions = config.altActions || {};
        state.maxResults = config.maxResults || 200;

        state.active = true;
        sessionStarted(newSid);
        itemsChanged();

        return newSid;
    }

    function endSession() {
        if (!state.active) return;
        var oldSid = state.sessionId;
        state.active = false;
        state.items = [];
        state.prompt = "";
        state.callbackCmd = "";
        state.altActions = {};
        launcherOpenTimer.stop();
        sessionEnded(oldSid);
    }

    function formatResult(value, index) {
        if (state.resultFormat === "json") {
            return JSON.stringify({
                "value": value,
                "index": index,
                "sessionId": state.sessionId
            });
        } else if (state.resultFormat === "index") {
            return index.toString();
        }
        return value;
    }

    // ── Config builder ──
    function buildConfig(overrides) {
        var defaults = pluginApi ? pluginApi.pluginSettings : {};
        var manifest = pluginApi ? (pluginApi.manifest.metadata.defaultSettings || {}) : {};
        var cfg = {};

        cfg.resultFile = overrides.resultFile
            || defaults.resultFile
            || manifest.resultFile
            || "/tmp/noctalia-dmenu-result";
        cfg.resultFormat = overrides.resultFormat || "plain";
        cfg.allowCustomInput = overrides.allowCustomInput;
        cfg.closeOnSelect = overrides.closeOnSelect;
        cfg.maxResults = overrides.maxResults
            || defaults.maxResults
            || manifest.maxResults
            || 200;
        cfg.showToastOnSelect = overrides.showToastOnSelect !== undefined
            ? overrides.showToastOnSelect
            : (defaults.showToastOnSelect || false);

        cfg.items = overrides.items || [];
        cfg.prompt = overrides.prompt || "";
        cfg.callbackCmd = overrides.callbackCmd || "";
        cfg.altActions = overrides.altActions || {};

        return cfg;
    }

    // ── Item parsing ──
    function parseItems(input, separator) {
        if (typeof input === "string") {
            try {
                var parsed = JSON.parse(input);
                if (Array.isArray(parsed)) {
                    return normalizeItems(parsed);
                }
                if (parsed.items && Array.isArray(parsed.items)) {
                    return normalizeItems(parsed.items);
                }
            } catch (e) {
                // Not JSON — treat as separated string
            }
            var sep = separator || "\n";
            // Unescape common separator literals passed as strings from IPC
            // (IPC sends "\n" as two chars: backslash + n)
            sep = sep.replace(/\\n/g, "\n")
                     .replace(/\\t/g, "\t")
                     .replace(/\\r/g, "\r");
            var lines = input.split(sep).filter(function(l) { return l.length > 0; });
            return lines.map(function(line, idx) {
                return { name: line.trim(), value: line.trim(), index: idx };
            });
        }
        if (Array.isArray(input)) {
            return normalizeItems(input);
        }
        return [];
    }

    function normalizeItems(arr) {
        if (!Array.isArray(arr)) {
            Logger.w("DmenuProvider", "normalizeItems received non-array, wrapping");
            arr = [arr];
        }
        return arr.map(function(item, idx) {
            if (typeof item === "string") {
                return { name: item, value: item, index: idx };
            }
            return {
                name: item.name || item.label || item.value || ("Item " + idx),
                description: item.description || "",
                value: item.value || item.name || item.label || "",
                icon: item.icon || "",
                image: item.image || "",
                isTablerIcon: item.isTablerIcon !== undefined ? item.isTablerIcon : true,
                altActions: item.altActions || {},
                index: idx
            };
        });
    }

    // ── Selection handler ──
    function handleSelection(value, index, altKey) {
        if (!state.active) return;

        var sid = state.sessionId;
        var resultStr = formatResult(value, index);
        var resultFile = state.resultFile;
        var callbackCmd = state.callbackCmd;
        var showToast = pluginApi?.pluginSettings?.showToastOnSelect ?? false;
        var shouldClose = state.closeOnSelect;

        // Capture item name BEFORE endSession clears items
        var itemName = "";
        if (index >= 0 && index < state.items.length) {
            itemName = state.items[index].name || "";
        }

        // Handle alt-action
        var actualCallback = callbackCmd;
        if (altKey && altKey !== "") {
            var itemAltActions = {};
            if (index >= 0 && index < state.items.length) {
                itemAltActions = state.items[index].altActions || {};
            }
            var globalAltActions = state.altActions || {};
            var altAction = itemAltActions[altKey] || globalAltActions[altKey];
            if (altAction) {
                if (typeof altAction === "string") {
                    actualCallback = altAction;
                } else if (altAction.callback) {
                    actualCallback = altAction.callback;
                }
                if (altAction.value !== undefined) {
                    resultStr = formatResult(altAction.value, index);
                }
            }
        }

        // Step 1: Write result file (atomic: tmp + mv)
        var escaped = resultStr.replace(/'/g, "'\\''");
        var escapedFile = resultFile.replace(/'/g, "'\\''");
        Quickshell.execDetached([
            "sh", "-c",
            "printf '%s' '" + escaped + "' > '" + escapedFile + ".tmp' && mv '" + escapedFile + ".tmp' '" + escapedFile + "'"
        ]);

        // Step 2: Close launcher and record timestamp
        if (shouldClose && pluginApi) {
            lastCloseTimestamp = Date.now();
            pluginApi.withCurrentScreen(function(screen) {
                pluginApi.closePanel(screen);
            });
        }

        // Step 3: End session
        endSession();

        // Step 4: Toast
        if (showToast) {
            ToastService.showNotice(
                pluginApi?.tr("provider.selected", { value: value })
            );
        }

        // Step 5: Fire callback immediately
        // The callback itself may call show/showSimple, which will use
        // openPanelSmart() to defer the open if needed.
        if (actualCallback && actualCallback !== "") {
            var cmd = actualCallback.replace(/\{\}/g, resultStr);
            cmd = cmd.replace(/\{value\}/g, resultStr);
            cmd = cmd.replace(/\{index\}/g, index.toString());
            cmd = cmd.replace(/\{name\}/g, itemName || resultStr);
            Quickshell.execDetached(["sh", "-c", cmd]);
        }

        Logger.i("DmenuProvider", "Session " + sid + " selection: " + value
            + (altKey ? " (alt: " + altKey + ")" : ""));
    }

    function handleCustomInput(text) {
        if (!state.active || !state.allowCustomInput) return;
        var prefix = pluginApi
            ? (pluginApi.pluginSettings.customInputPrefix || "") : "";
        handleSelection(prefix + text, -1, "");
    }

    // ── IPC Handlers ──
    IpcHandler {
        target: "plugin:dmenu"

        // ── showItems(items, options) ──
        // For plain text item lists.
        //   items:   delimiter-separated string
        //   options: JSON object (or "") with separator, prompt, callbackCmd, etc.
        function showItems(items: string, options: string) {
            if (!pluginApi) return;
            var opts = {};
            if (options && options !== "") {
                try { opts = JSON.parse(options); }
                catch (e) {
                    Logger.e("DmenuProvider", "Invalid options JSON:", e);
                    return;
                }
            }
            var sep = opts.separator || "\n";
            opts.items = root.parseItems(items, sep);
            var merged = root.buildConfig(opts);
            root.beginSession(merged);
            root.openPanelSmart();
            Logger.i("DmenuProvider", "Session " + root.state.sessionId
                + " started with " + merged.items.length + " items");
        }

        // ── showJson(config) ──
        // For structured items with descriptions, icons, images.
        // Single JSON object containing items array + all options.
        //
        // {
        //   "items": ["a", "b"] or [{"name":"a","value":"x","icon":"star"}, ...],
        //   "prompt": "Pick:",
        //   "callbackCmd": "echo {}",
        //   "resultFormat": "plain",
        //   ...any other option
        // }
        //
        // This avoids Quickshell's CLI bug where [...] at the top level
        // gets split by the argument parser. The outer {…} is safe.
        function showJson(config: string) {
            if (!pluginApi) return;
            var cfg;
            try { cfg = JSON.parse(config); }
            catch (e) {
                Logger.e("DmenuProvider", "Invalid JSON config:", e);
                return;
            }
            if (!cfg.items) {
                Logger.e("DmenuProvider", "showJson: missing 'items' key");
                return;
            }
            cfg.items = root.normalizeItems(
                Array.isArray(cfg.items) ? cfg.items : [cfg.items]
            );
            var merged = root.buildConfig(cfg);
            root.beginSession(merged);
            root.openPanelSmart();
            Logger.i("DmenuProvider", "Session " + root.state.sessionId
                + " started with " + merged.items.length + " items");
        }

        // ── showFromFile(filePath, options) ──
        // Read items from a file. Auto-detects format:
        //   - JSON array if file starts with '['
        //   - JSON config object with "items" key if file starts with '{'
        //   - Delimiter-separated text otherwise
        // options is JSON (or "").
        function showFromFile(filePath: string, options: string) {
            if (!pluginApi) return;
            var opts = {};
            if (options && options !== "") {
                try { opts = JSON.parse(options); }
                catch (e) {
                    Logger.e("DmenuProvider", "Invalid options JSON:", e);
                    return;
                }
            }
            fileLoader.separator = opts.separator || "\n";
            fileLoader.prompt = opts.prompt || "";
            fileLoader.callbackCmd = opts.callbackCmd || "";
            fileLoader.options = opts;
            fileLoader.path = "";
            fileLoader.path = filePath;
        }

        function toggle() {
            if (!pluginApi) return;
            pluginApi.withCurrentScreen(function(screen) {
                pluginApi.togglePanel(screen);
            });
        }

        function close() {
            if (!pluginApi) return;
            root.endSession();
            pluginApi.withCurrentScreen(function(screen) {
                pluginApi.closePanel(screen);
            });
        }

        function clear() {
            root.endSession();
        }
    }

    // ── File loader ──
    FileView {
        id: fileLoader
        path: ""
        watchChanges: false

        property string separator: "\n"
        property string prompt: ""
        property string callbackCmd: ""
        property var options: ({})

        onLoaded: {
            var content = text();
            var opts = fileLoader.options || {};
            var parsed;
            var trimmed = content.replace(/^\s+/, "");

            if (trimmed.charAt(0) === "[") {
                // JSON array file
                try {
                    parsed = root.normalizeItems(JSON.parse(content));
                } catch (e) {
                    Logger.e("DmenuProvider", "Invalid JSON file:", e);
                    return;
                }
            } else if (trimmed.charAt(0) === "{") {
                // JSON config object with items key
                try {
                    var config = JSON.parse(content);
                    parsed = root.normalizeItems(config.items || []);
                    // Merge file-level config into opts (file config wins for prompt etc.)
                    for (var key in config) {
                        if (key !== "items" && opts[key] === undefined)
                            opts[key] = config[key];
                    }
                } catch (e) {
                    Logger.e("DmenuProvider", "Invalid JSON config file:", e);
                    return;
                }
            } else {
                // Delimiter-separated text
                parsed = root.parseItems(content, fileLoader.separator);
            }

            opts.items = parsed;
            var merged = root.buildConfig(opts);
            root.beginSession(merged);
            root.openPanelSmart();

            Logger.i("DmenuProvider", "Session " + root.state.sessionId
                + " (file) started with " + parsed.length + " items");
        }
    }

    Component.onCompleted: {
        Logger.i("DmenuProvider", "Main component loaded");
    }
}
