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
        { key: "mini",        name: "Mini" },
        { key: "compact",     name: "Compact" },
        { key: "default",     name: "Default" },
        { key: "comfortable", name: "Comfortable" },
        { key: "spacious",    name: "Spacious" }
    ]
    readonly property var buttonBehaviorModel: [
        { key: "toggle-auto-rotate-lock", name: "Toggle auto-rotate / lock rotation" },
        { key: "manual-rotate", name: "Rotate manually" }
    ]

    spacing: Style.marginL

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NLabel {
            Layout.fillWidth: true
            label: "Bar icon"
            description: "Tabler icon name used for the bar widget."
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
            text: "Browse Library"
            onClicked: iconPicker.open()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Show transform in tooltip"
        description: "Include the current rotation state in the bar widget tooltip."
        checked: root.editShowTransformInTooltip
        onToggled: checked => {
            root.editShowTransformInTooltip = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Show success toast"
        description: "Display a toast after a rotation command succeeds."
        checked: root.editShowSuccessToast
        onToggled: checked => {
            root.editShowSuccessToast = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Auto-switch bar density in tablet mode"
        description: "When tablet mode is active, switch Noctalia's bar density automatically."
        checked: root.editAutoTabletBarDensity
        onToggled: checked => {
            root.editAutoTabletBarDensity = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Use exclusive dock in tablet mode"
        description: "When tablet mode is active, enable the Noctalia dock if needed and switch it to exclusive mode."
        checked: root.editExclusiveDockInTabletMode
        onToggled: checked => {
            root.editExclusiveDockInTabletMode = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Auto-rotate screen in tablet mode"
        description: "Use monitor-sensor while tablet mode is active to rotate the internal display automatically."
        checked: root.editAutoRotateInTabletMode
        onToggled: checked => {
            root.editAutoRotateInTabletMode = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        visible: root.editAutoRotateInTabletMode
        label: "Allow auto-rotate outside tablet mode"
        description: "Keep sensor-based auto-rotation available even when tablet mode is not active."
        checked: root.editAutoRotateOutsideTabletMode
        onToggled: checked => {
            root.editAutoRotateOutsideTabletMode = checked
            root.saveSettings()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Hyprland: sync touchscreen transform"
        description: "After rotating a display on Hyprland, also rotate mapped touchscreen coordinates for matching touch devices."
        checked: root.editSyncHyprTouchTransform
        onToggled: checked => {
            root.editSyncHyprTouchTransform = checked
            root.saveSettings()
        }
    }

    NComboBox {
        Layout.fillWidth: true
        label: "Bar and Control Center button behavior"
        description: "Choose whether the main button toggles auto-rotate lock or rotates the display manually."
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
        label: "Auto-rotate requires iio-sensor-proxy"
        description: "Install iio-sensor-proxy so monitor-sensor and the sensor service are available for tablet-mode rotation."
    }

    NToggle {
        Layout.fillWidth: true
        visible: root.editAutoRotateInTabletMode
        label: "Flip vertical sensor orientation"
        description: "Swap left-up and right-up auto-rotate behavior for laptops whose sensor reports the portrait directions inverted."
        checked: root.editFlipVerticalSensorOrientation
        onToggled: checked => {
            root.editFlipVerticalSensorOrientation = checked
            root.saveSettings()
        }
    }

    NComboBox {
        Layout.fillWidth: true
        visible: root.editAutoTabletBarDensity
        label: "Tablet mode bar density"
        description: "Choose the Noctalia bar density to apply while tablet mode is active."
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
