import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  function settingBool(key, fallback) {
    const s = pluginApi?.pluginSettings;
    return s && s[key] !== undefined ? !!s[key] : fallback;
  }

  property bool valueShowGpuUse: true
  property bool valueShowTempJunction: true
  property bool valueShowTempEdge: false
  property bool valueShowTempMemory: false
  property bool valueShowVram: true
  property bool valueShowVramActivity: false
  property bool valueShowFanSpeed: false
  property bool valueShowPower: true
  property bool valueShowSclk: true
  property bool valueShowMclk: true
  property bool valueShowFclk: false
  property bool valueShowSocclk: false
  property bool valueShowDcefclk: false
  property bool valueCompactMode: true
  property string valueIconColor: "primary"
  property string valueTextColor: "onSurface"
  property bool valueUseMonospaceFont: true
  property bool valueUsePadding: false

  property int valueDeviceIndex: 0

  spacing: Style.marginL

  Component.onCompleted: loadFromPluginSettings()

  function loadFromPluginSettings() {
    const d = defaults;
    valueShowGpuUse = settingBool("showGpuUse", d.showGpuUse ?? true);
    valueShowTempJunction = settingBool("showTempJunction", d.showTempJunction ?? true);
    valueShowTempEdge = settingBool("showTempEdge", d.showTempEdge ?? false);
    valueShowTempMemory = settingBool("showTempMemory", d.showTempMemory ?? false);
    valueShowVram = settingBool("showVram", d.showVram ?? true);
    valueShowVramActivity = settingBool("showVramActivity", d.showVramActivity ?? false);
    valueShowFanSpeed = settingBool("showFanSpeed", d.showFanSpeed ?? false);
    valueShowPower = settingBool("showPower", d.showPower ?? true);
    valueShowSclk = settingBool("showSclk", d.showSclk ?? true);
    valueShowMclk = settingBool("showMclk", d.showMclk ?? true);
    valueShowFclk = settingBool("showFclk", d.showFclk ?? false);
    valueShowSocclk = settingBool("showSocclk", d.showSocclk ?? false);
    valueShowDcefclk = settingBool("showDcefclk", d.showDcefclk ?? false);

    valueCompactMode = settingBool("compactMode", d.compactMode ?? true);
    valueIconColor = pluginApi?.pluginSettings?.iconColor ?? d.iconColor ?? "primary";
    valueTextColor = pluginApi?.pluginSettings?.textColor ?? d.textColor ?? "onSurface";
    valueUseMonospaceFont = settingBool("useMonospaceFont", d.useMonospaceFont ?? true);
    valueUsePadding = settingBool("usePadding", d.usePadding ?? false);

    valueDeviceIndex = pluginApi?.pluginSettings?.deviceIndex ?? d.deviceIndex ?? 0;
  }

  NText {
    text: pluginApi?.tr("settings.bar_section")
    pointSize: Style.fontSizeL
    font.weight: Font.Bold
    color: Color.mOnSurface
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.compact_mode_label")
    description: pluginApi?.tr("settings.compact_mode_description")
    checked: root.valueCompactMode
    onToggled: checked => root.valueCompactMode = checked
    defaultValue: defaults.compactMode ?? true
  }

  NColorChoice {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.icon_color_label")
    currentKey: root.valueIconColor
    onSelected: key => root.valueIconColor = key
    defaultValue: defaults.iconColor ?? "primary"
  }

  NColorChoice {
    Layout.fillWidth: true
    currentKey: root.valueTextColor
    onSelected: key => root.valueTextColor = key
    visible: !root.valueCompactMode
    defaultValue: defaults.textColor ?? "onSurface"
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.monospace_font_label")
    description: pluginApi?.tr("settings.monospace_font_description")
    checked: root.valueUseMonospaceFont
    onToggled: checked => root.valueUseMonospaceFont = checked
    visible: !root.valueCompactMode
    defaultValue: defaults.useMonospaceFont ?? true
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.use_padding_label")
    description: pluginApi?.tr("settings.use_padding_description")
    checked: root.valueUsePadding && root.valueUseMonospaceFont
    onToggled: checked => root.valueUsePadding = checked
    visible: !root.valueCompactMode
    enabled: root.valueUseMonospaceFont
    defaultValue: defaults.usePadding ?? false
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
  }

  NText {
    text: pluginApi?.tr("settings.metrics_section")
    pointSize: Style.fontSizeL
    font.weight: Font.Bold
    color: Color.mOnSurface
  }

  NText {
    text: pluginApi?.tr("settings.metrics_description")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.gpu_use")
    checked: root.valueShowGpuUse
    onToggled: checked => root.valueShowGpuUse = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.temp_junction")
    checked: root.valueShowTempJunction
    onToggled: checked => root.valueShowTempJunction = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.temp_edge")
    checked: root.valueShowTempEdge
    onToggled: checked => root.valueShowTempEdge = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.temp_memory")
    checked: root.valueShowTempMemory
    onToggled: checked => root.valueShowTempMemory = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.vram")
    checked: root.valueShowVram
    onToggled: checked => root.valueShowVram = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.vram_activity")
    checked: root.valueShowVramActivity
    onToggled: checked => root.valueShowVramActivity = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.fan_speed")
    checked: root.valueShowFanSpeed
    onToggled: checked => root.valueShowFanSpeed = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.power")
    checked: root.valueShowPower
    onToggled: checked => root.valueShowPower = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.sclk")
    checked: root.valueShowSclk
    onToggled: checked => root.valueShowSclk = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.mclk")
    checked: root.valueShowMclk
    onToggled: checked => root.valueShowMclk = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.fclk")
    checked: root.valueShowFclk
    onToggled: checked => root.valueShowFclk = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.socclk")
    checked: root.valueShowSocclk
    onToggled: checked => root.valueShowSocclk = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("metrics.dcefclk")
    checked: root.valueShowDcefclk
    onToggled: checked => root.valueShowDcefclk = checked
  }
  NText {
    text: pluginApi?.tr("settings.display_section")
    pointSize: Style.fontSizeL
    font.weight: Font.Bold
    color: Color.mOnSurface
    Layout.topMargin: Style.marginL
  }

  NSpinBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.device_index")
    description: pluginApi?.tr("settings.device_index_description")
    from: 0
    to: 7
    value: root.valueDeviceIndex
    onValueChanged: root.valueDeviceIndex = value
  }

  function saveSettings() {
    if (!pluginApi)
      return;

    const s = pluginApi.pluginSettings;
    s.compactMode = root.valueCompactMode;
    s.iconColor = root.valueIconColor;
    s.textColor = root.valueTextColor;
    s.useMonospaceFont = root.valueUseMonospaceFont;
    s.usePadding = root.valueUsePadding;

    s.showGpuUse = root.valueShowGpuUse;
    s.showTempJunction = root.valueShowTempJunction;
    s.showTempEdge = root.valueShowTempEdge;
    s.showTempMemory = root.valueShowTempMemory;
    s.showVram = root.valueShowVram;
    s.showVramActivity = root.valueShowVramActivity;
    s.showFanSpeed = root.valueShowFanSpeed;
    s.showPower = root.valueShowPower;
    s.showSclk = root.valueShowSclk;
    s.showMclk = root.valueShowMclk;
    s.showFclk = root.valueShowFclk;
    s.showSocclk = root.valueShowSocclk;
    s.showDcefclk = root.valueShowDcefclk;
    s.deviceIndex = root.valueDeviceIndex;

    pluginApi.saveSettings();
    if (mainInstance)
      mainInstance.refreshNow();
    Logger.i("AmdGpuMonitor", "Settings saved");
  }
}

