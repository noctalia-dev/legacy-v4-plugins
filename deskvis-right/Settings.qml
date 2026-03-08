import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    property var screen: null

    spacing: Style.marginM

    // ── Local state ───────────────────────────────────────────────────────────
    property string valueMode:            pluginApi?.pluginSettings?.mode            ?? "bars"
    property int    valueBarCount:        pluginApi?.pluginSettings?.barCount        ?? 32
    property int    valueFps:             pluginApi?.pluginSettings?.fps             ?? 60
    property real   valueSensitivity:     pluginApi?.pluginSettings?.sensitivity     ?? 1.5
    property real   valueSmoothing:       pluginApi?.pluginSettings?.smoothing       ?? 0.18
    property bool   valueUseGradient:     pluginApi?.pluginSettings?.useGradient     ?? true
    property bool   valueFadeWhenIdle:    pluginApi?.pluginSettings?.fadeWhenIdle    ?? true
    property bool   valueUseCustomColors: pluginApi?.pluginSettings?.useCustomColors ?? false
    property color  valueCustomPrimary:   pluginApi?.pluginSettings?.customPrimaryColor   ?? "#6750A4"
    property color  valueCustomSecondary: pluginApi?.pluginSettings?.customSecondaryColor ?? "#625B71"
    property int    valueCustomWidth:     pluginApi?.pluginSettings?.customWidth  ?? 0
    property int    valueCustomHeight:    pluginApi?.pluginSettings?.customHeight ?? 0

    // ── Header ────────────────────────────────────────────────────────────────
    NHeader {
        label: pluginApi?.manifest?.name ?? "DeskVis"
        description: "Audio visualizer settings"
    }

    // ── Visualizer mode ───────────────────────────────────────────────────────
    NComboBox {
        Layout.fillWidth: true
        label: "Visualizer Mode"
        description: "How the audio is displayed"
        model: [
            { "key": "bars",   "name": "Bars"   },
            { "key": "wave",   "name": "Wave"   },
            { "key": "mirror", "name": "Mirror" }
        ]
        currentKey: root.valueMode
        onSelected: key => root.valueMode = key
    }

    // ── Bar count (bars + mirror only) ────────────────────────────────────────
    NValueSlider {
        Layout.fillWidth: true
        visible: root.valueMode !== "wave"
        label: "Bar Count"
        value: root.valueBarCount
        from: 8
        to: 64
        stepSize: 1
        onMoved: value => root.valueBarCount = Math.round(value)
    }

    // ── Sensitivity ───────────────────────────────────────────────────────────
    NValueSlider {
        Layout.fillWidth: true
        label: "Sensitivity"
        value: root.valueSensitivity
        from: 0.5
        to: 3.0
        stepSize: 0.1
        onMoved: value => root.valueSensitivity = value
    }

    // ── Smoothing ─────────────────────────────────────────────────────────────
    NValueSlider {
        Layout.fillWidth: true
        label: "Smoothing"
        description: "Higher = slower decay"
        value: root.valueSmoothing
        from: 0.02
        to: 0.5
        stepSize: 0.01
        onMoved: value => root.valueSmoothing = value
    }

    // ── FPS ───────────────────────────────────────────────────────────────────
    NComboBox {
        Layout.fillWidth: true
        label: "Target FPS"
        model: [
            { "key": "24",  "name": "24 fps"  },
            { "key": "30",  "name": "30 fps"  },
            { "key": "60",  "name": "60 fps"  },
            { "key": "120", "name": "120 fps" },
            { "key": "144", "name": "144 fps" },
            { "key": "165", "name": "165 fps" },
            { "key": "180", "name": "180 fps" },
            { "key": "240", "name": "240 fps" }
        ]
        currentKey: String(root.valueFps)
        onSelected: key => root.valueFps = parseInt(key)
    }

    // ── Size ──────────────────────────────────────────────────────────────────
    NValueSlider {
        Layout.fillWidth: true
        label: "Custom Width"
        description: "0 = use default"
        value: root.valueCustomWidth
        from: 0
        to: 1920
        stepSize: 10
        onMoved: value => root.valueCustomWidth = Math.round(value)
    }

    NValueSlider {
        Layout.fillWidth: true
        label: "Custom Height"
        description: "0 = use default"
        value: root.valueCustomHeight
        from: 0
        to: 1080
        stepSize: 10
        onMoved: value => root.valueCustomHeight = Math.round(value)
    }

    // ── Toggles ───────────────────────────────────────────────────────────────
    NToggle {
        label: "Color Gradient"
        description: "Blend primary → secondary color"
        checked: root.valueUseGradient
        onToggled: checked => root.valueUseGradient = checked
    }

    NToggle {
        label: "Fade When Idle"
        description: "Fade out when no audio is playing"
        checked: root.valueFadeWhenIdle
        onToggled: checked => root.valueFadeWhenIdle = checked
    }

    NToggle {
        label: "Use Custom Colors"
        description: "Override theme colors with your own"
        checked: root.valueUseCustomColors
        onToggled: checked => root.valueUseCustomColors = checked
    }

    // ── Custom color pickers ──────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: root.valueUseCustomColors
        spacing: Style.marginM
        NText { text: "Primary Color"; Layout.fillWidth: true }
        NColorPicker {
            screen: Screen
            selectedColor: root.valueCustomPrimary
            onColorSelected: color => root.valueCustomPrimary = color
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.valueUseCustomColors
        spacing: Style.marginM
        NText { text: "Secondary Color"; Layout.fillWidth: true }
        NColorPicker {
            screen: Screen
            selectedColor: root.valueCustomSecondary
            onColorSelected: color => root.valueCustomSecondary = color
        }
    }

    // ── Save ──────────────────────────────────────────────────────────────────
    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.mode                = root.valueMode
        pluginApi.pluginSettings.barCount            = root.valueBarCount
        pluginApi.pluginSettings.fps                 = root.valueFps
        pluginApi.pluginSettings.sensitivity         = root.valueSensitivity
        pluginApi.pluginSettings.smoothing           = root.valueSmoothing
        pluginApi.pluginSettings.useGradient         = root.valueUseGradient
        pluginApi.pluginSettings.fadeWhenIdle        = root.valueFadeWhenIdle
        pluginApi.pluginSettings.useCustomColors     = root.valueUseCustomColors
        pluginApi.pluginSettings.customPrimaryColor   = root.valueCustomPrimary.toString()
        pluginApi.pluginSettings.customSecondaryColor = root.valueCustomSecondary.toString()
        pluginApi.pluginSettings.customWidth          = root.valueCustomWidth
        pluginApi.pluginSettings.customHeight         = root.valueCustomHeight
        pluginApi.saveSettings()
    }
}
