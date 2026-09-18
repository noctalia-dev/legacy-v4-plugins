import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Plugins-menu entry: embeds the shared controls; the dialog calls
// saveSettings() when the user presses Save.
ColumnLayout {
    id: root
    property var pluginApi: null

    spacing: Style.marginM

    SettingsControls {
        id: controls
        Layout.fillWidth: true
        pluginApi: root.pluginApi
    }

    function saveSettings() {
        var updated = controls.collectSettings();
        if (root.pluginApi) {
            for (var k in updated)
                root.pluginApi.pluginSettings[k] = updated[k];
            // Transient runtime state must never land in settings.json.
            delete root.pluginApi.pluginSettings.drift;
            delete root.pluginApi.pluginSettings.checkedAtMs;
            root.pluginApi.saveSettings();
        }
        return updated;
    }
}
