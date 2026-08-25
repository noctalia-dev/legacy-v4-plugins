// Panel.qml v2.1 — data-dense redesign.
//
// Visual hierarchy (per design review): provider identity in the header,
// a HERO box for the headline metric (ring gauge for window vendors, big
// money for balance vendors), every remaining metric and breakdown in its
// own NBox card, per-tool ratio gauges, valid-until chip. Tabs stay compact.
//
// Structure heritage: vendor tab strip ported from ai-usagebar FullRepresentation.
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "Logic.js" as Logic

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 380 * Style.uiScaleRatio
  property real contentPreferredHeight: contentCol.implicitHeight + Style.marginL * 2
  readonly property bool allowAttach: true
  anchors.fill: parent

  property string selectedId: ""

  readonly property var mainInstance: pluginApi ? pluginApi.mainInstance : null
  readonly property var providers: mainInstance ? mainInstance.providers : []
  readonly property var entries: mainInstance ? mainInstance.entries : ({})
  readonly property var errors: mainInstance ? mainInstance.errors : ({})
  readonly property var fetching: mainInstance ? mainInstance.fetching : ({})
  readonly property real now: mainInstance ? mainInstance.now : 0

  readonly property string currentId: {
    if (selectedId !== "" && providers.some(function (p) { return p.id === selectedId; }))
      return selectedId;
    return mainInstance ? mainInstance.activeProviderId : "";
  }
  readonly property var currentProvider: {
    for (var i = 0; i < providers.length; i++) {
      if (providers[i].id === currentId)
        return providers[i];
    }
    return null;
  }
  readonly property var currentEntry: entries[currentId] !== undefined ? entries[currentId] : null
  readonly property string currentError: errors[currentId] !== undefined ? errors[currentId] : ""

  // A bar-segment click swaps the ACTIVE provider while this panel is open;
  // drop a stale local tab selection so the content follows the new active.
  Connections {
    target: root.mainInstance
    function onActiveProviderIdChanged() {
      root.selectedId = "";
    }
  }

  readonly property var trFn: pluginApi ? function (key) {
    return pluginApi.tr(key);
  } : null
  readonly property string hUnit: trFn ? trFn("units.h") : "h"
  readonly property string mUnit: trFn ? trFn("units.m") : "m"

  // --- hero helpers ---------------------------------------------------------

  readonly property var hero: mainInstance && currentEntry ? mainInstance.headlineSection(currentEntry) : null
  readonly property bool heroPercent: hero !== null && hero.percent !== null && hero.percent !== undefined
  readonly property int heroLeft: heroPercent ? 100 - hero.percent : -1
  // money strings never contain '%' (zai/kimi values do) → no duplication with the ring
  readonly property string heroMoney: hero && hero.value !== "" && String(hero.value).indexOf('%') === -1 ? hero.value : ""

  readonly property string planLine: Logic.planLine(currentProvider, currentEntry)

  function severityColor(sev) {
    return mainInstance ? mainInstance.severityColor(sev) : Color.mTertiary;
  }

  readonly property var validInfo: {
    if (!currentProvider || !currentProvider.validUntil)
      return null;
    var info = Logic.validUntilInfo(currentProvider.validUntil, now);
    return info === null ? null : {
      date: Qt.formatDateTime(new Date(info.epochMs), "dd.MM"),
      days: info.days,
      soon: info.soon
    };
  }

  // Sections of the current entry, split by render type (hero excluded).
  readonly property var metricSections: {
    var out = [];
    if (!currentEntry || !hero)
      return out;
    for (var i = 0; i < currentEntry.sections.length; i++) {
      var s = currentEntry.sections[i];
      if (s.type === 'metric' && s.key !== hero.key)
        out.push(s);
    }
    return out;
  }

  readonly property var blockSections: {
    var out = [];
    if (!currentEntry)
      return out;
    for (var j = 0; j < currentEntry.sections.length; j++) {
      if (currentEntry.sections[j].type === 'block')
        out.push(currentEntry.sections[j]);
    }
    return out;
  }

  function metricLabel(key) {
    if (!trFn)
      return "";
    if (key === "session")
      return trFn("panel.session_label");
    if (key === "weekly")
      return trFn("panel.weekly_label");
    if (key === "balance")
      return trFn("panel.balance_label");
    return Logic.prettySectionKey(key);
  }

  function blockLabel(key) {
    if (!trFn)
      return "";
    if (key === "tools")
      return trFn("panel.tools_label");
    if (key === "breakdown")
      return trFn("panel.breakdown_label");
    if (key === "key")
      return trFn("panel.key_label");
    return key;
  }

  // Sub-line of a metric card: humanised detail + reset countdown.
  function metricSubline(sec) {
    if (!trFn)
      return "";
    var parts = [];
    var detail = sec.detail || "";
    if (/^\d+$/.test(detail)) {
      // bare number = remaining units of a quota
      parts.push(trFn("panel.remaining_num").replace("{num}", detail));
    } else if (detail !== "") {
      parts.push(detail);
    }
    if (sec.resetAt > 0) {
      var time = Qt.formatDateTime(new Date(sec.resetAt), "HH:mm");
      var dur = Logic.formatDuration(Logic.remainingMs(sec.resetAt, now), hUnit, mUnit);
      parts.push(trFn("panel.resets").replace("{time}", time).replace("{duration}", dur));
    }
    return parts.join("  ·  ");
  }

  function updatedText() {
    if (!trFn || !currentEntry)
      return "";
    var ago = Logic.formatDuration(Date.now() - currentEntry.fetchedAt, hUnit, mUnit);
    var text = trFn("panel.updated").replace("{duration}", ago);
    if (currentError !== "")
      text += trFn("panel.cached");
    return text;
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"
    radius: Style.radiusM

    ColumnLayout {
      id: contentCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      // --- header: provider identity + refresh ------------------------------
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        ProviderChip {
          visible: root.currentProvider !== null
          monogram: root.mainInstance && root.currentProvider ? root.mainInstance.chipFor(root.currentProvider).monogram : "?"
          chipColor: root.mainInstance && root.currentProvider ? root.mainInstance.chipFor(root.currentProvider).color : Color.mOnSurfaceVariant
          size: Style.fontSizeXXL
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            Layout.fillWidth: true
            text: root.currentProvider && root.mainInstance ? root.mainInstance.displayLabel(root.currentProvider) : (root.trFn ? root.trFn("panel.header") : "")
            color: Color.mOnSurface
            pointSize: Style.fontSizeXL
            font.bold: true
            elide: Text.ElideRight
          }

          NText {
            Layout.fillWidth: true
            visible: root.planLine !== ""
            text: root.planLine
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            font.capitalization: Font.AllUppercase
            elide: Text.ElideRight
          }
        }

        NIconButton {
          icon: "refresh"
          enabled: !root.fetching[root.currentId] && root.currentProvider !== null
          onClicked: {
            if (root.mainInstance && root.currentProvider)
              root.mainInstance.fetchProvider(root.currentProvider);
          }
        }
      }

      // --- provider tabs (failing stay visible, ported from vendor-tabs) ----
      RowLayout {
        Layout.fillWidth: true
        visible: root.providers.length > 1
        spacing: Style.marginXS

        Repeater {
          model: root.providers

          delegate: Rectangle {
            id: tab
            required property var modelData
            readonly property bool active: modelData.id === root.currentId
            // Never-fetched (or throttled) is NOT failing — exclude in-flight fetches.
            readonly property bool failing: (root.errors[modelData.id] !== undefined && root.errors[modelData.id] !== "") || (root.entries[modelData.id] === undefined && modelData.enabled && root.fetching[modelData.id] !== true)
            readonly property var m: root.mainInstance

            Layout.fillWidth: true
            Layout.preferredHeight: Style.fontSizeM + Style.marginS * 2
            radius: height / 2
            color: active ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.16) : Color.mSurfaceVariant
            border.width: active ? 1 : 0
            border.color: Color.mPrimary
            opacity: modelData.enabled ? 1 : 0.4

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectedId = tab.modelData.id
            }

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.marginXS

              ProviderChip {
                monogram: tab.m ? tab.m.chipFor(tab.modelData).monogram : "?"
                chipColor: tab.m ? tab.m.chipFor(tab.modelData).color : Color.mOnSurfaceVariant
                size: Style.fontSizeS
              }

              NText {
                text: tab.m ? tab.m.displayLabel(tab.modelData) : ""
                color: tab.active ? Color.mOnSurface : Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                font.bold: tab.active
                elide: Text.ElideRight
              }

              NText {
                visible: tab.failing
                text: "⚠"
                color: Color.mError
                pointSize: Style.fontSizeXS
              }
            }
          }
        }
      }

      // --- status surface ------------------------------------------------------
      Rectangle {
        Layout.fillWidth: true
        visible: root.providers.length === 0 || root.currentError !== "" || (root.currentEntry === null && root.fetching[root.currentId])
        implicitHeight: statusText.implicitHeight + Style.marginM * 2
        radius: Style.radiusS
        color: Qt.rgba(Color.mError.r, Color.mError.g, Color.mError.b, 0.09)
        border.width: 1
        border.color: Qt.rgba(Color.mError.r, Color.mError.g, Color.mError.b, 0.35)

        NText {
          id: statusText
          anchors.fill: parent
          anchors.margins: Style.marginS
          text: {
            if (!root.trFn)
              return "";
            if (root.providers.length === 0)
              return root.trFn("panel.no_providers");
            if (root.currentProvider && (!root.currentProvider.apiKey || root.currentProvider.apiKey === ""))
              return root.trFn("panel.no_key");
            if (root.currentError !== "")
              return root.currentError;
            if (root.currentEntry === null)
              return root.trFn("panel.never");
            return "";
          }
          color: Color.mOnSurface
          pointSize: Style.fontSizeS
          wrapMode: Text.WordWrap
        }
      }

      // --- HERO: the headline metric ---------------------------------------
      NBox {
        Layout.fillWidth: true
        visible: root.hero !== null
        implicitHeight: heroRow.implicitHeight + Style.marginM * 2

        RowLayout {
          id: heroRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginL

          // Ring gauge with the REMAINING share (window vendors)
          NCircleStat {
            visible: root.heroPercent
            ratio: root.heroLeft / 100
            fillColor: root.hero ? root.severityColor(root.hero.severity) : Color.mTertiary
            suffix: "%"
            contentScale: 1.5
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            NText {
              Layout.fillWidth: true
              text: root.hero ? root.metricLabel(root.hero.key) : ""
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
              font.capitalization: Font.AllUppercase
              elide: Text.ElideRight
            }

            // Big money value (balance vendors; for mixed vendors a side note)
            NText {
              Layout.fillWidth: true
              visible: root.heroMoney !== ""
              text: root.heroMoney
              color: root.hero ? root.severityColor(root.hero.severity) : Color.mOnSurface
              pointSize: root.heroPercent ? Style.fontSizeL : Style.fontSizeXXXL
              font.bold: true
              elide: Text.ElideRight
            }

            // reset countdown for window metrics
            NText {
              Layout.fillWidth: true
              visible: text !== "" && root.hero && root.heroPercent && root.hero.resetAt > 0
              text: {
                if (!root.trFn || !root.hero || !(root.hero.resetAt > 0))
                  return "";
                var time = Qt.formatDateTime(new Date(root.hero.resetAt), "HH:mm");
                var dur = Logic.formatDuration(Logic.remainingMs(root.hero.resetAt, root.now), root.hUnit, root.mUnit);
                return root.trFn("panel.resets").replace("{time}", time).replace("{duration}", dur);
              }
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeS
              elide: Text.ElideRight
            }

            // valid-until chip
            Rectangle {
              Layout.topMargin: Style.marginXXS
              visible: root.validInfo !== null
              implicitWidth: chipText.implicitWidth + Style.marginS * 2
              implicitHeight: chipText.implicitHeight + Style.marginXS * 2
              radius: height / 2
              readonly property color c: root.validInfo && root.validInfo.soon ? Color.mSecondary : Color.mOnSurfaceVariant
              color: Qt.rgba(c.r, c.g, c.b, 0.10)
              border.width: 1
              border.color: Qt.rgba(c.r, c.g, c.b, 0.45)

              NText {
                id: chipText
                anchors.centerIn: parent
                text: root.validInfo && root.trFn ? root.trFn("desktop_widget.until").replace("{date}", root.validInfo.date).replace("{days}", root.validInfo.days) : ""
                color: parent.c
                pointSize: Style.fontSizeXS
              }
            }
          }
        }
      }

      // --- metric cards (everything except the headline) --------------------
      NText {
        Layout.fillWidth: true
        visible: root.metricSections.length > 0
        text: root.trFn ? root.trFn("panel.section_title") : ""
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        font.capitalization: Font.AllUppercase
      }

      Repeater {
        model: root.metricSections

        delegate: NBox {
          id: metricCard
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: metricCol.implicitHeight + Style.marginM * 2

          ColumnLayout {
            id: metricCol
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginXS

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NText {
                Layout.fillWidth: true
                text: root.metricLabel(metricCard.modelData.key)
                color: Color.mOnSurface
                pointSize: Style.fontSizeM
                font.bold: true
                elide: Text.ElideRight
              }

              NText {
                visible: metricCard.modelData.value !== ""
                text: metricCard.modelData.value
                color: root.severityColor(metricCard.modelData.severity)
                pointSize: Style.fontSizeL
                font.bold: true
              }
            }

            UsageBar {
              Layout.fillWidth: true
              visible: metricCard.modelData.percent !== null && metricCard.modelData.percent !== undefined
              pct: metricCard.modelData.percent || 0
              fillColor: root.severityColor(metricCard.modelData.severity)
            }

            NText {
              Layout.fillWidth: true
              visible: text !== ""
              text: root.metricSubline(metricCard.modelData)
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeS
              elide: Text.ElideRight
            }
          }
        }
      }

      // --- block cards (tools with gauges, breakdown, key info) -------------
      Repeater {
        model: root.blockSections

        delegate: NBox {
          id: blockCard
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: blockCol.implicitHeight + Style.marginM * 2

          ColumnLayout {
            id: blockCol
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginXS

            NText {
              Layout.fillWidth: true
              text: root.blockLabel(blockCard.modelData.key)
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
              font.capitalization: Font.AllUppercase
            }

            // tools: rows with a ratio gauge per tool
            Repeater {
              visible: blockCard.modelData.key === 'tools' && blockCard.modelData.items !== undefined
              model: visible ? blockCard.modelData.items : []

              delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Style.marginXXS

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginS

                  NText {
                    Layout.fillWidth: true
                    text: modelData.name
                    color: Color.mOnSurface
                    pointSize: Style.fontSizeS
                    elide: Text.ElideRight
                  }

                  NText {
                    text: modelData.usage
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                    font.bold: true
                  }
                }

                NLinearGauge {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 4
                  orientation: Qt.Horizontal
                  ratio: blockCard.modelData.limit > 0 ? modelData.usage / blockCard.modelData.limit : 0
                  fillColor: Color.mTertiary
                }
              }
            }

            // plain body lines (breakdown, key info)
            Repeater {
              visible: blockCard.modelData.key !== 'tools' || blockCard.modelData.items === undefined
              model: visible ? blockCard.modelData.body : []

              delegate: NText {
                required property string modelData
                Layout.fillWidth: true
                text: modelData
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                elide: Text.ElideRight
              }
            }
          }
        }
      }

      NText {
        Layout.fillWidth: true
        visible: text !== ""
        horizontalAlignment: Text.AlignHCenter
        text: root.updatedText()
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        opacity: 0.8
      }
    }
  }
}
