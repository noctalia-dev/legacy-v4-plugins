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
    property bool enabled: pluginApi.pluginSettings.enabled || false

    
    /***************************
    * COMPONENTS
    ***************************/
    // Active toggle
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.toggle.label") || "Enable video wallpapers"
        description: pluginApi?.tr("settings.toggle.description") || "Enable video wallpapers shown with QtMultimedia."
        checked: root.enabled
        onToggled: checked => root.enabled = checked
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
    }


    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if(!pluginApi) {
            Logger.e("video-wallpaper", "Cannot save, pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.active = enabled;

        general.saveSettings();
        automation.saveSettings();

        pluginApi.saveSettings();
    }
}
