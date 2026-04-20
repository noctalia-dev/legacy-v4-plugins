import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property string editMode: 
        pluginApi?.pluginSettings?.mode || 
        pluginApi?.manifest?.metadata?.defaultSettings?.mode || 
        "region"

    spacing: Style.marginM

    NComboBox {
        label: pluginApi?.tr("settings.mode.label")
        description: pluginApi?.tr("settings.mode.description")
        model: [
            {
                "key": "region",
                "name": pluginApi?.tr("settings.mode.region")
            },
            {
                "key": "screen",
                "name": pluginApi?.tr("settings.mode.screen")
            }
        ]
        currentKey: root.editMode
        onSelected: key => root.editMode = key
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.mode || "region"
    }

    function saveSettings() {
        if (!pluginApi) return;

        pluginApi.pluginSettings.mode = root.editMode;
        pluginApi.saveSettings();
    }
}
