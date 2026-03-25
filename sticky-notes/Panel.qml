import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import "components"
import "utils/storage.js" as Storage

// Panel Component — Main sticky-note interface
Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null

  // SmartPanel geometry
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 420 * Style.uiScaleRatio
  
  // Calculate dynamic height based on NoteList content, bounded by available screen height.
  property real contentPreferredHeight: {
      var padding = Style.marginM * 2; // Assuming ~24px total vertical padding in panel Container
      var target = (noteList.listContentHeight || 200) + padding;
      var maxH = Screen.desktopAvailableHeight ? (Screen.desktopAvailableHeight - 100 * Style.uiScaleRatio) : (1000 * Style.uiScaleRatio);
      var minH = 200 * Style.uiScaleRatio;
      return Math.max(minH, Math.min(target, maxH));
  }
  
  readonly property bool allowAttach: true

  anchors.fill: parent
  focus: true

  Component.onCompleted: loadNotes()

  Keys.onPressed: (event) => {
    if (event.key === Qt.Key_Escape && noteList.hasActiveEditor) {
      noteList.saveActiveEditor();
      event.accepted = true;
    } else if (event.key === Qt.Key_Escape && noteList.hasSelectedNote) {
      noteList.clearSelection();
      event.accepted = true;
    }
  }

  Keys.onShortcutOverride: (event) => {
    if (event.key !== Qt.Key_Escape) return;

    if (noteList.hasActiveEditor) {
      noteList.saveActiveEditor();
      event.accepted = true;
    } else if (noteList.hasSelectedNote) {
      noteList.clearSelection();
      event.accepted = true;
    }
  }

  // ── Notes Model (ListModel for proper Repeater updates) ──
  ListModel { id: notesModel }

  onVisibleChanged: {
    if (visible) loadNotes();
  }

  onPluginApiChanged: {
    if (pluginApi) loadNotes();
  }

  // ── Timestamp auto-refresh timer (#1) ──
  Timer {
    id: timestampRefreshTimer
    interval: 60000 // 1 minute
    running: root.visible
    repeat: true
    onTriggered: refreshTimestamps()
  }

  function refreshTimestamps() {
    for (var i = 0; i < notesModel.count; i++) {
      var item = notesModel.get(i);
      var newStr = Storage.formatDate(new Date(item.modified), root.pluginApi);
      if (item.modifiedStr !== newStr) {
        notesModel.setProperty(i, "modifiedStr", newStr);
      }
    }
  }

  // ── Functions ──────────────────────────────────────────

  function loadNotes() {
    if (!root.pluginApi || !root.pluginApi.mainInstance) return;

    var notes = root.pluginApi.mainInstance.getDisplayNotes();
    
    // Simple check: if count is same and it's not empty, we might skip full reload 
    // but for now let's at least check if we actually have different data.
    // A better way is to compare JSON strings of the raw data.
    var currentNotesJson = JSON.stringify(root.pluginApi.mainInstance.loadStoredNotes());
    if (root._lastLoadedJson === currentNotesJson) return;
    root._lastLoadedJson = currentNotesJson;

    notesModel.clear();
    for (var i = 0; i < notes.length; i++) {
      notesModel.append(notes[i]);
    }
  }

  property string _lastLoadedJson: ""

  function saveNote(noteId, content, saveColor) {
    if (root.pluginApi?.mainInstance) {
      root.pluginApi.mainInstance.saveNote(noteId, content, saveColor);
    }
    loadNotes();
  }

  function deleteNote(noteId) {
    if (root.pluginApi?.mainInstance) {
      root.pluginApi.mainInstance.deleteNote(noteId);
    }
    loadNotes();
  }

  // ── UI ─────────────────────────────────────────────────

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    NoteList {
      id: noteList
      anchors.fill: parent
      anchors.margins: Style.marginM
      pluginApi: root.pluginApi
      notesModel: notesModel

      onSaveRequested: function(noteId, content, saveColor) {
        root.saveNote(noteId, content, saveColor);
      }

      onDeleteRequested: function(noteId) {
        root.deleteNote(noteId);
      }

      onExpandRequested: function(noteId, content, noteColor) {
        if (root.pluginApi?.mainInstance && root.pluginApi?.panelOpenScreen) {
          root.pluginApi.mainInstance.openExpandedNote(root.pluginApi.panelOpenScreen, noteId, content, noteColor);
        }
      }
    }

    Connections {
      target: root.pluginApi?.mainInstance || null

      function onNotesChanged() {
        root.loadNotes();
      }
    }
  }
}
