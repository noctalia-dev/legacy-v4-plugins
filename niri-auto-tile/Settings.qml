import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    readonly property var settings: pluginApi?.pluginSettings ?? ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

    property bool valueEnabled: settings.enabled ?? defaults.enabled ?? true
    property bool valuePerWorkspace: settings.perWorkspace ?? defaults.perWorkspace ?? false
    property bool valueOnlyAtMax: settings.onlyAtMax ?? defaults.onlyAtMax ?? true
    property int valueMaxVisible: settings.maxVisible ?? defaults.maxVisible ?? 4
    property int valueDebounceMs: settings.debounceMs ?? defaults.debounceMs ?? 300
    property int valueMaxEventsPerSecond: settings.maxEventsPerSecond ?? defaults.maxEventsPerSecond ?? 20

    spacing: Style.marginM

    function saveSettings() {
        if (!pluginApi) return;
        pluginApi.pluginSettings.enabled = root.valueEnabled;
        pluginApi.pluginSettings.perWorkspace = root.valuePerWorkspace;
        pluginApi.pluginSettings.onlyAtMax = root.valueOnlyAtMax;
        pluginApi.pluginSettings.maxVisible = root.valueMaxVisible;
        pluginApi.pluginSettings.debounceMs = root.valueDebounceMs;
        pluginApi.pluginSettings.maxEventsPerSecond = root.valueMaxEventsPerSecond;
        pluginApi.saveSettings();
    }

    // ─── Enable / Disable ───
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.enabled") ?? "Enable Auto-Tile"
        description: pluginApi?.tr("settings.enabled-desc") ?? "Automatically redistribute column widths when windows open or close"
        checked: root.valueEnabled
        onToggled: checked => {
            root.valueEnabled = checked;
            root.saveSettings();
        }
    }

    // ─── Per Workspace ───
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.per-workspace") ?? "Per workspace"
        description: pluginApi?.tr("settings.per-workspace-desc") ?? "Each workspace has its own column count setting"
        checked: root.valuePerWorkspace
        onToggled: checked => {
            root.valuePerWorkspace = checked;
            root.saveSettings();
            pluginApi?.mainInstance?.restartDaemon();
        }
    }

    // ─── Only at Max ───
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.only-at-max") ?? "Only at max"
        description: pluginApi?.tr("settings.only-at-max-desc") ?? "Only redistribute when column count reaches the maximum"
        checked: root.valueOnlyAtMax
        onToggled: checked => {
            root.valueOnlyAtMax = checked;
            root.saveSettings();
            pluginApi?.mainInstance?.restartDaemon();
        }
    }

    // ─── Max Visible Columns ───
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: (pluginApi?.tr("settings.max-visible") ?? "Max visible columns") + ": " + root.valueMaxVisible
            description: pluginApi?.tr("settings.max-visible-desc") ?? "Maximum number of columns visible on screen at once"
        }

        NSlider {
            Layout.fillWidth: true
            from: 1
            to: 8
            value: root.valueMaxVisible
            stepSize: 1
            onMoved: {
                root.valueMaxVisible = Math.round(value);
                root.saveSettings();
                pluginApi?.mainInstance?.restartDaemon();
            }
        }
    }

    // ─── Debounce ───
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: (pluginApi?.tr("settings.debounce") ?? "Debounce delay") + ": " + root.valueDebounceMs + "ms"
            description: pluginApi?.tr("settings.debounce-desc") ?? "Delay before redistribution to coalesce rapid events"
        }

        NSlider {
            Layout.fillWidth: true
            from: 100
            to: 1000
            value: root.valueDebounceMs
            stepSize: 50
            onMoved: {
                root.valueDebounceMs = Math.round(value);
                root.saveSettings();
                pluginApi?.mainInstance?.restartDaemon();
            }
        }
    }

    // ─── Rate Limit ───
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: (pluginApi?.tr("settings.rate-limit") ?? "Rate limit") + ": " + root.valueMaxEventsPerSecond + "/s"
            description: pluginApi?.tr("settings.rate-limit-desc") ?? "Maximum events processed per second"
        }

        NSlider {
            Layout.fillWidth: true
            from: 5
            to: 50
            value: root.valueMaxEventsPerSecond
            stepSize: 5
            onMoved: {
                root.valueMaxEventsPerSecond = Math.round(value);
                root.saveSettings();
                pluginApi?.mainInstance?.restartDaemon();
            }
        }
    }

    // ─── Status ───
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        spacing: 8

        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: {
                const status = pluginApi?.mainInstance?.status ?? "stopped";
                if (status === "running") return Color.mPrimary;
                if (status === "error") return Color.mError;
                return Color.mOutline;
            }
        }

        NText {
            text: {
                const status = pluginApi?.mainInstance?.status ?? "stopped";
                if (status === "running") return pluginApi?.tr("settings.status-running") ?? "Daemon running";
                if (status === "error") return pluginApi?.tr("settings.status-error") ?? "Daemon error — restarting...";
                return pluginApi?.tr("settings.status-stopped") ?? "Daemon stopped";
            }
            Layout.fillWidth: true
        }
    }

    // ─── About ───
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        spacing: 4

        NText {
            text: pluginApi?.tr("settings.about-title") ?? "About"
            font.bold: true
        }

        NText {
            text: pluginApi?.tr("settings.about-credit") ?? "Developed by Pir0c0pter0 using Claude"
            opacity: 0.7
            font.pixelSize: 12
        }

        NText {
            text: (pluginApi?.tr("settings.about-date") ?? "Date") + ": 2026-02-19"
            opacity: 0.5
            font.pixelSize: 11
        }

        NText {
            text: "v" + (pluginApi?.manifest?.version ?? "1.1.0")
            opacity: 0.5
            font.pixelSize: 11
        }
    }
}
