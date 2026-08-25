// UsageBar.qml — severity-colored usage bar with animated fill.
//
// Ported from ai-usagebar (MIT) kde-plasmoid/package/contents/ui/UsageBar.qml
// to Noctalia's qs.Commons design tokens. Policy-free: the caller passes the
// fill color (mainInstance.severityColor(severity)) — the severity→theme
// mapping lives in Main.qml, not here.
import QtQuick
import qs.Commons

Item {
  id: root

  required property int pct
  required property color fillColor

  readonly property int clampedPct: Math.max(0, Math.min(100, root.pct))

  implicitHeight: 8
  implicitWidth: 120

  Rectangle {
    id: track
    anchors.fill: parent
    radius: height / 2
    color: Color.mOnSurfaceVariant
    opacity: 0.25

    Rectangle {
      width: Math.round(parent.width * root.clampedPct / 100)
      height: parent.height
      radius: parent.radius
      color: root.fillColor

      // Switching metrics reads as a transition rather than a jump.
      Behavior on width {
        NumberAnimation {
          duration: 160
          easing.type: Easing.OutCubic
        }
      }
    }
  }
}
