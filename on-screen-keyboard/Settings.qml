import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "Layout.js" as Layouts

ColumnLayout {
    id: root
    property var pluginApi: null

    spacing: Style.marginL

    // Local state
    property string selectedLayout: "English (US)"
    property bool pinnedOnStartup: false
    property bool showFunctionKeys: true
    property int keyboardHeight: 300

    Component.onCompleted: {
        if (pluginApi) {
            selectedLayout = pluginApi.pluginSettings?.layout ?? "English (US)";
            pinnedOnStartup = pluginApi.pluginSettings?.pinnedOnStartup ?? false;
            showFunctionKeys = pluginApi.pluginSettings?.showFunctionKeys ?? true;
            keyboardHeight = pluginApi.pluginSettings?.keyboardHeight ?? 300;
        }
    }

    function saveSettings() {
        if (pluginApi) {
            pluginApi.pluginSettings.layout = selectedLayout;
            pluginApi.pluginSettings.pinnedOnStartup = pinnedOnStartup;
            pluginApi.pluginSettings.showFunctionKeys = showFunctionKeys;
            pluginApi.pluginSettings.keyboardHeight = keyboardHeight;
            pluginApi.saveSettings();

            // Update main instance
            pluginApi.mainInstance.currentLayout = selectedLayout;
            pluginApi.mainInstance.isPinned = pinnedOnStartup;
            pluginApi.mainInstance.showFunctionKeys = showFunctionKeys;
            pluginApi.mainInstance.keyboardHeight = keyboardHeight;
        }
    }

    // Keyboard Layout Section
    NLabel {
        label: pluginApi?.tr("settings.layout.title") || "Keyboard Layout"
        description: pluginApi?.tr("settings.layout.description") || "Select the keyboard layout to use"
    }

    NComboBox {
        id: layoutComboBox
        Layout.fillWidth: true
        model: Object.keys(Layouts.byName)
        currentIndex: {
            var keys = Object.keys(Layouts.byName);
            return keys.indexOf(selectedLayout);
        }
        onActivated: {
            selectedLayout = model[index];
            saveSettings();
        }
    }

    // Startup Settings
    NLabel {
        label: pluginApi?.tr("settings.startup.title") || "Startup Settings"
        description: pluginApi?.tr("settings.startup.description") || "Configure keyboard behavior on startup"
    }

    NCheckBox {
        text: pluginApi?.tr("settings.pinned-on-startup") || "Pin keyboard on startup"
        checked: pinnedOnStartup
        onToggled: {
            pinnedOnStartup = checked;
            saveSettings();
        }
    }

    // Display Settings
    NLabel {
        label: pluginApi?.tr("settings.display.title") || "Display Settings"
        description: pluginApi?.tr("settings.display.description") || "Customize keyboard appearance"
    }

    NCheckBox {
        text: pluginApi?.tr("settings.show-function-keys") || "Show function keys row (F1-F12)"
        checked: showFunctionKeys
        onToggled: {
            showFunctionKeys = checked;
            saveSettings();
        }
    }

    // Keyboard Shortcuts
    NLabel {
        label: pluginApi?.tr("settings.shortcuts.title") || "Keyboard Shortcuts"
        description: pluginApi?.tr("settings.shortcuts.description") || "Control the keyboard using IPC commands"
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: shortcutsText.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceContainerHighest
        radius: Style.radiusM

        NText {
            id: shortcutsText
            anchors.fill: parent
            anchors.margins: Style.marginM
            text: "# Toggle keyboard\nqs -c \"noctalia-shell\" ipc call plugin:on-screen-keyboard toggle\n\n# Open keyboard\nqs -c \"noctalia-shell\" ipc call plugin:on-screen-keyboard open\n\n# Close keyboard\nqs -c \"noctalia-shell\" ipc call plugin:on-screen-keyboard close"
            font.family: Settings.data.ui.fontFixed
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
            wrapMode: Text.WordWrap
        }
    }

    // Dependencies
    NLabel {
        label: pluginApi?.tr("settings.dependencies.title") || "Dependencies"
        description: pluginApi?.tr("settings.dependencies.description") || "Required software for this plugin"
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: depsText.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceContainerHighest
        radius: Style.radiusM

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NText {
                id: depsText
                Layout.fillWidth: true
                text: pluginApi?.tr("settings.dependencies.ydotool") || "This plugin requires ydotool for keyboard input simulation."
                pointSize: Style.fontSizeM
                color: Color.mOnSurface
                wrapMode: Text.WordWrap
            }

            NText {
                Layout.fillWidth: true
                text: "# Install on Arch Linux\nsudo pacman -S ydotool\n\n# Install on Ubuntu/Debian\nsudo apt install ydotool\n\n# Start ydotool daemon\nsudo systemctl enable --now ydotoold"
                font.family: Settings.data.ui.fontFixed
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                wrapMode: Text.WordWrap
            }
        }
    }

    Item { Layout.fillHeight: true }
}
