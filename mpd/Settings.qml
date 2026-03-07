import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string editLeftButton:           cfg.leftButton           ?? defaults.leftButton           ?? "next"
  property string editRightButton:          cfg.rightButton          ?? defaults.rightButton          ?? "toggle"
  property string editMiddleButton:         cfg.middleButton         ?? defaults.middleButton         ?? "shuffle"
  property bool   editShuffleStopsPlayback: cfg.shuffleStopsPlayback ?? defaults.shuffleStopsPlayback ?? true

  spacing: Style.marginL

  readonly property var actionModel: [
    { key: "next",    name: "Next track"      },
    { key: "prev",    name: "Previous track"  },
    { key: "toggle",  name: "Play / Pause"    },
    { key: "stop",    name: "Stop"            },
    { key: "shuffle", name: "Toggle ashuffle" },
    { key: "none",    name: "Do nothing"      },
  ]

  function saveSettings() {
    if (!pluginApi) return
    pluginApi.pluginSettings.leftButton   = root.editLeftButton
    pluginApi.pluginSettings.rightButton  = root.editRightButton
    pluginApi.pluginSettings.middleButton         = root.editMiddleButton
    pluginApi.pluginSettings.shuffleStopsPlayback = root.editShuffleStopsPlayback
    pluginApi.saveSettings()
  }

  // Mouse button actions
  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NComboBox {
      label: "Left click"
      description: "Action when left-clicking the widget"
      model: root.actionModel
      currentKey: root.editLeftButton
      onSelected: key => root.editLeftButton = key
    }

    NComboBox {
      label: "Right click"
      description: "Action when right-clicking the widget"
      model: root.actionModel
      currentKey: root.editRightButton
      onSelected: key => root.editRightButton = key
    }

    NComboBox {
      label: "Middle click"
      description: "Action when middle-clicking the widget"
      model: root.actionModel
      currentKey: root.editMiddleButton
      onSelected: key => root.editMiddleButton = key
    }

    NToggle {
      label: "Stop playback when disabling shuffle"
      description: "When toggling ashuffle off, also send mpc stop. Only applies to the \"Toggle ashuffle\" action."
      checked: root.editShuffleStopsPlayback
      onToggled: checked => root.editShuffleStopsPlayback = checked
    }
  }

}
