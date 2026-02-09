import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null



    property bool editCompactMode:
        pluginApi?.pluginSettings?.compactMode ??
        pluginApi?.manifest?.metadata?.defaultSettings?.compactMode ??
        false

    property string editIconColor:
        pluginApi?.pluginSettings?.iconColor ??
        pluginApi?.manifest?.metadata?.defaultSettings?.iconColor ??
        "none"

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("Timer", "Cannot save: pluginApi is null")
            return
        }


        pluginApi.pluginSettings.compactMode = root.editCompactMode
        pluginApi.pluginSettings.iconColor = root.editIconColor

        pluginApi.saveSettings()
        Logger.i("Timer", "Settings saved successfully")
    }



    // Icon Color
    NComboBox {
        label: I18n.tr("common.select-icon-color")
        description: I18n.tr("common.select-color-description")
        model: Color.colorKeyModel
        currentKey: root.editIconColor
        onSelected: key => root.editIconColor = key
        minimumWidth: 200
    }

    // Compact Mode
    NToggle {
        label: pluginApi?.tr("settings.compact-mode") || "Compact Mode"
        description: pluginApi?.tr("settings.compact-mode-desc") || "Hide the circular progress bar for a cleaner look"
        checked: root.editCompactMode
        onToggled: checked => root.editCompactMode = checked
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.compactMode ?? false
    }

    Item {
        Layout.fillHeight: true
    }
}
