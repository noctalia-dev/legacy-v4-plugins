import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null

    // --- Shared state (accessible via pluginApi.mainInstance) ---
    property var messages: []
    property int unreadCount: 0
    property bool isLoading: false
    property string errorMessage: ""
    property int lastPollTimestamp: 0

    // --- Settings ---
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string serverUrl: cfg.serverUrl ?? defaults.serverUrl ?? "https://ntfy.sh"
    property string topics: cfg.topics ?? defaults.topics ?? ""
    property string authMethod: cfg.authMethod ?? defaults.authMethod ?? "none"
    property string authToken: cfg.authToken ?? defaults.authToken ?? ""
    property string authUsername: cfg.authUsername ?? defaults.authUsername ?? ""
    property string authPassword: cfg.authPassword ?? defaults.authPassword ?? ""
    property int pollInterval: cfg.pollInterval ?? defaults.pollInterval ?? 30
    property bool enableToasts: cfg.enableToasts ?? defaults.enableToasts ?? true
    property int maxMessages: cfg.maxMessages ?? defaults.maxMessages ?? 100
    property var readMessageIds: cfg.readMessageIds ?? defaults.readMessageIds ?? []

    // --- Signals ---
    signal refreshRequested()
    signal messagesUpdated()

    // --- IPC Handler ---
    IpcHandler {
        target: "plugin:ntfy-notifications"

        function refresh() {
            root.pollMessages();
        }

        function toggle() {
            if (pluginApi) {
                pluginApi.withCurrentScreen(screen => {
                    pluginApi.togglePanel(screen);
                });
            }
        }
    }

    // --- Poll Timer ---
    Timer {
        id: pollTimer
        interval: root.pollInterval * 1000
        running: root.topics.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pollMessages()
    }

    // --- React to settings changes ---
    onTopicsChanged: {
        if (topics.length > 0) {
            root.messages = [];
            root.lastPollTimestamp = 0;
            Qt.callLater(pollMessages);
        }
    }

    onServerUrlChanged: {
        if (topics.length > 0) {
            root.messages = [];
            root.lastPollTimestamp = 0;
            Qt.callLater(pollMessages);
        }
    }

    // --- Connections from BarWidget/Panel requesting refresh ---
    Component.onCompleted: {
        refreshRequested.connect(pollMessages);
    }

    // --- Core: Poll for messages ---
    function pollMessages() {
        if (!topics || topics.trim().length === 0) {
            root.errorMessage = "";
            root.isLoading = false;
            return;
        }

        root.isLoading = true;
        root.errorMessage = "";

        var cleanTopics = topics.split(",").map(function(t) { return t.trim(); }).filter(function(t) { return t.length > 0; }).join(",");
        if (cleanTopics.length === 0) {
            root.isLoading = false;
            return;
        }

        var baseUrl = serverUrl.replace(/\/+$/, "");
        var url = baseUrl + "/" + encodeURIComponent(cleanTopics) + "/json?poll=1";

        if (root.lastPollTimestamp > 0) {
            url += "&since=" + (root.lastPollTimestamp + 1);
        } else {
            // On first poll, get messages from last 24h
            var since = Math.floor(Date.now() / 1000) - 86400;
            url += "&since=" + since;
        }

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;

            if (xhr.status === 200) {
                try {
                    parseMessages(xhr.responseText);
                } catch (e) {
                    root.errorMessage = pluginApi?.tr("error.parse");
                    Logger.e("ntfy", "Parse error:", e.toString());
                }
            } else if (xhr.status === 401 || xhr.status === 403) {
                root.errorMessage = pluginApi?.tr("error.auth");
                Logger.w("ntfy", "Auth error:", xhr.status);
            } else if (xhr.status === 0) {
                root.errorMessage = pluginApi?.tr("error.network");
                Logger.w("ntfy", "Network error");
            } else {
                root.errorMessage = pluginApi?.tr("error.server");
                Logger.w("ntfy", "HTTP error:", xhr.status);
            }

            root.isLoading = false;
        };

        xhr.open("GET", url);

        // Authentication
        if (authMethod === "token" && authToken.length > 0) {
            xhr.setRequestHeader("Authorization", "Bearer " + authToken);
        } else if (authMethod === "basic" && authUsername.length > 0) {
            xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(authUsername + ":" + authPassword));
        }

        xhr.send();
    }

    // --- Parse NDJSON response from ntfy ---
    function parseMessages(responseText) {
        var lines = responseText.split("\n");
        var newMessages = [];
        var latestTimestamp = root.lastPollTimestamp;

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.length === 0) continue;

            try {
                var msg = JSON.parse(line);

                // Only process actual messages, skip open/keepalive events
                if (msg.event !== "message") continue;

                // Track latest timestamp
                if (msg.time && msg.time > latestTimestamp) {
                    latestTimestamp = msg.time;
                }

                newMessages.push({
                    id: msg.id || "",
                    time: msg.time || 0,
                    topic: msg.topic || "",
                    title: msg.title || "",
                    message: msg.message || "",
                    priority: msg.priority || 3,
                    tags: msg.tags || [],
                    click: msg.click || ""
                });
            } catch (e) {
                // Skip malformed lines
                Logger.d("ntfy", "Skipping malformed line:", line);
            }
        }

        if (latestTimestamp > root.lastPollTimestamp) {
            root.lastPollTimestamp = latestTimestamp;
        }

        if (newMessages.length > 0) {
            // Deduplicate by message ID
            var existingIds = {};
            for (var e = 0; e < root.messages.length; e++) {
                existingIds[root.messages[e].id] = true;
            }
            var trulyNew = newMessages.filter(function(m) { return !existingIds[m.id]; });

            if (trulyNew.length === 0) {
                root.isLoading = false;
                return;
            }

            // Show toast(s) for new messages
            if (root.enableToasts) {
                showToasts(trulyNew);
            }

            // Merge with existing messages and cap at maxMessages
            var allMessages = trulyNew.concat(root.messages);

            // Sort by time descending (newest first)
            allMessages.sort(function(a, b) { return b.time - a.time; });

            // Trim to max
            if (allMessages.length > root.maxMessages) {
                allMessages = allMessages.slice(0, root.maxMessages);
            }

            root.messages = allMessages;
            updateUnreadCount();
            messagesUpdated();
        }

        root.isLoading = false;
    }

    // --- Toast notifications ---
    function showToasts(newMessages) {
        if (newMessages.length === 1) {
            var msg = newMessages[0];
            var title = msg.title || msg.topic || pluginApi?.tr("toast.newMessage");
            ToastService.showNotice(title, msg.message, "bell");
        } else if (newMessages.length > 1) {
            var countText = pluginApi?.tr("toast.newMessages", { count: newMessages.length });
            ToastService.showNotice(countText, "", "bell");
        }
    }

    // --- Read status ---
    function updateUnreadCount() {
        var count = 0;
        var readSet = {};
        for (var r = 0; r < readMessageIds.length; r++) {
            readSet[readMessageIds[r]] = true;
        }
        for (var i = 0; i < messages.length; i++) {
            if (!readSet[messages[i].id]) {
                count++;
            }
        }
        root.unreadCount = count;
    }

    function isMessageRead(messageId) {
        return readMessageIds.indexOf(messageId) !== -1;
    }

    function markAsRead(messageId) {
        if (readMessageIds.indexOf(messageId) === -1) {
            var newIds = readMessageIds.slice();
            newIds.push(messageId);
            root.readMessageIds = newIds;
            persistReadIds();
            updateUnreadCount();
            messagesUpdated();
        }
    }

    function markAllAsRead() {
        var newIds = readMessageIds.slice();
        for (var i = 0; i < messages.length; i++) {
            if (newIds.indexOf(messages[i].id) === -1) {
                newIds.push(messages[i].id);
            }
        }
        root.readMessageIds = newIds;
        persistReadIds();
        updateUnreadCount();
        messagesUpdated();
    }

    function persistReadIds() {
        if (!pluginApi) return;
        // Keep readMessageIds trimmed to only IDs that still exist in messages
        var msgIdSet = {};
        for (var i = 0; i < messages.length; i++) {
            msgIdSet[messages[i].id] = true;
        }
        var trimmed = readMessageIds.filter(function(id) { return msgIdSet[id]; });
        root.readMessageIds = trimmed;
        pluginApi.pluginSettings.readMessageIds = trimmed;
        pluginApi.saveSettings();
    }
}
