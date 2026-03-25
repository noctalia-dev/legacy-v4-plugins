import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property real zoomAmount: cfg.zoomAmount ?? defaults.zoomAmount ?? 1.1
  property string parallaxDirection: cfg.parallaxDirection ?? defaults.parallaxDirection ?? "horizontal"
  property real hParallaxAmount: cfg.hParallaxAmount ?? defaults.hParallaxAmount ?? 50
  property int hParallaxDuration: cfg.hParallaxDuration ?? defaults.hParallaxDuration ?? 400
  property real vParallaxAmount: cfg.vParallaxAmount ?? defaults.vParallaxAmount ?? 50
  property int vParallaxDuration: cfg.vParallaxDuration ?? defaults.vParallaxDuration ?? 400
  property bool invertDirection: cfg.invertDirection ?? defaults.invertDirection ?? false
  property bool autoZoom: cfg.autoZoom ?? defaults.autoZoom ?? false
  property string parallaxEasing: cfg.parallaxEasing ?? defaults.parallaxEasing ?? "OutCubic"

  readonly property bool showHorizontal: parallaxDirection === "horizontal" || parallaxDirection === "both"
  readonly property bool showVertical: parallaxDirection === "vertical" || parallaxDirection === "both"

  spacing: Style.marginL

  // ── Wallpaper Zoom ──

  NValueSlider {
    label: pluginApi.tr("settings.zoom.label")
    description: pluginApi.tr("settings.zoom.desc")
    text: root.zoomAmount.toFixed(2) + "x"
    from: 1.00
    to: 2.00
    stepSize: 0.01
    value: root.zoomAmount
    defaultValue: root.defaults.zoomAmount
    showReset: true
    onMoved: val => {
      root.zoomAmount = val;
      root.saveSettings();
    }
  }

  NDivider { Layout.fillWidth: true }

  // ── Parallax Direction ──

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi.tr("settings.direction.label")
    description: pluginApi.tr("settings.direction.desc")
    defaultValue: root.defaults.parallaxDirection
    model: [
      { "key": "none", "name": pluginApi.tr("settings.direction.none") },
      { "key": "horizontal", "name": pluginApi.tr("settings.direction.horizontal") },
      { "key": "vertical", "name": pluginApi.tr("settings.direction.vertical") },
      { "key": "both", "name": pluginApi.tr("settings.direction.both") }
    ]
    currentKey: root.parallaxDirection
    onSelected: function(key) {
      root.parallaxDirection = key;
      root.saveSettings();
    }
  }

  // ── Horizontal Parallax Settings ──

  NDivider { Layout.fillWidth: true; visible: root.showHorizontal }

  NLabel {
    visible: root.showHorizontal
    label: pluginApi.tr("settings.horizontal.title")
  }

  NValueSlider {
    visible: root.showHorizontal
    label: pluginApi.tr("settings.horizontal.amount")
    text: Math.round(root.hParallaxAmount) + "px"
    from: 1
    to: 200
    stepSize: 1
    value: root.hParallaxAmount
    defaultValue: root.defaults.hParallaxAmount
    showReset: true
    onMoved: val => {
      root.hParallaxAmount = val;
      root.saveSettings();
    }
  }

  NValueSlider {
    visible: root.showHorizontal
    label: pluginApi.tr("settings.horizontal.duration")
    text: Math.round(root.hParallaxDuration) + "ms"
    from: 50
    to: 2000
    stepSize: 50
    value: root.hParallaxDuration
    defaultValue: root.defaults.hParallaxDuration
    showReset: true
    onMoved: val => {
      root.hParallaxDuration = val;
      root.saveSettings();
    }
  }

  // ── Vertical Parallax Settings ──

  NDivider { Layout.fillWidth: true; visible: root.showVertical }

  NLabel {
    visible: root.showVertical
    label: pluginApi.tr("settings.vertical.title")
  }

  NValueSlider {
    visible: root.showVertical
    label: pluginApi.tr("settings.vertical.amount")
    text: Math.round(root.vParallaxAmount) + "px"
    from: 1
    to: 200
    stepSize: 1
    value: root.vParallaxAmount
    defaultValue: root.defaults.vParallaxAmount
    showReset: true
    onMoved: val => {
      root.vParallaxAmount = val;
      root.saveSettings();
    }
  }

  NValueSlider {
    visible: root.showVertical
    label: pluginApi.tr("settings.vertical.duration")
    text: Math.round(root.vParallaxDuration) + "ms"
    from: 50
    to: 2000
    stepSize: 50
    value: root.vParallaxDuration
    defaultValue: root.defaults.vParallaxDuration
    showReset: true
    onMoved: val => {
      root.vParallaxDuration = val;
      root.saveSettings();
    }
  }

  // ── Invert Direction ──

  NDivider { Layout.fillWidth: true }

  NToggle {
    label: pluginApi.tr("settings.invert.label")
    description: pluginApi.tr("settings.invert.desc")
    defaultValue: root.defaults.invertDirection
    checked: root.invertDirection
    onToggled: checked => {
      root.invertDirection = checked;
      root.saveSettings();
    }
  }

  // ── Auto Zoom ──

  NDivider { Layout.fillWidth: true }

  NToggle {
    label: pluginApi.tr("settings.autoZoom.label")
    description: pluginApi.tr("settings.autoZoom.desc")
    defaultValue: root.defaults.autoZoom
    checked: root.autoZoom
    onToggled: checked => {
      root.autoZoom = checked;
      root.saveSettings();
    }
  }

  // ── Easing Curve ──

  NDivider { Layout.fillWidth: true }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi.tr("settings.easing.label")
    description: pluginApi.tr("settings.easing.desc")
    defaultValue: root.defaults.parallaxEasing
    model: [
      { "key": "Linear", "name": pluginApi.tr("settings.easing.linear") },
      { "key": "InQuad", "name": pluginApi.tr("settings.easing.inQuad") },
      { "key": "OutQuad", "name": pluginApi.tr("settings.easing.outQuad") },
      { "key": "InOutQuad", "name": pluginApi.tr("settings.easing.inOutQuad") },
      { "key": "InCubic", "name": pluginApi.tr("settings.easing.inCubic") },
      { "key": "OutCubic", "name": pluginApi.tr("settings.easing.outCubic") },
      { "key": "InOutCubic", "name": pluginApi.tr("settings.easing.inOutCubic") },
      { "key": "InQuart", "name": pluginApi.tr("settings.easing.inQuart") },
      { "key": "OutQuart", "name": pluginApi.tr("settings.easing.outQuart") },
      { "key": "InOutQuart", "name": pluginApi.tr("settings.easing.inOutQuart") },
      { "key": "InExpo", "name": pluginApi.tr("settings.easing.inExpo") },
      { "key": "OutExpo", "name": pluginApi.tr("settings.easing.outExpo") },
      { "key": "InOutExpo", "name": pluginApi.tr("settings.easing.inOutExpo") }
    ]
    currentKey: root.parallaxEasing
    onSelected: function(key) {
      root.parallaxEasing = key;
      root.saveSettings();
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("Parallax Wallpaper", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.zoomAmount = root.zoomAmount;
    pluginApi.pluginSettings.parallaxDirection = root.parallaxDirection;
    pluginApi.pluginSettings.hParallaxAmount = root.hParallaxAmount;
    pluginApi.pluginSettings.hParallaxDuration = root.hParallaxDuration;
    pluginApi.pluginSettings.vParallaxAmount = root.vParallaxAmount;
    pluginApi.pluginSettings.vParallaxDuration = root.vParallaxDuration;
    pluginApi.pluginSettings.invertDirection = root.invertDirection;
    pluginApi.pluginSettings.autoZoom = root.autoZoom;
    pluginApi.pluginSettings.parallaxEasing = root.parallaxEasing;

    pluginApi.saveSettings();
  }
}
