// BarWidget.qml v3.1 — multi-provider capsule: every enabled provider gets a
// segment "chip + compact value" joined with " | " (percent for window
// vendors, money for balance vendors). Clicking a segment makes it active
// and opens the panel on it (without closing an already-open panel); with
// no providers the gauge placeholder stays.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "Logic.js" as Logic

Item {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  // Bar positioning properties
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: screenName !== "" ? Settings.getBarPositionForScreen(screenName) : ""
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: screenName !== "" ? Style.getBarHeightForScreen(screenName) : 30
  readonly property real capsuleHeight: screenName !== "" ? Style.getCapsuleHeightForScreen(screenName) : 24
  readonly property real barFontSize: screenName !== "" ? Style.getBarFontSizeForScreen(screenName) : 11

  readonly property var mainInstance: pluginApi ? pluginApi.mainInstance : null
  readonly property bool hasProviders: mainInstance ? mainInstance.providers.length > 0 : false

  // One entry per enabled provider: chip identity + one-glance value.
  readonly property var segments: {
    var out = [];
    if (!mainInstance)
      return out;
    var ps = mainInstance.providers;
    for (var i = 0; i < ps.length; i++) {
      var p = ps[i];
      if (!p.enabled)
        continue;
      var entry = mainInstance.entries[p.id] !== undefined ? mainInstance.entries[p.id] : null;
      var err = mainInstance.errors[p.id] !== undefined ? mainInstance.errors[p.id] : "";
      var text = entry ? Logic.compactValue(entry) : "";
      if (text === "")
        text = err !== "" ? "⚠" : "…";
      out.push({
        providerId: p.id,
        chip: mainInstance.chipFor(p),
        label: mainInstance.displayLabel(p),
        text: text,
        failing: !entry && err !== "",
        // stale-data dimming: error with a cached entry keeps the old value,
        // but visibly degraded
        stale: entry && err !== "",
        active: p.id === mainInstance.activeProviderId
      });
    }
    return out;
  }

  // Vertical bars keep the single-provider summary (segments won't fit).
  readonly property var activeEntry: mainInstance ? mainInstance.activeEntry : null
  readonly property string activeText: activeEntry ? (Logic.compactValue(activeEntry) || "…") : "…"

  readonly property color contentColor: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface

  readonly property string tooltipText: {
    if (!hasProviders || segments.length === 0)
      return "AI";
    var parts = [];
    for (var i = 0; i < segments.length; i++)
      parts.push(segments[i].label + " " + segments[i].text);
    return parts.join(" | ");
  }

  function selectSegment(seg) {
    if (!pluginApi || !mainInstance || !seg)
      return;
    if (seg.providerId !== mainInstance.activeProviderId)
      mainInstance.setActive(seg.providerId);
    // openPanel TOGGLES when the panel is already showing this plugin —
    // skip it so a segment click switches the provider instead of closing.
    if (!pluginApi.panelOpenScreen)
      pluginApi.openPanel(root.screen, root);
  }

  readonly property real contentWidth: root.isVertical ? root.capsuleHeight : horizontalRow.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: root.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  // Declared BEFORE the capsule so segment MouseAreas (stacked above) win
  // the clicks; empty-capsule clicks still fall through to the panel here.
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: function (mouse) {
      if (mouse.button === Qt.LeftButton) {
        if (root.pluginApi)
          root.pluginApi.openPanel(root.screen, root);
      }
    }
  }

  // Visual capsule - pixel-perfect centered
  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusL
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    // NOTE: no anchors on children of layouts — Row/RowLayout refuse to lay
    // out anchored children ("Row will not function" → blank capsule).
    RowLayout {
      id: horizontalRow
      anchors.centerIn: parent
      spacing: Style.marginS
      visible: !root.isVertical

      // placeholder when nothing is configured yet
      NIcon {
        visible: root.segments.length === 0
        Layout.alignment: Qt.AlignVCenter
        icon: "gauge"
        applyUiScale: false
        color: root.contentColor
      }

      NText {
        visible: root.segments.length === 0
        Layout.alignment: Qt.AlignVCenter
        text: "…"
        color: root.contentColor
        pointSize: root.barFontSize
        applyUiScale: false
      }

      Repeater {
        model: root.segments

        delegate: Item {
          id: seg
          required property var modelData
          required property int index

          implicitWidth: segLayout.implicitWidth
          implicitHeight: segLayout.implicitHeight
          Layout.alignment: Qt.AlignVCenter

          RowLayout {
            id: segLayout
            anchors.fill: parent
            spacing: Style.marginXS

            NText {
              visible: seg.index > 0
              Layout.alignment: Qt.AlignVCenter
              // breathing room between the separator and the next chip
              Layout.rightMargin: Style.marginS
              text: "|"
              color: root.contentColor
              opacity: 0.35
              pointSize: root.barFontSize
              applyUiScale: false
            }

            ProviderChip {
              Layout.alignment: Qt.AlignVCenter
              monogram: seg.modelData.chip.monogram
              chipColor: seg.modelData.chip.color
              size: root.barFontSize + 2
            }

            NText {
              Layout.alignment: Qt.AlignVCenter
              // Hover is owned by the WHOLE capsule (segMouse passes hover
              // through), so hover inverts every segment at once — the stock
              // mHover background / mOnHover foreground pattern.
              // stale: cached value shown while the last fetch failed.
              text: seg.modelData.text
              color: seg.modelData.failing ? Color.mError
                 : mouseArea.containsMouse ? Color.mOnHover
                 : seg.modelData.active ? Color.mOnSurface
                 : Color.mOnSurfaceVariant
              opacity: seg.modelData.stale ? 0.55 : 1
              pointSize: root.barFontSize
              font.bold: seg.modelData.active
              applyUiScale: false
            }
          }

          MouseArea {
            id: segMouse
            anchors.fill: parent
            anchors.margins: -Style.marginXS
            acceptedButtons: Qt.LeftButton
            // No hover handling here: hover must reach the capsule's
            // MouseArea below, keeping the highlight alive over segments
            // (and inverting all of them at once). Clicks still land here.
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            onClicked: root.selectSegment(seg.modelData)
          }
        }
      }
    }

    Column {
      anchors.centerIn: parent
      spacing: 2
      visible: root.isVertical

      NIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        icon: "gauge"
        applyUiScale: false
        color: root.contentColor
      }

      NText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.activeText
        color: root.contentColor
        pointSize: Math.max(7, root.barFontSize - 2)
        applyUiScale: false
      }
    }
  }
}
