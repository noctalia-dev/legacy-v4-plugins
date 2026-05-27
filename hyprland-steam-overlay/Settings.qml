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
  property bool valueAutoLaunchSteam: cfg.autoLaunchSteam ?? defaults.autoLaunchSteam ?? true
  property bool valueUseCustomLayout: cfg.useCustomLayout ?? defaults.useCustomLayout ?? false
  property bool valueEnableChatNotifications: cfg.enableChatNotifications ?? defaults.enableChatNotifications ?? true
  property int valueFriendsWidth: cfg.friendsWidthPercent ?? defaults.friendsWidthPercent ?? 10
  property int valueMainWidth: cfg.mainWidthPercent ?? defaults.mainWidthPercent ?? 60
  property int valueChatWidth: cfg.chatWidthPercent ?? defaults.chatWidthPercent ?? 25
  property int valueGapSize: cfg.gapSize ?? defaults.gapSize ?? 10
  property real valueTopMargin: cfg.topMarginPercent ?? defaults.topMarginPercent ?? 2.5
  property real valueWindowHeight: cfg.windowHeightPercent ?? defaults.windowHeightPercent ?? 95

  spacing: Style.marginM

  Component.onCompleted: {
    Logger.i("SteamOverlay", "Settings UI loaded");
  }

  NLabel {
    label: "Steam Overlay Settings"
    description: "Configure the Steam overlay window layout and behavior"
  }

  // Auto-launch Steam toggle
  NCheckbox {
    Layout.fillWidth: true
    label: "Auto-launch Steam"
    description: "Automatically launch Steam when toggling overlay if it's not running"
    checked: root.valueAutoLaunchSteam
    onToggled: root.valueAutoLaunchSteam = checked
  }

  // Chat notifications toggle
  NCheckbox {
    Layout.fillWidth: true
    label: "Chat Notifications"
    description: "Show notification indicator on bar icon when new Steam chat messages arrive"
    checked: root.valueEnableChatNotifications
    onToggled: root.valueEnableChatNotifications = checked
  }

  // Custom Hyprland layout toggle
  NCheckbox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.custom-layout-label")
    description: pluginApi?.tr("settings.custom-layout-description")
    checked: root.valueUseCustomLayout
    onToggled: root.valueUseCustomLayout = checked
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    Layout.bottomMargin: Style.marginS
  }

  // Window Layout Section
  NLabel {
    label: "Window Layout (Percentages)"
    description: "Adjust the width distribution of the three main Steam windows"
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "Friends List Width: " + root.valueFriendsWidth + "%"
      description: "Width of the Friends List window"
    }

    NSlider {
      Layout.fillWidth: true
      from: 5
      to: 30
      value: root.valueFriendsWidth
      stepSize: 1
      onValueChanged: root.valueFriendsWidth = value
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "Main Window Width: " + root.valueMainWidth + "%"
      description: "Width of the main Steam window"
    }

    NSlider {
      Layout.fillWidth: true
      from: 40
      to: 80
      value: root.valueMainWidth
      stepSize: 1
      onValueChanged: root.valueMainWidth = value
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "Chat Window Width: " + root.valueChatWidth + "%"
      description: "Width of the chat window"
    }

    NSlider {
      Layout.fillWidth: true
      from: 10
      to: 40
      value: root.valueChatWidth
      stepSize: 1
      onValueChanged: root.valueChatWidth = value
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    Layout.bottomMargin: Style.marginS
  }

  // Spacing Section
  NLabel {
    label: "Spacing & Margins"
    description: "Adjust gaps between windows and screen margins"
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "Gap Size: " + root.valueGapSize + "px"
      description: "Space between windows in pixels"
    }

    NSlider {
      Layout.fillWidth: true
      from: 0
      to: 50
      value: root.valueGapSize
      stepSize: 5
      onValueChanged: root.valueGapSize = value
    }
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
      to: 10
      value: root.valueTopMargin
      stepSize: 0.5
      onValueChanged: root.valueTopMargin = value
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "Window Height: " + root.valueWindowHeight + "%"
      description: "Height of overlay windows"
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

  // Info text
  NLabel {
    label: "💡 Tip"
    description: "After changing settings, toggle the overlay off and on (Super+S twice) to apply the new layout."
  }

  Item {
    Layout.fillHeight: true
  }

  // This function is called by the dialog to save settings
  function saveSettings() {
    if (!pluginApi) {
      Logger.e("SteamOverlay", "Cannot save settings: pluginApi is null");
      return;
    }

    // Update the plugin settings object
    pluginApi.pluginSettings.autoLaunchSteam = root.valueAutoLaunchSteam;
    pluginApi.pluginSettings.useCustomLayout = root.valueUseCustomLayout;
    pluginApi.pluginSettings.enableChatNotifications = root.valueEnableChatNotifications;
    pluginApi.pluginSettings.friendsWidthPercent = root.valueFriendsWidth;
    pluginApi.pluginSettings.mainWidthPercent = root.valueMainWidth;
    pluginApi.pluginSettings.chatWidthPercent = root.valueChatWidth;
    pluginApi.pluginSettings.gapSize = root.valueGapSize;
    pluginApi.pluginSettings.topMarginPercent = root.valueTopMargin;
    pluginApi.pluginSettings.windowHeightPercent = root.valueWindowHeight;

    // Save to disk
    pluginApi.saveSettings();

    Logger.i("SteamOverlay", "Settings saved successfully");
  }
}
