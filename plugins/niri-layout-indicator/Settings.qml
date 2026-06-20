import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var pluginApi: null

  property string displayModeValue: pluginApi?.pluginSettings?.displayMode ?? "text"
  property string middleClickActionValue: pluginApi?.pluginSettings?.middleClickAction ?? "previous"
  property int pollIntervalMsValue: pluginApi?.pluginSettings?.pollIntervalMs ?? 750

  function tr(key) {
    return pluginApi?.tr(key) || key
  }

  function saveSettings() {
    if (!pluginApi || !pluginApi.pluginSettings)
      return

    pluginApi.pluginSettings.displayMode = root.displayModeValue
    pluginApi.pluginSettings.middleClickAction = root.middleClickActionValue
    pluginApi.pluginSettings.pollIntervalMs = root.pollIntervalMsValue

    pluginApi.saveSettings()
  }

  NText {
    Layout.fillWidth: true
    text: root.tr("settings.title")
    pointSize: Style.fontSizeXXL
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NText {
    Layout.fillWidth: true
    text: root.tr("settings.description")
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeM
    wrapMode: Text.WordWrap
  }

  NComboBox {
    label: root.tr("settings.display.title")
    description: root.tr("settings.display.description")
    minimumWidth: 260

    model: [
      { "key": "text", "name": root.tr("settings.display.text") },
      { "key": "flag", "name": root.tr("settings.display.flag") }
    ]

    currentKey: root.displayModeValue

    onSelected: key => {
      root.displayModeValue = key
    }
  }

  NComboBox {
    label: root.tr("settings.middle.title")
    description: root.tr("settings.middle.description")
    minimumWidth: 280

    model: [
      { "key": "previous", "name": root.tr("settings.middle.previous") },
      { "key": "toggle-mode", "name": root.tr("settings.middle.toggle_display") }
    ]

    currentKey: root.middleClickActionValue

    onSelected: key => {
      root.middleClickActionValue = key
    }
  }

  NComboBox {
    label: root.tr("settings.update.title")
    description: root.tr("settings.update.description")
    minimumWidth: 180

    model: [
      { "key": "250", "name": "250 ms" },
      { "key": "500", "name": "500 ms" },
      { "key": "750", "name": "750 ms" },
      { "key": "1000", "name": "1000 ms" },
      { "key": "1500", "name": "1500 ms" }
    ]

    currentKey: root.pollIntervalMsValue.toString()

    onSelected: key => {
      root.pollIntervalMsValue = parseInt(key)
    }
  }

  Item {
    Layout.fillHeight: true
  }
}
