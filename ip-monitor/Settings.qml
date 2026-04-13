import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string valueIconColor: cfg.iconColor ?? defaults.iconColor
  property int valueRefreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 300
  property string valueSuccessIcon: cfg.successIcon ?? defaults.successIcon ?? "hierarchy-2"
  property string valueErrorIcon: cfg.errorIcon ?? defaults.errorIcon ?? "alert-circle"
  property string valueLoadingIcon: cfg.loadingIcon ?? defaults.loadingIcon ?? "loader"

  spacing: Style.marginL

  Component.onCompleted: {
    Logger.d("IpMonitor", "Settings UI loaded");
  }

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    // Appearance section
    NText {
      text: pluginApi?.tr("settings.appearance.title")
      font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      font.weight: Font.Medium
      color: Color.mOnSurface
    }

    NComboBox {
      label: pluginApi?.tr("settings.iconColor.label")
      description: pluginApi?.tr("settings.iconColor.desc")
      model: Color.colorKeyModel
      currentKey: root.valueIconColor
      onSelected: key => root.valueIconColor = key
    }

    // State Icons section
    NText {
      text: pluginApi?.tr("settings.stateIcons.title")
      font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      font.weight: Font.Medium
      color: Color.mOnSurface
      Layout.topMargin: Style.marginM
    }

    RowLayout {
      spacing: Style.marginM

      NLabel {
        label: pluginApi?.tr("settings.successIcon.label")
        description: pluginApi?.tr("settings.successIcon.desc")
      }

      NIcon {
        Layout.alignment: Qt.AlignVCenter
        icon: valueSuccessIcon
        pointSize: Style.fontSizeXXL * 1.5
        visible: valueSuccessIcon !== ""
      }

      NButton {
        text: pluginApi?.tr("settings.browseIcons")
        onClicked: successIconPicker.open()
      }
    }

    NIconPicker {
      id: successIconPicker
      initialIcon: valueSuccessIcon
      onIconSelected: iconName => {
        valueSuccessIcon = iconName;
        settingsChanged(saveSettings());
      }
    }

    RowLayout {
      spacing: Style.marginM

      NLabel {
        label: pluginApi?.tr("settings.errorIcon.label")
        description: pluginApi?.tr("settings.errorIcon.desc")
      }

      NIcon {
        Layout.alignment: Qt.AlignVCenter
        icon: valueErrorIcon
        pointSize: Style.fontSizeXXL * 1.5
        visible: valueErrorIcon !== ""
      }

      NButton {
        text: pluginApi?.tr("settings.browseIcons")
        onClicked: errorIconPicker.open()
      }
    }

    NIconPicker {
      id: errorIconPicker
      initialIcon: valueErrorIcon
      onIconSelected: iconName => {
        valueErrorIcon = iconName;
        settingsChanged(saveSettings());
      }
    }

    RowLayout {
      spacing: Style.marginM

      NLabel {
        label: pluginApi?.tr("settings.loadingIcon.label")
        description: pluginApi?.tr("settings.loadingIcon.desc")
      }

      NIcon {
        Layout.alignment: Qt.AlignVCenter
        icon: valueLoadingIcon
        pointSize: Style.fontSizeXXL * 1.5
        visible: valueLoadingIcon !== ""
      }

      NButton {
        text: pluginApi?.tr("settings.browseIcons")
        onClicked: loadingIconPicker.open()
      }
    }

    NIconPicker {
      id: loadingIconPicker
      initialIcon: valueLoadingIcon
      onIconSelected: iconName => {
        valueLoadingIcon = iconName;
        settingsChanged(saveSettings());
      }
    }

    // Behavior section
    NText {
      text: pluginApi?.tr("settings.behavior.title")
      font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      font.weight: Font.Medium
      color: Color.mOnSurface
      Layout.topMargin: Style.marginM
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.refreshInterval.label")
      description: pluginApi?.tr("settings.refreshInterval.desc")
      placeholderText: pluginApi?.tr("settings.refreshInterval.placeholder")
      text: root.valueRefreshInterval.toString()
      onTextChanged: {
        var val = parseInt(text);
        if (!isNaN(val) && val >= 0 && val <= 86400) {
          root.valueRefreshInterval = val;
        }
      }
    }

		// IPC keybinding
		NText {
      text: pluginApi?.tr("settings.commands.title")
      font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      font.weight: Font.Medium
      color: Color.mOnSurface
      Layout.topMargin: Style.marginM
    }

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: infoCol.implicitHeight + Style.marginM * 2
			color: Color.mSurfaceVariant
			radius: Style.radiusM

			ColumnLayout {
				id: infoCol
				anchors {
					fill: parent
					margins: Style.marginM
				}
				spacing: Style.marginS

				RowLayout {
					spacing: Style.marginS

					NIcon {
						icon: "info-circle"
						pointSize: Style.fontSizeS
						color: Color.mPrimary
					}

					NText {
						text: pluginApi?.tr("settings.ipcCommands.title")
						pointSize: Style.fontSizeS
						font.weight: Font.Medium
						color: Color.mOnSurface
					}
				}

				NText {
					Layout.fillWidth: true
					text: pluginApi?.tr("settings.ipcCommands.refreshIp") + ": qs -c noctalia-shell ipc call plugin:ip-monitor refreshIp"
					pointSize: Style.fontSizeXS
					font.family: Settings.data.ui.fontFixed
					color: Color.mOnSurfaceVariant
					wrapMode: Text.WrapAnywhere
				}

				NText {
					Layout.fillWidth: true
					text: pluginApi?.tr("settings.ipcCommands.togglePanel") + ": qs -c noctalia-shell ipc call plugin:ip-monitor toggle"
					pointSize: Style.fontSizeXS
					font.family: Settings.data.ui.fontFixed
					color: Color.mOnSurfaceVariant
					wrapMode: Text.WrapAnywhere
				}
			}
		}
  }

  signal settingsChanged(var settings)
  function saveSettings() {
    if (!pluginApi) {
      Logger.e("IpMonitor", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.iconColor = root.valueIconColor;
    pluginApi.pluginSettings.refreshInterval = root.valueRefreshInterval;
    pluginApi.pluginSettings.successIcon = root.valueSuccessIcon;
    pluginApi.pluginSettings.errorIcon = root.valueErrorIcon;
    pluginApi.pluginSettings.loadingIcon = root.valueLoadingIcon;
    pluginApi.saveSettings();

    Logger.d("IpMonitor", "Settings saved successfully");
  }
}
