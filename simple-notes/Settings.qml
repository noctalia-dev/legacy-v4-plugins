import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property bool showCount: cfg.showCountInBar ?? defaults.showCountInBar ?? true
  property string barIcon: cfg.barIcon ?? defaults.barIcon ?? "paperclip"
  property bool hideBarWidget: cfg.hideBarWidget ?? defaults.hideBarWidget ?? false
  property string positionMode: cfg.positionMode ?? defaults.positionMode ?? "attached"
  property string notesDirectory: cfg.notesDirectory ?? defaults.notesDirectory ?? ""

  spacing: Style.marginM

  NToggle {
    label: pluginApi?.tr("settings.show_count.label")
    description: pluginApi?.tr("settings.show_count.description")
    checked: root.showCount
    onToggled: checked => { root.showCount = checked; }
  }

  RowLayout {
    spacing: Style.marginL

    NLabel {
      label: pluginApi?.tr("settings.bar_icon.label")
      description: pluginApi?.tr("settings.bar_icon.description")
    }

    NText {
      text: root.barIcon
      color: Settings.data.colorSchemes.darkMode ? Color.mPrimary : Color.mOnPrimary
    }

    NIcon {
      icon: root.barIcon
      color: Settings.data.colorSchemes.darkMode ? Color.mPrimary : Color.mOnPrimary
    }

    NButton {
      text: pluginApi?.tr("settings.bar_icon.change_button")
      onClicked: changeIcon.open()
    }

    NIconPicker {
      id: changeIcon
      onIconSelected: icon => { root.barIcon = icon; }
    }
  }

  NToggle {
    label: pluginApi?.tr("settings.hide_bar_widget.label")
    description: pluginApi?.tr("settings.hide_bar_widget.description")
    checked: root.hideBarWidget
    onToggled: checked => { root.hideBarWidget = checked; }
  }

  NDivider {}

  NComboBox {
    label: pluginApi?.tr("settings.panel_position.label")
    description: pluginApi?.tr("settings.panel_position.description")
    currentKey: root.positionMode
    model: [
      { "key": "attached",      "name": "Attached to Dock" },
      { "key": "center",        "name": "Center Screen" },
      { "key": "top_left",      "name": "Top Left" },
      { "key": "top_right",     "name": "Top Right" },
      { "key": "bottom_left",   "name": "Bottom Left" },
      { "key": "bottom_right",  "name": "Bottom Right" }
    ]
    onSelected: key => root.positionMode = key
  }

  NDivider {}

  NTextInputButton {
    label: pluginApi?.tr("settings.notes_directory.label")
    description: pluginApi?.tr("settings.notes_directory.description")
    placeholderText: "/home/user/notes/"
    text: root.notesDirectory
    buttonIcon: "folder"
    buttonTooltip: pluginApi?.tr("settings.notes_directory.select")
    onInputEditingFinished: root.notesDirectory = text
    onButtonClicked: dirPicker.openFilePicker()
  }

  NFilePicker {
    id: dirPicker
    selectionMode: "directories"
    title: pluginApi?.tr("settings.notes_directory.picker_title")
    initialPath: root.notesDirectory || Quickshell.env("HOME")
    onAccepted: paths => {
      if (paths.length > 0) root.notesDirectory = paths[0];
    }
  }

  NDivider {}

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    Layout.topMargin: Style.marginL

    NLabel {
      label: pluginApi?.tr("settings.keyboard_shortcut.title")
      description: pluginApi?.tr("settings.keyboard_shortcut.description")
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: commandText.implicitHeight + Style.marginM * 2
      color: Color.mSurfaceVariant
      radius: Style.radiusM

      TextEdit {
        id: commandText
        anchors.fill: parent
        anchors.margins: Style.marginM
        text: "qs -c noctalia-shell ipc call plugin:simple-notes togglePanel"
        font.pointSize: Style.fontSizeS
        font.family: Settings.data.ui.fontFixed
        color: Color.mPrimary
        wrapMode: TextEdit.WrapAnywhere
        readOnly: true
        selectByMouse: true
        selectionColor: Color.mPrimary
        selectedTextColor: Color.mOnPrimary
      }
    }
  }

  function saveSettings() {
    if (!pluginApi) return;
    pluginApi.pluginSettings.showCountInBar = root.showCount;
    pluginApi.pluginSettings.barIcon = root.barIcon;
    pluginApi.pluginSettings.hideBarWidget = root.hideBarWidget;
    pluginApi.pluginSettings.positionMode = root.positionMode;
    pluginApi.pluginSettings.notesDirectory = root.notesDirectory;
    pluginApi.saveSettings();
  }
}
