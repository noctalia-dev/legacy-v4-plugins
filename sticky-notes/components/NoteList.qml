import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

import "../utils/storage.js" as Storage

Item {
  id: root

  required property var pluginApi
  required property var notesModel // ListModel from Panel
  focus: true

  signal saveRequested(string noteId, string content, string saveColor)
  signal deleteRequested(string noteId)
  signal expandRequested(string noteId, string content, string noteColor)

  // Editing state
  property string newNoteColor: ""
  property int editingIndex: -1
  property string editingNoteId: ""
  property string editingContent: ""
  property bool creatingNew: false
  property string selectedNoteId: ""
  readonly property bool hasActiveEditor: creatingNew || editingIndex >= 0
  readonly property bool hasSelectedNote: selectedNoteId.length > 0

  // Provide actual total content height (grid + spacing + top action row)
  property real listContentHeight: gridFlow.height + (36 * Style.uiScaleRatio) 
  readonly property real scrollBarReserve: 12 * Style.uiScaleRatio
  readonly property bool hasVerticalOverflow: {
    var scrollTarget = root.getScrollTarget();
    return !!scrollTarget && (scrollTarget.contentHeight > scrollTarget.height + 1);
  }

  function startEditing(index, noteId, content) {
    root.forceActiveFocus();
    root.selectedNoteId = noteId;
    root.editingNoteId = noteId;
    root.editingContent = content;
    root.creatingNew = false;
    root.editingIndex = index;
  }

  function startCreating() {
    root.forceActiveFocus();
    root.selectedNoteId = "";
    root.editingIndex = -2;
    root.editingNoteId = "";
    root.editingContent = "";
    root.newNoteColor = Storage.pickRandomColor();
    root.creatingNew = true;
    var scrollTarget = root.getScrollTarget();
    if (scrollTarget) scrollTarget.contentY = 0;
  }

  function finishEditing(content, saveColor) {
    if (root.editingIndex === -1 && !root.creatingNew) return;

    // Empty content protection (#16)
    if (!content || content.trim().length === 0) {
      cancelEditing();
      return;
    }

    root.saveRequested(root.editingNoteId, content, saveColor || "");
    root.editingIndex = -1;
    root.editingNoteId = "";
    root.editingContent = "";
    root.creatingNew = false;
    root.newNoteColor = "";
  }

  function cancelEditing() {
    root.editingIndex = -1;
    root.editingNoteId = "";
    root.editingContent = "";
    root.creatingNew = false;
    root.newNoteColor = "";
  }

  function saveActiveEditor() {
    if (root.creatingNew) {
      root.finishEditing(newNoteCard.getText(), root.newNoteColor);
      return;
    }

    if (root.editingIndex < 0) return;

    var activeCard = noteRepeater.itemAt(root.editingIndex);
    if (!activeCard) return;

    root.finishEditing(activeCard.getEditedText(), activeCard.noteColor);
  }

  function openExpanded(index, noteId, content, noteColor) {
    if (root.hasActiveEditor && root.editingNoteId !== noteId) {
      root.saveActiveEditor();
    }

    root.expandRequested(noteId, content, noteColor || "#FFF9C4");
  }

  function selectNote(noteId) {
    root.forceActiveFocus();
    if (root.selectedNoteId === noteId) {
      return;
    }
    root.selectedNoteId = noteId;
  }

  function clearSelection() {
    root.selectedNoteId = "";
  }

  function startEditingSelectedNote() {
    if (!root.hasSelectedNote || root.hasActiveEditor) return;

    for (var i = 0; i < root.notesModel.count; i++) {
      var item = root.notesModel.get(i);
      if (item.noteId !== root.selectedNoteId) continue;
      root.startEditing(i, item.noteId, item.content || "");
      return;
    }
  }

  function openExpandedSelectedNote() {
    if (!root.hasSelectedNote || root.hasActiveEditor) return;

    for (var i = 0; i < root.notesModel.count; i++) {
      var item = root.notesModel.get(i);
      if (item.noteId !== root.selectedNoteId) continue;
      root.openExpanded(i, item.noteId, item.content || "", item.noteColor || "#FFF9C4");
      return;
    }
  }

  Keys.onPressed: (event) => {
    if (event.key === Qt.Key_Escape && root.hasActiveEditor) {
      root.saveActiveEditor();
      event.accepted = true;
    } else if (event.key === Qt.Key_Escape && root.hasSelectedNote) {
      root.clearSelection();
      event.accepted = true;
    } else if (event.key === Qt.Key_N && !root.hasSelectedNote && !root.hasActiveEditor) {
      root.startCreating();
      event.accepted = true;
    } else if (event.key === Qt.Key_E && root.hasSelectedNote && !root.hasActiveEditor) {
      root.startEditingSelectedNote();
      event.accepted = true;
    } else if (event.key === Qt.Key_F && root.hasSelectedNote && !root.hasActiveEditor) {
      root.openExpandedSelectedNote();
      event.accepted = true;
    }
  }

  Keys.onShortcutOverride: (event) => {
    if (event.key !== Qt.Key_Escape) return;

    if (root.hasActiveEditor) {
      root.saveActiveEditor();
      event.accepted = true;
    } else if (root.hasSelectedNote) {
      root.clearSelection();
      event.accepted = true;
    }
  }

  function scrollListByDelta(deltaY) {
    var scrollTarget = root.getScrollTarget();
    if (!scrollTarget) return;

    var maxY = Math.max(0, scrollTarget.contentHeight - scrollTarget.height);
    if (maxY <= 0) return;

    var targetY = scrollTarget.contentY - deltaY;
    scrollTarget.contentY = Math.max(0, Math.min(maxY, targetY));
  }

  function getScrollTarget() {
    if (gridScrollView && gridScrollView.contentItem &&
        gridScrollView.contentItem.contentY !== undefined &&
        gridScrollView.contentItem.contentHeight !== undefined) {
      return gridScrollView.contentItem;
    }
    if (gridScrollView && gridScrollView.flickableItem &&
        gridScrollView.flickableItem.contentY !== undefined &&
        gridScrollView.flickableItem.contentHeight !== undefined) {
      return gridScrollView.flickableItem;
    }
    return null;
  }

  function syncSelectionWithModel() {
    if (!root.selectedNoteId) return;

    for (var i = 0; i < root.notesModel.count; i++) {
      var item = root.notesModel.get(i);
      if (item.noteId === root.selectedNoteId) return;
    }

    root.clearSelection();
  }

  Shortcut {
    sequence: "Escape"
    enabled: root.hasActiveEditor || root.hasSelectedNote
    // Panel-local handling is more reliable than application-global shortcuts
    // in Quickshell plugin surfaces.
    context: Qt.WindowShortcut
    onActivated: {
      if (root.hasActiveEditor) {
        root.saveActiveEditor();
      } else {
        root.clearSelection();
      }
    }
  }

  Shortcut {
    sequence: "E"
    enabled: root.hasSelectedNote && !root.hasActiveEditor
    context: Qt.WindowShortcut
    onActivated: root.startEditingSelectedNote()
  }

  Shortcut {
    sequence: "F"
    enabled: root.hasSelectedNote && !root.hasActiveEditor
    context: Qt.WindowShortcut
    onActivated: root.openExpandedSelectedNote()
  }

  Shortcut {
    sequence: "N"
    enabled: !root.hasSelectedNote && !root.hasActiveEditor
    context: Qt.WindowShortcut
    onActivated: root.startCreating()
  }

  Connections {
    target: root.notesModel
    function onCountChanged() {
      root.syncSelectionWithModel();
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginS

    // New note button row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      Item { Layout.fillWidth: true }

      NIconButton {
        icon: "add"
        baseSize: 28 * Style.uiScaleRatio
        colorBg: Color.mPrimary
        colorFg: Color.mOnPrimary
        customRadius: 14 * Style.uiScaleRatio
        tooltipText: root.pluginApi?.tr("notes.new")

        onClicked: {
          root.startCreating();
        }
      }
    }

    // Sticky notes list
    Item {
      id: listContainer
      Layout.fillWidth: true
      Layout.fillHeight: true

      HoverHandler {
        id: listHover
      }

      NScrollView {
        id: gridScrollView
        anchors.fill: parent
        showGradientMasks: false
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: (root.hasVerticalOverflow && listHover.hovered)
          ? ScrollBar.AsNeeded
          : ScrollBar.AlwaysOff

        Column {
          id: gridFlow
          width: Math.max(0, gridScrollView.width - (root.hasVerticalOverflow ? root.scrollBarReserve : 0))
          spacing: Style.marginS

          // New note card (when creating)
          NewNoteCard {
            id: newNoteCard
            visible: root.creatingNew
            width: gridFlow.width
            noteColor: root.newNoteColor || "#FFF9C4"
            pluginApi: root.pluginApi

            onSaveClicked: function(content, color) {
              root.finishEditing(content, color);
            }

            onCancelClicked: {
              root.cancelEditing();
            }
          }

          // Existing notes
          Repeater {
            id: noteRepeater
            model: root.notesModel

            delegate: NoteCard {
              editingIndex: root.editingIndex
              editingContent: root.editingContent
              pluginApi: root.pluginApi
              isSelected: root.selectedNoteId === noteId
              width: gridFlow.width

              onSaveClicked: function(editedContent, editedColor) {
                root.finishEditing(editedContent, editedColor);
              }

              onEditClicked: {
                root.startEditing(index, noteId, content);
              }

              onDeleteClicked: {
                if (root.selectedNoteId === noteId) {
                  root.clearSelection();
                }
                root.deleteRequested(noteId);
              }

              onCancelClicked: {
                root.cancelEditing();
              }

              onExpandClicked: {
                root.openExpanded(index, noteId, content, noteColor);
              }

              onSelectRequested: {
                root.selectNote(noteId);
              }

              onClearSelectionRequested: {
                root.clearSelection();
              }

              onRequestListScroll: function(deltaY) {
                root.scrollListByDelta(deltaY);
              }
            }
          }
        }
      }

      // Empty state
      EmptyState {
        anchors.centerIn: parent
        width: parent.width
        height: implicitHeight
        visible: root.notesModel.count === 0 && !root.creatingNew
        pluginApi: root.pluginApi
      }
    }
  }
}
