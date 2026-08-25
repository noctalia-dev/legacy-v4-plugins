import QtQuick

// NIconButtonHot stub — API surface only.
Item {
  property real baseSize: 33
  property bool applyUiScale: true
  property string icon: ""
  property var tooltipText: ""
  property string tooltipDirection: "auto"
  property bool hot: false
  signal clicked
  signal rightClicked
}
