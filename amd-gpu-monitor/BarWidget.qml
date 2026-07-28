import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property var mon: pluginApi?.mainInstance
  readonly property var cfg: pluginApi?.pluginSettings ?? pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  readonly property bool compactMode: cfg.compactMode !== undefined ? cfg.compactMode : true
  readonly property string iconColorKey: cfg.iconColor !== undefined ? cfg.iconColor : "primary"
  readonly property string textColorKey: cfg.textColor !== undefined ? cfg.textColor : "onSurface"
  readonly property bool useMonospaceFont: cfg.useMonospaceFont !== undefined ? cfg.useMonospaceFont : true
  readonly property bool usePadding: !compactMode && !isVertical && useMonospaceFont && (cfg.usePadding !== undefined ? cfg.usePadding : false)
  readonly property string fontFamily: useMonospaceFont ? Settings.data.ui.fontFixed : Settings.data.ui.fontDefault
  readonly property color iconColor: Color.resolveColorKey(iconColorKey === "none" ? "primary" : iconColorKey)
  readonly property color textColor: Color.resolveColorKey(textColorKey === "none" ? "onSurface" : textColorKey)

  function cfgBool(key, fallback) {
    return cfg[key] !== undefined ? !!cfg[key] : fallback;
  }

  readonly property bool dataReady: mon?.available ?? false

  readonly property int paddingPercent: usePadding ? String("100%").length : 0
  readonly property int paddingTemp: usePadding ? String("999°").length : 0
  readonly property int paddingPower: usePadding ? String("999W").length : 0
  readonly property int paddingMhz: usePadding ? String("9999").length : 0
  readonly property int paddingFan: usePadding ? String("999%").length : 0

  readonly property real iconSize: Style.toOdd(capsuleHeight * 0.48)
  readonly property real miniGaugeWidth: Math.max(3, Style.toOdd(iconSize * 0.25))
  readonly property real powerGaugeMax: mon ? Math.max(50, mon.powerGraphMax) : 300

  readonly property real contentWidth: isVertical ? capsuleHeight : Math.round(mainGrid.implicitWidth + Style.marginM * 2)
  readonly property real contentHeight: isVertical ? Math.round(mainGrid.implicitHeight + Style.marginM * 2) : capsuleHeight

  function tempTint(sensor) {
    if (!mon)
      return iconColor;
    if (sensor === "junction") {
      if (mon.gpuCritical)
        return Color.mError;
      if (mon.gpuWarning)
        return Color.mWarning;
    }
    return iconColor;
  }

  function clockGaugeMax(history) {
    return mon ? mon.historyMax(history, 100) : 100;
  }

  function gaugeFillColor(ratio, baseColor) {
    if (ratio >= 0.9)
      return Color.mError;
    if (ratio >= 0.75)
      return Color.mTertiary;
    return baseColor;
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

  readonly property var tempGaugeEntries: {
    if (!dataReady || !mon)
      return [];
    const entries = [];
    if (cfgBool("showTempJunction", true))
      entries.push({
                     "ratio": Math.min(1, mon.tempJunction / 100),
                     "fillColor": gaugeFillColor(Math.min(1, mon.tempJunction / 100), tempTint("junction"))
                   });
    if (cfgBool("showTempEdge", false))
      entries.push({
                     "ratio": Math.min(1, mon.tempEdge / 100),
                     "fillColor": gaugeFillColor(Math.min(1, mon.tempEdge / 100), tempTint("edge"))
                   });
    if (cfgBool("showTempMemory", false))
      entries.push({
                     "ratio": Math.min(1, mon.tempMemory / 100),
                     "fillColor": gaugeFillColor(Math.min(1, mon.tempMemory / 100), tempTint("memory"))
                   });
    return entries;
  }

  readonly property string tempTextValue: mon && displayTempSensor !== "" ? `${Math.round(displayTemp)}°`.padStart(paddingTemp, " ") : ""
  readonly property color tempIconTint: tempTint("junction")
  readonly property color tempTextTint: tempTint("junction")

  readonly property var vramGaugeEntries: {
    if (!dataReady || !mon)
      return [];
    const entries = [];
    if (cfgBool("showVram", true))
      entries.push({
                     "ratio": mon.vramPercent / 100,
                     "fillColor": gaugeFillColor(mon.vramPercent / 100, iconColor)
                   });
    if (cfgBool("showVramActivity", false))
      entries.push({
                     "ratio": mon.vramActivity / 100,
                     "fillColor": gaugeFillColor(mon.vramActivity / 100, iconColor)
                   });
    return entries;
  }

  readonly property string vramTextValue: {
    if (!mon)
      return "";
    if (cfgBool("showVram", true))
      return `${Math.round(mon.vramPercent)}%`.padStart(paddingPercent, " ");
    if (cfgBool("showVramActivity", false))
      return `${Math.round(mon.vramActivity)}%`.padStart(paddingPercent, " ");
    return "";
  }

  readonly property var clockGaugeEntries: {
    if (!dataReady || !mon)
      return [];
    const entries = [];
    if (cfgBool("showSclk", true))
      entries.push({
                     "ratio": Math.min(1, mon.sclkMhz / clockGaugeMax(mon.sclkHistory)),
                     "fillColor": gaugeFillColor(Math.min(1, mon.sclkMhz / clockGaugeMax(mon.sclkHistory)), iconColor)
                   });
    if (cfgBool("showMclk", true))
      entries.push({
                     "ratio": Math.min(1, mon.mclkMhz / clockGaugeMax(mon.mclkHistory)),
                     "fillColor": gaugeFillColor(Math.min(1, mon.mclkMhz / clockGaugeMax(mon.mclkHistory)), iconColor)
                   });
    if (cfgBool("showFclk", false))
      entries.push({
                     "ratio": Math.min(1, mon.fclkMhz / clockGaugeMax(mon.fclkHistory)),
                     "fillColor": gaugeFillColor(Math.min(1, mon.fclkMhz / clockGaugeMax(mon.fclkHistory)), iconColor)
                   });
    if (cfgBool("showSocclk", false))
      entries.push({
                     "ratio": Math.min(1, mon.socclkMhz / clockGaugeMax(mon.socclkHistory)),
                     "fillColor": gaugeFillColor(Math.min(1, mon.socclkMhz / clockGaugeMax(mon.socclkHistory)), iconColor)
                   });
    if (cfgBool("showDcefclk", false))
      entries.push({
                     "ratio": Math.min(1, mon.dcefclkMhz / clockGaugeMax(mon.dcefclkHistory)),
                     "fillColor": gaugeFillColor(Math.min(1, mon.dcefclkMhz / clockGaugeMax(mon.dcefclkHistory)), iconColor)
                   });
    return entries;
  }

  readonly property string clockTextValue: {
    if (!mon)
      return "";
    if (cfgBool("showSclk", true))
      return mon.sclkMhz > 0 ? `${Math.round(mon.sclkMhz)}`.padStart(paddingMhz, " ") : "—";
    if (cfgBool("showMclk", true))
      return mon.mclkMhz > 0 ? `${Math.round(mon.mclkMhz)}`.padStart(paddingMhz, " ") : "—";
    if (cfgBool("showFclk", false))
      return mon.fclkMhz > 0 ? `${Math.round(mon.fclkMhz)}`.padStart(paddingMhz, " ") : "—";
    if (cfgBool("showSocclk", false))
      return mon.socclkMhz > 0 ? `${Math.round(mon.socclkMhz)}`.padStart(paddingMhz, " ") : "—";
    if (cfgBool("showDcefclk", false))
      return mon.dcefclkMhz > 0 ? `${Math.round(mon.dcefclkMhz)}`.padStart(paddingMhz, " ") : "—";
    return "";
  }

  function clockMhzLabel(mhz) {
    return mhz > 0 ? `${Math.round(mhz)} MHz` : "—";
  }

  function buildTooltipContent() {
    if (!dataReady || !mon)
      return [];

    const rows = [];
    const tr = key => pluginApi?.tr(key) ?? key;

    if (mon.productName)
      rows.push([mon.productName, ""]);

    if (cfgBool("showGpuUse", true))
      rows.push([tr("metrics.gpu_use"), `${Math.round(mon.gpuUse)}%`]);

    if (cfgBool("showTempJunction", true))
      rows.push([tr("metrics.temp_junction"), `${Math.round(mon.tempJunction)}°C`]);
    if (cfgBool("showTempEdge", false))
      rows.push([tr("metrics.temp_edge"), `${Math.round(mon.tempEdge)}°C`]);
    if (cfgBool("showTempMemory", false))
      rows.push([tr("metrics.temp_memory"), `${Math.round(mon.tempMemory)}°C`]);

    if (cfgBool("showVram", true)) {
      if (mon.vramTotalGb > 0)
        rows.push([tr("metrics.vram"), `${Math.round(mon.vramPercent)}% (${mon.vramUsedGb.toFixed(1)} / ${mon.vramTotalGb.toFixed(1)} GiB)`]);
      else
        rows.push([tr("metrics.vram"), `${Math.round(mon.vramPercent)}%`]);
    }

    if (cfgBool("showVramActivity", false))
      rows.push([tr("metrics.vram_activity"), `${Math.round(mon.vramActivity)}%`]);

    if (cfgBool("showFanSpeed", false))
      rows.push([tr("metrics.fan_speed"), `${Math.round(mon.fanSpeed)}%`]);

    if (cfgBool("showPower", true))
      rows.push([tr("metrics.power"), `${mon.powerWatts.toFixed(0)} W`]);

    if (cfgBool("showSclk", true))
      rows.push([tr("metrics.sclk"), clockMhzLabel(mon.sclkMhz)]);
    if (cfgBool("showMclk", true))
      rows.push([tr("metrics.mclk"), clockMhzLabel(mon.mclkMhz)]);
    if (cfgBool("showFclk", false))
      rows.push([tr("metrics.fclk"), clockMhzLabel(mon.fclkMhz)]);
    if (cfgBool("showSocclk", false))
      rows.push([tr("metrics.socclk"), clockMhzLabel(mon.socclkMhz)]);
    if (cfgBool("showDcefclk", false))
      rows.push([tr("metrics.dcefclk"), clockMhzLabel(mon.dcefclkMhz)]);

    return rows;
  }

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Component.onCompleted: {
    if (mon)
      mon.registerPoller("bar:" + (screenName || "unknown"));
  }

  Component.onDestruction: {
    if (mon)
      mon.unregisterPoller("bar:" + (screenName || "unknown"));
  }

  Rectangle {
    id: visualCapsule
    anchors.centerIn: parent
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusL
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    GridLayout {
      id: mainGrid
      anchors.centerIn: parent
      flow: isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
      rows: isVertical ? -1 : 1
      columns: isVertical ? 1 : -1
      rowSpacing: isVertical ? (compactMode ? Style.marginL : Style.marginXL) : 0
      columnSpacing: isVertical ? 0 : Style.marginM

      StatCell {
        visible: cfgBool("showGpuUse", true) && dataReady
        metricIcon: "activity"
        percentText: `${Math.round(mon.gpuUse)}%`.padStart(paddingPercent, " ")
        gaugeRatio: mon.gpuUse / 100
        iconTint: iconColor
        textTint: textColor
        gaugeTint: gaugeFillColor(mon.gpuUse / 100, iconColor)
      }

      GroupedStatCell {
        visible: tempGaugeEntries.length > 0
        metricIcon: "flame"
        iconTint: tempIconTint
        textValue: tempTextValue
        textTint: tempTextTint
        gaugeEntries: tempGaugeEntries
      }

      GroupedStatCell {
        visible: vramGaugeEntries.length > 0
        metricIcon: "database"
        iconTint: iconColor
        textValue: vramTextValue
        textTint: textColor
        gaugeEntries: vramGaugeEntries
      }

      StatCell {
        visible: cfgBool("showPower", true) && dataReady
        metricIcon: "bolt"
        percentText: `${Math.round(mon.powerWatts)}W`.padStart(paddingPower, " ")
        gaugeRatio: Math.min(1, mon.powerWatts / powerGaugeMax)
        iconTint: iconColor
        textTint: textColor
        gaugeTint: gaugeFillColor(Math.min(1, mon.powerWatts / powerGaugeMax), iconColor)
      }

      StatCell {
        visible: cfgBool("showFanSpeed", false) && dataReady
        metricIcon: "car-fan"
        percentText: `${Math.round(mon.fanSpeed)}%`.padStart(paddingFan, " ")
        gaugeRatio: mon.fanSpeed / 100
        iconTint: iconColor
        textTint: textColor
        gaugeTint: gaugeFillColor(mon.fanSpeed / 100, iconColor)
      }

      GroupedStatCell {
        visible: clockGaugeEntries.length > 0
        metricIcon: "clock"
        iconTint: iconColor
        textValue: clockTextValue
        textTint: textColor
        gaugeEntries: clockGaugeEntries
      }

      Item {
        visible: !dataReady
        Layout.preferredWidth: iconSize
        Layout.preferredHeight: iconSize
        Layout.alignment: Qt.AlignHCenter

        NIcon {
          anchors.centerIn: parent
          icon: "thermometer"
          pointSize: iconSize
          applyUiScale: false
          color: Color.mOnSurfaceVariant
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: function (mouse) {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi)
          pluginApi.openPanel(root.screen, root);
      } else if (mouse.button === Qt.RightButton) {
        TooltipService.hide();
        PanelService.showContextMenu(contextMenu, root, screen);
      }
    }

    onEntered: {
      const rows = buildTooltipContent();
      if (rows.length > 0)
        TooltipService.show(root, rows, BarService.getTooltipDirection(screenName));
      tooltipRefreshTimer.start();
    }

    onExited: {
      tooltipRefreshTimer.stop();
      TooltipService.hide();
    }
  }

  Timer {
    id: tooltipRefreshTimer
    interval: mon ? mon.pollIntervalMs : 1000
    repeat: true
    onTriggered: {
      const rows = buildTooltipContent();
      if (rows.length > 0)
        TooltipService.updateText(rows);
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("actions.widget_settings") || "Settings",
        "action": "widget-settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "widget-settings")
        BarService.openPluginSettings(screen, pluginApi.manifest);
    }
  }

  component StatCell: Item {
    id: cell

    property string metricIcon: ""
    property string percentText: ""
    property real gaugeRatio: 0
    property color iconTint: root.iconColor
    property color textTint: root.textColor
    property color gaugeTint: root.iconColor
    property bool showGauge: true
    property bool forceShowText: false

    implicitWidth: cellContent.implicitWidth
    implicitHeight: cellContent.implicitHeight
    Layout.preferredWidth: isVertical ? root.width : implicitWidth
    Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
    Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter

    GridLayout {
      id: cellContent
      anchors.centerIn: parent
      flow: (isVertical && !compactMode) ? GridLayout.TopToBottom : GridLayout.LeftToRight
      rows: (isVertical && !compactMode) ? 2 : 1
      columns: (isVertical && !compactMode) ? 1 : 2
      rowSpacing: compactMode ? 3 : Style.marginXS
      columnSpacing: compactMode ? 3 : Style.marginXS

      Item {
        Layout.preferredWidth: iconSize
        Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
        Layout.alignment: Qt.AlignCenter
        Layout.row: (isVertical && !compactMode) ? 1 : 0
        Layout.column: 0

        NIcon {
          icon: cell.metricIcon
          pointSize: iconSize
          applyUiScale: false
          x: Style.pixelAlignCenter(parent.width, width)
          y: Style.pixelAlignCenter(parent.height, (compactMode || isVertical) ? iconSize : capsuleHeight)
          color: cell.iconTint
        }
      }

      NText {
        visible: !compactMode || cell.forceShowText
        text: cell.percentText
        family: fontFamily
        pointSize: barFontSize
        applyUiScale: false
        Layout.alignment: Qt.AlignCenter
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: cell.textTint
        Layout.row: isVertical ? 0 : 0
        Layout.column: isVertical ? 0 : 1
      }

      Loader {
        active: compactMode && cell.showGauge
        visible: compactMode && cell.showGauge
        sourceComponent: miniGaugeComponent
        Layout.alignment: Qt.AlignCenter
        Layout.row: 0
        Layout.column: 1

        onLoaded: {
          item.ratio = Qt.binding(() => cell.gaugeRatio);
          item.fillColor = Qt.binding(() => cell.gaugeTint);
        }
      }
    }

    Component {
      id: miniGaugeComponent

      NLinearGauge {
        ratio: 0
        orientation: Qt.Vertical
        fillColor: Color.mPrimary
        width: root.miniGaugeWidth
        height: root.iconSize
      }
    }
  }

  component GroupedStatCell: Item {
    id: group

    property string metricIcon: ""
    property color iconTint: root.iconColor
    property string textValue: ""
    property color textTint: root.textColor
    property var gaugeEntries: []

    readonly property bool verticalGaugeLayout: isVertical && (!compactMode || gaugeEntries.length > 0)

    implicitWidth: groupContent.implicitWidth
    implicitHeight: groupContent.implicitHeight
    Layout.preferredWidth: isVertical ? root.width : implicitWidth
    Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
    Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter

    GridLayout {
      id: groupContent
      anchors.centerIn: parent
      flow: verticalGaugeLayout ? GridLayout.TopToBottom : GridLayout.LeftToRight
      rows: verticalGaugeLayout ? -1 : 1
      columns: verticalGaugeLayout ? 1 : -1
      rowSpacing: compactMode ? 3 : Style.marginXS
      columnSpacing: compactMode ? 3 : Style.marginXS

      Item {
        Layout.preferredWidth: iconSize
        Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
        Layout.alignment: Qt.AlignCenter
        Layout.row: (isVertical && !compactMode) ? 1 : 0
        Layout.column: 0

        NIcon {
          icon: group.metricIcon
          pointSize: iconSize
          applyUiScale: false
          x: Style.pixelAlignCenter(parent.width, width)
          y: Style.pixelAlignCenter(parent.height, (compactMode || isVertical) ? iconSize : capsuleHeight)
          color: group.iconTint
        }
      }

      NText {
        visible: !compactMode
        text: group.textValue
        family: fontFamily
        pointSize: barFontSize
        applyUiScale: false
        Layout.alignment: Qt.AlignCenter
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: group.textTint
        Layout.row: isVertical ? 0 : 0
        Layout.column: isVertical ? 0 : 1
      }

      Row {
        visible: compactMode && group.gaugeEntries.length > 0
        spacing: 3
        Layout.alignment: Qt.AlignCenter
        Layout.row: verticalGaugeLayout ? 1 : 0
        Layout.column: verticalGaugeLayout ? 0 : 1

        Repeater {
          model: group.gaugeEntries

          delegate: NLinearGauge {
            required property var modelData
            width: isVertical ? iconSize : miniGaugeWidth
            height: isVertical ? miniGaugeWidth : iconSize
            orientation: isVertical ? Qt.Horizontal : Qt.Vertical
            ratio: modelData.ratio
            fillColor: modelData.fillColor
          }
        }
      }
    }
  }
}
