import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string editIconColor: cfg.iconColor
        ?? defaults.iconColor ?? "primary"

    property string editHoverColor: cfg.hoverColor
        ?? defaults.hoverColor ?? "primary"

    property real editBtnWidth: cfg.buttonWidth
        ?? defaults.buttonWidth ?? 470

    property real editBtnHeight: cfg.buttonHeight
        ?? defaults.buttonHeight ?? 280

    property real editBtnSpacing: cfg.buttonSpacing
        ?? defaults.buttonSpacing ?? 20

    property real editBtnOpacity: cfg.buttonOpacity
        ?? defaults.buttonOpacity ?? 0.50

    property bool editUseOverlay: cfg.useOverlay
        ?? defaults.useOverlay ?? true

    property bool editAnimationsEnabled: cfg.animationsEnabled
        ?? defaults.animationsEnabled ?? true

    property bool editLockOnSuspend: cfg.lockOnSuspend
        ?? defaults.lockOnSuspend ?? true

    property real editHoverDesaturation: cfg.hoverDesaturation
        ?? defaults.hoverDesaturation ?? 0.0

    property real editOverlayBlur: cfg.overlayBlur
        ?? defaults.overlayBlur ?? 0.75

    property real editOverlayTint: cfg.overlayTint
        ?? defaults.overlayTint ?? 0.6

    property real editPanelTint: cfg.panelTint
        ?? defaults.panelTint ?? 0.7

    spacing: Style.marginM

    NText {
        text: pluginApi?.tr("header.title")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
    }

    NText {
        text: pluginApi?.tr("header.desc")
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        Layout.bottomMargin: Style.marginM
    }

    NDivider { Layout.fillWidth: true }

    NText {
        text: pluginApi?.tr("section.barButton")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
    }

    NColorChoice {
        label: pluginApi?.tr("settings.iconColor.label")
        description: pluginApi?.tr("settings.iconColor.desc")
        currentKey: root.editIconColor
        onSelected: key => { root.editIconColor = key; }
        defaultValue: defaults.iconColor || "primary"
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginS; Layout.bottomMargin: Style.marginS }

    NText {
        text: pluginApi?.tr("section.behavior")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.lockOnSuspend.label")
        description: pluginApi?.tr("settings.lockOnSuspend.desc")
        checked: root.editLockOnSuspend
        onToggled: checked => { root.editLockOnSuspend = checked; }
        defaultValue: defaults.lockOnSuspend ?? true
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginS; Layout.bottomMargin: Style.marginS }

    NText {
        text: pluginApi?.tr("section.buttons")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
    }

    NValueSlider {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.buttonWidth.label")
        from: 200; to: 500; stepSize: 10; snapAlways: true
        value: root.editBtnWidth
        text: root.editBtnWidth + "px"
        defaultValue: defaults.buttonWidth ?? 470
        showReset: true
        onMoved: v => { root.editBtnWidth = v; }
    }

    NValueSlider {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.buttonHeight.label")
        from: 150; to: 400; stepSize: 10; snapAlways: true
        value: root.editBtnHeight
        text: root.editBtnHeight + "px"
        defaultValue: defaults.buttonHeight ?? 280
        showReset: true
        onMoved: v => { root.editBtnHeight = v; }
    }

    NValueSlider {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.buttonSpacing.label")
        description: pluginApi?.tr("settings.buttonSpacing.desc")
        from: 10; to: 80; stepSize: 5; snapAlways: true
        value: root.editBtnSpacing
        text: root.editBtnSpacing + "px"
        defaultValue: defaults.buttonSpacing ?? 20
        showReset: true
        onMoved: v => { root.editBtnSpacing = v; }
    }

    NValueSlider {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.buttonOpacity.label")
        from: 0.1; to: 1.0; stepSize: 0.05; snapAlways: true
        value: root.editBtnOpacity
        text: Math.round(root.editBtnOpacity * 100) + "%"
        defaultValue: defaults.buttonOpacity ?? 0.50
        showReset: true
        onMoved: v => { root.editBtnOpacity = v; }
    }

    NColorChoice {
        label: pluginApi?.tr("settings.hoverColor.label")
        description: pluginApi?.tr("settings.hoverColor.desc")
        currentKey: root.editHoverColor
        onSelected: key => { root.editHoverColor = key; }
        defaultValue: defaults.hoverColor || "primary"
    }

    NValueSlider {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.hoverDesaturation.label")
        description: pluginApi?.tr("settings.hoverDesaturation.desc")
        from: 0; to: 85; stepSize: 5; snapAlways: true
        value: root.editHoverDesaturation * 100
        text: Math.round(root.editHoverDesaturation * 100) + "%"
        defaultValue: defaults.hoverDesaturation ?? 0.0
        showReset: true
        onMoved: v => { root.editHoverDesaturation = v / 100; }
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginS; Layout.bottomMargin: Style.marginS }

    NText {
        text: pluginApi?.tr("section.background")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.useOverlay.label")
        description: pluginApi?.tr("settings.useOverlay.desc")
        checked: root.editUseOverlay
        onToggled: checked => { root.editUseOverlay = checked; }
        defaultValue: defaults.useOverlay ?? true
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.editUseOverlay
        spacing: Style.marginM

        NValueSlider {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.overlayBlur.label")
            description: pluginApi?.tr("settings.overlayBlur.desc")
            from: 0.0; to: 1.0; stepSize: 0.05; snapAlways: true
            value: root.editOverlayBlur
            text: Math.round(root.editOverlayBlur * 100) + "%"
            defaultValue: defaults.overlayBlur ?? 0.75
            showReset: true
            onMoved: v => { root.editOverlayBlur = v; }
        }

        NValueSlider {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.overlayTint.label")
            description: pluginApi?.tr("settings.overlayTint.desc")
            from: 0.0; to: 1.0; stepSize: 0.05; snapAlways: true
            value: root.editOverlayTint
            text: Math.round(root.editOverlayTint * 100) + "%"
            defaultValue: defaults.overlayTint ?? 0.6
            showReset: true
            onMoved: v => { root.editOverlayTint = v; }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: !root.editUseOverlay
        spacing: Style.marginM

        NValueSlider {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.panelTint.label")
            description: pluginApi?.tr("settings.panelTint.desc")
            from: 0.0; to: 1.0; stepSize: 0.05; snapAlways: true
            value: root.editPanelTint
            text: Math.round(root.editPanelTint * 100) + "%"
            defaultValue: defaults.panelTint ?? 0.7
            showReset: true
            onMoved: v => { root.editPanelTint = v; }
        }
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginS; Layout.bottomMargin: Style.marginS }

    NText {
        text: pluginApi?.tr("section.animations")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.animationsEnabled.label")
        description: pluginApi?.tr("settings.animationsEnabled.desc")
        checked: root.editAnimationsEnabled
        onToggled: checked => { root.editAnimationsEnabled = checked; }
        defaultValue: defaults.animationsEnabled ?? true
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("Somnus", "Cannot save settings: pluginApi is null")
            return
        }
        pluginApi.pluginSettings.iconColor = root.editIconColor || "primary"
        pluginApi.pluginSettings.hoverColor = root.editHoverColor || "primary"
        pluginApi.pluginSettings.buttonWidth = root.editBtnWidth
        pluginApi.pluginSettings.buttonHeight = root.editBtnHeight
        pluginApi.pluginSettings.buttonSpacing = root.editBtnSpacing
        pluginApi.pluginSettings.buttonOpacity = root.editBtnOpacity
        pluginApi.pluginSettings.useOverlay = root.editUseOverlay
        pluginApi.pluginSettings.overlayBlur = root.editOverlayBlur
        pluginApi.pluginSettings.overlayTint = root.editOverlayTint
        pluginApi.pluginSettings.panelTint = root.editPanelTint
        pluginApi.pluginSettings.animationsEnabled = root.editAnimationsEnabled
        pluginApi.pluginSettings.lockOnSuspend = root.editLockOnSuspend
        pluginApi.pluginSettings.hoverDesaturation = root.editHoverDesaturation
        pluginApi.saveSettings()
        Logger.i("Somnus", "Settings saved successfully")
    }
}
