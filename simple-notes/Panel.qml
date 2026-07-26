import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 700 * Style.uiScaleRatio
  property real contentPreferredHeight: 500 * Style.uiScaleRatio

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string positionMode: cfg.positionMode ?? defaults.positionMode ?? "attached"
  readonly property bool allowAttach: positionMode === "attached"

  readonly property bool panelAnchorHorizontalCenter: positionMode === "center"
  readonly property bool panelAnchorVerticalCenter: positionMode === "center"
  readonly property bool panelAnchorTop: positionMode === "top_left" || positionMode === "top_right"
  readonly property bool panelAnchorBottom: positionMode === "bottom_left" || positionMode === "bottom_right"
  readonly property bool panelAnchorLeft: positionMode === "top_left" || positionMode === "bottom_left"
  readonly property bool panelAnchorRight: positionMode === "top_right" || positionMode === "bottom_right"

  readonly property string notesDirectory: cfg.notesDirectory ?? defaults.notesDirectory ?? ""
  readonly property bool hasNotesDirectory: notesDirectory !== ""

  property string exportError: ""

  anchors.fill: parent

  property string viewMode: "list"
  property var currentNote: null
  property ListModel notesModel: ListModel {}

  FileView {
    id: fileExporter
    path: ""
    watchChanges: false
  }

  Component.onCompleted: {
    if (pluginApi) loadNotes();
  }

  onPluginApiChanged: {
    if (pluginApi) loadNotes();
  }

  function loadNotes() {
    notesModel.clear();
    var notes = cfg.notes || [];
    notes.sort((a, b) => new Date(b.modifiedAt) - new Date(a.modifiedAt));
    for (var i = 0; i < notes.length; i++) {
      if (notes[i].fileName === undefined) notes[i].fileName = "";
      notesModel.append(notes[i]);
    }
  }

  function sanitizeFileName(title) {
    if (!title) return "untitled.md";
    var name = title.toLowerCase()
      .replace(/[^a-z0-9\s-]/g, "")
      .replace(/\s+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "");
    if (!name) return "untitled.md";
    return name + ".md";
  }

  function exportNoteToFile(title, content, fileName) {
    if (!root.hasNotesDirectory) return;
    root.exportError = "";
    try {
      var dir = root.notesDirectory;
      if (!dir.endsWith("/")) dir += "/";
      fileExporter.path = dir + fileName;
      fileExporter.setText(content.endsWith("\n") ? content : content + "\n");
    } catch (e) {
      root.exportError = pluginApi?.tr("panel.export.error") ?? ("Failed to export note: " + e);
      Logger.e("simple-notes", "File export failed: " + e);
    }
  }

  function createNote() {
    root.currentNote = { id: null, title: "", content: "", fileName: "", modifiedAt: new Date().toISOString() };
    root.viewMode = "edit";
  }

  function editNote(noteId) {
    var notes = cfg.notes || [];
    var note = notes.find(n => n.id === noteId);
    if (note) {
      root.currentNote = { id: note.id, title: note.title, content: note.content, fileName: note.fileName || "", modifiedAt: note.modifiedAt };
      root.viewMode = "edit";
    }
  }

  function saveCurrentNote(title, content, fileName) {
    if (!pluginApi) return;
    var notes = pluginApi.pluginSettings.notes || [];
    var now = new Date().toISOString();
    var resolvedFileName = fileName || sanitizeFileName(title);

    if (root.currentNote.id === null) {
      notes.push({ id: Date.now().toString(), title: title || "Untitled Note", content: content, fileName: resolvedFileName, modifiedAt: now });
    } else {
      var idx = notes.findIndex(n => n.id === root.currentNote.id);
      if (idx >= 0) {
        notes[idx].title = title || "Untitled Note";
        notes[idx].content = content;
        notes[idx].fileName = resolvedFileName;
        notes[idx].modifiedAt = now;
      }
    }

    pluginApi.pluginSettings.notes = notes;
    pluginApi.pluginSettings.count = notes.length;
    pluginApi.saveSettings();

    if (root.hasNotesDirectory) exportNoteToFile(title || "Untitled Note", content, resolvedFileName);

    loadNotes();
    root.viewMode = "list";
    root.currentNote = null;
  }

  function deleteNote(noteId) {
    if (!pluginApi) return;
    var notes = pluginApi.pluginSettings.notes || [];
    var idx = notes.findIndex(n => n.id === noteId);
    if (idx >= 0) {
      notes.splice(idx, 1);
      pluginApi.pluginSettings.notes = notes;
      pluginApi.pluginSettings.count = notes.length;
      pluginApi.saveSettings();
      loadNotes();
    }
  }

  function deleteCurrentNote() {
    if (root.currentNote && root.currentNote.id) deleteNote(root.currentNote.id);
    root.viewMode = "list";
    root.currentNote = null;
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginL

      // Export error banner
      Rectangle {
        Layout.fillWidth: true
        visible: root.exportError !== ""
        color: Color.mErrorContainer
        radius: Style.radiusM
        implicitHeight: exportErrorText.implicitHeight + Style.marginS * 2

        NText {
          id: exportErrorText
          anchors.fill: parent
          anchors.margins: Style.marginS
          text: root.exportError
          color: Color.mOnErrorContainer
          wrapMode: Text.WordWrap
          font.pointSize: Style.fontSizeS
        }

        NIconButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.marginS
          icon: "x"
          onClicked: root.exportError = ""
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        // LIST VIEW
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          visible: root.viewMode === "list"
          spacing: Style.marginM

          RowLayout {
            spacing: Style.marginM

            NIcon {
              icon: "sticky-note"
              pointSize: Style.fontSizeL
            }

            NText {
              text: pluginApi?.tr("panel.header.title")
              font.pointSize: Style.fontSizeL
              font.weight: Font.Medium
              color: Color.mOnSurface
            }

            Item { Layout.fillWidth: true }

            NButton {
              text: pluginApi?.tr("panel.header.add_button")
              icon: "plus"
              onClicked: createNote()
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: notesModel.count === 0

            NText {
              text: pluginApi?.tr("panel.list.empty_message")
              color: Color.mOnSurfaceVariant
              anchors.centerIn: parent
              font.pointSize: Style.fontSizeM
            }
          }

          ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: notesModel.count > 0
            clip: true

            ListView {
              id: notesList
              model: root.notesModel
              spacing: Style.marginS
              boundsBehavior: Flickable.StopAtBounds
              flickableDirection: Flickable.VerticalFlick

              delegate: Rectangle {
                width: ListView.view.width
                height: cardContent.implicitHeight + Style.marginM * 2
                color: Color.mSurface
                radius: Style.radiusS

                property bool hovered: false

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: parent.hovered = true
                  onExited: parent.hovered = false
                  onClicked: editNote(model.id)
                }

                RowLayout {
                  id: cardContent
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.marginM
                  spacing: Style.marginM

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.marginS

                      NText {
                        text: model.title
                        font.weight: Font.Medium
                        font.pointSize: Style.fontSizeM
                        color: parent.parent.parent.hovered ? Color.mPrimary : Color.mOnSurface
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      NText {
                        text: new Date(model.modifiedAt).toLocaleDateString()
                        font.pointSize: Style.fontSizeS
                        color: Color.mOnSurfaceVariant
                      }
                    }

                    NText {
                      text: model.content.replace(/\n/g, " ")
                      font.pointSize: Style.fontSizeS
                      color: Color.mOnSurfaceVariant
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                      maximumLineCount: 1
                    }
                  }

                  NIconButton {
                    icon: "circle-x"
                    tooltipText: pluginApi?.tr("panel.editor.delete_button")
                    color: Color.mError
                    implicitWidth: Style.baseWidgetSize * 0.8
                    implicitHeight: Style.baseWidgetSize * 0.8
                    radius: Style.radiusM
                    opacity: 0.7
                    onEntered: opacity = 1.0
                    onExited: opacity = 0.7
                    onClicked: deleteNote(model.id)
                  }
                }
              }
            }
          }
        }

        // EDIT VIEW
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          visible: root.viewMode === "edit"
          spacing: Style.marginM

          RowLayout {
            spacing: Style.marginS

            NIconButton {
              icon: "arrow-left"
              onClicked: {
                root.viewMode = "list";
                root.currentNote = null;
              }
            }

            NText {
              text: root.currentNote && root.currentNote.id ? pluginApi?.tr("panel.editor.title_edit") : pluginApi?.tr("panel.editor.title_new")
              font.pointSize: Style.fontSizeL
              font.weight: Font.Medium
              color: Color.mOnSurface
            }

            Item { Layout.fillWidth: true }

            NButton {
              text: pluginApi?.tr("panel.editor.delete_button")
              visible: root.currentNote && root.currentNote.id !== null
              backgroundColor: Color.mError
              onClicked: deleteCurrentNote()
            }

            NButton {
              text: pluginApi?.tr("panel.editor.save_button")
              onClicked: saveCurrentNote(titleInput.text, contentInput.text, fileNameInput.text)
            }
          }

          NTextInput {
            id: titleInput
            Layout.fillWidth: true
            placeholderText: pluginApi?.tr("panel.editor.title_placeholder")
            text: root.currentNote ? root.currentNote.title : ""
          }

          RowLayout {
            Layout.fillWidth: true
            visible: root.hasNotesDirectory
            spacing: Style.marginS

            NText {
              text: pluginApi?.tr("panel.editor.filename_label")
              font.pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }

            NTextInput {
              id: fileNameInput
              Layout.fillWidth: true
              placeholderText: titleInput.text
                ? root.sanitizeFileName(titleInput.text)
                : pluginApi?.tr("panel.editor.filename_placeholder")
              text: root.currentNote ? (root.currentNote.fileName || "") : ""
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Color.mSurface
            radius: Style.radiusM

            ScrollView {
              anchors.fill: parent
              anchors.margins: Style.marginS

              TextArea {
                id: contentInput
                width: parent.width
                placeholderText: pluginApi?.tr("panel.editor.content_placeholder")
                placeholderTextColor: Color.mOnSurfaceVariant
                text: root.currentNote ? root.currentNote.content : ""
                wrapMode: TextEdit.Wrap
                color: Color.mOnSurface
                font.pointSize: Style.fontSizeM
                background: null
                selectByMouse: true
              }
            }
          }
        }
      }
    }
  }
}
