function defaultSettings(pluginApi) {
    if (!pluginApi || !pluginApi.manifest || !pluginApi.manifest.metadata || !pluginApi.manifest.metadata.defaultSettings)
        return {}
    return pluginApi.manifest.metadata.defaultSettings
}

function setting(pluginApi, key, fallback) {
    var settings = pluginApi && pluginApi.pluginSettings ? pluginApi.pluginSettings : {}
    var defaults = defaultSettings(pluginApi)
    var value = settings[key]
    if (value === undefined || value === null || value === "")
        value = defaults[key]
    if (value === undefined || value === null || value === "")
        value = fallback
    return value
}

function command(pluginApi) {
    return [
        setting(pluginApi, "codexbarPath", "codexbar"),
        "usage",
        "--provider", "codex",
        "--source", setting(pluginApi, "codexbarSource", "cli"),
        "--format", "json"
    ]
}

function refreshIntervalMs(pluginApi) {
    var seconds = Number(setting(pluginApi, "refreshIntervalSec", 60))
    if (isNaN(seconds))
        seconds = 60
    return Math.max(5, seconds) * 1000
}

function valueOrFallback(value, fallback) {
    return value === undefined || value === null ? fallback : value
}

function emptyUsage() {
    return {
        error: "",
        sourceName: "",
        providerName: "Codex",
        versionText: "",
        updatedAt: "",
        accountEmail: "",
        loginMethod: "",
        providerId: "codex",
        primaryPercent: -1,
        secondaryPercent: -1,
        primaryWindowMinutes: 0,
        secondaryWindowMinutes: 0,
        primaryResetAt: "",
        secondaryResetAt: "",
        primaryReset: "",
        secondaryReset: "",
        creditsRemaining: 0,
        creditEventsCount: 0
    }
}

function parseUsage(output) {
    var result = emptyUsage()
    try {
        var trimmed = String(output || "").trim()
        if (trimmed === "") {
            result.error = "empty codexbar output"
            return result
        }

        var data = JSON.parse(trimmed)
        var item = Array.isArray(data) && data.length > 0 ? data[0] : data
        if (item.error) {
            result.error = item.error.message || "codexbar error"
            return result
        }

        var usage = item.usage || {}
        var primary = usage.primary || {}
        var secondary = usage.secondary || {}
        var identity = usage.identity || {}
        var credits = item.credits || {}

        result.sourceName = item.source || "codex-cli"
        result.providerName = item.provider || identity.providerID || "codex"
        result.versionText = item.version || ""
        result.updatedAt = usage.updatedAt || credits.updatedAt || ""
        result.accountEmail = usage.accountEmail || identity.accountEmail || ""
        result.loginMethod = usage.loginMethod || identity.loginMethod || ""
        result.providerId = identity.providerID || item.provider || "codex"
        result.primaryPercent = Number(valueOrFallback(primary.usedPercent, -1))
        result.secondaryPercent = Number(valueOrFallback(secondary.usedPercent, -1))
        result.primaryWindowMinutes = Number(valueOrFallback(primary.windowMinutes, 0))
        result.secondaryWindowMinutes = Number(valueOrFallback(secondary.windowMinutes, 0))
        result.primaryResetAt = primary.resetsAt || ""
        result.secondaryResetAt = secondary.resetsAt || ""
        result.primaryReset = primary.resetDescription || ""
        result.secondaryReset = secondary.resetDescription || ""
        result.creditsRemaining = Number(valueOrFallback(credits.remaining, 0))
        result.creditEventsCount = Array.isArray(credits.events) ? credits.events.length : 0
        return result
    } catch (e) {
        result.error = "parse failed: " + e
        return result
    }
}

function clampPercent(value) {
    if (value < 0 || isNaN(value))
        return 0
    return Math.min(100, Math.max(0, value))
}

function percentLabel(value) {
    if (value < 0 || isNaN(value))
        return "—"
    return Math.round(value) + "%"
}

function windowLabel(minutes) {
    if (minutes === 300)
        return "5 hour window"
    if (minutes === 10080)
        return "Weekly window"
    if (minutes >= 1440)
        return Math.round(minutes / 1440) + " day window"
    if (minutes >= 60)
        return Math.round(minutes / 60) + " hour window"
    return minutes > 0 ? minutes + " minute window" : "Window"
}
