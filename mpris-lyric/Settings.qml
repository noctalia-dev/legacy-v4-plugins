import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL

  property var pluginApi: null

  // Shortcut to settings and defaults
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Editable settings
  property string editPlayerName: cfg.playerName || defaults.playerName || "musicfox"
  property int editUpdateInterval: cfg.updateInterval || defaults.updateInterval || 200
  property int editWidth: cfg.width || defaults.width || 300
  property bool editHideWhenInactive: cfg.hideWhenInactive ?? defaults.hideWhenInactive ?? true

  Component.onCompleted: {
    Logger.i("MprisLyric", "Settings UI loaded")
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("MprisLyric", "Cannot save: pluginApi is null")
      return
    }

    pluginApi.pluginSettings.playerName = root.editPlayerName
    pluginApi.pluginSettings.updateInterval = root.editUpdateInterval
    pluginApi.pluginSettings.width = root.editWidth
    pluginApi.pluginSettings.hideWhenInactive = root.editHideWhenInactive

    pluginApi.saveSettings()
    Logger.i("MprisLyric", "Settings saved successfully")
  }

  // Player name
  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.player-name")
    description: pluginApi?.tr("settings.player-name-desc")
    text: root.editPlayerName
    placeholderText: "musicfox"
    onTextChanged: root.editPlayerName = text
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    Layout.bottomMargin: Style.marginS
  }

  NToggle {
    label: pluginApi?.tr("settings.hide-when-inactive")
    description: pluginApi?.tr("settings.hide-when-inactive-desc")
    checked: root.editHideWhenInactive
    onToggled: checked => root.editHideWhenInactive = checked
  }

  // Update interval
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.update-interval", {
        value: root.editUpdateInterval
      })
      description: pluginApi?.tr("settings.update-interval-desc")
    }

    NSlider {
      Layout.fillWidth: true
      from: 50
      to: 500
      stepSize: 50
      value: root.editUpdateInterval
      onValueChanged: root.editUpdateInterval = value
    }
  }

  // Width
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.width", {
        value: root.editWidth
      })
      description: pluginApi?.tr("settings.width-desc")
    }

    NSlider {
      Layout.fillWidth: true
      from: 100
      to: 600
      stepSize: 50
      value: root.editWidth
      onValueChanged: root.editWidth = value
    }
  }

  Item {
    Layout.fillHeight: true
  }
}
