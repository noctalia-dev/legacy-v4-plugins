import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string editBindAddress: cfg.bindAddress ?? defaults.bindAddress ?? "127.0.0.1"
  property int editPort: Number(cfg.port ?? defaults.port ?? 55854)
  property string editToken: cfg.token ?? defaults.token ?? ""
  property int editPollIntervalSec: Number(cfg.pollIntervalSec ?? defaults.pollIntervalSec ?? 2)
  property bool editHideWhenEmpty: cfg.hideWhenEmpty ?? defaults.hideWhenEmpty ?? false

  spacing: Style.marginL

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.bindAddress.label")
    description: pluginApi?.tr("settings.bindAddress.desc")
    text: root.editBindAddress
    onTextChanged: root.editBindAddress = text
  }

  NSpinBox {
    label: pluginApi?.tr("settings.port.label")
    description: pluginApi?.tr("settings.port.desc")
    from: 1
    to: 65535
    value: root.editPort
    onValueChanged: root.editPort = value
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.token.label")
    description: pluginApi?.tr("settings.token.desc")
    text: root.editToken
    onTextChanged: root.editToken = text
  }

  NSpinBox {
    label: pluginApi?.tr("settings.pollInterval.label")
    description: pluginApi?.tr("settings.pollInterval.desc")
    from: 1
    to: 30
    value: root.editPollIntervalSec
    onValueChanged: root.editPollIntervalSec = value
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: hideToggle.implicitHeight

    NToggle {
      id: hideToggle
      anchors.fill: parent
      label: pluginApi?.tr("settings.hideWhenEmpty.label")
      description: pluginApi?.tr("settings.hideWhenEmpty.desc")
      checked: root.editHideWhenEmpty
      onToggled: checked => root.editHideWhenEmpty = checked
    }
  }

  function saveSettings() {
    if (!pluginApi) return

    pluginApi.pluginSettings.bindAddress = root.editBindAddress.trim() || "127.0.0.1"
    pluginApi.pluginSettings.port = root.editPort
    pluginApi.pluginSettings.token = root.editToken.trim()
    pluginApi.pluginSettings.pollIntervalSec = root.editPollIntervalSec
    pluginApi.pluginSettings.hideWhenEmpty = root.editHideWhenEmpty
    pluginApi.saveSettings()
    pluginApi.mainInstance?.restartService()
  }
}
