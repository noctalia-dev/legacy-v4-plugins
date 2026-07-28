import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  property real contentPreferredWidth: 440 * Style.uiScaleRatio
  property real contentPreferredHeight: panelContainer.implicitHeight

  readonly property var mon: pluginApi?.mainInstance
  readonly property var cfg: pluginApi?.pluginSettings ?? pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  readonly property bool dataReady: mon?.available ?? false
  readonly property real headerToMetricsGap: 8

  function cfgBool(key, fallback) {
    return cfg[key] !== undefined ? !!cfg[key] : fallback;
  }

  readonly property string iconColorKey: cfg.iconColor !== undefined ? cfg.iconColor : "primary"
  readonly property color graphColor: Color.resolveColorKey(iconColorKey === "none" ? "primary" : iconColorKey)

  // Цвета для разных линий графиков (берем из темы)
  readonly property var lineColors: [
    Color.mPrimary,
    Color.mSecondary,
    Color.mTertiary,
    Color.resolveColorKey("error"),
    Color.resolveColorKey("warning"),
  ]

  function getLineColor(index) {
    return lineColors[index % lineColors.length];
  }

  // Функция для определения цвета на основе процента (75% warning, 90% critical)
  function getThresholdColor(percentValue) {
    if (percentValue >= 90)
      return Color.resolveColorKey("error");
    if (percentValue >= 75)
      return Color.mTertiary;
    return graphColor;
  }

  // Цвет для температурных датчиков
  function tempGraphColor(sensorType) {
    if (sensorType === "junction")
      return Color.mPrimary;
    if (sensorType === "edge")
      return Color.mSecondary;
    if (sensorType === "memory")
      return Color.mTertiary;
    return graphColor;
  }

  // Цвет для температурных датчиков с учетом предупреждений
  function getTempColor(sensorType) {
    if (!mon)
      return tempGraphColor(sensorType);

    if (sensorType === "junction") {
      if (mon.gpuCritical)
        return Color.resolveColorKey("error");
      if (mon.gpuWarning)
        return Color.resolveColorKey("warning");
    }

    return tempGraphColor(sensorType);
  }

  function clockMhzLabel(mhz) {
    return mhz > 0 ? `${Math.round(mhz)} MHz` : "—";
  }

  readonly property string displayTempSensor: {
    if (cfgBool("showTempJunction", true))
      return "junction";
    if (cfgBool("showTempEdge", false))
      return "edge";
    if (cfgBool("showTempMemory", false))
      return "memory";
    return "";
  }

  readonly property real displayTemp: {
    if (!mon || displayTempSensor === "")
      return 0;
    if (displayTempSensor === "edge")
      return mon.tempEdge;
    if (displayTempSensor === "memory")
      return mon.tempMemory;
    return mon.tempJunction;
  }

  readonly property string displayClockKey: {
    if (cfgBool("showSclk", true))
      return "sclk";
    if (cfgBool("showMclk", true))
      return "mclk";
    if (cfgBool("showFclk", false))
      return "fclk";
    if (cfgBool("showSocclk", false))
      return "socclk";
    if (cfgBool("showDcefclk", false))
      return "dcefclk";
    return "";
  }

  function clockMhzForKey(key) {
    if (!mon || !key)
      return 0;
    if (key === "mclk")
      return mon.mclkMhz;
    if (key === "fclk")
      return mon.fclkMhz;
    if (key === "socclk")
      return mon.socclkMhz;
    if (key === "dcefclk")
      return mon.dcefclkMhz;
    return mon.sclkMhz;
  }

  readonly property string displayClockValue: mon && displayClockKey !== "" ? clockMhzLabel(clockMhzForKey(displayClockKey)) : "—"

  readonly property string displayVramValue: {
    if (!mon)
      return "—";
    if (cfgBool("showVram", true)) {
      if (mon.vramTotalGb > 0)
        return `${mon.vramUsedGb.toFixed(1)} / ${mon.vramTotalGb.toFixed(1)} GiB`;
      return `${Math.round(mon.vramPercent)}%`;
    }
    if (cfgBool("showVramActivity", false))
      return `${Math.round(mon.vramActivity)}%`;
    return "—";
  }

  Component.onCompleted: {
    if (mon)
      mon.registerPoller("panel:" + (pluginApi?.instanceId ?? "unknown"));
  }

  Component.onDestruction: {
    if (mon)
      mon.unregisterPoller("panel:" + (pluginApi?.instanceId ?? "unknown"));
  }

  NBox {
    id: panelContainer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.marginS
    implicitHeight: mainColumn.implicitHeight + Style.marginM * 2
    color: Color.mSurface
    border.width: 0
    radius: Style.radiusL

    ColumnLayout {
      id: mainColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginM
      spacing: headerToMetricsGap

      // Заголовок
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: "device-desktop-analytics"
          pointSize: 24 * Style.uiScaleRatio
          color: Color.mOnSurface
        }

        NText {
          text: pluginApi?.tr("panel.title") ?? "AMD GPU Monitor"
          pointSize: Style.fontSizeM
          color: Color.mOnSurface
        }

        Item { Layout.fillWidth: true }

        NText {
          text: mon ? mon.productName : "—"
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
        }
      }

      NBox {
        id: errorBox
        visible: !dataReady
        Layout.fillWidth: true
        implicitHeight: errorCol.implicitHeight + Style.marginM * 2
        color: Color.resolveColorKey("errorContainer")
        border.color: Color.resolveColorKey("error")
        border.width: 1
        radius: Style.radiusM

        ColumnLayout {
          id: errorCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText {
            text: pluginApi?.tr("panel.unavailable") ?? "GPU data unavailable"
            pointSize: Style.fontSizeS
            color: Color.resolveColorKey("onErrorContainer")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            text: mon?.lastError || pluginApi?.tr("panel.check_rocm") || ""
            pointSize: Style.fontSizeXS
            color: Color.resolveColorKey("onErrorContainer")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }
        }
      }

      // Основные метрики
      ColumnLayout {
        visible: dataReady
        Layout.fillWidth: true
        spacing: Style.marginM

        // GPU Use
        MetricCard {
          id: gpuUseCard
          cardIcon: "activity"
          cardTitle: pluginApi?.tr("metrics.gpu_use") ?? "GPU Use"
          displayValue: mon ? `${Math.round(mon.gpuUse)}%` : "—"
          displayColor: getThresholdColor(mon?.gpuUse ?? 0)
          graphValues: mon ? mon.gpuUseHistory : []
          graphMin: 0
          graphMax: 100
          pollMs: mon ? mon.pollIntervalMs : 1000

          readonly property bool _isVisible: cfgBool("showGpuUse", true)
          visible: _isVisible
          Layout.fillWidth: true
        }

        // Temperatures (Grouped)
        GroupedMetricCard {
          id: tempCard
          cardIcon: "flame"
          cardTitle: pluginApi?.tr("metrics.temperature") ?? "Temperature"
          displayValue: mon && displayTempSensor !== "" ? `${Math.round(displayTemp)}°C` : "—"
          displayColor: getTempColor(displayTempSensor || "junction")
          graphMin: 0 // Явно задаем минимум для температур
          graphMax: 100 // Фиксированный максимум для температур
          pollMs: mon ? mon.pollIntervalMs : 1000
          lines: [
            {
              visible: cfgBool("showTempJunction", true),
              values: mon ? mon.tempJunctionHistory : [],
              color: tempGraphColor("junction"),
              isPrimary: displayTempSensor === "junction",
              label: pluginApi?.tr("temp.junction") ?? "Junction"
            },
            {
              visible: cfgBool("showTempEdge", false),
              values: mon ? mon.tempEdgeHistory : [],
              color: tempGraphColor("edge"),
              isPrimary: displayTempSensor === "edge",
              label: pluginApi?.tr("temp.edge") ?? "Edge"
            },
            {
              visible: cfgBool("showTempMemory", false),
              values: mon ? mon.tempMemoryHistory : [],
              color: tempGraphColor("memory"),
              isPrimary: displayTempSensor === "memory",
              label: pluginApi?.tr("temp.memory") ?? "Memory"
            }
          ]

          readonly property bool _isVisible: cfgBool("showTempJunction", true) || cfgBool("showTempEdge", false) || cfgBool("showTempMemory", false)
          visible: _isVisible
          Layout.fillWidth: true
        }

        // VRAM (Grouped: VRAM Usage + VRAM Activity)
        GroupedMetricCard {
          id: vramCard
          cardIcon: "database"
          cardTitle: pluginApi?.tr("metrics.vram") ?? "VRAM"
          displayValue: displayVramValue
          displayColor: graphColor
          graphMin: 0
          graphMax: 100
          pollMs: mon ? mon.pollIntervalMs : 1000
          lines: [
            {
              visible: cfgBool("showVram", true),
              values: mon ? mon.vramHistory : [],
              color: graphColor,
              isPrimary: cfgBool("showVram", true),
              label: pluginApi?.tr("vram.usage") ?? "Usage"
            },
            {
              visible: cfgBool("showVramActivity", false),
              values: mon ? mon.vramActivityHistory : [],
              color: getLineColor(1),
              isPrimary: !cfgBool("showVram", true) && cfgBool("showVramActivity", false),
              label: pluginApi?.tr("vram.activity") ?? "Activity"
            }
          ]

          readonly property bool _isVisible: cfgBool("showVram", true) || cfgBool("showVramActivity", false)
          visible: _isVisible
          Layout.fillWidth: true
        }

        // Fan Speed
        MetricCard {
          id: fanSpeedCard
          cardIcon: "car-fan"
          cardTitle: pluginApi?.tr("metrics.fan_speed") ?? "Fan Speed"
          displayValue: mon ? `${Math.round(mon.fanSpeed)}%` : "—"
          displayColor: graphColor
          graphValues: mon ? mon.fanSpeedHistory : []
          graphMin: 0
          graphMax: 100
          pollMs: mon ? mon.pollIntervalMs : 1000

          readonly property bool _isVisible: cfgBool("showFanSpeed", false)
          visible: _isVisible
          Layout.fillWidth: true
        }

        // Power
        MetricCard {
          id: powerCard
          cardIcon: "bolt"
          cardTitle: pluginApi?.tr("metrics.power") ?? "Power"
          displayValue: mon ? `${mon.powerWatts.toFixed(0)} W` : "—"
          displayColor: graphColor
          graphValues: mon ? mon.powerHistory : []
          graphMin: 0
          graphMax: mon ? Math.max(50, mon.powerGraphMax ?? 300) : 300
          pollMs: mon ? mon.pollIntervalMs : 1000

          readonly property bool _isVisible: cfgBool("showPower", true)
          visible: _isVisible
          Layout.fillWidth: true
        }

        // Clocks (Grouped: SCLK, MCLK, FCLK, SOCCLK, DCEFLK)
        GroupedMetricCard {
          id: clocksCard
          cardIcon: "clock"
          cardTitle: pluginApi?.tr("metrics.clock_speeds") ?? "Clock speeds"
          displayValue: displayClockValue
          displayColor: graphColor
          graphMin: 0
          graphMax: mon ? Math.max(
            100,
            cfgBool("showSclk", true) ? mon.historyMax(mon.sclkHistory, 100) : 0,
            cfgBool("showMclk", true) ? mon.historyMax(mon.mclkHistory, 100) : 0,
            cfgBool("showFclk", false) ? mon.historyMax(mon.fclkHistory, 100) : 0,
            cfgBool("showSocclk", false) ? mon.historyMax(mon.socclkHistory, 100) : 0,
            cfgBool("showDcefclk", false) ? mon.historyMax(mon.dcefclkHistory, 100) : 0
          ) : 100
          pollMs: mon ? mon.pollIntervalMs : 1000
          lines: [
            {
              visible: cfgBool("showSclk", true),
              values: mon ? mon.sclkHistory : [],
              color: graphColor,
              isPrimary: displayClockKey === "sclk",
              label: pluginApi?.tr("clocks.sclk") ?? "SCLK"
            },
            {
              visible: cfgBool("showMclk", true),
              values: mon ? mon.mclkHistory : [],
              color: getLineColor(1),
              isPrimary: displayClockKey === "mclk",
              label: pluginApi?.tr("clocks.mclk") ?? "MCLK"
            },
            {
              visible: cfgBool("showFclk", false),
              values: mon ? mon.fclkHistory : [],
              color: getLineColor(2),
              isPrimary: displayClockKey === "fclk",
              label: pluginApi?.tr("clocks.fclk") ?? "FCLK"
            },
            {
              visible: cfgBool("showSocclk", false),
              values: mon ? mon.socclkHistory : [],
              color: getLineColor(3),
              isPrimary: displayClockKey === "socclk",
              label: pluginApi?.tr("clocks.socclk") ?? "SOCCLK"
            },
            {
              visible: cfgBool("showDcefclk", false),
              values: mon ? mon.dcefclkHistory : [],
              color: getLineColor(4),
              isPrimary: displayClockKey === "dcefclk",
              label: pluginApi?.tr("clocks.dcefclk") ?? "DCEFCLK"
            }
          ]

          readonly property bool _isVisible: cfgBool("showSclk", true) || cfgBool("showMclk", true) || cfgBool("showFclk", false) || cfgBool("showSocclk", false) || cfgBool("showDcefclk", false)
          visible: _isVisible
          Layout.fillWidth: true
        }

        // VRAM Activity (Separate Card if needed)
        MetricCard {
          id: vramActivityCard
          cardIcon: "chart-line"
          cardTitle: pluginApi?.tr("metrics.vram_activity") ?? "VRAM Activity"
          displayValue: mon ? `${Math.round(mon.vramActivity)}%` : "—"
          displayColor: getLineColor(1)
          graphValues: mon ? mon.vramActivityHistory : []
          graphMin: 0
          graphMax: 100
          pollMs: mon ? mon.pollIntervalMs : 1000

          readonly property bool _isVisible: cfgBool("showVramActivity", false) && !cfgBool("showVram", true)
          visible: _isVisible
          Layout.fillWidth: true
        }
      }
    }
  }

  // Компонент для одиночных метрик
  component MetricCard: NBox {
    id: card

    property string cardIcon: ""
    property string cardTitle: ""
    property string displayValue: ""
    property color displayColor: Color.mPrimary
    property var graphValues: []
    property real graphMin: 0
    property real graphMax: 100
    property int pollMs: 1000

    Layout.preferredHeight: (100 + 8) * Style.uiScaleRatio

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginS
      anchors.bottomMargin: Style.radiusM
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        NIcon {
          icon: card.cardIcon
          pointSize: Style.fontSizeXS
          color: card.displayColor
        }

        NText {
          text: card.cardTitle
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
        }

        Item {
          Layout.fillWidth: true
        }

        NText {
          text: card.displayValue
          pointSize: Style.fontSizeXS
          color: card.displayColor
          font.family: Settings.data.ui.fontFixed
        }
      }

      NGraph {
        id: singleGraph
        Layout.fillWidth: true
        Layout.preferredHeight: 48 * Style.uiScaleRatio
        values: card.graphValues
        minValue: card.graphMin
        maxValue: card.graphMax
        color: card.displayColor
        strokeWidth: Math.max(1, Style.uiScaleRatio)
        fill: true
        fillOpacity: 0.15
        updateInterval: card.pollMs
        animateScale: true
      }
    }
  }

  // Компонент для группированных метрик с несколькими линиями
  component GroupedMetricCard: NBox {
    id: groupedCard

    property string cardIcon: ""
    property string cardTitle: ""
    property string displayValue: ""
    property color displayColor: Color.mPrimary
    property real graphMin: 0
    property real graphMax: 100
    property int pollMs: 1000
    
    // Массив объектов, описывающих линии графика: { visible, values, color, isPrimary }
    property var lines: []

    Layout.preferredHeight: (138) * Style.uiScaleRatio

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginS
      anchors.bottomMargin: Style.radiusM
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        NIcon {
          icon: groupedCard.cardIcon
          pointSize: Style.fontSizeXS
          color: groupedCard.displayColor
        }

        NText {
          text: groupedCard.cardTitle
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
        }

        Item {
          Layout.fillWidth: true
        }

        NText {
          text: groupedCard.displayValue
          pointSize: Style.fontSizeXS
          color: groupedCard.displayColor
          font.family: Settings.data.ui.fontFixed
        }
      }

      // Подписи линий
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Repeater {
          model: groupedCard.lines.length

          NText {
            required property int index

            visible: groupedCard.lines[index].visible
            text: groupedCard.lines[index].label ?? ""
            pointSize: Style.fontSizeXS
            color: groupedCard.lines[index].color
            font.family: Settings.data.ui.fontFixed
          }
        }
      }

      // Контейнер для наложенных графиков
      Item {
        id: graphContainer
        Layout.fillWidth: true
        Layout.preferredHeight: 48 * Style.uiScaleRatio

        Repeater {
          model: groupedCard.lines.length

          NGraph {
            required property int index

            anchors.fill: parent
            visible: groupedCard.lines[index].visible
            values: groupedCard.lines[index].values
            minValue: groupedCard.graphMin
            maxValue: groupedCard.graphMax
            color: groupedCard.lines[index].color
            strokeWidth: Math.max(1, Style.uiScaleRatio)
            fill: groupedCard.lines[index].isPrimary // Заполняем только основную линию
            fillOpacity: 0.15
            updateInterval: groupedCard.pollMs
            animateScale: true
            z: groupedCard.lines[index].isPrimary ? 1 : 0 // Основная линия сверху
          }
        }
      }
    }
  }
}