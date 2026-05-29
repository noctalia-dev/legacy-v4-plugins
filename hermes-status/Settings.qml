import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})

  spacing: Style.marginM

  // statusScript
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXS

    NText {
      text: pluginApi?.tr("settings.statusScript") ?? "Status check script"
      font.pixelSize: Style.fontSizeS
      font.weight: Font.DemiBold
      color: Color.mOnSurface
    }

    NTextInput {
      Layout.fillWidth: true
      text: cfg.statusScript ?? pluginApi?.manifest?.metadata?.defaultSettings?.statusScript ?? ""
      placeholderText: "~/.config/noctalia/hermes-status-check"
      onEditingFinished: {
        pluginApi.setPluginSetting("statusScript", text);
      }
    }
  }

  // pollInterval
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXS

    NText {
      text: pluginApi?.tr("settings.pollInterval") ?? "Poll interval (seconds)"
      font.pixelSize: Style.fontSizeS
      font.weight: Font.DemiBold
      color: Color.mOnSurface
    }

    NSpinBox {
      Layout.fillWidth: true
      from: 5
      to: 300
      value: cfg.pollInterval ?? pluginApi?.manifest?.metadata?.defaultSettings?.pollInterval ?? 30
      onValueModified: {
        pluginApi.setPluginSetting("pollInterval", value);
      }
    }
  }

  // signalFile
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXS

    NText {
      text: pluginApi?.tr("settings.signalFile") ?? "Signal file"
      font.pixelSize: Style.fontSizeS
      font.weight: Font.DemiBold
      color: Color.mOnSurface
    }

    NTextInput {
      Layout.fillWidth: true
      text: cfg.signalFile ?? pluginApi?.manifest?.metadata?.defaultSettings?.signalFile ?? ""
      placeholderText: "~/.hermes/status_signal"
      onEditingFinished: {
        pluginApi.setPluginSetting("signalFile", text);
      }
    }
  }

  // hideWhenIdle
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.hideWhenIdle") ?? "Hide when idle"
    description: pluginApi?.tr("settings.hideWhenIdleDesc") ?? "Only show when gateway is offline, busy, or needs attention"
    checked: cfg.hideWhenIdle ?? pluginApi?.manifest?.metadata?.defaultSettings?.hideWhenIdle ?? false
    onToggled: checked => {
      pluginApi.setPluginSetting("hideWhenIdle", checked);
    }
    defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.hideWhenIdle ?? false
  }
}
