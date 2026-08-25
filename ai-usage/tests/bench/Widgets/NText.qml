import QtQuick

// NText stub — real Text underneath; pointSize wired to the font.
Text {
  id: root
  property real pointSize: 10
  property bool applyUiScale: true
  font.pointSize: root.pointSize
}
