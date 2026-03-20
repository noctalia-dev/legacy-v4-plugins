import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property bool editCustomizeText: cfg.customizeText ?? defaults.customizeText ?? false
  property string editFirstLine: cfg.firstLine ?? defaults.firstLine ?? ""
  property string editSecondLine: cfg.secondLine ?? defaults.secondLine ?? ""
  property int editFirstLineSize: cfg.firstLineSize ?? defaults.firstLineSize ?? 22
  property int editSecondLineSize: cfg.secondLineSize ?? defaults.secondLineSize ?? 14
  property int editMarginRight: cfg.marginRight ?? defaults.marginRight ?? 50
  property int editMarginBottom: cfg.marginBottom ?? defaults.marginBottom ?? 50

  spacing: Style.marginM

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.customizeText.label")
    description: pluginApi?.tr("settings.customizeText.desc")
    checked: root.editCustomizeText
    onToggled: checked => root.editCustomizeText = checked
  }

  NTextInput {
    visible: root.editCustomizeText
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.firstLine.label")
    placeholderText: pluginApi?.tr("settings.firstLine.placeholder")
    text: root.editFirstLine
    onTextChanged: root.editFirstLine = text
  }

  NTextInput {
    visible: root.editCustomizeText
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.secondLine.label")
    placeholderText: pluginApi?.tr("settings.secondLine.placeholder")
    text: root.editSecondLine
    onTextChanged: root.editSecondLine = text
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.firstLineSize.label")
      description: pluginApi?.tr("settings.firstLineSize.desc", { value: root.editFirstLineSize })
    }

    NSlider {
      from: 8
      to: 72
      value: root.editFirstLineSize
      stepSize: 1
      onValueChanged: root.editFirstLineSize = value
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.secondLineSize.label")
      description: pluginApi?.tr("settings.secondLineSize.desc", { value: root.editSecondLineSize })
    }

    NSlider {
      from: 8
      to: 72
      value: root.editSecondLineSize
      stepSize: 1
      onValueChanged: root.editSecondLineSize = value
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.marginRight.label")
      description: pluginApi?.tr("settings.marginRight.desc", { value: root.editMarginRight })
    }

    NSlider {
      from: 0
      to: 500
      value: root.editMarginRight
      stepSize: 5
      onValueChanged: root.editMarginRight = value
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.marginBottom.label")
      description: pluginApi?.tr("settings.marginBottom.desc", { value: root.editMarginBottom })
    }

    NSlider {
      from: 0
      to: 500
      value: root.editMarginBottom
      stepSize: 5
      onValueChanged: root.editMarginBottom = value
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("ActivateLinux", "Cannot save: pluginApi is null")
      return
    }

    pluginApi.pluginSettings.customizeText = root.editCustomizeText
    pluginApi.pluginSettings.firstLine = root.editFirstLine
    pluginApi.pluginSettings.secondLine = root.editSecondLine
    pluginApi.pluginSettings.firstLineSize = root.editFirstLineSize
    pluginApi.pluginSettings.secondLineSize = root.editSecondLineSize
    pluginApi.pluginSettings.marginRight = root.editMarginRight
    pluginApi.pluginSettings.marginBottom = root.editMarginBottom
    pluginApi.saveSettings()
  }
}
