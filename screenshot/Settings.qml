import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property string editMode: 
        pluginApi?.pluginSettings?.mode || 
        pluginApi?.manifest?.metadata?.defaultSettings?.mode || 
        "region"

    property string editNiriMode: 
        pluginApi?.pluginSettings?.niriMode || 
        pluginApi?.manifest?.metadata?.defaultSettings?.niriMode || 
        "default"

    spacing: Style.marginM

    NComboBox {
        visible: CompositorService.isHyprland || (!CompositorService.isHyprland && !CompositorService.isNiri)
        label: pluginApi?.tr("settings.mode.label") || "Screenshot Mode"
        description: pluginApi?.tr("settings.mode.description") || "Choose between region selection or direct screen capture"
        model: [
            {
                "key": "region",
                "name": pluginApi?.tr("settings.mode.region") || "Region Selection"
            },
            {
                "key": "screen",
                "name": pluginApi?.tr("settings.mode.screen") || "Full Screen"
            }
        ]
        currentKey: root.editMode
        onSelected: key => root.editMode = key
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.mode || "region"
    }

    NComboBox {
        visible: CompositorService.isNiri
        label: pluginApi?.tr("settings.niriMode.label") || "Niri Screenshot Type"
        description: pluginApi?.tr("settings.niriMode.description") || "Choose the type of screenshot to take"
        model: [
            {
                "key": "default",
                "name": pluginApi?.tr("settings.niriMode.default") || "Default (Interactive)"
            },
            {
                "key": "window",
                "name": pluginApi?.tr("settings.niriMode.window") || "Window"
            },
            {
                "key": "fullscreen",
                "name": pluginApi?.tr("settings.niriMode.fullscreen") || "Fullscreen"
            }
        ]
        currentKey: root.editNiriMode
        onSelected: key => root.editNiriMode = key
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.niriMode || "default"
    }

    function saveSettings() {
        if (!pluginApi) return;

        pluginApi.pluginSettings.mode = root.editMode;
        pluginApi.pluginSettings.niriMode = root.editNiriMode;
        pluginApi.saveSettings();
    }
}
