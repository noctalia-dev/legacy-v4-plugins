import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    // ── Edit state ──
    property string editResultFile:
        pluginApi?.pluginSettings?.resultFile
        || pluginApi?.manifest?.metadata?.defaultSettings?.resultFile
        || "/tmp/noctalia-dmenu-result"

    property bool editShowToast:
        pluginApi?.pluginSettings?.showToastOnSelect
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.showToastOnSelect
        ?? false

    property int editMaxResults:
        pluginApi?.pluginSettings?.maxResults
        || pluginApi?.manifest?.metadata?.defaultSettings?.maxResults
        || 200

    property string editPanelPosition:
        pluginApi?.pluginSettings?.panelPosition
        || pluginApi?.manifest?.metadata?.defaultSettings?.panelPosition
        || "follow_launcher"

    property bool editShowMatchCount:
        pluginApi?.pluginSettings?.showMatchCount
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.showMatchCount
        ?? true

    property bool editShowFooter:
        pluginApi?.pluginSettings?.showFooter
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.showFooter
        ?? true

    // Position options
    readonly property var positionOptions: [
        { key: "follow_launcher", name: root.pluginApi?.tr("settings.positionFollowLauncher") },
        { key: "center",          name: root.pluginApi?.tr("settings.positionCenter") },
        { key: "top_center",      name: root.pluginApi?.tr("settings.positionTopCenter") },
        { key: "bottom_center",   name: root.pluginApi?.tr("settings.positionBottomCenter") },
        { key: "top_left",        name: root.pluginApi?.tr("settings.positionTopLeft") },
        { key: "top_right",       name: root.pluginApi?.tr("settings.positionTopRight") },
        { key: "bottom_left",     name: root.pluginApi?.tr("settings.positionBottomLeft") },
        { key: "bottom_right",    name: root.pluginApi?.tr("settings.positionBottomRight") },
        { key: "center_left",     name: root.pluginApi?.tr("settings.positionCenterLeft") },
        { key: "center_right",    name: root.pluginApi?.tr("settings.positionCenterRight") }
    ]

    spacing: Style.marginM

    // ═══════════════════════════════════════
    // Panel position
    // ═══════════════════════════════════════

    NComboBox {
        label: root.pluginApi?.tr("settings.panelPosition")
        description: root.pluginApi?.tr("settings.panelPositionDesc")
        Layout.fillWidth: true
        model: root.positionOptions
        currentKey: root.editPanelPosition
        onSelected: function(key) {
            root.editPanelPosition = key;
        }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ═══════════════════════════════════════
    // Display
    // ═══════════════════════════════════════

    NLabel {
        label: root.pluginApi?.tr("settings.display")
    }

    NToggle {
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.showMatchCount")
        description: root.pluginApi?.tr("settings.showMatchCountDesc")
        checked: root.editShowMatchCount
        onToggled: function(v) { root.editShowMatchCount = v }
    }

    NToggle {
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.showFooter")
        description: root.pluginApi?.tr("settings.showFooterDesc")
        checked: root.editShowFooter
        onToggled: function(v) { root.editShowFooter = v }
    }

    NToggle {
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.showToast")
        description: root.pluginApi?.tr("settings.showToastDesc")
        checked: root.editShowToast
        onToggled: function(v) { root.editShowToast = v }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ═══════════════════════════════════════
    // Advanced
    // ═══════════════════════════════════════

    NLabel {
        label: root.pluginApi?.tr("settings.advanced")
    }

    NTextInput {
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.resultFile")
        description: root.pluginApi?.tr("settings.resultFileDesc")
        placeholderText: "/tmp/noctalia-dmenu-result"
        text: root.editResultFile
        onTextChanged: root.editResultFile = text
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: root.pluginApi?.tr("settings.maxResultsLabel", { count: root.editMaxResults })
            description: root.pluginApi?.tr("settings.maxResultsDesc", { count: root.editMaxResults })
        }

        NSlider {
            Layout.fillWidth: true
            from: 50
            to: 1000
            stepSize: 50
            value: root.editMaxResults
            onValueChanged: root.editMaxResults = value
        }
    }

    // ── Save ──
    function saveSettings() {
        if (!pluginApi) {
            Logger.e("DmenuProvider", "Cannot save: pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.resultFile = root.editResultFile;
        pluginApi.pluginSettings.showToastOnSelect = root.editShowToast;
        pluginApi.pluginSettings.maxResults = root.editMaxResults;
        pluginApi.pluginSettings.panelPosition = root.editPanelPosition;
        pluginApi.pluginSettings.showMatchCount = root.editShowMatchCount;
        pluginApi.pluginSettings.showFooter = root.editShowFooter;
        pluginApi.saveSettings();

        Logger.i("DmenuProvider", "Settings saved");
    }
}
