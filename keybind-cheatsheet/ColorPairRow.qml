import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "." as Local

// Label + background pill + text pill + reset. Used by Settings.qml for per-category
// color customization. Empty bgValue/textValue means "use fallback".
RowLayout {
  id: row

  property var pluginApi
  property var screen
  property string labelText: ""
  property string bgValue: ""
  property string textValue: ""
  property color bgFallback: "#888888"
  property color textFallback: "#FFFFFF"
  property string letter: "A"
  property string clipboardHex: ""
  property bool showBg: true
  property bool showText: true

  signal bgPicked(color value)
  signal textPicked(color value)
  signal bgPasted(string hex)
  signal textPasted(string hex)
  signal resetRequested()

  Layout.fillWidth: true
  spacing: Style.marginM

  NText {
    text: row.labelText
    color: Color.mOnSurface
    pointSize: Style.fontSizeM
    Layout.preferredWidth: 180 * Style.uiScaleRatio
    elide: Text.ElideRight
  }

  Local.ColorPill {
    Layout.preferredWidth: 130 * Style.uiScaleRatio
    visible: row.showBg
    screen: row.screen
    hexValue: row.bgValue
    displayColor: row.bgValue.length > 0 ? row.bgValue : row.bgFallback
    textMode: false
    clipboardHex: row.clipboardHex
    placeholderText: row.bgValue.length === 0 ? row.pluginApi?.tr("settings.color-auto") : ""
    onColorPicked: c => row.bgPicked(c)
    onPasteRequested: hex => row.bgPasted(hex)
  }

  Local.ColorPill {
    Layout.preferredWidth: 130 * Style.uiScaleRatio
    visible: row.showText
    screen: row.screen
    hexValue: row.textValue
    displayColor: row.textValue.length > 0 ? row.textValue : row.textFallback
    textMode: true
    letter: row.letter
    textModeBg: row.bgValue.length > 0 ? row.bgValue : row.bgFallback
    clipboardHex: row.clipboardHex
    placeholderText: row.textValue.length === 0 ? row.pluginApi?.tr("settings.color-auto") : ""
    onColorPicked: c => row.textPicked(c)
    onPasteRequested: hex => row.textPasted(hex)
  }

  Item { Layout.fillWidth: true }

  NIconButton {
    icon: "rotate"
    tooltipText: row.pluginApi?.tr("settings.reset-color")
    onClicked: row.resetRequested()
  }
}
