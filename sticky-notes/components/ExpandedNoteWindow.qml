import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

import "../utils/markdown.js" as Markdown

Item {
  id: root

  required property string noteId
  required property string content
  required property string noteColor
  property var pluginApi: null
  property bool editing: false

  signal saveRequested(string noteId, string content, string noteColor)
  signal closed()

  visible: false
  z: 1000

  function beginEdit() {
    root.editing = true;
    editor.text = root.content;
    editor.forceActiveFocus();
    editor.cursorPosition = editor.text.length;
  }

  function saveCurrent() {
    root.saveRequested(root.noteId, editor.text, root.noteColor);
    root.editing = false;
  }

  function closePanel() {
    root.editing = false;
    root.closed();
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.22)

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onPressed: (mouse) => mouse.accepted = true
      onClicked: (mouse) => mouse.accepted = true
    }
  }

  Rectangle {
    id: dialog
    width: Math.min(parent.width - (Style.marginL * 2), 1120 * Style.uiScaleRatio)
    height: Math.min(parent.height - (Style.marginL * 2), 820 * Style.uiScaleRatio)
    anchors.centerIn: parent
    radius: Style.radiusL
    color: root.noteColor || "#FFF9C4"
    border.width: Style.borderS
    border.color: Qt.darker(root.noteColor || "#FFF9C4", 1.08)

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Item { Layout.fillWidth: true }

        NIconButton {
          icon: root.editing ? "check" : "pencil"
          baseSize: 34 * Style.uiScaleRatio
          customRadius: Style.iRadiusL
          colorBg: Qt.rgba(0, 0, 0, 0.06)
          colorBgHover: Qt.rgba(0, 0, 0, 0.12)
          colorFg: "#37474F"
          colorFgHover: "#37474F"
          colorBorder: "transparent"
          colorBorderHover: "transparent"

          onClicked: {
            if (root.editing) {
              root.saveCurrent();
            } else {
              root.beginEdit();
            }
          }
        }

        NIconButton {
          icon: "arrow-down-right"
          baseSize: 34 * Style.uiScaleRatio
          customRadius: Style.iRadiusL
          colorBg: Qt.rgba(0, 0, 0, 0.06)
          colorBgHover: Qt.rgba(0, 0, 0, 0.12)
          colorFg: "#37474F"
          colorFgHover: "#37474F"
          colorBorder: "transparent"
          colorBorderHover: "transparent"

          onClicked: root.closePanel()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.radiusM
        color: Qt.rgba(1, 1, 1, 0.28)
        border.width: root.editing ? Style.borderM : Style.borderS
        border.color: root.editing
          ? (editor.activeFocus ? Qt.darker(Color.mPrimary, 1.35) : Color.mPrimary)
          : Qt.rgba(0, 0, 0, 0.08)

        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on border.width { NumberAnimation { duration: 150 } }

        Item {
          anchors.fill: parent
          anchors.margins: Style.marginM

          NScrollView {
            id: previewScrollView
            anchors.fill: parent
            visible: !root.editing
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            gradientColor: Qt.tint(root.noteColor || "#FFF9C4", Qt.rgba(1, 1, 1, 0.28))

            TextArea {
              id: previewText
              text: Markdown.render(root.content || "", { noteColor: root.noteColor || "#FFF9C4" })
              textFormat: TextEdit.RichText
              font.pointSize: Style.fontSizeM * Style.uiScaleRatio
              color: "#37474F"
              wrapMode: TextArea.Wrap
              readOnly: true
              selectByMouse: true
              activeFocusOnTab: false
              background: Item {}

              onLinkActivated: (link) => Qt.openUrlExternally(link)
            }
          }

          NScrollView {
            id: editorScrollView
            anchors.fill: parent
            visible: root.editing
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            gradientColor: Qt.tint(root.noteColor || "#FFF9C4", Qt.rgba(1, 1, 1, 0.28))

            TextArea {
              id: editor
              height: Math.max(editorScrollView.height, contentHeight)
              color: "#3E2723"
              font.pointSize: Style.fontSizeM * Style.uiScaleRatio
              wrapMode: TextArea.Wrap
              selectByMouse: true
              selectByKeyboard: true
              persistentSelection: true
              background: Item {}

              Shortcut {
                sequences: [StandardKey.Copy]
                enabled: editor.activeFocus
                onActivated: editor.copy()
              }

              Shortcut {
                sequences: [StandardKey.Cut]
                enabled: editor.activeFocus
                onActivated: editor.cut()
              }

              Shortcut {
                sequences: [StandardKey.Paste]
                enabled: editor.activeFocus
                onActivated: editor.paste()
              }

              Shortcut {
                sequences: [StandardKey.SelectAll]
                enabled: editor.activeFocus
                onActivated: editor.selectAll()
              }

              Shortcut {
                sequences: [StandardKey.Undo]
                enabled: editor.activeFocus
                onActivated: editor.undo()
              }

              Shortcut {
                sequences: [StandardKey.Redo]
                enabled: editor.activeFocus
                onActivated: editor.redo()
              }

              Keys.onPressed: (event) => {
                if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                  root.saveCurrent();
                  event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                  root.saveCurrent();
                  event.accepted = true;
                }
              }
            }
          }
        }
      }

      NText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        text: root.pluginApi?.tr("editor.hint")
        visible: root.editing
        font.pointSize: (Style.fontSizeXS - 1) * Style.uiScaleRatio
        color: Qt.rgba(0, 0, 0, 0.35)
      }
    }
  }

  Shortcut {
    sequence: "Escape"
    enabled: root.visible && !root.editing
    context: Qt.WindowShortcut
    onActivated: root.closePanel()
  }
}
