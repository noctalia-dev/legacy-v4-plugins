import QtQuick

// NComboBox stub — API surface only.
Item {
  property string label: ""
  property string description: ""
  property var model
  property string currentKey: ""
  signal selected(string key)
}
