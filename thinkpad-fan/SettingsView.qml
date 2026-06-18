import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null

    // ===== EDIT STATE =====
    property bool editColorizeByStatus:
        pluginApi?.pluginSettings?.colorizeByStatus ??
        pluginApi?.manifest?.metadata?.defaultSettings?.colorizeByStatus ??
        true

    property bool editAllowPopupOpening:
        pluginApi?.pluginSettings?.allowPopupOpening ??
        pluginApi?.manifest?.metadata?.defaultSettings?.allowPopupOpening ??
        true

    // ===== SAVE =====
    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.colorizeByStatus = root.editColorizeByStatus
        pluginApi.pluginSettings.allowPopupOpening = root.editAllowPopupOpening
        pluginApi.saveSettings()
    }

    // ===== UI =====
    NText {
        text: pluginApi?.tr("settings.title")
        pointSize: Style.fontSizeM
        font.weight: Font.Bold
        color: Color.mOnSurface
    }

    // Option 1: Dynamic coloring based on fan status
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.dynamic-coloring")
        description: pluginApi?.tr("settings.dynamic-coloring-desc")
        checked: root.editColorizeByStatus
        onToggled: checked => {
            root.editColorizeByStatus = checked
            root.saveSettings()
        }
    }

    // Option 2: Left Click Interaction Toggle
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.allow-popup")
        description: pluginApi?.tr("settings.allow-popup-desc")
        checked: root.editAllowPopupOpening
        onToggled: checked => {
            root.editAllowPopupOpening = checked
            root.saveSettings()
        }
    }

    Item { Layout.fillHeight: true }
}