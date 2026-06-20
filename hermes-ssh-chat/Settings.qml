import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property string valueHost: cfg.host ?? defaults.host ?? ""
  property int valuePort: cfg.port ?? defaults.port ?? 22
  property string valueUser: cfg.user ?? defaults.user ?? ""
  property bool valueRememberLastTarget: cfg.rememberLastTarget ?? defaults.rememberLastTarget ?? true
  property bool valueAutoConnectOnStartup: cfg.autoConnectOnStartup ?? defaults.autoConnectOnStartup ?? false
  property int valuePanelWidth: cfg.panelWidth ?? defaults.panelWidth ?? 1200
  property int valuePanelHeight: cfg.panelHeight ?? defaults.panelHeight ?? 760
  property int valueTerminalCols: cfg.terminalCols ?? defaults.terminalCols ?? 180
  property int valueTerminalRows: cfg.terminalRows ?? defaults.terminalRows ?? 32
  property int valueTerminalFontSize: cfg.terminalFontSize ?? defaults.terminalFontSize ?? 11
  property bool valueShowBarText: cfg.showBarText ?? defaults.showBarText ?? true
  property string valueToggleShortcutName: cfg.toggleShortcutName ?? defaults.toggleShortcutName ?? "hermes-toggle"

  function saveSettings() {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.host = root.valueHost;
    pluginApi.pluginSettings.port = root.valuePort;
    pluginApi.pluginSettings.user = root.valueUser;
    pluginApi.pluginSettings.rememberLastTarget = root.valueRememberLastTarget;
    pluginApi.pluginSettings.autoConnectOnStartup = root.valueAutoConnectOnStartup;
    pluginApi.pluginSettings.panelWidth = root.valuePanelWidth;
    pluginApi.pluginSettings.panelHeight = root.valuePanelHeight;
    pluginApi.pluginSettings.terminalCols = root.valueTerminalCols;
    pluginApi.pluginSettings.terminalRows = root.valueTerminalRows;
    pluginApi.pluginSettings.terminalFontSize = root.valueTerminalFontSize;
    pluginApi.pluginSettings.showBarText = root.valueShowBarText;
    pluginApi.pluginSettings.toggleShortcutName = root.valueToggleShortcutName;
    pluginApi.saveSettings();
  }

  spacing: Style.marginL

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.host.label")
    description: pluginApi?.tr("settings.host.desc")
    placeholderText: pluginApi?.tr("settings.host.placeholder")
    text: root.valueHost
    onTextChanged: root.valueHost = text
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.user.label")
    placeholderText: pluginApi?.tr("settings.user.placeholder")
    text: root.valueUser
    onTextChanged: root.valueUser = text
  }

  NSpinBox {
    label: pluginApi?.tr("settings.port.label")
    from: 1
    to: 65535
    stepSize: 1
    value: root.valuePort
    onValueChanged: root.valuePort = value
  }

  NSpinBox {
    label: pluginApi?.tr("settings.panelWidth.label")
    description: pluginApi?.tr("settings.panelWidth.desc")
    from: 720
    to: 1800
    stepSize: 20
    value: root.valuePanelWidth
    onValueChanged: root.valuePanelWidth = value
  }

  NSpinBox {
    label: pluginApi?.tr("settings.panelHeight.label")
    description: pluginApi?.tr("settings.panelHeight.desc")
    from: 560
    to: 1200
    stepSize: 20
    value: root.valuePanelHeight
    onValueChanged: root.valuePanelHeight = value
  }

  NSpinBox {
    label: pluginApi?.tr("settings.terminalCols.label")
    from: 80
    to: 240
    stepSize: 5
    value: root.valueTerminalCols
    onValueChanged: root.valueTerminalCols = value
  }

  NSpinBox {
    label: pluginApi?.tr("settings.terminalRows.label")
    from: 20
    to: 80
    stepSize: 1
    value: root.valueTerminalRows
    onValueChanged: root.valueTerminalRows = value
  }

  NSpinBox {
    label: pluginApi?.tr("settings.terminalFontSize.label")
    from: 8
    to: 20
    stepSize: 1
    value: root.valueTerminalFontSize
    onValueChanged: root.valueTerminalFontSize = value
  }

  NToggle {
    label: pluginApi?.tr("settings.autoConnectOnStartup.label")
    checked: root.valueAutoConnectOnStartup
    onToggled: checked => root.valueAutoConnectOnStartup = checked
  }

  NToggle {
    label: pluginApi?.tr("settings.rememberLastTarget.label")
    checked: root.valueRememberLastTarget
    onToggled: checked => root.valueRememberLastTarget = checked
  }

  NToggle {
    label: pluginApi?.tr("settings.showBarText.label")
    checked: root.valueShowBarText
    onToggled: checked => root.valueShowBarText = checked
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.toggleShortcut.label")
    description: pluginApi?.tr("settings.toggleShortcut.desc", { name: root.valueToggleShortcutName })
    placeholderText: "hermes-toggle"
    text: root.valueToggleShortcutName
    onTextChanged: root.valueToggleShortcutName = text
  }
}
