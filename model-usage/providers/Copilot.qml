import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property string providerId: "copilot"
    property string providerName: "Copilot"
    property string providerIcon: "ai"
    property bool enabled: false
    property bool ready: false

    property real rateLimitPercent: -1
    property string rateLimitLabel: "Premium"
    property string rateLimitResetAt: ""
    property real secondaryRateLimitPercent: -1
    property string secondaryRateLimitLabel: "Chat"
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
    property string authHelpText: "Run `gh auth login` to re-authenticate."
    property bool hasLocalStats: false
    property string usageStatusText: ""

    property string ghToken: ""
    property double lastRefreshAtMs: 0
    property int refreshMinIntervalMs: 5 * 60 * 1000
    property var providerSettings: ({})

    Process {
        id: tokenProcess
        command: ["gh", "auth", "token"]
        running: false
        stdout: StdioCollector {
            id: tokenOutput
            onStreamFinished: {
                const token = text.trim();
                if (token) {
                    root.ghToken = token;
                    root.fetchUsage();
                } else {
                    Logger.e("model-usage/copilot", "gh auth token returned empty");
                    root.usageStatusText = "No token";
                    root.ready = false;
                    root.clearRateLimits();
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                Logger.e("model-usage/copilot", "gh auth token failed (exit " + code + ")");
                root.usageStatusText = "Not authenticated";
                root.ready = false;
                root.clearRateLimits();
            }
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.refreshToken()
    }

    onEnabledChanged: {
        if (enabled)
            refreshToken();
    }

    function refreshToken() {
        tokenProcess.running = true;
    }

    function fetchUsage() {
        if (!root.ghToken)
            return;

        const xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.github.com/copilot_internal/user");
        xhr.setRequestHeader("Authorization", "token " + root.ghToken);
        xhr.setRequestHeader("Accept", "application/json");

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status === 401 || xhr.status === 403) {
                root.usageStatusText = "Token invalid";
                root.ready = false;
                root.ghToken = "";
                root.tierLabel = "";
                root.clearRateLimits();
                Logger.e("model-usage/copilot", "Auth failed (status " + xhr.status + ")");
                return;
            }

            if (xhr.status < 200 || xhr.status >= 300) {
                Logger.e("model-usage/copilot", "Usage request failed (status " + xhr.status + ")");
                root.ready = false;
                root.clearRateLimits();
                return;
            }

            try {
                const data = JSON.parse(xhr.responseText);
                root.parseUsageData(data);
                root.usageStatusText = "";
                root.ready = true;
            } catch (e) {
                Logger.e("model-usage/copilot", "Failed to parse usage response:", e);
            }
        };

        xhr.send();
    }

    function parseUsageData(data) {
        root.clearRateLimits();
        root.tierLabel = data.copilot_plan ? formatPlan(data.copilot_plan) : "";

        const resetDate = data.quota_reset_date ?? "";

        // Paid tier: quota_snapshots
        const snapshots = data.quota_snapshots;
        if (snapshots) {
            const premium = snapshots.premium_interactions;
            if (premium && typeof premium.percent_remaining === "number") {
                const usedPct = Math.min(100, Math.max(0, 100 - premium.percent_remaining));
                root.rateLimitPercent = usedPct / 100;
                root.rateLimitLabel = "Premium (" + Math.round(usedPct) + "%)";
                root.rateLimitResetAt = normalizeResetAt(resetDate);
            }

            const chat = snapshots.chat;
            if (chat && typeof chat.percent_remaining === "number") {
                const chatUsed = Math.min(100, Math.max(0, 100 - chat.percent_remaining));
                root.secondaryRateLimitPercent = chatUsed / 100;
                root.secondaryRateLimitLabel = "Chat (" + Math.round(chatUsed) + "%)";
                root.secondaryRateLimitResetAt = normalizeResetAt(resetDate);
            }
        }

        // Free tier: limited_user_quotas
        if (data.limited_user_quotas && data.monthly_quotas) {
            const lq = data.limited_user_quotas;
            const mq = data.monthly_quotas;
            const freeReset = data.limited_user_reset_date ?? "";

            if (typeof lq.chat === "number" && typeof mq.chat === "number" && mq.chat > 0) {
                const used = mq.chat - lq.chat;
                const usedPct = Math.min(100, Math.max(0, Math.round((used / mq.chat) * 100)));
                root.rateLimitPercent = usedPct / 100;
                root.rateLimitLabel = "Chat (" + used + "/" + mq.chat + ")";
                root.rateLimitResetAt = normalizeResetAt(freeReset);
            }

            if (typeof lq.completions === "number" && typeof mq.completions === "number" && mq.completions > 0) {
                const used = mq.completions - lq.completions;
                const usedPct = Math.min(100, Math.max(0, Math.round((used / mq.completions) * 100)));
                root.secondaryRateLimitPercent = usedPct / 100;
                root.secondaryRateLimitLabel = "Completions (" + used + "/" + mq.completions + ")";
                root.secondaryRateLimitResetAt = normalizeResetAt(freeReset);
            }
        }
    }

    function formatPlan(plan) {
        if (!plan)
            return "";
        const p = String(plan);
        return p.charAt(0).toUpperCase() + p.slice(1);
    }

    function clearRateLimits() {
        root.rateLimitPercent = -1;
        root.rateLimitLabel = "Premium";
        root.rateLimitResetAt = "";
        root.secondaryRateLimitPercent = -1;
        root.secondaryRateLimitLabel = "Chat";
        root.secondaryRateLimitResetAt = "";
    }

    function normalizeResetAt(value) {
        if (value === null || value === undefined || value === "")
            return "";
        const d = new Date(String(value));
        if (!isNaN(d.getTime()))
            return d.toISOString();
        return "";
    }

    function refresh() {
        const now = Date.now();
        if (root.lastRefreshAtMs > 0 && (now - root.lastRefreshAtMs) < root.refreshMinIntervalMs)
            return;
        root.lastRefreshAtMs = now;
        refreshToken();
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
