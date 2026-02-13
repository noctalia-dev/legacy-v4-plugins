import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

import "./common"
import "./settings"

ColumnLayout {
    id: root

    property var pluginApi: null

    property bool active:
        pluginApi?.pluginSettings?.active ||
        false

    spacing: Style.marginM

    // Active toggle
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.toggle.label") || "Enable mpvpaper"
        description: pluginApi?.tr("settings.toggle.description") || "Enable the mpvpaper integration"
        checked: root.active
        onToggled: checked => root.active = checked
    }

    NDivider {}

    ToolRow {
        pluginApi: root.pluginApi
        enabled: root.active
    }

    NDivider {}

    NTabBar {
        id: subTabBar
        Layout.fillWidth: true
        distributeEvenly: true
        currentIndex: tabView.currentIndex

        NTabButton {
            enabled: root.active
            text: pluginApi?.tr("settings.tab_bar.playback") || "Playback"
            tabIndex: 0
            checked: subTabBar.currentIndex === 0
        }
        NTabButton {
            enabled: root.active
            text: pluginApi?.tr("settings.tab_bar.audio") || "Audio"
            tabIndex: 1
            checked: subTabBar.currentIndex === 1
        }
        NTabButton {
            enabled: root.active
            text: pluginApi?.tr("settings.tab_bar.automation") || "Automation"
            tabIndex: 2
            checked: subTabBar.currentIndex === 2
        }
        NTabButton {
            enabled: root.active
            text: pluginApi?.tr("settings.tab_bar.advanced") || "Advanced"
            tabIndex: 3
            checked: subTabBar.currentIndex === 3
        }
    }

    NTabView {
        id: tabView
        currentIndex: subTabBar.currentIndex

        PlaybackTab {
            id: playback
            pluginApi: root.pluginApi
            active: root.active
        }

        AudioTab {
            id: audio
            pluginApi: root.pluginApi
            active: root.active
        }

        AutomationTab {
            id: automation
            pluginApi: root.pluginApi
            active: root.active
        }

        AdvancedTab {
            id: advanced
            pluginApi: root.pluginApi
            active: root.active
        }
    }


    /********************************
     * Save settings functionality
     ********************************/
    function saveSettings() {
        if(!pluginApi) {
            Logger.e("mpvpaper", "Cannot save: pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.active = active;

        playback.saveSettings();
        audio.saveSettings();
        advanced.saveSettings();
        automation.saveSettings();

        pluginApi.saveSettings();

        Logger.d("mpvpaper", "Settings saved");
    }
}
