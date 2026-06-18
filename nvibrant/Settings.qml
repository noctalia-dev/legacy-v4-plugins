import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings ?? ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  spacing: Style.marginM

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.vibrance-value")
      description: pluginApi?.tr("settings.vibrance-value-desc")
    }

    NSpinBox {
      id: vibranceSpinBox
      from: 0
      to: 1023
      stepSize: 64
      value: root.cfg.vibranceValue ?? root.defaults.vibranceValue ?? 512
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.display-index")
      description: pluginApi?.tr("settings.display-index-desc")
    }

    NSpinBox {
      id: displayIndexSpinBox
      from: 1
      to: 8
      stepSize: 1
      value: root.cfg.displayIndex ?? root.defaults.displayIndex ?? 1
    }
  }

  function saveSettings() {
    if (!pluginApi) return
    pluginApi.pluginSettings.vibranceValue = vibranceSpinBox.value
    pluginApi.pluginSettings.displayIndex  = displayIndexSpinBox.value
    pluginApi.saveSettings()
  }
}
