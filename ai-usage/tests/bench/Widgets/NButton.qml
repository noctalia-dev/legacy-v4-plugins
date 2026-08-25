import QtQuick

// NButton stub — API surface only.
Item {
  property string text: ""
  property string icon: ""
  property real fontSize: 11
  property int buttonRadius: 12
  property bool outlined: false
  signal clicked
  signal rightClicked
}
