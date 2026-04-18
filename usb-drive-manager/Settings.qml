import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null

    // ===== EDIT STATE =====

    property bool editAutoMount:
        pluginApi?.pluginSettings?.autoMount ??
        pluginApi?.manifest?.metadata?.defaultSettings?.autoMount ??
        false

    property string editFileBrowser:
        pluginApi?.pluginSettings?.fileBrowser ||
        pluginApi?.manifest?.metadata?.defaultSettings?.fileBrowser ||
        "yazi"

    property string editTerminalCommand:
        pluginApi?.pluginSettings?.terminalCommand ||
        pluginApi?.manifest?.metadata?.defaultSettings?.terminalCommand ||
        "kitty"

    property bool editShowNotifications:
        pluginApi?.pluginSettings?.showNotifications ??
        pluginApi?.manifest?.metadata?.defaultSettings?.showNotifications ??
        true

    property bool editHideWhenEmpty:
        pluginApi?.pluginSettings?.hideWhenEmpty ??
        pluginApi?.manifest?.metadata?.defaultSettings?.hideWhenEmpty ??
        false

    property bool editShowBadge:
        pluginApi?.pluginSettings?.showBadge ??
        pluginApi?.manifest?.metadata?.defaultSettings?.showBadge ??
        true

    property string iconColor:
        pluginApi?.pluginSettings?.iconColor ??
        pluginApi?.manifest?.metadata?.defaultSettings?.iconColor ??
        "none"

    // ===== SAVE =====

    function saveSettings() {
        if (!pluginApi) return

        pluginApi.pluginSettings.autoMount          = root.editAutoMount
        pluginApi.pluginSettings.fileBrowser        = root.editFileBrowser
        pluginApi.pluginSettings.terminalCommand    = root.editTerminalCommand
        pluginApi.pluginSettings.showNotifications  = root.editShowNotifications
        pluginApi.pluginSettings.hideWhenEmpty      = root.editHideWhenEmpty
        pluginApi.pluginSettings.showBadge          = root.editShowBadge
        pluginApi.pluginSettings.iconColor          = root.iconColor

        pluginApi.saveSettings()
    }

    // ===== UI =====

    // ── Section: Bar Widget ───────────────────────────────────────────────────
    NText {
        text: pluginApi?.tr("settings.section-bar")
        pointSize: Style.fontSizeM
        font.weight: Font.Bold
        color: Color.mOnSurface
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.hide-when-empty")
        description: pluginApi?.tr("settings.hide-when-empty-desc")
        checked: root.editHideWhenEmpty
        onToggled: checked => {
            root.editHideWhenEmpty = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.show-badge")
        description: pluginApi?.tr("settings.show-badge-desc")
        checked: root.editShowBadge
        onToggled: checked => {
            root.editShowBadge = checked
            root.saveSettings()
        }
    }

    NDivider { Layout.fillWidth: true }

    // ── Section: Behavior ─────────────────────────────────────────────────────
    NText {
        text: pluginApi?.tr("settings.section-behavior")
        pointSize: Style.fontSizeM
        font.weight: Font.Bold
        color: Color.mOnSurface
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.auto-mount")
        description: pluginApi?.tr("settings.auto-mount-desc")
        checked: root.editAutoMount
        onToggled: checked => {
            root.editAutoMount = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.notifications")
        description: pluginApi?.tr("settings.notifications-desc")
        checked: root.editShowNotifications
        onToggled: checked => {
            root.editShowNotifications = checked
            root.saveSettings()
        }
    }

    NDivider { Layout.fillWidth: true }

    // ── Section: File Browser ─────────────────────────────────────────────────
    NText {
        text: pluginApi?.tr("settings.section-browser")
        pointSize: Style.fontSizeM
        font.weight: Font.Bold
        color: Color.mOnSurface
    }

    NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.file-browser")
        description: pluginApi?.tr("settings.file-browser-desc")
        model: [
            { key: "yazi",     name: "yazi" },
            { key: "ranger",   name: "ranger" },
            { key: "xdg-open", name: "xdg-open" },
            { key: "dolphin",  name: "dolphin" },
            { key: "thunar",   name: "thunar" },
            { key: "nautilus", name: "nautilus" }
        ]
        currentKey: root.editFileBrowser
        onSelected: key => {
            root.editFileBrowser = key
            root.saveSettings()
        }
    }

    NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.terminal")
        description: pluginApi?.tr("settings.terminal-desc")
        model: [
            { key: "kitty",      name: "kitty" },
            { key: "foot",       name: "foot" },
            { key: "alacritty",  name: "alacritty" },
            { key: "wezterm",    name: "wezterm" },
            { key: "ghostty",    name: "ghostty" }
        ]
        currentKey: root.editTerminalCommand
        onSelected: key => {
            root.editTerminalCommand = key
            root.saveSettings()
        }
    }
    NDivider {
        Layout.fillWidth: true
    }

    // Section: Colors
    NText {
        text: pluginApi?.tr("settings.icon-color")
        pointSize: Style.fontSizeM
        font.weight: Font.Bold
        color: Color.mOnSurface
    }
    NColorChoice {
        currentKey: root.iconColor
        description: pluginApi?.tr("settings.icon-color-desc")
        label: pluginApi?.tr("settings.icon-color")
        onSelected: key => root.iconColor = key
    }

    Item { Layout.fillHeight: true }
}
