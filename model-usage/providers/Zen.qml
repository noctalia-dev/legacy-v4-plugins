import QtQuick
import Quickshell

Item {
    id: root
    visible: false

    property string providerId: "zen"
    property string providerName: "Zen"
    property string providerIcon: "ai"
    property bool enabled: false
    property bool ready: false

    property real rateLimitPercent: -1
    property string rateLimitLabel: ""
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
    property string authHelpText: "Check your Zen API key."
    property bool hasLocalStats: true

    property var providerSettings: ({})
    property string apiBaseUrl: providerSettings?.apiBaseUrl ?? "https://opencode.ai/zen/v1"
    property string apiKey: {
        const envZen = Quickshell.env("OPENCODE_ZEN_API_KEY") ?? "";
        if (envZen !== "")
            return envZen;
        const envOpenCode = Quickshell.env("OPENCODE_API_KEY") ?? "";
        if (envOpenCode !== "")
            return envOpenCode;
        const envLegacy = Quickshell.env("ZEN_API_KEY") ?? "";
        if (envLegacy !== "")
            return envLegacy;
        return providerSettings?.apiKey ?? "";
    }

    property string validatedApiKey: ""
    property string authState: "unknown"
    property bool modelsLoaded: false
    property int availableModels: 0
    property string defaultModel: ""

    Timer {
        interval: 10 * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.fetchModels()
    }

    onEnabledChanged: {
        if (enabled)
            refresh();
    }

    onApiKeyChanged: {
        root.validatedApiKey = "";
        root.authState = apiKey === "" ? "unknown" : "checking";
        root.updateState();
        if (enabled)
            refresh();
    }

    function updateState() {
        const hasKey = root.apiKey !== "";

        if (!hasKey) {
            root.tierLabel = "API key required";
            root.ready = false;
        } else if (root.authState === "invalid") {
            root.tierLabel = "Invalid API key";
            root.ready = false;
        } else if (root.authState === "valid") {
            root.tierLabel = "API key valid";
            root.ready = root.modelsLoaded;
        } else {
            root.tierLabel = "Checking API key...";
            root.ready = root.modelsLoaded;
        }

        root.rateLimitPercent = 0;
        root.rateLimitLabel = "Usage API unavailable";
        root.rateLimitResetAt = "";
        root.secondaryRateLimitPercent = -1;
        root.secondaryRateLimitLabel = "";
        root.secondaryRateLimitResetAt = "";
    }

    function extractErrorMessage(text) {
        if (!text)
            return "";
        try {
            const parsed = JSON.parse(text);
            return parsed?.error?.message ?? parsed?.message ?? "";
        } catch (e) {
            return "";
        }
    }

    function validateApiKey() {
        if (!root.apiKey)
            return;

        const xhr = new XMLHttpRequest();
        xhr.open("POST", root.apiBaseUrl + "/responses");
        xhr.setRequestHeader("Authorization", "Bearer " + root.apiKey);
        xhr.setRequestHeader("Content-Type", "application/json");

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            root.validatedApiKey = root.apiKey;

            if (xhr.status === 401 || xhr.status === 403) {
                const msg = root.extractErrorMessage(xhr.responseText);
                const msgLower = String(msg).toLowerCase();
                if (msgLower.indexOf("invalid api key") !== -1) {
                    Logger.e("model-usage/zen", "API key rejected (status " + xhr.status + "): " + msg);
                    root.authState = "invalid";
                } else {
                    Logger.e("model-usage/zen", "API key probe unauthorized (status " + xhr.status + ")" + (msg ? ": " + msg : ""));
                    root.authState = "unknown";
                }
            } else if (xhr.status >= 200 && xhr.status < 500) {
                root.authState = "valid";
            } else {
                Logger.e("model-usage/zen", "API key probe failed (status " + xhr.status + ")");
                root.authState = "unknown";
            }

            root.updateState();
        };

        xhr.send(JSON.stringify({
            model: "glm-5-free",
            input: "hi",
            max_output_tokens: 1
        }));
    }

    function fetchModels() {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", root.apiBaseUrl + "/models");
        if (root.apiKey)
            xhr.setRequestHeader("Authorization", "Bearer " + root.apiKey);

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status !== 200) {
                root.modelsLoaded = false;
                root.availableModels = 0;
                root.defaultModel = "";
                Logger.e("model-usage/zen", "Models request failed (status " + xhr.status + ")");
                root.updateState();
                return;
            }

            try {
                const data = JSON.parse(xhr.responseText);
                const models = data?.data ?? [];
                root.availableModels = models.length;
                root.defaultModel = models.length > 0 ? (models[0]?.id ?? "") : "";
                root.modelsLoaded = models.length > 0;
                root.ready = root.modelsLoaded;
                root.updateState();
            } catch (e) {
                root.modelsLoaded = false;
                root.availableModels = 0;
                root.defaultModel = "";
                Logger.e("model-usage/zen", "Failed to parse models response:", e);
                root.updateState();
            }
        };

        xhr.send();
    }

    function refresh() {
        fetchModels();
        if (root.apiKey && (root.validatedApiKey !== root.apiKey || root.authState === "unknown" || root.authState === "checking"))
            validateApiKey();
        else
            updateState();
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
