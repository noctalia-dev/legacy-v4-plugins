import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  // Shortcut to settings and defaults
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Local state - track changes before saving
  property bool valueAutoLaunchDiscord: cfg.autoLaunchDiscord ?? defaults.autoLaunchDiscord ?? true
  property int valueWindowWidth: cfg.windowWidthPercent ?? defaults.windowWidthPercent ?? 80
  property int valueWindowHeight: cfg.windowHeightPercent ?? defaults.windowHeightPercent ?? 90
  property real valueTopMargin: cfg.topMarginPercent ?? defaults.topMarginPercent ?? 5

  spacing: Style.marginM

  Component.onCompleted: {
    Logger.i("DiscordOverlay", "Settings UI loaded");
  }

  NLabel {
    label: "Discord Overlay Settings"
    description: "Configure the Discord overlay window layout and behavior"
  }

  // Auto-launch Discord toggle
  NCheckbox {
    Layout.fillWidth: true
    label: "Auto-launch Discord"
    description: "Automatically launch Discord when toggling overlay if it's not running"
    checked: root.valueAutoLaunchDiscord
    onToggled: root.valueAutoLaunchDiscord = checked
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    Layout.bottomMargin: Style.marginS
  }

  // Window Layout Section
  NLabel {
    label: "Window Layout (Percentages)"
    description: "Adjust the size and position of the Discord window"
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "Window Width: " + root.valueWindowWidth + "%"
      description: "Width of the Discord window"
    }

    NSlider {
      Layout.fillWidth: true
      from: 50
      to: 100
      value: root.valueWindowWidth
      stepSize: 1
      onValueChanged: root.valueWindowWidth = value
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "Window Height: " + root.valueWindowHeight + "%"
      description: "Height of the Discord window"
    }

    NSlider {
      Layout.fillWidth: true
      from: 70
      to: 100
      value: root.valueWindowHeight
      stepSize: 1
      onValueChanged: root.valueWindowHeight = value
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    Layout.bottomMargin: Style.marginS
  }

  // Spacing Section
  NLabel {
    label: "Position"
    description: "Adjust window position on screen"
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "Top Margin: " + root.valueTopMargin.toFixed(1) + "%"
      description: "Distance from top of screen"
    }

    NSlider {
      Layout.fillWidth: true
      from: 0
      to: 20
      value: root.valueTopMargin
      stepSize: 0.5
      onValueChanged: root.valueTopMargin = value
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    Layout.bottomMargin: Style.marginS
  }

  // Info text
  NLabel {
    label: "💡 Tip"
    description: "After changing settings, toggle the overlay off and on to apply the new layout."
  }

  Item {
    Layout.fillHeight: true
  }

  // This function is called by the dialog to save settings
  function saveSettings() {
    if (!pluginApi) {
      Logger.e("DiscordOverlay", "Cannot save settings: pluginApi is null");
      return;
    }

    // Update the plugin settings object
    pluginApi.pluginSettings.autoLaunchDiscord = root.valueAutoLaunchDiscord;
    pluginApi.pluginSettings.windowWidthPercent = root.valueWindowWidth;
    pluginApi.pluginSettings.windowHeightPercent = root.valueWindowHeight;
    pluginApi.pluginSettings.topMarginPercent = root.valueTopMargin;

    // Save to disk
    pluginApi.saveSettings();

    Logger.i("DiscordOverlay", "Settings saved successfully");
  }
}
