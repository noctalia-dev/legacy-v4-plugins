import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    property var pluginApi: null

    property var cfg:      pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    // Edit copies
    property int    editRefreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 3000
    property bool   editShowGovernor:    cfg.showGovernor    ?? defaults.showGovernor    ?? true
    property bool   editShowTurbo:       cfg.showTurbo       ?? defaults.showTurbo       ?? true
    property bool   editCompactMode:     cfg.compactMode     ?? defaults.compactMode     ?? false

    spacing: Style.marginL

    NToggle {
        Layout.fillWidth: true
        label:       pluginApi?.tr("settings.compact.label")
        description: pluginApi?.tr("settings.compact.desc")
        checked: root.editCompactMode
        onToggled: root.editCompactMode = checked
    }

    NToggle {
        Layout.fillWidth: true
        label:       pluginApi?.tr("settings.show-governor.label")
        description: pluginApi?.tr("settings.show-governor.desc")
        checked: root.editShowGovernor
        onToggled: root.editShowGovernor = checked
    }

    NToggle {
        Layout.fillWidth: true
        label:       pluginApi?.tr("settings.show-turbo.label")
        description: pluginApi?.tr("settings.show-turbo.desc")
        checked: root.editShowTurbo
        onToggled: root.editShowTurbo = checked
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
            text: pluginApi?.tr("settings.refresh.label")
            pointSize: Style.fontSizeS
            font.weight: Font.Medium
            color: Color.mOnSurface
        }

        NText {
            text: pluginApi?.tr("settings.refresh.desc")
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NSlider {
                Layout.fillWidth: true
                from: 1000
                to: 10000
                stepSize: 500
                value: root.editRefreshInterval
                onMoved: root.editRefreshInterval = value
            }

            NText {
                text: (root.editRefreshInterval / 1000).toFixed(1) + "s"
                pointSize: Style.fontSizeS
                font.family: Settings.data?.ui?.fontFixed ?? "monospace"
                color: Color.mOnSurface
                Layout.preferredWidth: 36 * Style.uiScaleRatio
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval
        pluginApi.pluginSettings.showGovernor    = root.editShowGovernor
        pluginApi.pluginSettings.showTurbo       = root.editShowTurbo
        pluginApi.pluginSettings.compactMode     = root.editCompactMode
        pluginApi.saveSettings()
    }
}
