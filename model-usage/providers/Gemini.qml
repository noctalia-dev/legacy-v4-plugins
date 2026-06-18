import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property string providerId: "gemini"
    property string providerName: "Gemini"
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
    property string authHelpText: "Gemini CLI usage from ~/.gemini/tmp"
    property bool hasLocalStats: true

    property var providerSettings: ({})

    function resolvePath(p) {
        if (p && p.startsWith("~"))
            return (Quickshell.env("HOME") ?? "/home") + p.substring(1);
        return p;
    }

    Timer {
        id: refreshTimer
        interval: 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.scanSessions()
    }

    onEnabledChanged: {
        if (enabled)
            scanSessions();
    }

    Process {
        id: sessionAggregator
        command: ["bash", "-c", "find " + root.resolvePath("~/.gemini/tmp") + " -type f -name \"session-$(date +%Y-%m-%d)*.jsonl\" -exec cat {} +"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseSessionContent(text || "");
                root.ready = true;
            }
        }
    }

    Process {
        id: sessionCounter
        command: ["bash", "-c", "find " + root.resolvePath("~/.gemini/tmp") + " -type f -name \"session-$(date +%Y-%m-%d)*.jsonl\" | wc -l"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.todaySessions = parseInt(text.trim()) || 0;
            }
        }
    }

    function scanSessions() {
        sessionAggregator.running = true;
        sessionCounter.running = true;
    }

    function parseSessionContent(content) {
        try {
            const lines = content.split("\n");
            let totalPrompts = 0;
            let totalTokens = 0;
            let tokensByModel = {};

            for (const line of lines) {
                if (!line.trim()) continue;
                try {
                    const entry = JSON.parse(line);
                    if (entry.type === "user") {
                        totalPrompts++;
                    } else if (entry.type === "gemini" && entry.tokens) {
                        const t = entry.tokens.total || 0;
                        totalTokens += t;
                        const m = entry.model || "gemini";
                        tokensByModel[m] = (tokensByModel[m] ?? 0) + t;
                    }
                } catch (e) {}
            }

            root.todayPrompts = totalPrompts;
            root.todayTotalTokens = totalTokens;
            root.todayTokensByModel = tokensByModel;
        } catch (e) {}
    }

    function refresh() {
        scanSessions();
    }
}
