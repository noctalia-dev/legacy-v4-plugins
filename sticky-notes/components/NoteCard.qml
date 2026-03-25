import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

import "../utils/markdown.js" as Markdown

Rectangle {
  id: noteCard

  // Model roles — auto-bound by Repeater
  required property int index
  required property string noteId
  required property string content
  required property string noteColor
  required property string modifiedStr

  // Parent-provided state
  property int editingIndex: -1
  property string editingContent: ""
  property var pluginApi: null
  property bool isSelected: false

  // Computed
  property bool isEditing: editingIndex === index
  property bool confirmingDelete: false
  property string renderedContent: ""
  property bool showDisplayScrollbar: false
  property bool showEditScrollbar: false
  readonly property real footerHeight: 28 * Style.uiScaleRatio
  readonly property real footerActionWidth: (28 * 4 + 2 * 3) * Style.uiScaleRatio
  readonly property real minEditHeight: 200 * Style.uiScaleRatio
  readonly property real previewHeight: Math.min(
    Math.max(
      100 * Style.uiScaleRatio,
      noteContent.contentHeight + noteCard.footerHeight + (Style.marginM * 2) + Style.marginXS
    ),
    300 * Style.uiScaleRatio
  )

  onContentChanged: updateRendered()
  onNoteColorChanged: updateRendered()
  Component.onCompleted: {
    updateRendered();
    updateDisplayScrollInteractivity();
    updateEditScrollInteractivity();
  }
  onHeightChanged: {
    updateDisplayScrollInteractivity();
    updateEditScrollInteractivity();
  }
  onIsSelectedChanged: {
    updateDisplayScrollInteractivity();
    updateEditScrollInteractivity();
  }

  function updateRendered() {
    renderedContent = Markdown.render(noteCard.content || "", { noteColor: noteCard.noteColor || "#FFF9C4" });
  }

  // Signals
  signal saveClicked(string editedContent, string editedColor)
  signal editClicked()
  signal deleteClicked()
  signal cancelClicked()
  signal expandClicked()
  signal selectRequested()
  signal clearSelectionRequested()
  signal requestListScroll(real deltaY)

  HoverHandler { id: cardHover }

  width: parent ? parent.width : 200
  height: isEditing
    ? Math.max(noteCard.minEditHeight, noteCard.previewHeight)
    : noteCard.previewHeight
  color: noteCard.noteColor || "#FFF9C4"
  radius: Style.radiusM
  border.color: isEditing
    ? (editTextArea.activeFocus ? Qt.darker(Color.mPrimary, 1.35) : Color.mPrimary)
    : (isSelected ? Color.mPrimary : Qt.darker(noteCard.noteColor || "#FFF9C4", 1.06))
  border.width: isEditing
    ? Style.borderM
    : (isSelected ? (Style.borderM + Style.borderS) : Style.borderS)

  Behavior on border.color { ColorAnimation { duration: 150 } }
  Behavior on border.width { NumberAnimation { duration: 150 } }
  Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

  Shortcut {
    sequence: "Escape"
    enabled: noteCard.isSelected && !noteCard.isEditing
    context: Qt.WindowShortcut
    onActivated: noteCard.clearSelectionRequested()
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0)
    radius: noteCard.radius
    border.color: Color.mPrimary
    border.width: (!noteCard.isEditing && noteCard.isSelected) ? Style.borderS : 0
    visible: !noteCard.isEditing && noteCard.isSelected
    z: 180
  }

  // Shadow
  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 2
    anchors.leftMargin: 2
    z: -1
    color: Qt.rgba(0, 0, 0, 0.08)
    radius: Style.radiusM
  }

  // ── Display mode ──
  ColumnLayout {
    id: noteContentCol
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginXS
    visible: !noteCard.isEditing && !noteCard.confirmingDelete

    NScrollView {
      id: noteScrollView
      Layout.fillWidth: true
      Layout.fillHeight: true
      // Keep wheel routing controlled by noteCard.WheelHandler so we can
      // preserve "selected-note first, then list" behavior.
      wheelScrollMultiplier: 1.0
      reserveScrollbarSpace: false
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: noteCard.showDisplayScrollbar ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
      gradientColor: noteCard.noteColor || "#FFF9C4"

      Item {
        id: noteScrollContent
        width: noteContentCol.width
        implicitHeight: Math.ceil(noteContent.contentHeight) + 1

        TextEdit {
          id: noteContent
          width: parent.width
          height: contentHeight
          text: noteCard.renderedContent
          textFormat: TextEdit.RichText
          font.pointSize: Style.fontSizeS * Style.uiScaleRatio
          color: "#37474F"
          wrapMode: TextEdit.Wrap
          readOnly: true
          selectByMouse: true
          activeFocusOnTab: false
          visible: (noteCard.content || "").length > 0

          onLinkActivated: (link) => Qt.openUrlExternally(link)
          onContentHeightChanged: {
            noteCard.updateDisplayScrollInteractivity();
            noteCard.updateEditScrollInteractivity();
          }

          Keys.onShortcutOverride: (event) => {
            if (event.key !== Qt.Key_Escape || !noteCard.isSelected || noteCard.isEditing) return;
            noteCard.clearSelectionRequested();
            event.accepted = true;
          }
        }

        // Ensure clicking content area also selects this card.
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton
          propagateComposedEvents: true
          onPressed: (mouse) => {
            noteCard.selectRequested();
            mouse.accepted = false;
          }
          onWheel: (wheel) => noteCard.handleWheelRouting(wheel)
        }
      }
    }

    WheelHandler {
      onWheel: (wheel) => noteCard.handleWheelRouting(wheel)
    }

    RowLayout {
      id: footerRow
      Layout.fillWidth: true
      Layout.minimumHeight: noteCard.footerHeight
      Layout.preferredHeight: noteCard.footerHeight
      Layout.maximumHeight: noteCard.footerHeight
      Layout.rightMargin: Style.marginXS
      spacing: Style.marginXS

      NText {
        Layout.alignment: Qt.AlignVCenter
        text: noteCard.isSelected
          ? noteCard.pluginApi?.tr("notes.hint-unselect")
          : noteCard.pluginApi?.tr("notes.hint-click-select")
        visible: noteCard.isSelected || (!noteCard.isSelected && cardHover.hovered)
        font.pointSize: (Style.fontSizeXS - 1) * Style.uiScaleRatio
        color: Qt.rgba(0, 0, 0, 0.35)
      }

      Item { Layout.fillWidth: true }

      Item {
        id: footerRightSlot
        Layout.alignment: Qt.AlignVCenter
        Layout.minimumWidth: noteCard.footerActionWidth
        Layout.preferredWidth: noteCard.footerActionWidth
        Layout.maximumWidth: noteCard.footerActionWidth
        Layout.fillHeight: true

        NText {
          id: timestampLabel
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: noteCard.modifiedStr || ""
          font.pointSize: (Style.fontSizeXS - 1) * Style.uiScaleRatio
          color: Qt.rgba(0, 0, 0, 0.35)
          opacity: cardHover.hovered ? 0.0 : 1.0
          Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        TextEdit {
          id: hiddenCopyHelper
          visible: false
          text: noteCard.content
        }

        Row {
          id: actionRow
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          opacity: cardHover.hovered ? 1.0 : 0.0
          enabled: cardHover.hovered
          Behavior on opacity { NumberAnimation { duration: 120 } }

          NIconButton {
            icon: "arrow-up-left"
            baseSize: 28 * Style.uiScaleRatio
            customRadius: Style.iRadiusL
            colorBg: Qt.rgba(0, 0, 0, 0.06)
            colorBgHover: Qt.rgba(0, 0, 0, 0.12)
            colorFg: "#37474F"
            colorFgHover: "#37474F"
            colorBorder: "transparent"
            colorBorderHover: "transparent"

            onClicked: noteCard.expandClicked()
          }

          NIconButton {
            id: copyBtn
            icon: "copy"
            baseSize: 28 * Style.uiScaleRatio
            customRadius: Style.iRadiusL
            colorBg: Qt.rgba(0, 0, 0, 0.06)
            colorBgHover: Qt.rgba(0, 0, 0, 0.12)
            colorFg: "#37474F"
            colorFgHover: "#37474F"
            colorBorder: "transparent"
            colorBorderHover: "transparent"

            onClicked: {
              hiddenCopyHelper.selectAll();
              hiddenCopyHelper.copy();
              hiddenCopyHelper.deselect();
              copyBtn.icon = "copy-check";
              resetCopyIconTimer.start();
              ToastService.showNotice(noteCard.pluginApi?.tr("notes.copied"));
            }

            Timer {
              id: resetCopyIconTimer
              interval: 1500
              onTriggered: copyBtn.icon = "copy"
            }
          }

          NIconButton {
            icon: "pencil"
            baseSize: 28 * Style.uiScaleRatio
            customRadius: Style.iRadiusL
            colorBg: Qt.rgba(0, 0, 0, 0.06)
            colorBgHover: Qt.rgba(0, 0, 0, 0.12)
            colorFg: "#37474F"
            colorFgHover: "#37474F"
            colorBorder: "transparent"
            colorBorderHover: "transparent"

            onClicked: noteCard.editClicked()
          }

          NIconButton {
            icon: "trash"
            baseSize: 28 * Style.uiScaleRatio
            customRadius: Style.iRadiusL
            colorBg: Qt.rgba(0, 0, 0, 0.06)
            colorBgHover: Qt.rgba(0.8, 0, 0, 0.15)
            colorFg: "#C62828"
            colorFgHover: "#C62828"
            colorBorder: "transparent"
            colorBorderHover: "transparent"

            onClicked: noteCard.confirmingDelete = true
          }
        }
      }
    }
  }

  // ── Delete confirmation overlay (#5) ──
  Rectangle {
    anchors.fill: parent
    visible: noteCard.confirmingDelete
    color: Qt.rgba(0, 0, 0, 0.55)
    radius: noteCard.radius
    z: 200

    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.marginM

      NText {
        Layout.alignment: Qt.AlignHCenter
        text: noteCard.pluginApi?.tr("notes.delete-confirm")
        color: "white"
        font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      }

      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.marginM

        NButton {
          width: 64 * Style.uiScaleRatio
          height: 30 * Style.uiScaleRatio
          buttonRadius: Style.radiusS
          backgroundColor: Qt.rgba(1, 1, 1, 0.15)
          hoverColor: Qt.rgba(1, 1, 1, 0.3)
          textColor: "white"
          textHoverColor: "white"
          text: noteCard.pluginApi?.tr("notes.cancel")
          fontSize: Style.fontSizeS * Style.uiScaleRatio

          onClicked: noteCard.confirmingDelete = false
        }

        NButton {
          width: 64 * Style.uiScaleRatio
          height: 30 * Style.uiScaleRatio
          buttonRadius: Style.radiusS
          backgroundColor: "#C62828"
          hoverColor: "#E53935"
          textColor: "white"
          textHoverColor: "white"
          text: noteCard.pluginApi?.tr("editor.delete")
          fontSize: Style.fontSizeS * Style.uiScaleRatio

          onClicked: {
            noteCard.confirmingDelete = false;
            noteCard.deleteClicked();
          }
        }
      }
    }
  }

  // ── Edit mode overlay ──
  Item {
    anchors.fill: parent
    visible: noteCard.isEditing

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: 2

      NScrollView {
        id: editScrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        reserveScrollbarSpace: false
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: noteCard.showEditScrollbar ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        gradientColor: noteCard.noteColor || "#FFF9C4"

        TextEdit {
          id: editTextArea
          width: editScrollView.width
          height: Math.ceil(editTextArea.contentHeight) + 1
          color: "#3E2723"
          font.pointSize: Style.fontSizeS * Style.uiScaleRatio
          wrapMode: TextEdit.Wrap
          selectByMouse: true
          selectByKeyboard: true
          persistentSelection: true
          onContentHeightChanged: noteCard.updateEditScrollInteractivity()

          Shortcut {
            sequences: [StandardKey.Copy]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.copy()
          }

          Shortcut {
            sequences: [StandardKey.Cut]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.cut()
          }

          Shortcut {
            sequences: [StandardKey.Paste]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.paste()
          }

          Shortcut {
            sequences: [StandardKey.SelectAll]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.selectAll()
          }

          Shortcut {
            sequences: [StandardKey.Undo]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.undo()
          }

          Shortcut {
            sequences: [StandardKey.Redo]
            enabled: editTextArea.activeFocus
            onActivated: editTextArea.redo()
          }

          Keys.onShortcutOverride: (event) => {
            if (event.key === Qt.Key_Escape) {
              noteCard.saveClicked(editTextArea.text, noteCard.noteColor);
              event.accepted = true;
            }
          }

          Keys.onPressed: (event) => {
            if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
              noteCard.saveClicked(editTextArea.text, noteCard.noteColor);
              event.accepted = true;
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        // Shortcut hint (#13)
        NText {
          Layout.alignment: Qt.AlignVCenter
          text: noteCard.pluginApi?.tr("editor.hint-esc-save")
          font.pointSize: (Style.fontSizeXS - 1) * Style.uiScaleRatio
          color: Qt.rgba(0, 0, 0, 0.3)
        }

        Item { Layout.fillWidth: true }

        NIconButton {
          Layout.alignment: Qt.AlignVCenter
          icon: "check"
          baseSize: 28 * Style.uiScaleRatio
          customRadius: Style.iRadiusL
          colorBg: Qt.rgba(0, 0, 0, 0.06)
          colorBgHover: Qt.rgba(0, 0, 0, 0.12)
          colorFg: "#37474F"
          colorFgHover: "#37474F"
          colorBorder: "transparent"
          colorBorderHover: "transparent"

          onClicked: noteCard.saveClicked(editTextArea.text, noteCard.noteColor)
        }
      }
    }
  }

  // Focus text area when entering edit mode
  onIsEditingChanged: {
    if (isEditing) {
      editTextArea.text = noteCard.editingContent;
      editTextArea.forceActiveFocus();
      editTextArea.cursorPosition = editTextArea.text.length;
    }
    confirmingDelete = false;
    updateDisplayScrollInteractivity();
    updateEditScrollInteractivity();
  }

  function getEditedText() {
    return editTextArea.text;
  }

  function saveCurrent() {
    noteCard.saveClicked(editTextArea.text, noteCard.noteColor);
  }

  function scrollDisplayByDelta(deltaY) {
    var target = getDisplayScrollTarget();
    if (!target) return deltaY;

    var maxY = Math.max(0, target.contentHeight - target.height);
    if (maxY <= 0) return deltaY;

    var currentY = target.contentY;
    var targetY = currentY - deltaY;
    var clampedY = Math.max(0, Math.min(maxY, targetY));
    target.contentY = clampedY;

    var consumed = currentY - clampedY;
    return deltaY - consumed;
  }

  function getDisplayScrollTarget() {
    return getScrollTarget(noteScrollView);
  }

  function getEditScrollTarget() {
    return getScrollTarget(editScrollView);
  }

  function getScrollTarget(scrollView) {
    if (!scrollView) return null;
    if (scrollView._internalFlickable &&
        scrollView._internalFlickable.contentY !== undefined &&
        scrollView._internalFlickable.contentHeight !== undefined) {
      return scrollView._internalFlickable;
    }
    if (scrollView.contentItem &&
        scrollView.contentItem.contentY !== undefined &&
        scrollView.contentItem.contentHeight !== undefined) {
      return scrollView.contentItem;
    }
    if (scrollView.flickableItem &&
        scrollView.flickableItem.contentY !== undefined &&
        scrollView.flickableItem.contentHeight !== undefined) {
      return scrollView.flickableItem;
    }
    return null;
  }

  function hasOverflow(target) {
    if (!target) return false;
    return target.contentHeight > target.height + 1;
  }

  function updateDisplayScrollInteractivity() {
    var target = getDisplayScrollTarget();
    var overflow = hasOverflow(target);
    noteCard.showDisplayScrollbar = overflow && (noteCard.isSelected || noteCard.isEditing);
    if (!target || target.interactive === undefined) return;
    target.interactive = noteCard.isSelected && overflow;
  }

  function updateEditScrollInteractivity() {
    var target = getEditScrollTarget();
    var overflow = hasOverflow(target);
    noteCard.showEditScrollbar = overflow && (noteCard.isSelected || noteCard.isEditing);
    if (!target || target.interactive === undefined) return;
    target.interactive = noteCard.isEditing && overflow;
  }

  function handleWheelRouting(wheel) {
    if (noteCard.isEditing || noteCard.confirmingDelete) {
      wheel.accepted = false;
      return;
    }

    var delta = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y;
    if (delta === 0) {
      wheel.accepted = false;
      return;
    }

    if (!noteCard.isSelected) {
      noteCard.requestListScroll(delta);
      wheel.accepted = true;
      return;
    }

    noteCard.scrollDisplayByDelta(delta);
    wheel.accepted = true;
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: noteCard.selectRequested()
  }

  // Fallback wheel bridge for any uncovered layout gaps (e.g. ColumnLayout spacing
  // between content and footer hint). It does not consume clicks.
  MouseArea {
    anchors.fill: parent
    z: 210
    visible: !noteCard.isEditing && !noteCard.confirmingDelete
    acceptedButtons: Qt.LeftButton
    hoverEnabled: false
    propagateComposedEvents: true
    onPressed: (mouse) => {
      noteCard.selectRequested();
      mouse.accepted = false;
    }
    onWheel: (wheel) => noteCard.handleWheelRouting(wheel)
  }

  // Catch wheel events across the full card surface (including layout margins
  // and footer gaps) so list scrolling still works when no note is selected.
  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: (wheel) => noteCard.handleWheelRouting(wheel)
  }
}
