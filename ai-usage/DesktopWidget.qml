// DesktopWidget.qml v2 — multi-provider card.
// Layout: the active provider expanded on top (chip + name + plan + big
// remaining value + severity bar + reset countdown + valid-until), other
// enabled providers as compact rows beneath (click = make active).
// Single provider renders without the list.
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services.UI
import qs.Widgets
import "Logic.js" as Logic

DraggableDesktopWidget {
  id: root

  property var pluginApi: null

  showBackground: pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.showBackground !== undefined ? pluginApi.pluginSettings.showBackground : (pluginApi && pluginApi.manifest ? pluginApi.manifest.metadata.defaultSettings.showBackground : true)

  readonly property var mainInstance: pluginApi ? pluginApi.mainInstance : null
  readonly property var providers: mainInstance ? mainInstance.providers : []
  readonly property string activeId: mainInstance ? mainInstance.activeProviderId : ""
  readonly property var entries: mainInstance ? mainInstance.entries : ({})
  readonly property var errors: mainInstance ? mainInstance.errors : ({})
  readonly property var fetching: mainInstance ? mainInstance.fetching : ({})
  readonly property real now: mainInstance ? mainInstance.now : 0

  readonly property var activeProvider: mainInstance ? mainInstance.activeProvider : null
  readonly property var activeEntry: mainInstance ? mainInstance.activeEntry : null
  readonly property string activeError: mainInstance ? mainInstance.activeError : ""
  readonly property bool hasProviders: providers.length > 0

  readonly property var trFn: pluginApi ? function (key) {
    return pluginApi.tr(key);
  } : null
  readonly property string hUnit: trFn ? trFn("units.h") : "h"
  readonly property string mUnit: trFn ? trFn("units.m") : "m"

  readonly property var headline: mainInstance && activeEntry ? mainInstance.headlineSection(activeEntry) : null
  readonly property int leftPct: mainInstance && activeEntry ? mainInstance.leftPercent(activeEntry) : -1
  readonly property bool isPercentMode: leftPct >= 0
  readonly property string planLine: Logic.planLine(activeProvider, activeEntry)

  readonly property color accentColor: {
    if (!headline)
      return Color.mOnSurfaceVariant;
    return mainInstance ? mainInstance.severityColor(headline.severity) : Color.mTertiary;
  }

  readonly property var validInfo: {
    if (!activeProvider || !activeProvider.validUntil)
      return null;
    var info = Logic.validUntilInfo(activeProvider.validUntil, now);
    return info === null ? null : {
      date: Qt.formatDateTime(new Date(info.epochMs), "dd.MM"),
      days: info.days,
      soon: info.soon
    };
  }

  readonly property string valueLine: {
    if (!trFn)
      return "";
    if (!hasProviders)
      return "";
    if (!activeEntry) {
      if (activeError !== "")
        return trFn("desktop_widget.error");
      if (activeProvider && (!activeProvider.apiKey || activeProvider.apiKey === ""))
        return trFn("desktop_widget.no_key");
      return trFn("desktop_widget.loading");
    }
    if (isPercentMode)
      return leftPct + "%";
    return headline ? headline.value : "";
  }

  // Scaled dimensions
  readonly property int scaledMarginM: Math.round(Style.marginM * widgetScale)
  readonly property int scaledMarginS: Math.round(Style.marginS * widgetScale)
  readonly property int scaledFontSizeS: Math.round(Style.fontSizeS * widgetScale)
  readonly property int scaledFontSizeM: Math.round(Style.fontSizeM * widgetScale)
  readonly property int scaledFontSizeXL: Math.round(Style.fontSizeXL * widgetScale)
  readonly property int scaledBarHeight: Math.max(4, Math.round(8 * widgetScale))

  implicitWidth: Math.round(260 * widgetScale)
  implicitHeight: contentCol.implicitHeight + scaledMarginM * 2

  Component.onCompleted: {
    if (pluginApi)
      Logger.i("AiUsage", "desktop widget initialized");
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: function (mouse) {
      if (mouse.button !== Qt.LeftButton)
        return;
      if (!root.hasProviders && root.pluginApi) {
        BarService.openPluginSettings(root.screen, root.pluginApi.manifest);
        return;
      }
      if (root.pluginApi)
        root.pluginApi.openPanel(root.screen, root);
    }
  }

  ColumnLayout {
    id: contentCol
    anchors.fill: parent
    anchors.margins: scaledMarginM
    spacing: scaledMarginS

    // --- empty state -------------------------------------------------------
    ColumnLayout {
      Layout.fillWidth: true
      visible: !root.hasProviders
      spacing: 0

      NText {
        Layout.fillWidth: true
        text: root.trFn ? root.trFn("desktop_widget.no_providers") : ""
        color: Color.mOnSurfaceVariant
        pointSize: root.scaledFontSizeM
      }
      NText {
        Layout.fillWidth: true
        text: root.trFn ? root.trFn("desktop_widget.add_provider_hint") : ""
        color: Color.mOnSurfaceVariant
        pointSize: root.scaledFontSizeS
        opacity: 0.7
      }
    }

    // --- active provider block ----------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      visible: root.hasProviders
      spacing: scaledMarginS

      ProviderChip {
        monogram: root.mainInstance && root.activeProvider ? root.mainInstance.chipFor(root.activeProvider).monogram : "?"
        chipColor: root.mainInstance && root.activeProvider ? root.mainInstance.chipFor(root.activeProvider).color : Color.mOnSurfaceVariant
        scale_: root.widgetScale
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        NText {
          Layout.fillWidth: true
          text: root.mainInstance && root.activeProvider ? root.mainInstance.displayLabel(root.activeProvider) : ""
          color: Color.mOnSurface
          pointSize: root.scaledFontSizeM
          elide: Text.ElideRight
        }

        NText {
          Layout.fillWidth: true
          visible: root.planLine !== ""
          text: root.planLine
          color: Color.mOnSurfaceVariant
          pointSize: root.scaledFontSizeS
          font.capitalization: Font.AllUppercase
          elide: Text.ElideRight
        }
      }

      NText {
        visible: root.valueLine !== ""
        text: root.valueLine
        color: root.hasProviders && root.activeEntry === null && root.activeError !== "" ? Color.mError : root.accentColor
        pointSize: root.scaledFontSizeXL
        font.bold: true
      }
    }

    // --- active severity bar --------------------------------------------------
    UsageBar {
      Layout.fillWidth: true
      Layout.preferredHeight: root.scaledBarHeight
      visible: root.isPercentMode
      pct: (root.headline && root.headline.percent) || 0
      fillColor: root.mainInstance && root.headline
        ? root.mainInstance.severityColor(root.headline.severity)
        : Color.mTertiary
    }

    // --- reset / valid-until lines ---------------------------------------------
    NText {
      Layout.fillWidth: true
      visible: text !== "" && root.isPercentMode && root.headline && root.headline.resetAt > 0
      text: {
        if (!root.trFn || !root.headline || !(root.headline.resetAt > 0))
          return "";
        var time = Qt.formatDateTime(new Date(root.headline.resetAt), "HH:mm");
        var dur = Logic.formatDuration(Logic.remainingMs(root.headline.resetAt, now), hUnit, mUnit);
        return root.trFn("desktop_widget.reset_in").replace("{duration}", dur) + " · " + root.trFn("desktop_widget.reset_at").replace("{time}", time);
      }
      color: Color.mOnSurfaceVariant
      pointSize: root.scaledFontSizeS
      elide: Text.ElideRight
    }

    // --- valid-until chip ------------------------------------------------------
    Rectangle {
      Layout.fillWidth: false
      Layout.alignment: Qt.AlignLeft
      Layout.topMargin: root.scaledMarginS / 2
      visible: root.validInfo !== null
      implicitWidth: untilText.implicitWidth + root.scaledMarginS * 2
      implicitHeight: untilText.implicitHeight + Math.round(2 * root.widgetScale) * 2
      radius: height / 2
      readonly property color c: root.validInfo && root.validInfo.soon ? Color.mSecondary : Color.mOnSurfaceVariant
      color: Qt.rgba(c.r, c.g, c.b, 0.10)
      border.width: Math.max(1, Math.round(root.widgetScale))
      border.color: Qt.rgba(c.r, c.g, c.b, 0.45)

      NText {
        id: untilText
        anchors.centerIn: parent
        text: root.validInfo && root.trFn ? root.trFn("desktop_widget.until").replace("{date}", root.validInfo.date).replace("{days}", root.validInfo.days) : ""
        color: parent.c
        pointSize: root.scaledFontSizeS
      }
    }

    // --- other providers --------------------------------------------------------
    Repeater {
      model: {
        var list = [];
        for (var i = 0; i < root.providers.length; i++) {
          var p = root.providers[i];
          if (p.enabled && p.id !== root.activeId)
            list.push(p);
        }
        return list;
      }

      delegate: RowLayout {
        id: row
        required property var modelData
        Layout.fillWidth: true
        spacing: root.scaledMarginS

        readonly property var m: root.mainInstance
        readonly property var entry: root.entries[row.modelData.id] !== undefined ? root.entries[row.modelData.id] : null

        MouseArea {
          Layout.fillWidth: true
          Layout.preferredHeight: parent.implicitHeight
          acceptedButtons: Qt.LeftButton
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.mainInstance)
              root.mainInstance.setActive(row.modelData.id);
          }

          RowLayout {
            anchors.fill: parent
            spacing: root.scaledMarginS

            ProviderChip {
              monogram: row.m ? row.m.chipFor(row.modelData).monogram : "?"
              chipColor: row.m ? row.m.chipFor(row.modelData).color : Color.mOnSurfaceVariant
              size: Style.fontSizeL
              scale_: root.widgetScale
            }

            NText {
              Layout.fillWidth: true
              text: row.m ? row.m.displayLabel(row.modelData) : ""
              color: Color.mOnSurfaceVariant
              pointSize: root.scaledFontSizeS
              elide: Text.ElideRight
            }

            NText {
              visible: row.entry !== null
              text: {
                if (!row.entry || !row.m)
                  return "";
                var lp = row.m.leftPercent(row.entry);
                if (lp >= 0)
                  return lp + "%";
                var h = row.m.headlineSection(row.entry);
                return h ? h.value : "";
              }
              color: Color.mOnSurface
              pointSize: root.scaledFontSizeS
              font.bold: true
            }
          }
        }
      }
    }
  }
}
