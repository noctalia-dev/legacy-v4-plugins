import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings ?? ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

    property string editIconName: cfg.iconName ?? defaults.iconName ?? "rotate-cw"
    property bool editShowTransformInTooltip: cfg.showTransformInTooltip ?? defaults.showTransformInTooltip ?? true
    property bool editShowSuccessToast: cfg.showSuccessToast ?? defaults.showSuccessToast ?? true
    property bool editAutoTabletBarDensity: cfg.autoTabletBarDensity ?? defaults.autoTabletBarDensity ?? false
    property bool editExclusiveDockInTabletMode: cfg.exclusiveDockInTabletMode ?? defaults.exclusiveDockInTabletMode ?? false
    property bool editAutoRotateInTabletMode: cfg.autoRotateInTabletMode ?? defaults.autoRotateInTabletMode ?? false
    property bool editAutoRotateOutsideTabletMode: cfg.autoRotateOutsideTabletMode ?? defaults.autoRotateOutsideTabletMode ?? false
    property bool editSyncHyprTouchTransform: cfg.syncHyprTouchTransform ?? defaults.syncHyprTouchTransform ?? true
    property bool editFlipVerticalSensorOrientation: cfg.flipVerticalSensorOrientation ?? defaults.flipVerticalSensorOrientation ?? false
    property string editButtonBehavior: cfg.buttonBehavior ?? defaults.buttonBehavior ?? "toggle-auto-rotate-lock"
    property string editTabletBarDensity: cfg.tabletBarDensity ?? defaults.tabletBarDensity ?? "default"
    property bool autoRotateDependencyAvailable: true
    readonly property var barDensityModel: [
        { key: "mini",        name: pluginApi?.tr("settings.tabletBarDensity.options.mini") },
        { key: "compact",     name: pluginApi?.tr("settings.tabletBarDensity.options.compact") },
        { key: "default",     name: pluginApi?.tr("settings.tabletBarDensity.options.default") },
        { key: "comfortable", name: pluginApi?.tr("settings.tabletBarDensity.options.comfortable") },
        { key: "spacious",    name: pluginApi?.tr("settings.tabletBarDensity.options.spacious") }
    ]
    readonly property var buttonBehaviorModel: [
        { key: "toggle-auto-rotate-lock", name: pluginApi?.tr("settings.buttonBehavior.options.toggleAutoRotateLock") },
        { key: "manual-rotate", name: pluginApi?.tr("settings.buttonBehavior.options.manualRotate") }
    ]

    spacing: Style.marginL

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NLabel {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.iconName.label")
            description: pluginApi?.tr("settings.iconName.description")
        }

        NIcon {
            Layout.alignment: Qt.AlignVCenter
            icon: root.editIconName
            pointSize: Style.fontSizeXXL * 1.5
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NTextInput {
            Layout.fillWidth: true
            text: root.editIconName
            onEditingFinished: {
                root.editIconName = text.trim() !== "" ? text.trim() : "rotate-cw"
                root.saveSettings()
            }
        }

        NButton {
            text: pluginApi?.tr("settings.iconName.browseLibrary")
            onClicked: iconPicker.open()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.showTransformInTooltip.label")
        description: pluginApi?.tr("settings.showTransformInTooltip.description")
        checked: root.editShowTransformInTooltip
        onToggled: checked => {
            root.editShowTransformInTooltip = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.showSuccessToast.label")
        description: pluginApi?.tr("settings.showSuccessToast.description")
        checked: root.editShowSuccessToast
        onToggled: checked => {
            root.editShowSuccessToast = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.autoTabletBarDensity.label")
        description: pluginApi?.tr("settings.autoTabletBarDensity.description")
        checked: root.editAutoTabletBarDensity
        onToggled: checked => {
            root.editAutoTabletBarDensity = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.exclusiveDockInTabletMode.label")
        description: pluginApi?.tr("settings.exclusiveDockInTabletMode.description")
        checked: root.editExclusiveDockInTabletMode
        onToggled: checked => {
            root.editExclusiveDockInTabletMode = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.autoRotateInTabletMode.label")
        description: pluginApi?.tr("settings.autoRotateInTabletMode.description")
        checked: root.editAutoRotateInTabletMode
        onToggled: checked => {
            root.editAutoRotateInTabletMode = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        visible: root.editAutoRotateInTabletMode
        label: pluginApi?.tr("settings.autoRotateOutsideTabletMode.label")
        description: pluginApi?.tr("settings.autoRotateOutsideTabletMode.description")
        checked: root.editAutoRotateOutsideTabletMode
        onToggled: checked => {
            root.editAutoRotateOutsideTabletMode = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.syncHyprTouchTransform.label")
        description: pluginApi?.tr("settings.syncHyprTouchTransform.description")
        checked: root.editSyncHyprTouchTransform
        onToggled: checked => {
            root.editSyncHyprTouchTransform = checked
            root.saveSettings()
        }
    }

    NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.buttonBehavior.label")
        description: pluginApi?.tr("settings.buttonBehavior.description")
        model: root.buttonBehaviorModel
        currentKey: root.editButtonBehavior
        onSelected: key => {
            root.editButtonBehavior = key
            root.saveSettings()
        }
    }

    NLabel {
        Layout.fillWidth: true
        visible: !root.autoRotateDependencyAvailable
        label: pluginApi?.tr("settings.autoRotateDependency.label")
        description: pluginApi?.tr("settings.autoRotateDependency.description")
    }

    NToggle {
        Layout.fillWidth: true
        visible: root.editAutoRotateInTabletMode
        label: pluginApi?.tr("settings.flipVerticalSensorOrientation.label")
        description: pluginApi?.tr("settings.flipVerticalSensorOrientation.description")
        checked: root.editFlipVerticalSensorOrientation
        onToggled: checked => {
            root.editFlipVerticalSensorOrientation = checked
            root.saveSettings()
        }
    }

    NComboBox {
        Layout.fillWidth: true
        visible: root.editAutoTabletBarDensity
        label: pluginApi?.tr("settings.tabletBarDensity.label")
        description: pluginApi?.tr("settings.tabletBarDensity.description")
        model: root.barDensityModel
        currentKey: root.editTabletBarDensity
        onSelected: key => {
            root.editTabletBarDensity = key
            root.saveSettings()
        }
    }

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.iconName = root.editIconName
        pluginApi.pluginSettings.showTransformInTooltip = root.editShowTransformInTooltip
        pluginApi.pluginSettings.showSuccessToast = root.editShowSuccessToast
        pluginApi.pluginSettings.autoTabletBarDensity = root.editAutoTabletBarDensity
        pluginApi.pluginSettings.exclusiveDockInTabletMode = root.editExclusiveDockInTabletMode
        pluginApi.pluginSettings.autoRotateInTabletMode = root.editAutoRotateInTabletMode
        pluginApi.pluginSettings.autoRotateOutsideTabletMode = root.editAutoRotateOutsideTabletMode
        pluginApi.pluginSettings.syncHyprTouchTransform = root.editSyncHyprTouchTransform
        pluginApi.pluginSettings.flipVerticalSensorOrientation = root.editFlipVerticalSensorOrientation
        pluginApi.pluginSettings.buttonBehavior = root.editButtonBehavior
        pluginApi.pluginSettings.tabletBarDensity = root.editTabletBarDensity
        pluginApi.saveSettings()
    }

    Process {
        id: dependencyCheckProc
        command: ["sh", "-c", "command -v monitor-sensor >/dev/null 2>&1 && [ -x /usr/lib/iio-sensor-proxy ]"]
        onExited: (exitCode, exitStatus) => {
            root.autoRotateDependencyAvailable = exitCode === 0
        }
        Component.onCompleted: running = true
    }

    NIconPicker {
        id: iconPicker
        initialIcon: root.editIconName
        onIconSelected: iconName => {
            root.editIconName = iconName
            root.saveSettings()
        }
    }
}
