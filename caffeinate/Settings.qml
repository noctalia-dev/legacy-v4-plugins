pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "DurationLanguage.js" as DurationLanguage
import "LauncherModel.js" as LauncherModel
import "SettingsModel.js" as SettingsModel

ColumnLayout {
  id: root

  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string editAlias: ""
  property bool editIncludeIndefinite: true
  property bool editHideInactive: false
  property real preferredWidth: 720 * Style.uiScaleRatio

  spacing: Style.marginL

  Component.onCompleted: loadSettings()

  ListModel {
    id: presetsModel
  }

  function replacePresets(source) {
    const presets = SettingsModel.copyPresets(source);
    presetsModel.clear();
    for (let index = 0; index < presets.length; index++) {
      presetsModel.append({
                            "expression": presets[index]
                          });
    }
  }

  function presetExpressions() {
    const presets = [];
    for (let index = 0; index < presetsModel.count; index++)
      presets.push(presetsModel.get(index).expression);
    return presets;
  }

  function loadSettings() {
    editAlias = cfg.alias ?? defaults.alias ?? "c";
    replacePresets(cfg.presets ?? defaults.presets ?? []);
    editIncludeIndefinite = cfg.includeIndefinitePreset ?? defaults.includeIndefinitePreset ?? true;
    editHideInactive = cfg.hideInactiveWidget ?? defaults.hideInactiveWidget ?? false;
  }

  function resetDefaults() {
    editAlias = defaults.alias ?? "c";
    replacePresets(defaults.presets ?? []);
    editIncludeIndefinite = defaults.includeIndefinitePreset ?? true;
    editHideInactive = defaults.hideInactiveWidget ?? false;
  }

  function aliasValidation() {
    return LauncherModel.validateAlias(editAlias, "caffeinate");
  }

  function aliasFeedback() {
    const validation = aliasValidation();
    if (validation.state === "invalid") {
      return pluginApi?.tr(validation.code === "alias-duplicates-canonical"
                           ? "settings.alias.duplicateError" : "settings.alias.formatError");
    }
    if (validation.normalized === "")
      return pluginApi?.tr("settings.alias.disabled");
    return pluginApi?.tr("settings.alias.valid", {
                           "alias": validation.normalized
                         });
  }

  function durationFeedback(expression) {
    const parsed = DurationLanguage.parse(expression);
    if (parsed.state === "valid") {
      return pluginApi?.tr("settings.presets.valid", {
                             "duration": parsed.normalized
                           });
    }

    return pluginApi?.tr("feedback." + parsed.state + "." + parsed.code);
  }

  function settingsAreValid() {
    return validatedSettings().valid;
  }

  function validatedSettings() {
    return SettingsModel.validate(editAlias, presetExpressions(), "caffeinate",
                                  LauncherModel.validateAlias, DurationLanguage.parse);
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("Caffeinate", "Cannot save settings: pluginApi is null");
      return;
    }

    const validated = validatedSettings();
    if (!validated.valid) {
      Logger.w("Caffeinate", pluginApi?.tr("settings.invalidSave"));
      return;
    }

    pluginApi.pluginSettings.alias = validated.alias;
    pluginApi.pluginSettings.presets = validated.presets;
    pluginApi.pluginSettings.includeIndefinitePreset = editIncludeIndefinite;
    pluginApi.pluginSettings.hideInactiveWidget = editHideInactive;
    pluginApi.saveSettings();
    Logger.i("Caffeinate", pluginApi?.tr("settings.saved"));
  }

  NText {
    text: pluginApi?.tr("settings.title")
    pointSize: Style.fontSizeL
    font.weight: Style.fontWeightBold
  }

  NText {
    Layout.fillWidth: true
    text: pluginApi?.tr("settings.description")
    color: Color.mOnSurfaceVariant
    wrapMode: Text.Wrap
  }

  NDivider {
    Layout.fillWidth: true
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.alias.label")
    description: pluginApi?.tr("settings.alias.description")
    placeholderText: pluginApi?.tr("settings.alias.placeholder")
    defaultValue: defaults.alias ?? "c"
    text: root.editAlias
    onTextChanged: root.editAlias = text
  }

  NText {
    Layout.fillWidth: true
    text: root.aliasFeedback()
    color: root.aliasValidation().state === "valid" ? Color.mOnSurfaceVariant : Color.mError
    wrapMode: Text.Wrap
  }

  NDivider {
    Layout.fillWidth: true
  }

  NLabel {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.bar.title")
    description: pluginApi?.tr("settings.bar.description")
  }

  NToggle {
    label: pluginApi?.tr("settings.bar.hideInactive.label")
    description: pluginApi?.tr("settings.bar.hideInactive.description")
    checked: root.editHideInactive
    defaultValue: defaults.hideInactiveWidget ?? false
    onToggled: checked => root.editHideInactive = checked
  }

  NDivider {
    Layout.fillWidth: true
  }

  NLabel {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.presets.title")
    description: pluginApi?.tr("settings.presets.description")
  }

  NScrollView {
    id: presetsScroll

    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(presetsColumn.implicitHeight, 360 * Style.uiScaleRatio)
    horizontalPolicy: ScrollBar.AlwaysOff
    showScrollbarWhenScrollable: true
    gradientColor: Color.mSurfaceVariant

    ColumnLayout {
      id: presetsColumn

      width: presetsScroll.availableWidth
      spacing: Style.marginM

      Repeater {
        model: presetsModel

        delegate: ColumnLayout {
          id: presetDelegate

          required property int index
          required property string expression

          Layout.fillWidth: true
          spacing: Style.marginXS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NTextInput {
              id: presetInput

              Layout.fillWidth: true
              placeholderText: pluginApi?.tr("settings.presets.placeholder")
              text: presetDelegate.expression
              onTextChanged: {
                if (presetDelegate.expression !== text) {
                  presetsModel.setProperty(presetDelegate.index, "expression", text);
                }
              }
            }

            NIconButton {
              icon: "arrow-up"
              tooltipText: pluginApi?.tr("settings.presets.moveUp")
              enabled: presetDelegate.index > 0
              onClicked: presetsModel.move(presetDelegate.index, presetDelegate.index - 1, 1)
            }

            NIconButton {
              icon: "arrow-down"
              tooltipText: pluginApi?.tr("settings.presets.moveDown")
              enabled: presetDelegate.index < presetsModel.count - 1
              onClicked: presetsModel.move(presetDelegate.index, presetDelegate.index + 1, 1)
            }

            NIconButton {
              icon: "trash"
              tooltipText: pluginApi?.tr("settings.presets.remove")
              onClicked: presetsModel.remove(presetDelegate.index)
            }
          }

          readonly property var parsed: DurationLanguage.parse(presetInput.text)

          NText {
            Layout.fillWidth: true
            text: root.durationFeedback(presetInput.text)
            color: presetDelegate.parsed.state === "valid" ? Color.mOnSurfaceVariant : Color.mError
            wrapMode: Text.Wrap
          }
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NButton {
      text: pluginApi?.tr("settings.presets.add")
      icon: "plus"
      onClicked: presetsModel.append({
                                       "expression": ""
                                     })
    }

    Item {
      Layout.fillWidth: true
    }

    NButton {
      text: pluginApi?.tr("settings.reset")
      icon: "restore"
      outlined: true
      onClicked: root.resetDefaults()
    }
  }

  NToggle {
    label: pluginApi?.tr("settings.indefinite.label")
    description: pluginApi?.tr("settings.indefinite.description")
    checked: root.editIncludeIndefinite
    defaultValue: defaults.includeIndefinitePreset ?? true
    onToggled: checked => root.editIncludeIndefinite = checked
  }
}
