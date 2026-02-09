import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: (pluginApi?.pluginSettings?.panelWidth ?? 600) * Style.uiScaleRatio
  property real contentPreferredHeight: (pluginApi?.pluginSettings?.panelHeight ?? 400) * Style.uiScaleRatio
  readonly property bool allowAttach: true
  anchors.fill: parent

  // File storage path (if configured)
  property string filePath: pluginApi?.pluginSettings?.filePath ?? ""
  property bool useFileStorage: filePath !== ""

  // Local state for the text content
  property string textContent: ""
  property int fontSize: pluginApi?.pluginSettings?.fontSize ?? 14
  property bool useMonospace: pluginApi?.pluginSettings?.useMonospace ?? false
  property int savedCursorPosition: pluginApi?.pluginSettings?.cursorPosition ?? 0
  property real savedScrollX: pluginApi?.pluginSettings?.scrollPositionX ?? 0
  property real savedScrollY: pluginApi?.pluginSettings?.scrollPositionY ?? 0
  property bool restoringState: false

  // FileView for external file storage
  FileView {
    id: externalFile
    path: root.filePath
    watchChanges: false

    onLoaded: {
      if (root.useFileStorage) {
        root.textContent = text() || "";
      }
    }

    onLoadFailed: function(error) {
      if (error === 2) {
        // File doesn't exist yet, will be created on save
        Logger.d("NotesScratchpad", "File doesn't exist yet:", root.filePath);
      } else {
        Logger.w("NotesScratchpad", "Failed to load file:", root.filePath, "error:", error);
      }
    }
  }

  // Auto-save timer
  Timer {
    id: saveTimer
    interval: 500
    repeat: false
    onTriggered: {
      if (pluginApi && !restoringState) {
        saveContent();
      }
    }
  }

  function saveContent() {
    if (!pluginApi) return;

    if (root.useFileStorage) {
      // Save to external file
      try {
        // Always ensure the content ends with a newline
        externalFile.setText(root.textContent.endsWith("\n") ? root.textContent : root.textContent + "\n");
      } catch (e) {
        Logger.e("NotesScratchpad", "Failed to save to file:", e);
      }
    } else {
      // Save to plugin settings
      pluginApi.pluginSettings.scratchpadContent = root.textContent;
    }

    // Always save cursor and scroll positions to settings
    pluginApi.pluginSettings.cursorPosition = textArea.cursorPosition;
    pluginApi.pluginSettings.scrollPositionX = scrollView.ScrollBar.horizontal.position;
    pluginApi.pluginSettings.scrollPositionY = scrollView.ScrollBar.vertical.position;
    pluginApi.saveSettings();
  }

  onTextContentChanged: {
    if (!restoringState) {
      saveTimer.restart();
    }
  }

  onFilePathChanged: {
    // Reload content when file path changes
    if (useFileStorage) {
      externalFile.reload();
    }
  }

  Component.onCompleted: {
    restoringState = true;
    
    if (pluginApi) {
      // Load content based on storage mode
      if (root.useFileStorage) {
        externalFile.reload();
      } else {
        textContent = pluginApi.pluginSettings.scratchpadContent || "";
      }
      
      savedCursorPosition = pluginApi.pluginSettings.cursorPosition ?? 0;
      savedScrollX = pluginApi.pluginSettings.scrollPositionX ?? 0;
      savedScrollY = pluginApi.pluginSettings.scrollPositionY ?? 0;
    }
    
    Qt.callLater(() => {
      textArea.forceActiveFocus();
      textArea.cursorPosition = savedCursorPosition;
      scrollView.ScrollBar.horizontal.position = savedScrollX;
      scrollView.ScrollBar.vertical.position = savedScrollY;
      restoringState = false;
    });
  }

  Component.onDestruction: {
    // Save everything when the panel is closed
    if (pluginApi) {
      saveContent();
    }
  }

  onPluginApiChanged: {
    if (pluginApi) {
      textContent = pluginApi.pluginSettings.scratchpadContent || "";
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"
    radius: Style.radiusL

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIcon {
          icon: "file-text"
          pointSize: Style.fontSizeL
        }

        NText {
          text: {
            if (root.useFileStorage && root.filePath) {
              var parts = root.filePath.split("/");
              return parts[parts.length - 1];
            }
            return pluginApi?.tr("panel.header.title") || "Scratchpad";
          }
          pointSize: Style.fontSizeL
          font.weight: Font.Bold
          Layout.fillWidth: true
        }

        NIconButton {
          icon: "x"
          onClicked: {
            if (pluginApi) {
              pluginApi.closePanel(pluginApi.panelOpenScreen)
            }
          }
        }
      }

      // Main text area
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusM
        border.color: Color.mOutline
        border.width: 1

        NScrollView {
          id: scrollView
          anchors.fill: parent
          anchors.margins: Style.marginM
          handleWidth: 5

          ScrollBar.horizontal.onPositionChanged: {
            if (!restoringState) saveTimer.restart();
          }
          ScrollBar.vertical.onPositionChanged: {
            if (!restoringState) saveTimer.restart();
          }

          TextArea {
            id: textArea
            text: root.textContent
            placeholderText: pluginApi?.tr("panel.placeholder") || "Start typing your notes here..."
            wrapMode: TextArea.Wrap
            selectByMouse: true
            color: Color.mOnSurface
            font.pixelSize: root.fontSize
            font.family: root.useMonospace ? Settings.data.ui.fontFixed : Settings.data.ui.fontDefault
            background: Item {}
            focus: true

            onTextChanged: {
              if (text !== root.textContent) {
                root.textContent = text;
              }
            }

            onCursorPositionChanged: {
              if (!restoringState) saveTimer.restart();
            }
          }
        }
      }

      // Character count
      NText {
        text: {
          var chars = textArea.text.length;
          var words = textArea.text.trim().split(/\s+/).filter(w => w.length > 0).length;
          var charText = pluginApi?.tr("panel.stats.characters") || "characters";
          var wordText = pluginApi?.tr("panel.stats.words") || "words";
          return chars + " " + charText + " · " + words + " " + wordText;
        }
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        Layout.alignment: Qt.AlignRight
      }
    }
  }
}
