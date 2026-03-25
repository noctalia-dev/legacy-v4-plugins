import QtQuick
import Quickshell
import "providers"

Item {
    id: root
    visible: false

    property var pluginApi: null
    property var pluginSettings: pluginApi?.pluginSettings ?? ({})

    Claude {
        id: claudeProvider
        enabled: root.providerEnabled("claude")
        providerSettings: root.pluginSettings?.providers?.claude ?? ({})
    }

    Codex {
        id: codexProvider
        enabled: root.providerEnabled("codex")
        providerSettings: root.pluginSettings?.providers?.codex ?? ({})
    }

    OpenRouter {
        id: openRouterProvider
        enabled: root.providerEnabled("openrouter")
        providerSettings: root.pluginSettings?.providers?.openrouter ?? ({})
    }

    Copilot {
        id: copilotProvider
        enabled: root.providerEnabled("copilot")
        providerSettings: root.pluginSettings?.providers?.copilot ?? ({})
    }

    Zen {
        id: zenProvider
        enabled: root.providerEnabled("zen")
        providerSettings: root.pluginSettings?.providers?.zen ?? ({})
    }

    property var providers: [claudeProvider, codexProvider, copilotProvider, openRouterProvider, zenProvider]

    property var enabledProviders: {
        const result = [];
        if (claudeProvider.enabled)
            result.push(claudeProvider);
        if (codexProvider.enabled)
            result.push(codexProvider);
        if (copilotProvider.enabled)
            result.push(copilotProvider);
        if (openRouterProvider.enabled)
            result.push(openRouterProvider);
        if (zenProvider.enabled)
            result.push(zenProvider);
        return result;
    }

    property int activeIndex: 0
    property var activeProvider: enabledProviders.length > 0 ? enabledProviders[Math.min(activeIndex, enabledProviders.length - 1)] : null

    property string barDisplayMode: pluginSettings?.barDisplayMode ?? "active"
    property int barCycleIntervalSec: pluginSettings?.barCycleIntervalSec ?? 5
    property string barMetric: pluginSettings?.barMetric ?? "prompts"
    property int refreshIntervalSec: pluginSettings?.refreshIntervalSec ?? 30

    Timer {
        interval: root.barCycleIntervalSec * 1000
        running: root.barDisplayMode === "cycle" && root.enabledProviders.length > 1
        repeat: true
        onTriggered: {
            root.activeIndex = (root.activeIndex + 1) % root.enabledProviders.length;
        }
    }

    Timer {
        interval: root.refreshIntervalSec * 1000
        running: true
        repeat: true
        onTriggered: root.refreshAll()
    }

    onEnabledProvidersChanged: {
        if (enabledProviders.length === 0) {
            activeIndex = 0;
        } else if (activeIndex >= enabledProviders.length) {
            activeIndex = 0;
        }
    }

    function providerEnabled(id) {
        return pluginSettings?.providers?.[id]?.enabled ?? false;
    }

    function refresh() {
        refreshAll();
    }

    function refreshAll() {
        for (const p of providers) {
            if (p.enabled)
                p.refresh();
        }
    }

    function formatTokenCount(n) {
        if (n === undefined || n === null)
            return "0";
        if (n >= 1e9)
            return (n / 1e9).toFixed(1) + "B";
        if (n >= 1e6)
            return (n / 1e6).toFixed(1) + "M";
        if (n >= 1e3)
            return (n / 1e3).toFixed(1) + "K";
        return String(n);
    }

    function friendlyModelName(id) {
        if (!id)
            return "Unknown";
        let name = id.replace(/^claude-/, "");
        name = name.replace(/-\d{8}$/, "");
        const parts = name.split("-");
        if (parts.length >= 3) {
            const family = parts[0].charAt(0).toUpperCase() + parts[0].slice(1);
            return family + " " + parts[1] + "." + parts[2];
        }
        if (parts.length === 2) {
            const family = parts[0].charAt(0).toUpperCase() + parts[0].slice(1);
            return family + " " + parts[1];
        }
        return name.charAt(0).toUpperCase() + name.slice(1);
    }
}
