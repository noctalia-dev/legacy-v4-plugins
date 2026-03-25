import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

import "utils/gistSync.js" as GistSync
import "utils/storage.js" as Storage

Item {
  id: root

  property var pluginApi: null
  property bool syncInProgress: false
  property bool lastSyncOk: false
  property string lastSyncMessage: ""
  property double lastSyncAt: 0
  property var expandedScreen: null
  property string expandedNoteId: ""
  signal notesChanged()

  // Internal cache for parsed and formatted notes
  property var _notesCache: []

  function getDisplayNotes() {
    if (_notesCache.length === 0) {
        _notesCache = _prepareNotes(loadStoredNotes());
    }
    return _notesCache;
  }

  function _prepareNotes(notes) {
    if (!Array.isArray(notes)) return [];
    
    for (var i = 0; i < notes.length; i++) {
      var note = notes[i];
      if (!note.color || note.color === "") {
        note.color = Storage.pickRandomColor();
      }
      note.noteColor = note.color;
      note.modifiedStr = Storage.formatDate(new Date(note.modified), root.pluginApi);
    }
    return notes;
  }


  function loadStoredNotes() {
    if (!pluginApi)
      return [];

    var stored = pluginApi.pluginSettings.notes;
    if (!stored || stored.length === 0)
      return [];

    try {
      var parsed = JSON.parse(stored);
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }

  function persistNotes(notes) {
    if (!pluginApi) {
      return;
    }

    _notesCache = _prepareNotes(notes);
    pluginApi.pluginSettings.notes = JSON.stringify(notes);
    pluginApi.saveSettings();

    notesChanged();
    syncNotesToGist(notes, true);
  }

  function saveNote(noteId, content, saveColor) {
    var notes = loadStoredNotes();
    var now = Date.now();
    var isNew = (!noteId || noteId.length === 0);

    if (isNew) {
      noteId = Storage.generateNoteId();
    }

    var finalColor = saveColor;
    var foundIndex = -1;
    var existingNote = null;
    for (var i = 0; i < notes.length; i++) {
      if (notes[i].noteId === noteId) {
        finalColor = notes[i].color || finalColor;
        foundIndex = i;
        existingNote = notes[i];
        break;
      }
    }

    var normalizedContent = content || "";
    var resolvedColor = finalColor || Storage.pickRandomColor();

    if (existingNote) {
      var existingContent = existingNote.content || "";
      var existingColor = existingNote.color || "";
      if (existingContent === normalizedContent && existingColor === resolvedColor) {
        return existingNote;
      }
    }

    var note = {
      noteId: noteId,
      content: normalizedContent,
      modified: now,
      color: resolvedColor
    };

    if (foundIndex >= 0) {
      notes[foundIndex] = note;
    } else {
      notes.unshift(note);
    }

    persistNotes(notes);
    return note;
  }

  function deleteNote(noteId) {
    var notes = loadStoredNotes();
    for (var i = 0; i < notes.length; i++) {
      if (notes[i].noteId === noteId) {
        notes.splice(i, 1);
        break;
      }
    }

    persistNotes(notes);

    if (expandedNoteId === noteId) {
      closeExpandedNote();
    }
  }

  function openExpandedNote(screen, noteId, content, noteColor) {
    expandedScreen = screen;
    expandedNoteId = noteId;
    expandedWindow.openFor(screen, noteId, content, noteColor || "#FFF9C4");
  }

  function closeExpandedNote() {
    expandedWindow.closeWindow();
    expandedScreen = null;
    expandedNoteId = "";
  }

  function hasSyncToken() {
    if (!pluginApi || !pluginApi.pluginSettings) {
      return false;
    }

    return ((pluginApi.pluginSettings.githubToken || "").trim().length > 0);
  }

  function syncNotesToGist(notes, silent) {
    if (!pluginApi) {
      return;
    }

    if (syncInProgress) {
      return;
    }

    var syncEnabled = pluginApi.pluginSettings.syncEnabled === true;
    if (!syncEnabled && silent !== false) {
      return;
    }

    if (!hasSyncToken()) {
      lastSyncOk = false;
      lastSyncMessage = pluginApi.tr("sync.errors.missing-token");
      lastSyncAt = Date.now();

      if (silent === true) {
        return;
      }
    }

    var syncNotes = notes;
    if (!Array.isArray(syncNotes)) {
      syncNotes = loadStoredNotes();
    }

    syncInProgress = true;
    lastSyncMessage = pluginApi.tr("sync.syncing");

    GistSync.syncNotes(pluginApi, syncNotes, function(success, message) {
      syncInProgress = false;
      lastSyncOk = success;
      lastSyncMessage = message || (success ? "Sync completed" : "Sync failed");
      lastSyncAt = Date.now();

      if (success) {
        if (silent !== true) {
          ToastService.showNotice(lastSyncMessage);
        }
      } else {
        ToastService.showError(lastSyncMessage);
      }
    });
  }

  function manualSync() {
    syncNotesToGist(loadStoredNotes(), false);
  }

  IpcHandler {
    target: "plugin:sticky-notes"

    function toggle() {
      if (!pluginApi) return;
      pluginApi.withCurrentScreen(function(screen) {
        if (screen) {
          pluginApi.togglePanel(screen);
        }
      });
    }
  }

  ExpandedPanelWindow {
    id: expandedWindow
    pluginApi: root.pluginApi

    onSaveRequested: function(noteId, content, noteColor) {
      root.saveNote(noteId, content, noteColor);
    }

    onNoteWindowClosed: {
      root.expandedScreen = null;
      root.expandedNoteId = "";
    }
  }
}
