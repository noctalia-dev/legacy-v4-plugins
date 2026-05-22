import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property var pluginApi: null
    readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})
    readonly property var pluginSettings: pluginApi?.pluginSettings ?? defaultSettings

    readonly property string helperPath: (pluginApi?.pluginDir ?? "") + "/scripts/model_usage.py"
    readonly property string providerMode: pluginSettings?.providerMode ?? defaultSettings?.providerMode ?? "auto"
    readonly property string sourceMode: pluginSettings?.sourceMode ?? defaultSettings?.sourceMode ?? "auto"
    readonly property string claudeSourceMode: pluginSettings?.claudeSourceMode ?? defaultSettings?.claudeSourceMode ?? "auto"
    readonly property string barMetric: pluginSettings?.barMetric ?? defaultSettings?.barMetric ?? "remaining"
    readonly property int refreshIntervalSec: Math.max(60, pluginSettings?.refreshIntervalSec ?? defaultSettings?.refreshIntervalSec ?? 300)
    readonly property string pythonPath: pluginSettings?.pythonPath ?? defaultSettings?.pythonPath ?? "python3"
    readonly property string codexBinary: pluginSettings?.codexBinary ?? defaultSettings?.codexBinary ?? "codex"
    readonly property string claudeBinary: pluginSettings?.claudeBinary ?? defaultSettings?.claudeBinary ?? "claude"
    readonly property string codexHome: pluginSettings?.codexHome ?? defaultSettings?.codexHome ?? ""
    readonly property string claudeHome: pluginSettings?.claudeHome ?? defaultSettings?.claudeHome ?? ""
    readonly property int requestTimeoutSec: Math.max(3, pluginSettings?.requestTimeoutSec ?? defaultSettings?.requestTimeoutSec ?? 8)

    property bool busy: false
    property bool ready: false
    property string statusText: "Waiting for data"
    property string errorText: ""
    property string lastUpdatedAt: ""
    property string providerLabel: ""
    property string shortLabel: ""
    property real creditsRemaining: -1
    property bool creditsUnlimited: false

    property var primaryWindow: null
    property var secondaryWindow: null
    property var tertiaryWindow: null
    property var extraRateWindows: []
    property var providers: []
    property var activeProvider: ({})
    property var lastPayload: ({})
    property var attemptErrors: []

    property string pendingStdout: ""
    property string pendingStderr: ""

    Timer {
        interval: root.refreshIntervalSec * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: usageProcess
        command: root.buildCommand()
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.pendingStdout = text;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.pendingStderr = text;
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (root.pendingStdout.trim() !== "") {
                root.applyPayload(root.pendingStdout);
                return;
            }

            const err = root.pendingStderr.trim() || root.pendingStdout.trim() || ("helper exited with code " + exitCode);
            root.ready = false;
            root.errorText = err;
            root.statusText = err;
            Logger.e("modelbar", err);
        }
    }

    Component.onCompleted: refresh()

    function resolvePath(path) {
        if (path && path.startsWith("~"))
            return (Quickshell.env("HOME") ?? "") + path.substring(1);
        return path;
    }

    function buildCommand() {
        const args = [
            root.pythonPath,
            root.helperPath,
            "--provider-mode",
            root.providerMode,
            "--source",
            root.sourceMode,
            "--claude-source",
            root.claudeSourceMode,
            "--timeout",
            String(root.requestTimeoutSec)
        ];

        if (root.codexBinary !== "")
            args.push("--codex-bin", root.codexBinary);

        if (root.claudeBinary !== "")
            args.push("--claude-bin", root.claudeBinary);

        if (root.codexHome !== "")
            args.push("--codex-home", root.resolvePath(root.codexHome));

        if (root.claudeHome !== "")
            args.push("--claude-home", root.resolvePath(root.claudeHome));

        return args;
    }

    function refresh() {
        if (usageProcess.running)
            return;

        root.pendingStdout = "";
        root.pendingStderr = "";
        root.busy = true;
        root.statusText = root.ready ? root.statusText : "Loading";
        usageProcess.command = root.buildCommand();
        usageProcess.running = true;
    }

    function applyPayload(rawText) {
        try {
            const payload = JSON.parse(rawText);
            root.lastPayload = payload;
            root.attemptErrors = payload?.errors ?? [];
            root.providers = payload?.providers ?? [];
            root.activeProvider = payload?.activeProvider ?? payload;

            if (!payload.ok) {
                root.ready = false;
                root.errorText = payload.error ?? "Model usage fetch failed";
                root.statusText = root.errorText;
                return;
            }

            const active = root.activeProvider ?? payload;
            const usage = active.usage ?? {};
            const credits = active.credits ?? {};

            root.primaryWindow = usage.primary ?? null;
            root.secondaryWindow = usage.secondary ?? null;
            root.tertiaryWindow = usage.tertiary ?? null;
            root.extraRateWindows = usage.extraRateWindows ?? [];
            root.lastUpdatedAt = active.updatedAt ?? payload.updatedAt ?? "";
            root.providerLabel = active.providerLabel ?? "";
            root.shortLabel = active.shortLabel ?? "";
            root.creditsUnlimited = credits.unlimited ?? false;
            root.creditsRemaining = Number(credits.remaining ?? -1);
            root.errorText = "";
            root.ready = true;
            root.statusText = "Updated " + root.formatUpdated(root.lastUpdatedAt);
        } catch (e) {
            root.ready = false;
            root.errorText = "Failed to parse helper output";
            root.statusText = root.errorText;
            Logger.e("modelbar", "parse failed:", e, rawText);
        }
    }

    function activeWindow() {
        return root.primaryWindow ?? root.secondaryWindow ?? root.tertiaryWindow;
    }

    function displayText() {
        if (root.busy && !root.ready)
            return "...";
        if (!root.ready)
            return "!";

        const window = root.activeWindow();
        let text = "";
        if (root.barMetric === "used") {
            if (!window)
                return "--";
            text = Math.round(Number(window.usedPercent ?? 0)) + "%";
            return root.decorateDisplayText(text);
        }

        if (root.barMetric === "credits") {
            if (root.creditsUnlimited)
                return root.decorateDisplayText("unl");
            if (root.creditsRemaining >= 0)
                return root.decorateDisplayText(root.formatCompact(root.creditsRemaining));
            return "--";
        }

        if (!window)
            return "--";
        text = Math.round(Number(window.remainingPercent ?? (100 - Number(window.usedPercent ?? 0)))) + "%";
        return root.decorateDisplayText(text);
    }

    function decorateDisplayText(text) {
        if (root.providerMode !== "auto" || root.providers.length <= 1 || root.shortLabel === "")
            return text;
        return root.shortLabel + " " + text;
    }

    function tooltipText() {
        if (!root.ready)
            return "ModelBar: " + (root.errorText || "waiting for data");

        if (root.providers.length > 0) {
            const lines = [];
            for (let i = 0; i < root.providers.length; i++) {
                const provider = root.providers[i];
                if (!provider.ok) {
                    lines.push((provider.providerLabel ?? "Provider") + ": " + (provider.error ?? "unavailable"));
                    continue;
                }
                const usage = provider.usage ?? {};
                const primary = root.describeWindow(usage.primary ?? null, "Session");
                const secondary = root.describeWindow(usage.secondary ?? null, "Weekly");
                const tertiary = root.describeWindow(usage.tertiary ?? null, "Model weekly");
                let line = provider.providerLabel ?? "Provider";
                if (primary !== "")
                    line += " - " + primary;
                if (secondary !== "")
                    line += " - " + secondary;
                if (tertiary !== "")
                    line += " - " + tertiary;
                lines.push(line);
            }
            return lines.join("\n");
        }

        const primary = root.describeWindow(root.primaryWindow, "Session");
        const secondary = root.describeWindow(root.secondaryWindow, "Weekly");
        let tip = root.providerLabel || "ModelBar";
        if (primary !== "")
            tip += " - " + primary;
        if (secondary !== "")
            tip += " - " + secondary;
        return tip;
    }

    function describeWindow(window, fallbackLabel) {
        if (!window)
            return "";
        const label = window.label ?? fallbackLabel;
        const used = Math.round(Number(window.usedPercent ?? 0));
        const reset = root.formatReset(window.resetsAt ?? "");
        return label + ": " + used + "% used" + (reset !== "" ? ", resets " + reset : "");
    }

    function windowUsed(window) {
        return Math.max(0, Math.min(100, Number(window?.usedPercent ?? 0)));
    }

    function windowRemaining(window) {
        return Math.max(0, Math.min(100, Number(window?.remainingPercent ?? (100 - root.windowUsed(window)))));
    }

    function formatReset(isoTimestamp) {
        if (!isoTimestamp)
            return "";
        const reset = new Date(isoTimestamp);
        if (isNaN(reset.getTime()))
            return "";
        const now = new Date();
        const diffMs = reset.getTime() - now.getTime();
        if (diffMs <= 0)
            return "now";
        const minsTotal = Math.max(1, Math.floor(diffMs / 60000));
        const days = Math.floor(minsTotal / 1440);
        const hours = Math.floor((minsTotal % 1440) / 60);
        const mins = minsTotal % 60;
        if (days > 0)
            return days + "d " + hours + "h";
        if (hours > 0)
            return hours + "h " + mins + "m";
        return mins + "m";
    }

    function formatUpdated(isoTimestamp) {
        if (!isoTimestamp)
            return "now";
        const updated = new Date(isoTimestamp);
        if (isNaN(updated.getTime()))
            return "now";
        const diffMs = Date.now() - updated.getTime();
        if (diffMs < 60000)
            return "now";
        const mins = Math.floor(diffMs / 60000);
        if (mins < 60)
            return mins + "m ago";
        return Math.floor(mins / 60) + "h ago";
    }

    function formatCompact(value) {
        const n = Number(value ?? 0);
        if (n >= 1000000)
            return (n / 1000000).toFixed(1) + "M";
        if (n >= 1000)
            return (n / 1000).toFixed(1) + "K";
        if (n >= 100)
            return String(Math.round(n));
        if (n >= 10)
            return n.toFixed(1);
        return n.toFixed(2).replace(/\.?0+$/, "");
    }

    function currencySymbol(currency) {
        const code = String(currency ?? "").trim().toUpperCase();
        if (code === "USD")
            return "$";
        if (code === "EUR")
            return "€";
        if (code === "GBP")
            return "£";
        if (code === "JPY")
            return "¥";
        return "";
    }

    function formatCurrency(value, currency) {
        const n = Number(value ?? 0);
        const code = String(currency ?? "").trim().toUpperCase();
        const symbol = root.currencySymbol(code);
        const amount = Math.abs(n) >= 1000 ? root.formatCompact(n) : n.toFixed(2);
        if (symbol !== "")
            return symbol + amount;
        if (code !== "")
            return amount + " " + code;
        return amount;
    }
}
