import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    
    property var pluginApi: null
    
    property string weekStart: "1"
    property string timeFormat: "24h"
    property string lineColorType: "mOutline"
    property string panelMode: "attached"
    property real hourLineOpacity: 0.5
    property real dayLineOpacity: 1.0
    
    spacing: Style.marginL
    
    Component.onCompleted: {
        Logger.i("WeeklyCalendar", "Settings UI loaded")
        
        if (pluginApi?.pluginSettings) {
            panelMode = pluginApi.pluginSettings.panelMode || "attached"
            weekStart = pluginApi.pluginSettings.weekStart || "1"
            timeFormat = pluginApi.pluginSettings.timeFormat || "24h"
            lineColorType = pluginApi.pluginSettings.lineColorType || "mOutline"
            hourLineOpacity = pluginApi.pluginSettings.hourLineOpacity || 0.5
            dayLineOpacity = pluginApi.pluginSettings.dayLineOpacity || 0.9
        }
    }

    // Time Format toggle
    NToggle {
        label: pluginApi.tr("settings.timeFormat")
        description: pluginApi.tr("settings.timeFormat_description")
        checked: root.timeFormat === pluginApi.tr("settings.12h")
        onToggled: checked => root.timeFormat = checked ? pluginApi.tr("settings.12h") : pluginApi.tr("settings.24h")
    }

    // Week Start selector
    NComboBox {
        Layout.fillWidth: true
        label: pluginApi.tr("settings.weekStart")
        description: pluginApi.tr("settings.weekStart_description")
        model: [
            {"key": "1", "name": pluginApi.tr("settings.monday")},
            {"key": "0", "name": pluginApi.tr("settings.sunday")},
            {"key": "6", "name": pluginApi.tr("settings.saturday")}
        ]
        currentKey: root.weekStart
        onSelected: key => root.weekStart = key
    }

    NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
    }

    // Line color type selector
    NComboBox {
        Layout.fillWidth: true
        label: pluginApi.tr("settings.gridColor")
        description: pluginApi.tr("settings.gridColor_description")
        model: [
            {"key": "mOutline", "name": pluginApi.tr("settings.colorOutline")},
            {"key": "mOnSurfaceVariant", "name": pluginApi.tr("settings.colorOnSurfaceVariant")}
        ]
        currentKey: root.lineColorType
        onSelected: key => root.lineColorType = key
    }

    // Hour line opacity slider
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        NLabel {
            label: pluginApi.tr("settings.hourLineOpacity")
        }
        RowLayout {
            Layout.fillWidth: true
            NText {
                text: pluginApi.tr("settings.hourLineOpacity_description")
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }
            NText {
                text: Math.round(root.hourLineOpacity * 100) + "%"
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }
        }

        NSlider {
            Layout.fillWidth: true
            from: 0.1
            to: 1
            stepSize: 0.1
            value: root.hourLineOpacity
            onValueChanged: root.hourLineOpacity = value
        }
    }

    // Day line opacity slider
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        NLabel {
            label: pluginApi.tr("settings.dayLineOpacity")
        }
        RowLayout {
            Layout.fillWidth: true
            NText {
                text: pluginApi.tr("settings.dayLineOpacity_description")
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }
            NText {
                text: Math.round(root.dayLineOpacity * 100) + "%"
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }
        }

        NSlider {
            Layout.fillWidth: true
            from: 0.1
            to: 1
            stepSize: 0.1
            value: root.dayLineOpacity
            onValueChanged: root.dayLineOpacity = value
        }
        
    }

    NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
    }

    NComboBox {
        Layout.fillWidth: true
        label: pluginApi.tr("settings.panelMode")
        description: pluginApi.tr("settings.panelMode_description")
        model: [
            {"key": "attached", "name": pluginApi.tr("settings.panelAttach")},
            {"key": "centered", "name": pluginApi.tr("settings.panelCenter")},
        ]
        currentKey: root.panelMode
        onSelected: key => root.panelMode = key
    }
    
    function saveSettings() {
        if (!pluginApi) {
            Logger.e("WeeklyCalendar", "Cannot save settings: pluginApi is null")
            return
        }
        
        if (!pluginApi.pluginSettings) {
            pluginApi.pluginSettings = {}
        }
        pluginApi.pluginSettings.panelMode = panelMode
        pluginApi.pluginSettings.weekStart = weekStart
        pluginApi.pluginSettings.timeFormat = timeFormat
        pluginApi.pluginSettings.lineColorType = lineColorType
        pluginApi.pluginSettings.hourLineOpacity = hourLineOpacity
        pluginApi.pluginSettings.dayLineOpacity = dayLineOpacity
        pluginApi.saveSettings()
        
        Logger.i("WeeklyCalendar", "Settings saved: weekStart=" + weekStart + 
                 ", timeFormat=" + timeFormat + 
                 ", panelMode=" + panelMode +
                 ", lineColorType=" + lineColorType +
                 ", hourLineOpacity=" + hourLineOpacity +
                 ", dayLineOpacity=" + dayLineOpacity)
    }
}