import QtQuick
import Quickshell

Item {
    id: root
    visible: false

    property string providerId: "openrouter"
    property string providerName: "OpenRouter"
    property string providerIcon: "ai"
    property bool enabled: false
    property bool ready: false

    property real rateLimitPercent: -1
    property string rateLimitLabel: "Spending limit"
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
    property string authHelpText: "Check your OpenRouter API key."
    property bool hasLocalStats: true

    property real usageDaily: 0
    property real usageWeekly: 0
    property real usageMonthly: 0
    property real spendingLimit: -1
    property real limitRemaining: -1
    property var providerSettings: ({})

    property string apiKey: {
        const envKey = Quickshell.env("OPENROUTER_API_KEY") ?? "";
        return envKey || (providerSettings?.apiKey ?? "");
    }

    Timer {
        interval: 5 * 60 * 1000
        running: root.enabled && root.apiKey !== ""
        repeat: true
        onTriggered: root.fetchKeyInfo()
    }

    onEnabledChanged: {
        if (enabled && apiKey !== "")
            fetchKeyInfo();
    }

    onApiKeyChanged: {
        if (enabled && apiKey !== "")
            fetchKeyInfo();
    }

    function fetchKeyInfo() {
        if (!root.apiKey)
            return;

        const xhr = new XMLHttpRequest();
        xhr.open("GET", "https://openrouter.ai/api/v1/key");
        xhr.setRequestHeader("Authorization", "Bearer " + root.apiKey);

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200) {
                Logger.e("model-usage/openrouter", "Key info request failed (status " + xhr.status + ")");
                return;
            }

            try {
                const data = JSON.parse(xhr.responseText);
                const info = data.data ?? data;

                root.usageDaily = root.parseFinite(info.usage_daily, 0);
                root.usageWeekly = root.parseFinite(info.usage_weekly, 0);
                root.usageMonthly = root.parseFinite(info.usage_monthly, 0);
                root.spendingLimit = root.parseFinite(info.limit, -1);
                root.limitRemaining = root.parseFinite(info.limit_remaining, -1);
                root.rateLimitResetAt = root.normalizeResetAt(info.limit_reset);

                if (root.spendingLimit > 0) {
                    root.rateLimitPercent = Math.min(1, Math.max(0, root.usageWeekly / root.spendingLimit));
                    root.rateLimitLabel = "Spending ($" + root.usageWeekly.toFixed(2) + " / $" + root.spendingLimit.toFixed(2) + ")";
                } else if (root.limitRemaining >= 0 && (root.usageWeekly + root.limitRemaining) > 0) {
                    const budget = root.usageWeekly + root.limitRemaining;
                    root.rateLimitPercent = Math.min(1, Math.max(0, root.usageWeekly / budget));
                    root.rateLimitLabel = "Budget ($" + root.usageWeekly.toFixed(2) + " / $" + budget.toFixed(2) + ")";
                } else {
                    root.rateLimitPercent = 0;
                    root.rateLimitLabel = "No spending limit";
                }

                root.tierLabel = info.is_free_tier ? "Free" : "Paid";
                root.ready = true;
            } catch (e) {
                Logger.e("model-usage/openrouter", "Failed to parse key info:", e);
            }
        };

        xhr.send();
        fetchActivity();
    }

    function parseFinite(value, fallback) {
        if (value === null || value === undefined)
            return fallback;
        const n = Number(value);
        return isFinite(n) ? n : fallback;
    }

    function normalizeResetAt(value) {
        if (value === null || value === undefined || value === "")
            return "";
        if (typeof value === "number" && isFinite(value)) {
            let ts = value;
            if (ts < 1e12)
                ts *= 1000;
            const d = new Date(ts);
            if (!isNaN(d.getTime()))
                return d.toISOString();
            return "";
        }
        const d = new Date(String(value));
        if (!isNaN(d.getTime()))
            return d.toISOString();
        return "";
    }

    function fetchActivity() {
        if (!root.apiKey)
            return;

        const today = new Date();
        const days = [];
        for (let i = 6; i >= 0; i--) {
            const d = new Date(today);
            d.setDate(d.getDate() - i);
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, "0");
            const dd = String(d.getDate()).padStart(2, "0");
            days.push(y + "-" + m + "-" + dd);
        }

        let completed = 0;
        const results = {};

        for (let i = 0; i < days.length; i++) {
            const date = days[i];
            const xhr = new XMLHttpRequest();
            xhr.open("GET", "https://openrouter.ai/api/v1/activity?date=" + date);
            xhr.setRequestHeader("Authorization", "Bearer " + root.apiKey);

            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE)
                    return;

                if (xhr.status === 200) {
                    try {
                        const data = JSON.parse(xhr.responseText);
                        const entries = data.data ?? [];
                        let dayRequests = 0;
                        let dayTokens = 0;

                        for (const entry of entries) {
                            dayRequests += entry.requests ?? 0;
                            dayTokens += (entry.prompt_tokens ?? 0) + (entry.completion_tokens ?? 0);
                        }

                        results[date] = {
                            requests: dayRequests,
                            tokens: dayTokens,
                            entries: entries
                        };
                    } catch (e) {
                        results[date] = {
                            requests: 0,
                            tokens: 0,
                            entries: []
                        };
                    }
                } else {
                    results[date] = {
                        requests: 0,
                        tokens: 0,
                        entries: []
                    };
                }

                completed++;
                if (completed === days.length)
                    root.processActivityResults(days, results);
            };

            xhr.send();
        }
    }

    function processActivityResults(days, results) {
        const recentDays = [];
        let totalTokens = 0;
        const models = {};

        for (const date of days) {
            const r = results[date] ?? {
                requests: 0,
                tokens: 0,
                entries: []
            };
            recentDays.push({
                date: date,
                messageCount: r.requests
            });
            totalTokens += r.tokens;

            for (const entry of (r.entries ?? [])) {
                const model = entry.model ?? "unknown";
                if (!models[model]) {
                    models[model] = {
                        inputTokens: 0,
                        outputTokens: 0,
                        cacheReadInputTokens: 0,
                        cacheCreationInputTokens: 0
                    };
                }
                models[model].inputTokens += entry.prompt_tokens ?? 0;
                models[model].outputTokens += entry.completion_tokens ?? 0;
            }
        }

        root.recentDays = recentDays;
        root.modelUsage = models;

        const todayStr = days[days.length - 1];
        const todayData = results[todayStr] ?? {
            requests: 0,
            tokens: 0
        };
        root.todayPrompts = todayData.requests;
        root.todayTotalTokens = todayData.tokens;

        const todayByModel = {};
        for (const entry of (todayData.entries ?? [])) {
            const model = entry.model ?? "unknown";
            todayByModel[model] = (todayByModel[model] ?? 0) + (entry.prompt_tokens ?? 0) + (entry.completion_tokens ?? 0);
        }
        root.todayTokensByModel = todayByModel;
    }

    function refresh() {
        if (root.apiKey !== "")
            fetchKeyInfo();
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
