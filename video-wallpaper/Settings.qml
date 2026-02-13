import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

import "./common"
import "./settings"

ColumnLayout {
    id: root
    property var pluginApi: null

    spacing: Style.marginM


    /***************************
    * PROPERTIES
    ***************************/
    property string activeBackend:  pluginApi?.pluginSettings?.activeBackend  || pluginApi?.manifest?.metadata?.defaultSettings?.activeBackend || ""
    property bool   enabled:        pluginApi?.pluginSettings?.enabled        || false


    /***************************
    * COMPONENTS
    ***************************/
    // Active toggle
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.toggle.label") || "Enable video wallpapers"
        description: pluginApi?.tr("settings.toggle.description") || "Choose your preferred backend to render the videos with, in the box below."
        checked: root.enabled
        onToggled: checked => root.enabled = checked
    }

    NComboBox {
        enabled: root.enabled
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.backend.label") || "Active backend"
        description: root.pluginApi?.tr("settings.backend.description") || "What to use to render the video wallpapers."
        defaultValue: "qt6-multimedia"
        model: [
            {
                "key": "qt6-multimedia",
                "name": root.pluginApi?.tr("settings.backend.qt6_multimedia") || "Qt6 Multimedia"
            },
            {
                "key": "mpvpaper",
                "name": root.pluginApi?.tr("settings.backend.mpvpaper") || "Mpvpaper"
            }
        ]
        currentKey: root.activeBackend
        onSelected: key => root.activeBackend = key
    }

    NDivider {}

    // Tool row
    ToolRow {
        pluginApi: root.pluginApi
        enabled: root.enabled
    }

    NDivider {}

    // Tab bar with all the settings menu
    NTabBar {
        id: subTabBar
        Layout.fillWidth: true
        distributeEvenly: true
        currentIndex: tabView.currentIndex

        NTabButton {
            enabled: root.enabled
            text: pluginApi?.tr("settings.tab_bar.general") || "General"
            tabIndex: 0
            checked: subTabBar.currentIndex === 0
        }
        NTabButton {
            enabled: root.enabled
            text: pluginApi?.tr("settings.tab_bar.automation") || "Automation"
            tabIndex: 1
            checked: subTabBar.currentIndex === 1
        }
        NTabButton {
            enabled: root.enabled
            text: pluginApi?.tr("settings.tab_bar.advanced") || "Advanced"
            tabIndex: 2
            checked: subTabBar.currentIndex === 2
        }
    }

    // The menu shown
    NTabView {
        id: tabView
        currentIndex: subTabBar.currentIndex

        GeneralTab {
            id: general
            pluginApi: root.pluginApi
            enabled: root.enabled
        }

        AutomationTab {
            id: automation
            pluginApi: root.pluginApi
            enabled: root.enabled
        }

        AdvancedTab {
            id: advanced
            pluginApi: root.pluginApi
            enabled: root.enabled
            activeBackend: root.activeBackend
        }
    }

    Connections {
        target: root.pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.activeBackend = root.pluginApi?.pluginSettings?.activeBackend  || root.pluginApi?.manifest?.metadata?.defaultSettings?.activeBackend || ""
            root.enabled =       root.pluginApi?.pluginSettings?.enabled        || false
        }
    }

    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if(!pluginApi) {
            Logger.e("video-wallpaper", "Cannot save, pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.enabled = enabled;
        pluginApi.pluginSettings.activeBackend = activeBackend;

        general.saveSettings();
        automation.saveSettings();
        advanced.saveSettings();

        pluginApi.saveSettings();
    }
}
