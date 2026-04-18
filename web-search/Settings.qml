import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string valueSearchEngine: cfg.search_engine ?? defaults.search_engine ?? "Google"
    property bool valueDirectUrl: cfg.direct_url ?? defaults.direct_url ?? true
    property bool valueShowSuggestions: cfg.show_suggestions ?? defaults.show_suggestions ?? true
    property int valueMaxResults: cfg.max_results ?? defaults.max_results ?? 5

    spacing: Style.marginL

    Component.onCompleted: {
        Logger.d("WebSearch", "Settings UI loaded");
    }

    ColumnLayout {
        spacing: Style.marginM
        Layout.fillWidth: true

        NComboBox {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.engine.label")
            description: pluginApi?.tr("settings.engine.description")
            model: ["Google", "DuckDuckGo", "Bing", "Brave", "Yandex"].map(function(n) {
                return { key: n, name: n };
            })
            
            currentKey: root.valueSearchEngine
            onSelected: key => root.valueSearchEngine = key
        }

        NToggle {
            label: pluginApi?.tr("settings.directUrl.label")
            description: pluginApi?.tr("settings.directUrl.description")
            checked: root.valueDirectUrl
            onToggled: root.valueDirectUrl = checked
        }

        NToggle {
            label: pluginApi?.tr("settings.suggestions.label")
            description: pluginApi?.tr("settings.suggestions.description")
            checked: root.valueShowSuggestions
            onToggled: root.valueShowSuggestions = checked
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        RowLayout {
            Layout.fillWidth: true

            NText {
                text: pluginApi?.tr("settings.maxResults.label")
                font.pointSize: Style.fontSizeL
                font.weight: Font.Medium
                color: Color.mOnSurface
                Layout.fillWidth: true
            }

            NText {
                text: root.valueMaxResults.toString()
                font.pointSize: Style.fontSizeM
                font.weight: Font.Medium
                color: Color.mPrimary
            }
        }

        NText {
            text: pluginApi?.tr("settings.maxResults.description")
            font.pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        NSlider {
            Layout.fillWidth: true
            from: 1
            to: 10
            stepSize: 1
            value: root.valueMaxResults
            onMoved: root.valueMaxResults = Math.round(value)
        }
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("WebSearch", "Cannot save settings: pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.search_engine = root.valueSearchEngine;
        pluginApi.pluginSettings.direct_url = root.valueDirectUrl;
        pluginApi.pluginSettings.show_suggestions = root.valueShowSuggestions;
        pluginApi.pluginSettings.max_results = root.valueMaxResults;
        pluginApi.saveSettings();

        Logger.d("WebSearch", "Settings saved successfully");
    }
}
