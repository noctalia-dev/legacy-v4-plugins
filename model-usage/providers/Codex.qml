import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property string providerId: "codex"
    property string providerName: "Codex"
    property string providerIcon: "ai"
    property bool enabled: false
    property bool ready: false

    property real rateLimitPercent: -1
    property string rateLimitLabel: "Weekly (7-day)"
    property string rateLimitResetAt: ""
    property real secondaryRateLimitPercent: -1
    property string secondaryRateLimitLabel: ""
    property string secondaryRateLimitResetAt: ""

    property int todayPrompts: 0
    property int todaySessions: 0
    property int todayTotalTokens: 0
    property var todayTokensByModel: ({})

    property var recentDays: []
    property int totalPrompts: 0
    property int totalSessions: 0
    property var modelUsage: ({})

    property string tierLabel: ""
    property string authHelpText: "Run `codex` to authenticate."
    property bool hasLocalStats: true

    property string configModel: ""
    property var providerSettings: ({})

    function resolvePath(p) {
        if (p && p.startsWith("~"))
            return (Quickshell.env("HOME") ?? "/home") + p.substring(1);
        return p;
    }

    function localDateString() {
        const now = new Date();
        const y = now.getFullYear();
        const m = String(now.getMonth() + 1).padStart(2, "0");
        const d = String(now.getDate()).padStart(2, "0");
        return y + "-" + m + "-" + d;
    }

    FileView {
        id: historyFile
        path: root.resolvePath("~/.codex/history.jsonl")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseHistory(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                Logger.e("model-usage/codex", "history.jsonl not found");
        }
    }

    FileView {
        id: configFile
        path: root.resolvePath("~/.codex/config.toml")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseConfig(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                Logger.e("model-usage/codex", "config.toml not found");
        }
    }

    Process {
        id: sessionLister
        command: ["find", root.resolvePath("~/.codex/sessions"), "-type", "f", "-name", "*.jsonl"]
        running: false
        stdout: StdioCollector {
            id: sessionListerOutput
            onStreamFinished: {
                const output = text;
                if (output)
                    root.parseSessionList(output);
            }
        }
    }

    property var sessionPaths: []
    property int sessionPathIndex: -1
    property bool sessionSearchInProgress: false
    property string latestSessionPath: ""
    FileView {
        id: latestSessionFile
        path: root.latestSessionPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseSessionData(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                Logger.e("model-usage/codex", "Session file not found:", root.latestSessionPath);
                root.loadPreviousSessionFile();
            }
        }
    }

    FileView {
        id: authFile
        path: root.resolvePath("~/.codex/auth.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseAuth(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                Logger.e("model-usage/codex", "auth.json not found");
        }
    }

    Timer {
        interval: 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.scanSessions()
    }

    onEnabledChanged: {
        if (enabled)
            scanSessions();
    }

    function parseHistory(content) {
        try {
            const now = new Date();
            const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() / 1000;
            const lines = content.split("\n");
            let prompts = 0;
            const sessions = {};

            for (let i = lines.length - 1; i >= 0; i--) {
                const line = lines[i].trim();
                if (!line)
                    continue;
                try {
                    const entry = JSON.parse(line);
                    if ((entry.ts ?? 0) < startOfDay)
                        break;
                    prompts++;
                    if (entry.session_id)
                        sessions[entry.session_id] = true;
                } catch (e) {
                    continue;
                }
            }

            root.todayPrompts = prompts;
            root.todaySessions = Object.keys(sessions).length;
            root.ready = true;
        } catch (e) {
            Logger.e("model-usage/codex", "Failed to parse history.jsonl:", e);
        }
    }

    function parseConfig(content) {
        try {
            const match = content.match(/model\s*=\s*"([^"]+)"/);
            if (match)
                root.configModel = match[1];
        } catch (e) {
            Logger.e("model-usage/codex", "Failed to parse config.toml:", e);
        }
    }

    function parseAuth(content) {
        try {
            const data = JSON.parse(content);
            if (data.auth_mode)
                root.tierLabel = data.auth_mode;
        } catch (e) {
            Logger.e("model-usage/codex", "Failed to parse auth.json:", e);
        }
    }

    function scanSessions() {
        sessionLister.running = true;
    }

    function parseSessionList(output) {
        if (!output)
            return;
        const lines = output.trim().split("\n");
        const unique = {};
        for (let i = 0; i < lines.length; i++) {
            const file = lines[i].trim();
            if (!file.endsWith(".jsonl"))
                continue;
            unique[file] = true;
        }

        const files = Object.keys(unique).sort();
        if (files.length === 0) {
            root.sessionPaths = [];
            root.sessionPathIndex = -1;
            root.sessionSearchInProgress = false;
            return;
        }

        root.sessionPaths = files.slice(Math.max(0, files.length - 16));
        root.sessionPathIndex = root.sessionPaths.length - 1;
        root.sessionSearchInProgress = true;
        const newestPath = root.sessionPaths[root.sessionPathIndex];
        if (root.latestSessionPath === newestPath)
            latestSessionFile.reload();
        else
            root.latestSessionPath = newestPath;
    }

    function loadPreviousSessionFile() {
        if (!root.sessionSearchInProgress)
            return;
        root.sessionPathIndex = root.sessionPathIndex - 1;
        if (root.sessionPathIndex >= 0) {
            root.latestSessionPath = root.sessionPaths[root.sessionPathIndex];
        } else {
            root.sessionSearchInProgress = false;
        }
    }

    function parseSessionData(content) {
        try {
            const lines = content.split("\n");
            let lastTokenCount = null;

            for (let i = lines.length - 1; i >= 0; i--) {
                const line = lines[i].trim();
                if (!line)
                    continue;
                try {
                    const entry = JSON.parse(line);
                    let candidate = null;
                    if (entry.type === "event_msg" && entry.payload?.type === "token_count")
                        candidate = entry.payload;
                    else if (entry.type === "token_count")
                        candidate = entry;
                    else if (entry.type === "response_item" && entry.payload?.type === "event_msg" && entry.payload?.payload?.type === "token_count")
                        candidate = entry.payload.payload;

                    if (candidate) {
                        lastTokenCount = candidate;
                        break;
                    }
                } catch (e) {
                    continue;
                }
            }

            if (!lastTokenCount) {
                root.loadPreviousSessionFile();
                return;
            }

            const rl = lastTokenCount.rate_limits?.primary;
            if (rl) {
                root.rateLimitPercent = (rl.used_percent ?? 0) / 100;
                if (rl.window_minutes === 10080)
                    root.rateLimitLabel = "Weekly (7-day)";
                else
                    root.rateLimitLabel = Math.round(rl.window_minutes / 60) + "h window";
                if (rl.resets_at) {
                    const resetDate = new Date(rl.resets_at * 1000);
                    root.rateLimitResetAt = resetDate.toISOString();
                }
            }

            const usage = lastTokenCount.info?.total_token_usage;
            if (usage) {
                const input = usage.input_tokens ?? 0;
                const output = usage.output_tokens ?? 0;
                const cached = usage.cached_input_tokens ?? 0;
                const reasoning = usage.reasoning_output_tokens ?? 0;
                root.todayTotalTokens = input + output + cached + reasoning;

                const modelName = root.configModel || "codex";
                root.todayTokensByModel = {};
                root.todayTokensByModel[modelName] = root.todayTotalTokens;

                root.modelUsage = {};
                root.modelUsage[modelName] = {
                    inputTokens: input,
                    outputTokens: output + reasoning,
                    cacheReadInputTokens: cached,
                    cacheCreationInputTokens: 0
                };
            }

            root.sessionSearchInProgress = false;
        } catch (e) {
            Logger.e("model-usage/codex", "Failed to parse session data:", e);
            root.loadPreviousSessionFile();
        }
    }

    function refresh() {
        historyFile.reload();
        configFile.reload();
        authFile.reload();
        root.scanSessions();
    }

    function formatResetTime(isoTimestamp) {
        if (!isoTimestamp)
            return "";
        const reset = new Date(isoTimestamp);
        const now = new Date();
        const diffMs = reset.getTime() - now.getTime();
        if (diffMs <= 0)
            return "now";
        const hours = Math.floor(diffMs / 3600000);
        const mins = Math.floor((diffMs % 3600000) / 60000);
        if (hours > 24)
            return Math.floor(hours / 24) + "d " + (hours % 24) + "h";
        if (hours > 0)
            return hours + "h " + mins + "m";
        return mins + "m";
    }
}
