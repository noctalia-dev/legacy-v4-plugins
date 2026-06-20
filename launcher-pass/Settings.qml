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

  property string editStorePath: cfg.storePath ?? defaults.storePath ?? ""
  property string editTypeDelay: String(cfg.typeDelay ?? defaults.typeDelay ?? 500)
  property string editWtypeDelay: String(cfg.wtypeDelay ?? defaults.wtypeDelay ?? 12)
  property string editClipTimeout: cfg.clipTimeout ?? defaults.clipTimeout ?? ""

  readonly property string envClipTimeout: Quickshell.env("PASSWORD_STORE_CLIP_TIME") || ""

  spacing: Style.marginL

  NTabBar {
    id: tabBar
    Layout.fillWidth: true
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    NTabButton {
      text: pluginApi?.tr("settings.tab.general")
      tabIndex: 0
      checked: tabBar.currentIndex === 0
    }

    NTabButton {
      text: pluginApi?.tr("settings.tab.advanced")
      tabIndex: 1
      checked: tabBar.currentIndex === 1
    }
  }

  NTabView {
    id: tabView
    Layout.fillWidth: true
    Layout.fillHeight: true
    currentIndex: tabBar.currentIndex

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginL

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.storePath.label")
        description: pluginApi?.tr("settings.storePath.desc")
        text: root.editStorePath
        onTextChanged: root.editStorePath = text
      }

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.clipTimeout.label")
        description: pluginApi?.tr("settings.clipTimeout.desc", { value: root.envClipTimeout })
        text: root.editClipTimeout
        onTextChanged: root.editClipTimeout = text
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginL

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.typeDelay.label")
        description: pluginApi?.tr("settings.typeDelay.desc")
        text: root.editTypeDelay
        onTextChanged: root.editTypeDelay = text
      }

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.wtypeDelay.label")
        description: pluginApi?.tr("settings.wtypeDelay.desc")
        text: root.editWtypeDelay
        onTextChanged: root.editWtypeDelay = text
      }
    }
  }

  function saveSettings() {
    if (!pluginApi) return;
    pluginApi.pluginSettings.storePath = root.editStorePath;

    var typeDelayVal = parseFloat(root.editTypeDelay)
    pluginApi.pluginSettings.typeDelay = isNaN(typeDelayVal) || typeDelayVal < 0 ? 500 : typeDelayVal;

    var wtypeDelayVal = parseInt(root.editWtypeDelay)
    pluginApi.pluginSettings.wtypeDelay = isNaN(wtypeDelayVal) || wtypeDelayVal < 0 ? 12 : wtypeDelayVal;

    pluginApi.pluginSettings.clipTimeout = root.editClipTimeout;

    pluginApi.saveSettings();
  }
}
