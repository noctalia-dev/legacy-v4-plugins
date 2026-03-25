import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

import "components"

PanelWindow {
  id: root

  property ShellScreen screen: null
  property var pluginApi: null
  property string noteId: ""
  property string content: ""
  property string noteColor: "#FFF9C4"

  signal saveRequested(string noteId, string content, string noteColor)
  signal noteWindowClosed()

  anchors.top: true
  anchors.left: true
  anchors.right: true
  anchors.bottom: true
  visible: false
  color: "transparent"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.namespace: "noctalia-sticky-notes-expanded-" + (screen?.name || "unknown")
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  function openFor(targetScreen, targetNoteId, targetContent, targetColor) {
    screen = targetScreen;
    noteId = targetNoteId;
    content = targetContent;
    noteColor = targetColor || "#FFF9C4";
    visible = true;
  }

  function closeWindow() {
    contentItem.editing = false;
    visible = false;
    noteWindowClosed();
  }

  ExpandedNoteWindow {
    id: contentItem
    anchors.fill: parent
    visible: root.visible
    noteId: root.noteId
    content: root.content
    noteColor: root.noteColor
    pluginApi: root.pluginApi

    onSaveRequested: function(noteId, content, noteColor) {
      root.content = content;
      root.noteColor = noteColor || root.noteColor;
      root.saveRequested(noteId, content, noteColor);
    }

    onClosed: root.closeWindow()
  }
}
