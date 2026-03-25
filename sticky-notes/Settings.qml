import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property var mainInstance: pluginApi?.mainInstance || null

  property bool valueSyncEnabled: cfg.syncEnabled ?? defaults.syncEnabled ?? false
  property string valueGithubToken: cfg.githubToken ?? defaults.githubToken ?? ""

  spacing: Style.marginL

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.syncEnabled.label")
    description: pluginApi?.tr("settings.syncEnabled.desc")
    checked: root.valueSyncEnabled
    onToggled: checked => root.valueSyncEnabled = checked
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.githubToken.label")
    description: pluginApi?.tr("settings.githubToken.desc")
    placeholderText: pluginApi?.tr("settings.githubToken.placeholder")
    text: root.valueGithubToken
    onTextChanged: root.valueGithubToken = text
  }

  NText {
    Layout.fillWidth: true
    text: pluginApi?.tr("settings.githubToken.help")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.Wrap
    textFormat: Text.MarkdownText
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NButton {
      text: pluginApi?.tr("settings.syncNow")
      icon: "refresh"
      enabled: !mainInstance?.syncInProgress
      onClicked: {
        root.saveSettings();
        if (mainInstance) {
          mainInstance.manualSync();
        }
      }
    }

    Item { Layout.fillWidth: true }

    NText {
      text: {
        if (mainInstance?.syncInProgress) {
          return pluginApi?.tr("sync.syncing");
        }
        return mainInstance?.lastSyncMessage || "";
      }
      color: mainInstance?.lastSyncOk ? Color.mPrimary : Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.Wrap
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignRight
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      return;
    }

    pluginApi.pluginSettings.syncEnabled = root.valueSyncEnabled;
    pluginApi.pluginSettings.githubToken = root.valueGithubToken.trim();
    pluginApi.saveSettings();

    ToastService.showNotice(pluginApi?.tr("settings.saved"));
  }
}
