import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  // Local state
  property int panelWidth: pluginApi?.pluginSettings?.panelWidth ?? 600
  property int panelHeight: pluginApi?.pluginSettings?.panelHeight ?? 400
  property int fontSize: pluginApi?.pluginSettings?.fontSize ?? 14
  property string filePath: pluginApi?.pluginSettings?.filePath ?? ""
  property bool filePathWritable: true

  spacing: Style.marginM

  // Check file path writability
  Process {
    id: writeCheckProcess

    onExited: function(exitCode, exitStatus) {
      root.filePathWritable = (exitCode === 0);
    }
  }

  function checkFilePathWritability() {
    if (root.filePath === "") {
      root.filePathWritable = true;
      return;
    }

    // Check if file exists and is writable, or if parent directory is writable
    var testCmd = "if [ -e \"" + root.filePath + "\" ]; then " +
                  "[ -w \"" + root.filePath + "\" ]; " +
                  "else " +
                  "[ -w \"$(dirname \"" + root.filePath + "\")\" ]; " +
                  "fi";
    writeCheckProcess.exec(["sh", "-c", testCmd]);
  }

  function saveSettings() {
    if (pluginApi) {
      pluginApi.pluginSettings.panelWidth = root.panelWidth
      pluginApi.pluginSettings.panelHeight = root.panelHeight
      pluginApi.pluginSettings.fontSize = root.fontSize
      pluginApi.pluginSettings.filePath = root.filePath
      pluginApi.saveSettings();
    }
  }

  onFilePathChanged: {
    checkFilePathWritability();
  }

  // UI Components
  NLabel {
    label: pluginApi?.tr("settings.panel_dimensions.title") || "Panel Dimensions"
    description: pluginApi?.tr("settings.panel_dimensions.description") || "Configure the size of the scratchpad panel when it opens."
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginL

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NText {
        text: (pluginApi?.tr("settings.panel_dimensions.width") || "Width") + ": " + root.panelWidth + "px"
        pointSize: Style.fontSizeM
      }

      NSlider {
        id: widthSlider
        Layout.fillWidth: true
        from: 400
        to: 1200
        value: root.panelWidth
        stepSize: 50
        onMoved: {
          root.panelWidth = Math.round(value);
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NText {
        text: (pluginApi?.tr("settings.panel_dimensions.height") || "Height") + ": " + root.panelHeight + "px"
        pointSize: Style.fontSizeM
      }

      NSlider {
        id: heightSlider
        Layout.fillWidth: true
        from: 300
        to: 900
        value: root.panelHeight
        stepSize: 50
        onMoved: {
          root.panelHeight = Math.round(value);
        }
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    Layout.topMargin: Style.marginM

    NTextInputButton {
      label: pluginApi?.tr("settings.file_storage.title") || "File Storage"
      description: pluginApi?.tr("settings.file_storage.description") || "Optionally save scratchpad content to a file instead of plugin storage. Leave empty to use default storage."
      placeholderText: "/home/user/notes.txt"
      text: root.filePath
      buttonIcon: "file"
      buttonTooltip: pluginApi?.tr("settings.file_storage.select") || "Select file"
      onInputEditingFinished: root.filePath = text
      onButtonClicked: filePicker.openFilePicker()
    }

    NText {
      visible: root.filePath !== "" && !root.filePathWritable
      text: pluginApi?.tr("settings.file_storage.not_writable") || "⚠ Warning: No write permission for this location"
      pointSize: Style.fontSizeS
      color: Color.mError
      Layout.fillWidth: true
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    Layout.topMargin: Style.marginM

    NText {
      text: pluginApi?.tr("settings.text_appearance.title") || "Text Appearance"
      pointSize: Style.fontSizeL
      font.weight: Font.DemiBold
    }

    NText {
      text: (pluginApi?.tr("settings.text_appearance.font_size") || "Font Size") + ": " + root.fontSize + "px"
      pointSize: Style.fontSizeM
    }

    NSlider {
      id: fontSizeSlider
      Layout.fillWidth: true
      from: 10
      to: 24
      value: root.fontSize
      stepSize: 1
      onMoved: {
        root.fontSize = Math.round(value)
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    Layout.topMargin: Style.marginL

    NLabel {
      label: pluginApi?.tr("settings.keyboard_shortcut.title") || "Keyboard Shortcut"
      description: pluginApi?.tr("settings.keyboard_shortcut.description") || "Toggle the scratchpad panel with this command:"
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
        text: "qs -c noctalia-shell ipc call plugin togglePanel notes-scratchpad"
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

  NFilePicker {
    id: filePicker
    selectionMode: "files"
    title: pluginApi?.tr("settings.file_storage.picker_title") || "Choose file for scratchpad"
    initialPath: root.filePath || Quickshell.env("HOME")
    onAccepted: paths => {
      if (paths.length > 0) {
        root.filePath = paths[0]
      }
    }
  }
}
