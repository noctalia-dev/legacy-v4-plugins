import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Compact color pill: circle + hex code + optional paste icon.
// Opens NColorPickerDialog on click. Used in pairs (bg + text) per keybind category.
Rectangle {
  id: pill

  property var screen
  property string hexValue: ""
  property color displayColor: "#888888"
  property bool textMode: false
  property string letter: "A"
  property color textModeBg: "#444444"
  property string clipboardHex: ""
  property string placeholderText: ""

  signal colorPicked(color value)
  signal pasteRequested(string hex)

  readonly property bool hasClipboardColor: clipboardHex.length > 0 &&
                                            clipboardHex.toLowerCase() !== hexValue.toLowerCase()

  implicitWidth: 150
  implicitHeight: Math.round(Style.baseWidgetSize * 1.1)

  radius: Style.iRadiusM
  color: Color.mSurface
  border.color: mouseArea.containsMouse ? Color.mPrimary : Color.mOutline
  border.width: Style.borderS

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      var startColor = pill.hexValue.length > 0 ? pill.hexValue : pill.displayColor;
      var dialog = dialogFactory.createObject(Overlay.overlay, {
        "selectedColor": startColor,
        "screen": pill.screen
      });
      if (!dialog) return;
      dialog.colorSelected.connect(function(c) {
        pill.colorPicked(c);
      });
      dialog.open();
    }
  }

  Component {
    id: dialogFactory
    NColorPickerDialog {}
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.marginS
    anchors.rightMargin: Style.marginS
    spacing: Style.marginS

    Rectangle {
      Layout.preferredWidth: pill.height * 0.62
      Layout.preferredHeight: pill.height * 0.62
      radius: width / 2
      color: pill.textMode ? pill.textModeBg : pill.displayColor
      border.color: Color.mOutline
      border.width: Style.borderS

      NText {
        anchors.centerIn: parent
        visible: pill.textMode
        text: pill.letter
        color: pill.displayColor
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeS
      }
    }

    NText {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: pill.hexValue.length > 0
            ? pill.hexValue.toUpperCase()
            : (pill.placeholderText.length > 0 ? pill.placeholderText : "auto")
      family: Settings.data.ui.fontFixed
      color: pill.hexValue.length > 0 ? Color.mOnSurface : Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
      elide: Text.ElideRight
    }

    Rectangle {
      Layout.preferredWidth: pill.height * 0.62
      Layout.preferredHeight: pill.height * 0.62
      visible: pill.hasClipboardColor
      radius: width / 2
      color: pasteArea.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
      border.color: Color.mOutline
      border.width: Style.borderS

      NIcon {
        anchors.centerIn: parent
        icon: "clipboard"
        color: pasteArea.containsMouse ? Color.mOnPrimary : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      MouseArea {
        id: pasteArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.pasteRequested(pill.clipboardHex)
      }

      ToolTip.visible: pasteArea.containsMouse && pill.clipboardHex.length > 0
      ToolTip.text: pill.clipboardHex.toUpperCase()
      ToolTip.delay: 400
    }
  }
}
