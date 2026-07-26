import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Modules.DesktopWidgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  readonly property var mainInstance: pluginApi?.mainInstance
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property int weeksShown: Math.max(4, Math.min(53, cfg.weeksShown ?? defaults.weeksShown ?? 52))
  readonly property bool showTotal: cfg.showTotal ?? defaults.showTotal ?? true
  readonly property bool showLabels: cfg.showLabels ?? defaults.showLabels ?? true

  readonly property bool hasData: mainInstance?.hasData ?? false
  readonly property var allDays: mainInstance?.days ?? []

  readonly property bool compact: (cfg.layout ?? defaults.layout ?? "graph") === "stats"
  readonly property int effectiveWeeks: compact ? Math.min(weeksShown, 13) : weeksShown

  readonly property var slicedDays: {
    if (!allDays.length) return []
    var lastWd = weekdayOf(allDays[allDays.length - 1].date)
    var keep = (effectiveWeeks - 1) * 7 + lastWd + 1
    return allDays.length > keep ? allDays.slice(allDays.length - keep) : allDays
  }
  readonly property int padOffset: slicedDays.length ? weekdayOf(slicedDays[0].date) : 0
  readonly property int columns: Math.ceil((padOffset + slicedDays.length) / 7)
  property int hoveredIndex: -1

  readonly property var monthLabels: {
    var labels = []
    var prevMonth = -1
    for (var i = 0; i < slicedDays.length; i++) {
      var idx = padOffset + i
      if (idx % 7 !== 0) continue
      var month = parseInt(slicedDays[i].date.substring(5, 7))
      if (month !== prevMonth && prevMonth !== -1 && idx / 7 <= columns - 3)
        labels.push({ "col": idx / 7, "name": Qt.locale().standaloneMonthName(month - 1, Locale.ShortFormat) })
      prevMonth = month
    }
    return labels
  }

  readonly property real cellStep: 13 * widgetScale
  readonly property real cellSize: 10 * widgetScale
  readonly property real dayLabelWidth: showLabels && !compact ? 30 * widgetScale : 0
  readonly property real statsWidth: compact && showTotal ? statsColumn.implicitWidth + Style.marginM * widgetScale : 0
  readonly property real contentMargin: Style.marginL * widgetScale

  implicitWidth: hasData ? dayLabelWidth + statsWidth + columns * cellStep - (3 * widgetScale) + contentMargin * 2 : 240 * widgetScale
  implicitHeight: contentColumn.implicitHeight + contentMargin * 2
  width: implicitWidth
  height: implicitHeight

  function weekdayOf(dateStr) {
    var p = dateStr.split("-")
    return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2])).getDay()
  }

  function cellColor(level) {
    if (level <= 0) return Qt.alpha(Color.mOnSurface, 0.08)
    return Qt.alpha(Color.mPrimary, [0.25, 0.45, 0.7, 1.0][Math.min(level, 4) - 1])
  }

  function footerText() {
    // Hover needs Noctalia >= 4.7.2; older shells keep desktop widgets click-through
    if (hoveredIndex >= 0 && hoveredIndex < slicedDays.length) {
      var day = slicedDays[hoveredIndex]
      var date = new Date(day.date + "T12:00:00").toLocaleDateString(Qt.locale(), Locale.ShortFormat)
      if (day.count === 0 || day.level === 0) return pluginApi?.tr("desktop.cellNone", { "date": date })
      if (day.count < 0) return pluginApi?.tr("desktop.cellSomeUnknown", { "date": date })
      return pluginApi?.tr("desktop.cellSome", { "count": day.count, "date": date })
    }
    var name = "@" + (mainInstance?.username ?? "")
    if (!allDays.length) return name
    // The calendar rolls over at UTC, so the last cell isn't always today locally
    var last = allDays[allDays.length - 1]
    var today = Qt.formatDate(new Date(), "yyyy-MM-dd")
    if (last.date !== today || last.count < 0) return name
    return name + " · " + pluginApi?.tr("desktop.todayCount", { "count": last.count })
  }

  ColumnLayout {
    id: contentColumn
    anchors.fill: parent
    anchors.margins: root.contentMargin
    spacing: Style.marginS * root.widgetScale

    // Total + streak header
    RowLayout {
      Layout.fillWidth: true
      visible: !root.compact && root.showTotal && root.hasData
      spacing: Style.marginM * root.widgetScale

      NText {
        text: pluginApi?.tr("desktop.total", { "total": root.mainInstance?.totalContributions ?? 0 })
        pointSize: Style.fontSizeS * root.widgetScale
        font.weight: Font.Bold
        color: Color.mOnSurface
      }

      Item { Layout.fillWidth: true }

      NText {
        visible: (root.mainInstance?.currentStreak ?? 0) > 0
        text: pluginApi?.tr("desktop.streak", { "count": root.mainInstance?.currentStreak ?? 0 })
        pointSize: Style.fontSizeXS * root.widgetScale
        color: Color.mOnSurfaceVariant
      }
    }

    // Month labels
    Item {
      Layout.fillWidth: true
      visible: !root.compact && root.showLabels && root.hasData
      implicitHeight: Style.fontSizeXS * root.widgetScale * 1.6

      Repeater {
        model: root.monthLabels
        NText {
          x: root.dayLabelWidth + modelData.col * root.cellStep
          text: modelData.name
          pointSize: Style.fontSizeXS * root.widgetScale
          color: Color.mOnSurfaceVariant
        }
      }
    }

    // Heatmap grid with stats or weekday labels alongside
    RowLayout {
      visible: root.hasData
      spacing: root.compact ? Style.marginM * root.widgetScale : 0

      ColumnLayout {
        id: statsColumn
        visible: root.compact && root.showTotal
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        NText {
          text: (root.mainInstance?.currentStreak ?? 0).toString()
          pointSize: Style.fontSizeXXL * 1.4 * root.widgetScale
          font.weight: Font.Bold
          color: Color.mPrimary
        }
        NText {
          text: pluginApi?.tr("desktop.streakLabel")
          pointSize: Style.fontSizeXS * root.widgetScale
          color: Color.mOnSurfaceVariant
        }
        Item { implicitHeight: Style.marginM * root.widgetScale }
        NText {
          text: Number(root.mainInstance?.totalContributions ?? 0).toLocaleString(Qt.locale(), 'f', 0)
          pointSize: Style.fontSizeXXL * 1.4 * root.widgetScale
          font.weight: Font.Bold
          color: Color.mOnSurface
        }
        NText {
          text: pluginApi?.tr("desktop.contributionsLabel")
          pointSize: Style.fontSizeXS * root.widgetScale
          color: Color.mOnSurfaceVariant
        }
      }

      Item {
        visible: !root.compact && root.showLabels
        implicitWidth: root.dayLabelWidth
        implicitHeight: gridArea.implicitHeight

        Repeater {
          model: [1, 3, 5]
          NText {
            y: modelData * root.cellStep + (root.cellSize - height) / 2
            text: Qt.locale().dayName(modelData, Locale.ShortFormat)
            pointSize: Style.fontSizeXXS * root.widgetScale
            color: Color.mOnSurfaceVariant
          }
        }
      }

      Item {
        id: gridArea
        implicitWidth: root.columns * root.cellStep - (3 * root.widgetScale)
        implicitHeight: 7 * root.cellStep - (3 * root.widgetScale)

        Repeater {
          model: root.slicedDays
          Rectangle {
            readonly property int gridIndex: index + root.padOffset
            x: Math.floor(gridIndex / 7) * root.cellStep
            y: (gridIndex % 7) * root.cellStep
            width: root.cellSize
            height: root.cellSize
            radius: 2 * root.widgetScale
            color: root.cellColor(modelData.level)
            border.width: root.hoveredIndex === index ? Math.max(1, root.widgetScale) : 0
            border.color: Color.mOnSurface
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
          onPositionChanged: mouse => {
            var col = Math.floor(mouse.x / root.cellStep)
            var row = Math.floor(mouse.y / root.cellStep)
            var i = col * 7 + row - root.padOffset
            root.hoveredIndex = (row >= 0 && row < 7 && i >= 0 && i < root.slicedDays.length) ? i : -1
          }
          onExited: root.hoveredIndex = -1
        }
      }
    }

    // Hovered day details / username
    NText {
      Layout.fillWidth: true
      visible: root.hasData
      text: root.footerText()
      pointSize: Style.fontSizeXS * root.widgetScale
      color: Color.mOnSurfaceVariant
      elide: Text.ElideRight
    }

    // Placeholder when not configured or loading
    NText {
      Layout.alignment: Qt.AlignHCenter
      Layout.margins: Style.marginL * root.widgetScale
      visible: !root.hasData
      text: {
        if (root.mainInstance?.errorMessage) return root.mainInstance.errorMessage
        if (root.mainInstance?.loading) return pluginApi?.tr("desktop.loading")
        return pluginApi?.tr("errors.noUsername")
      }
      pointSize: Style.fontSizeS * root.widgetScale
      color: Color.mOnSurfaceVariant
    }
  }
}
