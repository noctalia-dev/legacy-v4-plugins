import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
  id: newNoteCard

  property string noteColor: "#FFF9C4"
  property var pluginApi: null

  signal saveClicked(string content, string editedColor)
  signal cancelClicked()

  width: parent ? parent.width : 200 * Style.uiScaleRatio
  height: 200 * Style.uiScaleRatio
  color: noteColor
  radius: Style.radiusM
  border.color: textArea.activeFocus ? Qt.darker(Color.mPrimary, 1.35) : Color.mPrimary
  border.width: Style.borderM

  Behavior on border.color { ColorAnimation { duration: 150 } }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: 2

    Flickable {
      id: flickable
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: width
      contentHeight: Math.max(flickable.height, Math.ceil(textArea.contentHeight) + 1)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick

      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      TextEdit {
        id: textArea
        width: flickable.width
        height: flickable.contentHeight
        color: "#3E2723"
        font.pointSize: Style.fontSizeS * Style.uiScaleRatio
        wrapMode: TextEdit.Wrap
        selectByMouse: true
        selectByKeyboard: true
        persistentSelection: true
        focus: newNoteCard.visible

        Shortcut {
          sequences: [StandardKey.Copy]
          enabled: textArea.activeFocus
          onActivated: textArea.copy()
        }

        Shortcut {
          sequences: [StandardKey.Cut]
          enabled: textArea.activeFocus
          onActivated: textArea.cut()
        }

        Shortcut {
          sequences: [StandardKey.Paste]
          enabled: textArea.activeFocus
          onActivated: textArea.paste()
        }

        Shortcut {
          sequences: [StandardKey.SelectAll]
          enabled: textArea.activeFocus
          onActivated: textArea.selectAll()
        }

        Shortcut {
          sequences: [StandardKey.Undo]
          enabled: textArea.activeFocus
          onActivated: textArea.undo()
        }

        Shortcut {
          sequences: [StandardKey.Redo]
          enabled: textArea.activeFocus
          onActivated: textArea.redo()
        }

        Keys.onShortcutOverride: (event) => {
          if (event.key === Qt.Key_Escape) {
            newNoteCard.saveClicked(textArea.text, newNoteCard.noteColor);
            event.accepted = true;
          }
        }

        NText {
          visible: textArea.text.length === 0 && !textArea.activeFocus
          text: newNoteCard.pluginApi?.tr("editor.placeholder")
          font.pointSize: Style.fontSizeS * Style.uiScaleRatio
          color: Qt.rgba(0, 0, 0, 0.3)
        }

        Keys.onPressed: (event) => {
          if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
            newNoteCard.saveClicked(textArea.text, newNoteCard.noteColor);
            event.accepted = true;
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginL

      Item {
        Layout.fillWidth: true
      }

      // Shortcut hint
      NText {
        Layout.alignment: Qt.AlignVCenter
        text: newNoteCard.pluginApi?.tr("editor.hint")
        font.pointSize: (Style.fontSizeXS - 1) * Style.uiScaleRatio
        color: Qt.rgba(0, 0, 0, 0.3)
      }

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

        onClicked: newNoteCard.saveClicked(textArea.text, newNoteCard.noteColor)
      }
    }
  }

  onVisibleChanged: {
    if (visible) {
      textArea.text = "";
      textArea.forceActiveFocus();
    }
  }

  function getText() {
    return textArea.text;
  }

  function saveCurrent() {
    newNoteCard.saveClicked(textArea.text, newNoteCard.noteColor);
  }
}
