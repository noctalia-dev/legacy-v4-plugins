import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
ColumnLayout {
  id: root
  property var pluginApi: null
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property string editLeftButton:  cfg.leftButton  ?? defaults.leftButton  ?? "toggle"
  property string editRightButton: cfg.rightButton ?? defaults.rightButton ?? "next"
  property string editMiddleButton: cfg.middleButton ?? defaults.middleButton ?? "prev"
  spacing: Style.marginL
  readonly property var actionModel: [
    { key: "next",   name: "Next track"     },
    { key: "prev",   name: "Previous track" },
    { key: "toggle", name: "Play / Pause"   },
    { key: "stop",   name: "Stop"           },
  ]
  function saveSettings() {
    if (!pluginApi) return
    pluginApi.pluginSettings.leftButton  = root.editLeftButton
    pluginApi.pluginSettings.rightButton = root.editRightButton
    pluginApi.pluginSettings.middleButton = root.editMiddleButton
    pluginApi.saveSettings()
  }
  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true
    NComboBox {
      label: pluginApi?.tr("settings.left-click")
      description: pluginApi?.tr("settings.left-click-desc")
      model: root.actionModel
      currentKey: root.editLeftButton
      onSelected: key => root.editLeftButton = key
    }
    NComboBox {
      label: pluginApi?.tr("settings.right-click")
      description: pluginApi?.tr("settings.right-click-desc")
      model: root.actionModel
      currentKey: root.editRightButton
      onSelected: key => root.editRightButton = key
    }
    NComboBox {
      label: pluginApi?.tr("settings.middle-click")
      description: pluginApi?.tr("settings.middle-click-desc")
      model: root.actionModel
      currentKey: root.editMiddleButton
      onSelected: key => root.editMiddleButton = key
    }
  }
}