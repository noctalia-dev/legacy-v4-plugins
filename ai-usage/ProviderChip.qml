// ProviderChip.qml — colored monogram chip identifying a provider
// (Z / DS / OR / K + brand color). Replaces per-vendor logos: legible at
// small sizes, no external assets.
import QtQuick
import qs.Commons
import qs.Widgets

Rectangle {
  id: chip

  property string monogram: "?"
  property color chipColor: Color.mOnSurfaceVariant
  property real size: Style.fontSizeXL          // square side, unscaled
  property real scale_: 1.0                     // widgetScale multiplier

  readonly property int side: Math.max(10, Math.round(size * scale_))
  readonly property int glyphSize: Math.max(7, Math.round(Style.fontSizeS * scale_))

  width: side
  height: side
  radius: Math.round(side / 2)
  color: "transparent"
  border.width: Math.max(1, Math.round(scale_))
  border.color: chipColor

  NText {
    anchors.centerIn: parent
    text: chip.monogram
    color: chip.chipColor
    pointSize: chip.glyphSize
    font.bold: true
  }
}
