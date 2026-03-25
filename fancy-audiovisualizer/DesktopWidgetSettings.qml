import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var widgetSettings: null
  property var screen: null

  spacing: Style.marginM

  // Local state for editing
  property real valueSensitivity: widgetSettings?.data?.sensitivity ?? pluginApi?.pluginSettings?.sensitivity ?? 1.5
  property real valueRotationSpeed: widgetSettings?.data?.rotationSpeed ?? pluginApi?.pluginSettings?.rotationSpeed ?? 0.5
  property real valueBarWidth: widgetSettings?.data?.barWidth ?? pluginApi?.pluginSettings?.barWidth ?? 0.6
  property real valueRingOpacity: widgetSettings?.data?.ringOpacity ?? pluginApi?.pluginSettings?.ringOpacity ?? 0.8
  property real valueBloomIntensity: widgetSettings?.data?.bloomIntensity ?? pluginApi?.pluginSettings?.bloomIntensity ?? 0.5
  property int valueVisualizationMode: widgetSettings?.data?.visualizationMode ?? pluginApi?.pluginSettings?.visualizationMode ?? 3
  property real valueWaveThickness: widgetSettings?.data?.waveThickness ?? pluginApi?.pluginSettings?.waveThickness ?? 1.0
  property real valueInnerDiameter: widgetSettings?.data?.innerDiameter ?? pluginApi?.pluginSettings?.innerDiameter ?? 0.7
  property bool valueFadeWhenIdle: widgetSettings?.data?.fadeWhenIdle ?? pluginApi?.pluginSettings?.fadeWhenIdle ?? true
  property bool valueUseCustomColors: widgetSettings?.data?.useCustomColors ?? pluginApi?.pluginSettings?.useCustomColors ?? false
  property color valueCustomPrimaryColor: widgetSettings?.data?.customPrimaryColor ?? pluginApi?.pluginSettings?.customPrimaryColor ?? "#6750A4"
  property color valueCustomSecondaryColor: widgetSettings?.data?.customSecondaryColor ?? pluginApi?.pluginSettings?.customSecondaryColor ?? "#625B71"

  // Mode helpers
  readonly property bool modeHasBars: valueVisualizationMode === 0 || valueVisualizationMode === 3 || valueVisualizationMode === 5
  readonly property bool modeHasWave: valueVisualizationMode === 1 || valueVisualizationMode === 4 || valueVisualizationMode === 5
  readonly property bool modeHasRings: valueVisualizationMode >= 2

  NHeader {
    label: pluginApi?.tr("settings.title") ?? "Visualizer Settings"
    description: pluginApi?.tr("settings.description") ?? "Configure the audio visualizer appearance"
  }

  // Visualization mode selector
  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.visualizationMode") ?? "Visualization Mode"
    description: pluginApi?.tr("settings.visualizationMode-description") ?? "Choose visualization style"
    model: [
      {"key": "0", "name": pluginApi?.tr("settings.mode.bars") ?? "Bars"},
      {"key": "1", "name": pluginApi?.tr("settings.mode.wave") ?? "Wave"},
      {"key": "2", "name": pluginApi?.tr("settings.mode.rings") ?? "Rings"},
      {"key": "3", "name": pluginApi?.tr("settings.mode.barsRings") ?? "Bars + Rings"},
      {"key": "4", "name": pluginApi?.tr("settings.mode.waveRings") ?? "Wave + Rings"},
      {"key": "5", "name": pluginApi?.tr("settings.mode.all") ?? "All"}
    ]
    currentKey: String(root.valueVisualizationMode)
    onSelected: key => {
      root.valueVisualizationMode = parseInt(key);
      root.saveSettings();
    }
  }

  // Wave thickness slider (shown when mode includes wave)
  NValueSlider {
    Layout.fillWidth: true
    visible: root.modeHasWave
    label: pluginApi?.tr("settings.waveThickness") ?? "Wave Thickness"
    value: root.valueWaveThickness
    from: 0.3
    to: 2.0
    stepSize: 0.1
    onMoved: value => {
      root.valueWaveThickness = value;
      root.saveSettings();
    }
  }

  // Sensitivity slider
  NValueSlider {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.sensitivity") ?? "Sensitivity"
    value: root.valueSensitivity
    from: 0.5
    to: 3.0
    stepSize: 0.1
    onMoved: value => {
      root.valueSensitivity = value;
      root.saveSettings();
    }
  }

  // Rotation speed slider
  NValueSlider {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.rotationSpeed") ?? "Rotation Speed"
    value: root.valueRotationSpeed
    from: 0.0
    to: 2.0
    stepSize: 0.1
    onMoved: value => {
      root.valueRotationSpeed = value;
      root.saveSettings();
    }
  }

  // Bar width slider (shown when mode includes bars)
  NValueSlider {
    Layout.fillWidth: true
    visible: root.modeHasBars
    label: pluginApi?.tr("settings.barWidth") ?? "Bar Width"
    value: root.valueBarWidth
    from: 0.2
    to: 1.0
    stepSize: 0.1
    onMoved: value => {
      root.valueBarWidth = value;
      root.saveSettings();
    }
  }

  // Ring opacity slider (shown when mode includes rings)
  NValueSlider {
    Layout.fillWidth: true
    visible: root.modeHasRings
    label: pluginApi?.tr("settings.ringOpacity") ?? "Ring Opacity"
    value: root.valueRingOpacity
    from: 0.0
    to: 1.0
    stepSize: 0.1
    onMoved: value => {
      root.valueRingOpacity = value;
      root.saveSettings();
    }
  }

  // Base diameter slider
  NValueSlider {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.innerDiameter") ?? "Inner Diameter"
    value: root.valueInnerDiameter
    from: 0
    to: 1
    stepSize: 0.05
    onMoved: value => {
      root.valueInnerDiameter = value;
      root.saveSettings();
    }
  }

  // Bloom intensity slider
  NValueSlider {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.bloomIntensity") ?? "Bloom Intensity"
    value: root.valueBloomIntensity
    from: 0.0
    to: 1.0
    stepSize: 0.05
    onMoved: value => {
      root.valueBloomIntensity = value;
      root.saveSettings();
    }
  }

  // Fade when idle toggle
  NToggle {
    label: pluginApi?.tr("settings.fadeWhenIdle") ?? "Fade When Idle"
    description: pluginApi?.tr("settings.fadeWhenIdle-description") ?? "Fade out visualizer when no audio is playing"
    checked: root.valueFadeWhenIdle
    onToggled: checked => {
      root.valueFadeWhenIdle = checked;
      root.saveSettings();
    }
  }

  // Use custom colors toggle
  NToggle {
    label: pluginApi?.tr("settings.useCustomColors") ?? "Use Custom Colors"
    description: pluginApi?.tr("settings.useCustomColors-description") ?? "Override theme colors with custom colors"
    checked: root.valueUseCustomColors
    onToggled: checked => {
      root.valueUseCustomColors = checked;
      root.saveSettings();
    }
  }

  // Custom primary color picker
  RowLayout {
    Layout.fillWidth: true
    visible: root.valueUseCustomColors
    spacing: Style.marginM

    NText {
      text: pluginApi?.tr("settings.customPrimaryColor") ?? "Primary Color"
      Layout.fillWidth: true
    }

    NColorPicker {
      screen: Screen
      selectedColor: root.valueCustomPrimaryColor
      onColorSelected: color => {
        root.valueCustomPrimaryColor = color;
        root.saveSettings();
      }
    }
  }

  // Custom secondary color picker
  RowLayout {
    Layout.fillWidth: true
    visible: root.valueUseCustomColors
    spacing: Style.marginM

    NText {
      text: pluginApi?.tr("settings.customSecondaryColor") ?? "Secondary Color"
      Layout.fillWidth: true
    }

    NColorPicker {
      screen: Screen
      selectedColor: root.valueCustomSecondaryColor
      onColorSelected: color => {
        root.valueCustomSecondaryColor = color;
        root.saveSettings();
      }
    }
  }

  // Called when user clicks Apply/Save
  function saveSettings() {
    if (!widgetSettings)
      return;

    widgetSettings.data.sensitivity = root.valueSensitivity;
    widgetSettings.data.rotationSpeed = root.valueRotationSpeed;
    widgetSettings.data.barWidth = root.valueBarWidth;
    widgetSettings.data.ringOpacity = root.valueRingOpacity;
    widgetSettings.data.bloomIntensity = root.valueBloomIntensity;
    widgetSettings.data.visualizationMode = root.valueVisualizationMode;
    widgetSettings.data.waveThickness = root.valueWaveThickness;
    widgetSettings.data.innerDiameter = root.valueInnerDiameter;
    widgetSettings.data.fadeWhenIdle = root.valueFadeWhenIdle;
    widgetSettings.data.useCustomColors = root.valueUseCustomColors;
    widgetSettings.data.customPrimaryColor = root.valueCustomPrimaryColor.toString();
    widgetSettings.data.customSecondaryColor = root.valueCustomSecondaryColor.toString();

    widgetSettings.save();
  }
}
