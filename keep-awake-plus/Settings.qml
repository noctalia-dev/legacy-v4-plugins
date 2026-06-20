import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings ?? ({})

  property string defaultScope: cfg.defaultScope ?? "partial"
  property bool showRemainingText: cfg.showRemainingText ?? true
  property bool activateOnLeftClick: cfg.activateOnLeftClick ?? false
  property int quickExtendMinutes: cfg.quickExtendMinutes ?? 30
  property bool includeUnlimited: cfg.includeUnlimited ?? true
  property string durationsCsv: (cfg.durations ?? []).join(", ")

  spacing: Style.marginL

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.default-scope.label")
    description: pluginApi?.tr("settings.default-scope.desc")
    model: [
      { key: "partial", name: pluginApi?.tr("settings.scope-partial") },
      { key: "full", name: pluginApi?.tr("settings.scope-full") }
    ]
    currentKey: root.defaultScope
    onSelected: key => root.defaultScope = key
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.show-remaining.label")
    checked: root.showRemainingText
    onToggled: checked => root.showRemainingText = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.activate-on-left-click.label")
    description: pluginApi?.tr("settings.activate-on-left-click.desc")
    checked: root.activateOnLeftClick
    onToggled: checked => root.activateOnLeftClick = checked
  }

  NSpinBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.quick-extend.label")
    from: 5; to: 240; stepSize: 5
    value: root.quickExtendMinutes
    onValueChanged: root.quickExtendMinutes = value
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.durations.label")
    text: root.durationsCsv
    onEditingFinished: root.durationsCsv = text
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.include-unlimited.label")
    checked: root.includeUnlimited
    onToggled: checked => root.includeUnlimited = checked
  }

  // Called by Noctalia's settings framework when the dialog closes.
  function saveSettings() {
    if (!pluginApi) {
      Logger.e("keep-awake-plus", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.defaultScope = root.defaultScope;
    pluginApi.pluginSettings.showRemainingText = root.showRemainingText;
    pluginApi.pluginSettings.activateOnLeftClick = root.activateOnLeftClick;
    pluginApi.pluginSettings.quickExtendMinutes = root.quickExtendMinutes;
    pluginApi.pluginSettings.includeUnlimited = root.includeUnlimited;

    const arr = root.durationsCsv
      .split(/\s*,\s*/)
      .map(s => parseInt(s, 10))
      .filter(n => !isNaN(n) && n > 0);
    if (arr.length > 0) pluginApi.pluginSettings.durations = arr;

    pluginApi.saveSettings();
    Logger.i("keep-awake-plus", "Settings saved");
  }
}
