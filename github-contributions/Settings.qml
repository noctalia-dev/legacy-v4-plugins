import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  property string editUsername: ""
  property string editToken: ""
  property string editLayout: "graph"
  property int editWeeksShown: 52
  property int editRefreshInterval: 60
  property bool editShowTotal: true
  property bool editShowLabels: true

  spacing: Style.marginM

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.username.label")
    description: pluginApi?.tr("settings.username.desc")
    placeholderText: "octocat"
    text: root.editUsername
    onTextChanged: root.editUsername = text
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.token.label")
    description: pluginApi?.tr("settings.token.desc")
    placeholderText: "ghp_xxxxxxxxxxxx"
    text: root.editToken
    onTextChanged: root.editToken = text
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    Layout.bottomMargin: Style.marginS
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.layout.label")
    description: pluginApi?.tr("settings.layout.desc")
    model: [
      { key: "graph", name: pluginApi?.tr("settings.layout.graph") },
      { key: "stats", name: pluginApi?.tr("settings.layout.stats") }
    ]
    currentKey: root.editLayout
    onSelected: key => root.editLayout = key
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.weeksShown.label")
      description: pluginApi?.tr("settings.weeksShown.desc", { "count": root.editWeeksShown })
    }

    NSlider {
      Layout.fillWidth: true
      from: 4
      to: 53
      stepSize: 1
      value: root.editWeeksShown
      onValueChanged: root.editWeeksShown = value
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.refreshInterval.label")
      description: pluginApi?.tr("settings.refreshInterval.desc", { "count": root.editRefreshInterval })
    }

    NSlider {
      Layout.fillWidth: true
      from: 15
      to: 360
      stepSize: 15
      value: root.editRefreshInterval
      onValueChanged: root.editRefreshInterval = value
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showTotal.label")
    description: pluginApi?.tr("settings.showTotal.desc")
    checked: root.editShowTotal
    onToggled: checked => root.editShowTotal = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showLabels.label")
    description: pluginApi?.tr("settings.showLabels.desc")
    checked: root.editShowLabels
    onToggled: checked => root.editShowLabels = checked
  }

  function saveSettings() {
    if (!pluginApi) return

    pluginApi.pluginSettings.username = root.editUsername.trim()
    pluginApi.pluginSettings.token = root.editToken.trim()
    pluginApi.pluginSettings.layout = root.editLayout
    pluginApi.pluginSettings.weeksShown = root.editWeeksShown
    pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval
    pluginApi.pluginSettings.showTotal = root.editShowTotal
    pluginApi.pluginSettings.showLabels = root.editShowLabels
    pluginApi.saveSettings()

    if (pluginApi.mainInstance)
      pluginApi.mainInstance.refresh()
  }

  Component.onCompleted: {
    var settings = pluginApi?.pluginSettings
    var defaults = pluginApi?.manifest?.metadata?.defaultSettings

    root.editUsername = settings?.username || defaults?.username || ""
    root.editToken = settings?.token || defaults?.token || ""
    root.editLayout = settings?.layout || defaults?.layout || "graph"
    root.editWeeksShown = settings?.weeksShown ?? defaults?.weeksShown ?? 52
    root.editRefreshInterval = settings?.refreshInterval ?? defaults?.refreshInterval ?? 60
    root.editShowTotal = settings?.showTotal ?? defaults?.showTotal ?? true
    root.editShowLabels = settings?.showLabels ?? defaults?.showLabels ?? true
  }
}
