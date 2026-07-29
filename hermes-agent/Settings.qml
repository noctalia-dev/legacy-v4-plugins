import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var summary: mainInstance?.state?.summary || ({})
  readonly property var detectedModel: summary.model || ({})
  readonly property var availableModels: summary.models || []

  property string valueBridgeHost: cfg.bridgeHost ?? defaults.bridgeHost ?? "127.0.0.1"
  property int valueBridgePort: cfg.bridgePort ?? defaults.bridgePort ?? 19777
  property string valueStateFile: cfg.stateFile ?? defaults.stateFile ?? "~/.cache/noctalia-hermes/state.json"
  property string valueHermesHome: cfg.hermesHome ?? defaults.hermesHome ?? "~/.hermes"
  property string valueHermesCommand: cfg.hermesCommand ?? defaults.hermesCommand ?? "hermes"
  property bool valueAutoStartBridge: cfg.autoStartBridge ?? defaults.autoStartBridge ?? true
  property bool valueAutoStartGateway: cfg.autoStartGateway ?? defaults.autoStartGateway ?? true
  property bool valueClientOnlyMode: cfg.clientOnlyMode ?? defaults.clientOnlyMode ?? false
  property string valueBridgeTokenManual: cfg.bridgeTokenManual ?? defaults.bridgeTokenManual ?? ""
  property int valueStatusPollIntervalSec: cfg.statusPollIntervalSec ?? defaults.statusPollIntervalSec ?? 30
  property bool valueHideWhenIdle: cfg.hideWhenIdle ?? defaults.hideWhenIdle ?? false
  property string valueLauncherPrefix: cfg.launcherPrefix ?? defaults.launcherPrefix ?? ">hermes"
  property bool valuePanelPinned: cfg.panelPinned ?? defaults.panelPinned ?? false
  property bool valueShowToolActivity: cfg.showToolActivity ?? defaults.showToolActivity ?? false
  property string valueDefaultProvider: (detectedModel.provider || cfg.defaultProvider || defaults.defaultProvider || "")
  property string valueDefaultModel: (detectedModel.name || cfg.defaultModel || defaults.defaultModel || "")
  readonly property string selectedModelKey: modelKey(valueDefaultProvider, valueDefaultModel)
  property bool showAdvanced: false
  property string testResult: ""
  property color testResultColor: Color.mOnSurface

  spacing: Style.marginL

  NText {
    text: pluginApi?.tr("settings.title")
    pointSize: Style.fontSizeXL
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.providerSelect")
        model: root.providerOptions()
        currentKey: root.valueDefaultProvider
        minimumWidth: 180
        onSelected: function(key) {
          root.valueDefaultProvider = key;
          if (root.valueDefaultModel !== "" && root.findModel(root.valueDefaultProvider, root.valueDefaultModel) === null) {
            var first = root.firstModelForProvider(key);
            if (first) root.valueDefaultModel = first.model;
          }
        }
      }

      NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.modelSelect")
        model: root.modelOptions(root.valueDefaultProvider)
        currentKey: root.selectedModelKey
        minimumWidth: 320
        onSelected: function(key) {
          var item = root.findModelByKey(key);
          if (!item) return;
          root.valueDefaultProvider = item.provider || "";
          root.valueDefaultModel = item.model || "";
        }
      }
    }

    NButton {
      text: pluginApi?.tr("settings.applyModel")
      icon: "refresh"
      enabled: root.valueDefaultModel.trim() !== ""
      onClicked: {
        root.saveSettings();
        root.mainInstance?.setModel(root.valueDefaultProvider.trim(), root.valueDefaultModel.trim(), false);
      }
    }

    NToggle {
      label: pluginApi?.tr("settings.hideWhenIdle")
      description: pluginApi?.tr("settings.hideWhenIdleDescription")
      checked: root.valueHideWhenIdle
      onToggled: root.valueHideWhenIdle = checked
    }

    NToggle {
      label: pluginApi?.tr("settings.panelPinned")
      description: pluginApi?.tr("settings.panelPinnedDescription")
      checked: root.valuePanelPinned
      onToggled: root.valuePanelPinned = checked
    }

    NToggle {
      label: pluginApi?.tr("settings.showToolActivity")
      description: pluginApi?.tr("settings.showToolActivityDescription")
      checked: root.valueShowToolActivity
      onToggled: root.valueShowToolActivity = checked
    }

    NButton {
      text: root.showAdvanced ? pluginApi?.tr("settings.advancedHide") : pluginApi?.tr("settings.advancedShow")
      icon: root.showAdvanced ? "chevron-up" : "chevron-down"
      outlined: true
      onClicked: root.showAdvanced = !root.showAdvanced
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginM
      visible: root.showAdvanced

      NToggle {
        label: pluginApi?.tr("settings.clientOnlyMode")
        description: pluginApi?.tr("settings.clientOnlyModeDescription")
        checked: root.valueClientOnlyMode
        onToggled: root.valueClientOnlyMode = checked
      }

      NTextInput {
        Layout.fillWidth: true
        visible: root.valueClientOnlyMode
        label: pluginApi?.tr("settings.bridgeToken")
        description: pluginApi?.tr("settings.bridgeTokenDescription")
        text: root.valueBridgeTokenManual
        onTextChanged: {
          // Guard: only update when visible. Some QML components clear text
          // when hidden, which would wipe the saved token on toggle OFF.
          if (root.valueClientOnlyMode) root.valueBridgeTokenManual = text;
        }
      }

      RowLayout {
        Layout.fillWidth: true
        visible: root.valueClientOnlyMode
        spacing: Style.marginM

        NButton {
          text: pluginApi?.tr("settings.testConnection")
          onClicked: root.testConnection()
        }

        NLabel {
          label: root.testResult
          labelColor: root.testResultColor
        }
      }

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.bridgeHost")
        text: root.valueBridgeHost
        onTextChanged: root.valueBridgeHost = text
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            text: pluginApi?.tr("settings.bridgePort")
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightSemiBold
            color: Color.mOnSurface
          }

          NSpinBox {
            from: 1024
            to: 65535
            value: root.valueBridgePort
            stepSize: 1
            onValueChanged: root.valueBridgePort = value
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            text: pluginApi?.tr("settings.statusPollIntervalSec")
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightSemiBold
            color: Color.mOnSurface
          }

          NSpinBox {
            from: 5
            to: 300
            value: root.valueStatusPollIntervalSec
            stepSize: 5
            onValueChanged: root.valueStatusPollIntervalSec = value
          }
        }
      }

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.stateFile")
        text: root.valueStateFile
        onTextChanged: root.valueStateFile = text
      }

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.hermesHome")
        text: root.valueHermesHome
        onTextChanged: root.valueHermesHome = text
      }

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.hermesCommand")
        text: root.valueHermesCommand
        onTextChanged: root.valueHermesCommand = text
      }

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.launcherPrefix")
        text: root.valueLauncherPrefix
        onTextChanged: root.valueLauncherPrefix = text
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NTextInput {
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.defaultProvider")
          text: root.valueDefaultProvider
          onTextChanged: root.valueDefaultProvider = text
        }

        NTextInput {
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.defaultModel")
          text: root.valueDefaultModel
          onTextChanged: root.valueDefaultModel = text
        }
      }

      NToggle {
        label: pluginApi?.tr("settings.autoStartBridge")
        description: pluginApi?.tr("settings.autoStartBridgeDescription")
        visible: !root.valueClientOnlyMode
        checked: root.valueAutoStartBridge
        onToggled: root.valueAutoStartBridge = checked
      }

      NToggle {
        label: pluginApi?.tr("settings.autoStartGateway")
        description: pluginApi?.tr("settings.autoStartGatewayDescription")
        visible: !root.valueClientOnlyMode
        checked: root.valueAutoStartGateway
        onToggled: root.valueAutoStartGateway = checked
      }
    }
  }

  function saveSettings() {
    if (!pluginApi) return;
    Logger.i("hermes-agent", "saveSettings: tokenManual len:", root.valueBridgeTokenManual.length, "clientOnlyMode:", root.valueClientOnlyMode);
    pluginApi.pluginSettings.bridgeHost = root.valueBridgeHost;
    pluginApi.pluginSettings.bridgePort = root.valueBridgePort;
    pluginApi.pluginSettings.stateFile = root.valueStateFile;
    pluginApi.pluginSettings.hermesHome = root.valueHermesHome;
    pluginApi.pluginSettings.hermesCommand = root.valueHermesCommand;
    pluginApi.pluginSettings.autoStartBridge = root.valueAutoStartBridge;
    pluginApi.pluginSettings.autoStartGateway = root.valueAutoStartGateway;
    pluginApi.pluginSettings.clientOnlyMode = root.valueClientOnlyMode;
    pluginApi.pluginSettings.bridgeTokenManual = root.valueBridgeTokenManual;
    pluginApi.pluginSettings.statusPollIntervalSec = root.valueStatusPollIntervalSec;
    pluginApi.pluginSettings.hideWhenIdle = root.valueHideWhenIdle;
    pluginApi.pluginSettings.launcherPrefix = root.valueLauncherPrefix;
    pluginApi.pluginSettings.panelPinned = root.valuePanelPinned;
    pluginApi.pluginSettings.showToolActivity = root.valueShowToolActivity;
    pluginApi.pluginSettings.defaultProvider = root.valueDefaultProvider;
    pluginApi.pluginSettings.defaultModel = root.valueDefaultModel;
    pluginApi.saveSettings();
    root.mainInstance?.setPinnedPanelRequested(root.valuePanelPinned);
    root.mainInstance?.setModel(root.valueDefaultProvider, root.valueDefaultModel, false);
  }

  function testConnection() {
    root.testResult = pluginApi?.tr("settings.testing");
    root.testResultColor = Color.mOnSurface;
    var host = root.valueBridgeHost;
    var port = root.valueBridgePort;
    var token = root.valueBridgeTokenManual;
    var url = "http://" + host + ":" + port + "/health";
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return;
      if (xhr.status === 0) {
        root.testResult = pluginApi?.tr("settings.testFailedUnreachable");
        root.testResultColor = Color.mError;
      } else if (xhr.status === 403) {
        root.testResult = pluginApi?.tr("settings.testFailedAuth");
        root.testResultColor = Color.mError;
      } else if (xhr.status >= 200 && xhr.status < 300) {
        root.testResult = pluginApi?.tr("settings.testSuccess");
        root.testResultColor = Color.mPrimary;
      } else {
        root.testResult = pluginApi?.tr("settings.testFailed") + " " + xhr.status;
        root.testResultColor = Color.mError;
      }
    };
    xhr.open("GET", url);
    if (token) xhr.setRequestHeader("X-Bridge-Token", token);
    xhr.send();
  }

  function modelKey(provider, model) {
    return (provider || "") + "::" + (model || "");
  }

  function providerOptions() {
    var seen = {};
    var items = [{ "key": "", "name": pluginApi?.tr("settings.providerCurrent") }];
    for (var i = 0; i < root.availableModels.length; i++) {
      var provider = root.availableModels[i].provider || "";
      if (provider === "" || seen[provider]) continue;
      seen[provider] = true;
      items.push({ "key": provider, "name": provider });
    }
    if (root.valueDefaultProvider !== "" && !seen[root.valueDefaultProvider]) {
      items.push({ "key": root.valueDefaultProvider, "name": root.valueDefaultProvider });
    }
    return items;
  }

  function modelOptions(provider) {
    var items = [];
    for (var i = 0; i < root.availableModels.length; i++) {
      var item = root.availableModels[i];
      if (provider !== "" && item.provider !== provider) continue;
      items.push({
        "key": root.modelKey(item.provider || "", item.model || ""),
        "name": item.name || item.model || ""
      });
    }
    if (root.valueDefaultModel !== "" && root.findModel(root.valueDefaultProvider, root.valueDefaultModel) === null) {
      items.unshift({
        "key": root.selectedModelKey,
        "name": root.valueDefaultModel + (root.valueDefaultProvider ? " (" + root.valueDefaultProvider + ")" : "")
      });
    }
    return items;
  }

  function findModel(provider, model) {
    for (var i = 0; i < root.availableModels.length; i++) {
      var item = root.availableModels[i];
      if ((item.provider || "") === (provider || "") && (item.model || "") === (model || "")) return item;
    }
    return null;
  }

  function findModelByKey(key) {
    for (var i = 0; i < root.availableModels.length; i++) {
      var item = root.availableModels[i];
      if (root.modelKey(item.provider || "", item.model || "") === key) return item;
    }
    return null;
  }

  function firstModelForProvider(provider) {
    for (var i = 0; i < root.availableModels.length; i++) {
      var item = root.availableModels[i];
      if (provider === "" || item.provider === provider) return item;
    }
    return null;
  }
}
