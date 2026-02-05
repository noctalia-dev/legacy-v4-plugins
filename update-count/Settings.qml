import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property int updateIntervalMinutes: pluginApi?.pluginSettings?.updateIntervalMinutes || pluginApi?.manifest?.metadata?.defaultSettings?.updateIntervalMinutes
  property string updateTerminalCommand: pluginApi?.pluginSettings?.updateTerminalCommand || pluginApi?.manifest?.metadata.defaultSettings?.updateTerminalCommand
  property string currentIconName: pluginApi?.pluginSettings?.currentIconName || pluginApi?.manifest?.metadata?.defaultSettings?.currentIconName
  property bool hideOnZero: pluginApi?.pluginSettings?.hideOnZero || pluginApi?.manifest?.metadata?.defaultSettings?.hideOnZero

  property string customCmdGetNumUpdates: pluginApi?.pluginSettings.customCmdGetNumUpdates || ""
  property string customCmdDoSystemUpdate: pluginApi?.pluginSettings.customCmdDoSystemUpdate || ""

  spacing: Style.marginL

  Component.onCompleted: {
    Logger.i("UpdateCount", "Settings UI loaded");
  }

  //
  // ------ General ------
  //
  NToggle {
    id: widgetSwitch
    label: pluginApi?.tr("settings.hideWidget.label")
    description: pluginApi?.tr("settings.hideWidget.desc")
    checked: root.hideOnZero
    onToggled: function (checked) {
      root.hideOnZero = checked;
    }
  }

  RowLayout {
    spacing: Style.marginL

    NLabel {
      label: pluginApi?.tr("settings.currentIconName.label")
      description: pluginApi?.tr("settings.currentIconName.desc")
    }

    NText {
      text: root.currentIconName
      color: Settings.data.colorSchemes.darkMode ? Color.mPrimary : Color.mOnPrimary
    }

    NIcon {
      icon: root.currentIconName
      color: Settings.data.colorSchemes.darkMode ? Color.mPrimary : Color.mOnPrimary
    }

    NButton {
      text: pluginApi?.tr("settings.changeIcon.label")
      onClicked: {
        Logger.i("UpdateCount", "Icon selector button clicked.");
        changeIcon.open();
      }
    }

    NIconPicker {
      id: changeIcon
      onIconSelected: function (icon) {
        root.currentIconName = icon;
      }
    }
  }

  ColumnLayout {
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NLabel {
        label: pluginApi?.tr("settings.updateInterval.label")
        description: pluginApi?.tr("settings.updateInterval.desc")
      }

      NText {
        text: root.updateIntervalMinutes.toString().padStart(3, " ") + " minutes"
        color: Settings.data.colorSchemes.darkMode ? Color.mOnSurface : Color.mOnPrimary
      }
    }

    NSlider {
      Layout.fillWidth: true
      from: 5
      to: 300
      value: root.updateIntervalMinutes
      stepSize: 5
      onValueChanged: {
        root.updateIntervalMinutes = value;
      }
    }
  }

  NDivider {
    visible: true
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  //
  // ------ Custom commands ------
  //
  NTextInput {
    label: pluginApi?.tr("settings.customCmdGetNumUpdates.label")
    description: pluginApi?.tr("settings.customCmdGetNumUpdates.desc")
    placeholderText: pluginApi?.tr("settings.customCmdGetNumUpdates.placeholder")
    text: root.customCmdGetNumUpdates
    onTextChanged: root.customCmdGetNumUpdates = text
  }

  NTextInput {
    label: pluginApi?.tr("settings.customCmdDoSystemUpdate.label")
    description: pluginApi?.tr("settings.customCmdDoSystemUpdate.desc")
    placeholderText: pluginApi?.tr("settings.customCmdDoSystemUpdate.placeholder")
    text: root.customCmdDoSystemUpdate
    onTextChanged: root.customCmdDoSystemUpdate = text
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.terminal.label")
    description: pluginApi?.tr("settings.terminal.desc")
    placeholderText: pluginApi?.tr("settings.terminal.placeholder")
    text: root.updateTerminalCommand
    onTextChanged: root.updateTerminalCommand = text
  }

  NDivider {
    visible: true
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  //
  // ------ Information ------
  //
  NLabel {
    label: pluginApi?.tr("settings.currentCommands.label")
  }

  ColumnLayout {
    NText {
      text: pluginApi?.tr("settings.currentNumUpdatesCmd.label")
      color: Settings.data.colorSchemes.darkMode ? Color.mSecondary : Color.mOnSecondary
    }
    NLabel {
      description: `> ${root.customCmdGetNumUpdates || pluginApi?.mainInstance?.updater.cmdGetNumUpdates || "NA"}`
    }
  }

  ColumnLayout {
    NText {
      text: pluginApi?.tr("settings.currentUpdateCmd.label")
      color: Settings.data.colorSchemes.darkMode ? Color.mSecondary : Color.mOnSecondary
    }

    NLabel {
      description: `> ${root.customCmdDoSystemUpdate || pluginApi?.mainInstance?.updater.cmdDoSystemUpdate || "NA"}`
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("UpdateCount", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.updateIntervalMinutes = root.updateIntervalMinutes;
    pluginApi.pluginSettings.updateTerminalCommand = root.updateTerminalCommand || pluginApi?.manifest?.metadata.defaultSettings?.updateTerminalCommand;
    pluginApi.pluginSettings.currentIconName = root.currentIconName;
    pluginApi.pluginSettings.hideOnZero = root.hideOnZero;

    pluginApi.pluginSettings.customCmdGetNumUpdates = root.customCmdGetNumUpdates;
    pluginApi.pluginSettings.customCmdDoSystemUpdate = root.customCmdDoSystemUpdate;

    pluginApi.saveSettings();
    pluginApi?.mainInstance?.startGetNumUpdates();

    Logger.i("UpdateCount", "Settings saved successfully");
    pluginApi.closePanel(root.screen);
  }
}
