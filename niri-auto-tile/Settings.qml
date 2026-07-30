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
    property bool valueOnlyAtMax: settings.onlyAtMax ?? defaults.onlyAtMax ?? false
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
        label: pluginApi?.tr("settings.enabled")
        description: pluginApi?.tr("settings.enabled-desc")
        checked: root.valueEnabled
        onToggled: checked => {
            root.valueEnabled = checked;
            root.saveSettings();
        }
    }

    // ─── Per Workspace ───
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.per-workspace")
        description: pluginApi?.tr("settings.per-workspace-desc")
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
        label: pluginApi?.tr("settings.only-at-max")
        description: pluginApi?.tr("settings.only-at-max-desc")
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
            label: pluginApi?.tr("settings.max-visible", {"value": root.valueMaxVisible})
            description: pluginApi?.tr("settings.max-visible-desc")
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
            label: pluginApi?.tr("settings.debounce", {"value": root.valueDebounceMs})
            description: pluginApi?.tr("settings.debounce-desc")
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
            label: pluginApi?.tr("settings.rate-limit", {"value": root.valueMaxEventsPerSecond})
            description: pluginApi?.tr("settings.rate-limit-desc")
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
        spacing: Style.marginM

        Rectangle {
            width: Math.round(8 * Style.uiScaleRatio)
            height: Math.round(8 * Style.uiScaleRatio)
            radius: Math.round(4 * Style.uiScaleRatio)
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
                if (status === "running") return pluginApi?.tr("settings.status-running");
                if (status === "error") return pluginApi?.tr("settings.status-error");
                return pluginApi?.tr("settings.status-stopped");
            }
            Layout.fillWidth: true
        }
    }

    // ─── About ───
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        spacing: Style.marginXS

        NText {
            text: pluginApi?.tr("settings.about-title")
            font.bold: true
        }

        NText {
            text: pluginApi?.tr("settings.about-credit")
            opacity: 0.7
            pointSize: Style.fontSizeS
        }

        NText {
            text: pluginApi?.tr("settings.about-date", {"date": "2026-02-19"})
            opacity: 0.5
            pointSize: Style.fontSizeXS
        }

        NText {
            text: "v" + (pluginApi?.manifest?.version ?? "1.1.0")
            opacity: 0.5
            pointSize: Style.fontSizeXS
        }
    }
}
