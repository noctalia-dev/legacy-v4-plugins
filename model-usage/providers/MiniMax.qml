import QtQuick
import Quickshell

Item {
    id: root
    visible: false

    property string providerId: "minimax"
    property string providerName: "MiniMax"
    property string providerIcon: "ai"
    property bool enabled: false
    property bool ready: false
    property string usageStatusText: ""

    property real rateLimitPercent: -1
    property string rateLimitLabel: "5h window"
    property string rateLimitResetAt: ""
    property real secondaryRateLimitPercent: -1
    property string secondaryRateLimitLabel: "Weekly"
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
    property string authHelpText: "Set MINIMAX_API_KEY or enter key in settings."
    property bool hasLocalStats: false

    property var providerSettings: ({})

    // ----- API key resolution -----

    property string apiKey: {
        // 1. Settings (explicit override)
        const settingsKey = providerSettings?.apiKey ?? "";
        if (settingsKey && settingsKey.trim() !== "")
            return settingsKey.trim();

        // 2. Direct MiniMax env vars
        const directKey = Quickshell.env("MINIMAX_TOKEN_PLAN_API_KEY")
                        ?? Quickshell.env("MINIMAX_CODING_PLAN_API_KEY")
                        ?? Quickshell.env("MINIMAX_API_KEY")
                        ?? "";
        if (directKey)
            return directKey;

        // 3. ANTHROPIC_AUTH_TOKEN proxied through minimax base URL
        const anthropicToken = Quickshell.env("ANTHROPIC_AUTH_TOKEN") ?? "";
        const anthropicBase = Quickshell.env("ANTHROPIC_BASE_URL") ?? "";
        if (anthropicToken && /minimax/i.test(anthropicBase))
            return anthropicToken;

        // 4. OPENAI_API_KEY proxied through minimax base URL
        const openaiKey = Quickshell.env("OPENAI_API_KEY") ?? "";
        const openaiBase = Quickshell.env("OPENAI_BASE_URL")
                        ?? Quickshell.env("OPENAI_API_BASE")
                        ?? "";
        if (openaiKey && /minimax/i.test(openaiBase))
            return openaiKey;

        return "";
    }

    // ----- Endpoint resolution -----

    property string apiBaseUrl: {
        // Custom override from settings takes priority
        const override = providerSettings?.apiBaseUrl ?? "";
        if (override && override.trim() !== "")
            return override.trim();

        // Region-based default
        const region = providerSettings?.region ?? "international";
        if (region === "china")
            return "https://api.minimaxi.com/v1";
        // "international" or any other value
        return "https://api.minimax.io/v1";
    }

    // ----- Refresh timer -----

    Timer {
        interval: 5 * 60 * 1000
        running: root.enabled && root.apiKey !== ""
        repeat: true
        onTriggered: root.fetchQuota()
    }

    onEnabledChanged: {
        if (enabled && apiKey !== "")
            fetchQuota();
    }

    onApiKeyChanged: {
        if (enabled && apiKey !== "")
            fetchQuota();
    }

    // ----- Fetch -----

    function fetchQuota() {
        if (!root.apiKey)
            return;

        root.usageStatusText = "";
        const url = root.apiBaseUrl + "/api/openplatform/coding_plan/remains";
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Authorization", "Bearer " + root.apiKey);
        xhr.setRequestHeader("Content-Type", "application/json");

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status !== 200) {
                root.usageStatusText = "HTTP " + xhr.status;
                root.rateLimitPercent = -1;
                root.secondaryRateLimitPercent = -1;
                return;
            }

            try {
                const data = JSON.parse(xhr.responseText);

                // Check application-level status code
                const appStatus = data?.base_resp?.status_code
                               ?? data?.base_resp?.statuscode
                               ?? data?.status_code
                               ?? 0;
                if (appStatus !== 0 && appStatus !== "0" && appStatus !== "success" && appStatus !== 200) {
                    const msg = data?.base_resp?.status_msg
                             ?? data?.base_resp?.message
                             ?? data?.message
                             ?? ("status " + appStatus);
                    root.usageStatusText = msg;
                    root.rateLimitPercent = -1;
                    root.secondaryRateLimitPercent = -1;
                    return;
                }

                root.parseModelRemains(data);
                root.ready = true;
            } catch (e) {
                root.usageStatusText = "Parse error";
                root.rateLimitPercent = -1;
                root.secondaryRateLimitPercent = -1;
                Logger.e("model-usage/minimax", "Failed to parse quota response:", e);
            }
        };

        xhr.send();
    }

    function parseModelRemains(data) {
        const records = data?.model_remains ?? [];
        if (records.length === 0)
            return;

        // Prefer MiniMax-M* coding models; fall back to the row with the
        // tightest remaining quota (lowest remaining/total ratio).
        let codingRow = null;
        for (const rec of records) {
            const id = rec?.model_name ?? rec?.model ?? "";
            if (/^MiniMax-M/i.test(id)) {
                codingRow = rec;
                break;
            }
            if (!codingRow) {
                codingRow = rec;
            } else {
                // Compare remaining ratio; prefer tighter
                const prevTotal = codingRow?.total_intervals ?? 0;
                const prevRemaining = codingRow?.current_interval_usage_count ?? 0;
                const prevRatio = prevTotal > 0 ? prevRemaining / prevTotal : 0;

                const currTotal = rec?.total_intervals ?? 0;
                const currRemaining = rec?.current_interval_usage_count ?? 0;
                const currRatio = currTotal > 0 ? currRemaining / currTotal : 0;

                if (currRatio < prevRatio)
                    codingRow = rec;
            }
        }

        if (!codingRow)
            return;

        const total5h   = codingRow?.total_intervals          ?? 0;
        const remain5h  = codingRow?.current_interval_usage_count ?? 0;
        const totalWk   = codingRow?.total_weekly_intervals   ?? 0;
        const remainWk = codingRow?.current_weekly_usage_count ?? 0;

        // 5-hour rolling window -> primary
        if (total5h > 0) {
            root.rateLimitPercent = Math.min(1, Math.max(0, (total5h - remain5h) / total5h));
            root.rateLimitLabel = "5h window";
            // No discrete reset time in this endpoint -- leave resetAt empty
            root.rateLimitResetAt = "";
        } else {
            root.rateLimitPercent = -1;
        }

        // Weekly window -> secondary (only if weekly fields are present)
        if (totalWk > 0) {
            root.secondaryRateLimitPercent = Math.min(1, Math.max(0, (totalWk - remainWk) / totalWk));
            root.secondaryRateLimitLabel = "Weekly";
            root.secondaryRateLimitResetAt = "";
        } else {
            // No weekly data in this snapshot -- clear stale value
            root.secondaryRateLimitPercent = -1;
            root.secondaryRateLimitLabel = "";
            root.secondaryRateLimitResetAt = "";
        }
    }

    function refresh() {
        if (root.apiKey !== "")
            fetchQuota();
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
        const mins  = Math.floor((diffMs % 3600000) / 60000);
        if (hours > 24)
            return Math.floor(hours / 24) + "d " + (hours % 24) + "h";
        if (hours > 0)
            return hours + "h " + mins + "m";
        return mins + "m";
    }
}