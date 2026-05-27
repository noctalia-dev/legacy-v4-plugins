import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Hardware
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen

  // Keep the official Battery widget property surface so Bar.qml can pass its normal context.
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property var monitor: pluginApi?.mainInstance

  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

  readonly property string displayMode: cfg.displayMode ?? defaults.displayMode ?? "graphic-clean"
  readonly property bool useGraphicMode: displayMode === "graphic" || displayMode === "graphic-clean"

  readonly property bool hideIfNotDetected: cfg.hideIfNotDetected ?? defaults.hideIfNotDetected ?? true
  readonly property bool hideIfIdle: cfg.hideIfIdle ?? defaults.hideIfIdle ?? false
  readonly property bool showPowerProfiles: cfg.showPowerProfiles ?? defaults.showPowerProfiles ?? false
  readonly property bool showNoctaliaPerformance: cfg.showNoctaliaPerformance ?? defaults.showNoctaliaPerformance ?? false
  readonly property bool showPowerInBar: cfg.showPowerInBar ?? defaults.showPowerInBar ?? true
  readonly property bool showTimeInBar: cfg.showTimeInBar ?? defaults.showTimeInBar ?? true
  readonly property int refreshIntervalSeconds: Math.max(1, cfg.refreshIntervalSeconds ?? defaults.refreshIntervalSeconds ?? 5)
  property int refreshNonce: 0

  readonly property string deviceNativePath: cfg.deviceNativePath ?? defaults.deviceNativePath ?? "__default__"
  readonly property var selectedDevice: BatteryService.isDevicePresent(BatteryService.findDevice(deviceNativePath)) ? BatteryService.findDevice(deviceNativePath) : null

  readonly property bool isReady: BatteryService.isDeviceReady(selectedDevice)
  readonly property bool isPresent: BatteryService.isDevicePresent(selectedDevice)
  readonly property real percent: isReady ? BatteryService.getPercentage(selectedDevice) : -1
  readonly property bool isCharging: isReady ? BatteryService.isCharging(selectedDevice) : false
  readonly property bool isPluggedIn: isReady ? BatteryService.isPluggedIn(selectedDevice) : false
  readonly property bool isLowBattery: isReady ? BatteryService.isLowBattery(selectedDevice) : false
  readonly property bool isCriticalBattery: isReady ? BatteryService.isCriticalBattery(selectedDevice) : false
  readonly property bool shouldShow: !hideIfNotDetected || (isReady && (hideIfIdle ? !isPluggedIn : true))

  readonly property var barExtraSegments: buildBarExtraSegments()
  readonly property string barExtraText: barExtraSegments.join(" · ")
  readonly property string verticalBarExtraText: barExtraSegments.join("\n")

  readonly property var tooltipContent: {
    const tick = monitor ? monitor.refreshNonce : refreshNonce;
    if (!isReady || !isPresent) {
      return I18n.tr("battery.no-battery-detected");
    }

    let rows = [];
    const isInternal = selectedDevice.isLaptopBattery;
    if (isInternal) {
      rows.push([I18n.tr("battery.battery-level"), `${percent}%`]);

      let timeText = BatteryService.getTimeRemainingText(selectedDevice);
      if (timeText) {
        const colonIdx = timeText.indexOf(":");
        if (colonIdx >= 0) {
          rows.push([timeText.substring(0, colonIdx).trim(), timeText.substring(colonIdx + 1).trim()]);
        } else {
          rows.push([timeText, ""]);
        }
      }

      let rateText = BatteryService.getRateText(selectedDevice);
      if (!isPluggedIn && rateText) {
        const colonIdx = rateText.indexOf(":");
        if (colonIdx >= 0) {
          rows.push([rateText.substring(0, colonIdx).trim(), rateText.substring(colonIdx + 1).trim()]);
        } else {
          rows.push([rateText, ""]);
        }
      }

      let healthDevice = selectedDevice.healthSupported ? selectedDevice : (BatteryService.laptopBatteries.length > 0 ? BatteryService.laptopBatteries[0] : null);
      if (healthDevice && healthDevice.healthSupported) {
        rows.push([I18n.tr("battery.battery-health"), `${Math.round(healthDevice.healthPercentage)}%`]);
      }
    } else if (selectedDevice) {
      let name = BatteryService.getDeviceName(selectedDevice);
      rows.push([name, `${percent}%`]);
    }

    if (isInternal) {
      var external = BatteryService.bluetoothBatteries;
      if (external.length > 0) {
        if (rows.length > 0) {
          rows.push(["---", "---"]);
        }
        for (var j = 0; j < external.length; j++) {
          var dev = external[j];
          var dName = BatteryService.getDeviceName(dev);
          var dPct = BatteryService.getPercentage(dev);
          rows.push([dName, `${dPct}%`]);
        }
      }
    }

    return rows;
  }

  visible: shouldShow
  opacity: shouldShow ? 1.0 : 0.0

  implicitWidth: useGraphicMode ? capsule.width : pill.width
  implicitHeight: useGraphicMode ? capsule.height : pill.height

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("menu.settings"),
        "action": "settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "settings" && pluginApi) {
        BarService.openPluginSettings(screen, pluginApi.manifest);
      }
    }
  }

  // ==================== GRAPHIC MODE ====================

  Item {
    id: graphicContent
    visible: root.useGraphicMode
    anchors.centerIn: parent
    implicitWidth: root.isBarVertical ? Math.max(graphicColumn.implicitWidth, verticalExtraText.implicitWidth) : graphicRow.implicitWidth
    implicitHeight: root.isBarVertical ? graphicColumn.implicitHeight : graphicRow.implicitHeight
    width: implicitWidth
    height: implicitHeight

    RowLayout {
      id: graphicRow
      visible: !root.isBarVertical
      anchors.centerIn: parent
      spacing: Style.marginS

      NBattery {
        id: nBattery
        baseSize: (Style.getBarHeightForScreen(root.screenName) / root.capsuleHeight) * Style.fontSizeXXS
        showPercentageText: root.displayMode !== "graphic-clean"
        percentage: root.percent
        ready: root.isReady
        charging: root.isCharging
        pluggedIn: root.isPluggedIn
        low: root.isLowBattery
        critical: root.isCriticalBattery
        baseColor: graphicMouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        textColor: graphicMouseArea.containsMouse ? Color.mHover : Color.mSurface
      }

      NText {
        visible: root.barExtraText.length > 0
        text: `· ${root.barExtraText}`
        pointSize: Style.getBarFontSizeForScreen(root.screenName)
        font.weight: Style.fontWeightMedium
        color: graphicMouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
      }
    }

    ColumnLayout {
      id: graphicColumn
      visible: root.isBarVertical
      anchors.centerIn: parent
      spacing: Style.marginXS

      NBattery {
        Layout.alignment: Qt.AlignHCenter
        baseSize: (Style.getBarHeightForScreen(root.screenName) / root.capsuleHeight) * Style.fontSizeXXS
        showPercentageText: root.displayMode !== "graphic-clean"
        vertical: true
        percentage: root.percent
        ready: root.isReady
        charging: root.isCharging
        pluggedIn: root.isPluggedIn
        low: root.isLowBattery
        critical: root.isCriticalBattery
        baseColor: graphicMouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        textColor: graphicMouseArea.containsMouse ? Color.mHover : Color.mSurface
      }

      NText {
        id: verticalExtraText
        visible: root.verticalBarExtraText.length > 0
        Layout.alignment: Qt.AlignHCenter
        text: root.verticalBarExtraText
        pointSize: Math.max(Style.fontSizeXXS, Style.getBarFontSizeForScreen(root.screenName) * 0.75)
        font.weight: Style.fontWeightMedium
        color: graphicMouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 0.85
        lineHeightMode: Text.ProportionalHeight
      }
    }
  }

  Rectangle {
    id: capsule
    visible: root.useGraphicMode
    anchors.centerIn: graphicContent
    z: -1
    width: root.isBarVertical ? root.capsuleHeight : graphicContent.implicitWidth + Style.margin2S
    height: root.isBarVertical ? graphicContent.implicitHeight + Style.margin2S : root.capsuleHeight
    radius: Math.min(Style.radiusL, width / 2)
    color: graphicMouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.InOutQuad
      }
    }
  }

  MouseArea {
    id: graphicMouseArea
    visible: root.useGraphicMode
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      if (root.tooltipContent) {
        TooltipService.show(root, root.tooltipContent, BarService.getTooltipDirection(root.screen?.name));
        tooltipRefreshTimer.start();
      }
    }
    onExited: {
      tooltipRefreshTimer.stop();
      TooltipService.hide();
    }
    onClicked: mouse => {
      TooltipService.hide();
      if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, graphicContent, screen);
      } else {
        toggleBatteryPanel();
      }
    }
  }

  Timer {
    id: tooltipRefreshTimer
    interval: root.refreshIntervalSeconds * 1000
    repeat: true
    onTriggered: {
      if (graphicMouseArea.containsMouse) {
        TooltipService.updateText(root.tooltipContent);
      }
    }
  }

  // ==================== ICON MODE ====================

  BarPill {
    id: pill
    visible: !root.useGraphicMode
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: BatteryService.getIcon(root.percent, root.isCharging, root.isPluggedIn, root.isReady)
    text: iconModeText()
    suffix: iconModeSuffix()
    autoHide: false
    forceOpen: root.isReady && root.displayMode === "icon-always"
    forceClose: root.displayMode === "icon-only" || !root.isReady
    customBackgroundColor: root.isCharging ? Color.mPrimary : ((root.isLowBattery || root.isCriticalBattery) ? Color.mError : "transparent")
    customTextIconColor: root.isCharging ? Color.mOnPrimary : ((root.isLowBattery || root.isCriticalBattery) ? Color.mOnError : "transparent")
    tooltipText: root.tooltipContent
    onClicked: toggleBatteryPanel()
    onRightClicked: PanelService.showContextMenu(contextMenu, pill, screen)
  }

  Timer {
    interval: root.refreshIntervalSeconds * 1000
    repeat: true
    running: true
    onTriggered: root.refreshNonce++
  }

  // ==================== SHARED ====================

  function buildBarExtraSegments() {
    const tick = root.monitor ? root.monitor.refreshNonce : root.refreshNonce;
    const segments = [];
    if (showPowerInBar) {
      const powerText = formatPower(true, false);
      if (powerText) {
        segments.push(powerText);
      }
    }
    if (showTimeInBar) {
      const timeText = formatRemainingTime();
      if (timeText) {
        segments.push(timeText);
      }
    }
    return segments;
  }

  function iconModeText() {
    const tick = root.monitor ? root.monitor.refreshNonce : root.refreshNonce;
    if (!root.isReady) {
      return "-";
    }

    const extras = root.barExtraSegments;
    if (extras.length > 0 && root.displayMode !== "icon-only") {
      return `${root.percent}% · ${extras.join(" · ")}`;
    }

    return root.percent;
  }

  function iconModeSuffix() {
    if (!root.isReady) {
      return "%";
    }

    return root.barExtraSegments.length > 0 && root.displayMode !== "icon-only" ? "" : "%";
  }

  function formatPower(compact, showUnavailable) {
    if (root.monitor && root.monitor.sysfsOk) {
      return root.monitor.formatPower(compact, showUnavailable);
    }

    const rate = resolvePowerRate(selectedDevice);
    if (rate <= 0) {
      return showUnavailable ? pluginApi?.tr("common.unavailable") : "";
    }

    return `${rate.toFixed(1)}${compact ? "W" : " W"}`;
  }

  function resolvePowerRate(device) {
    const directRate = readDeviceRate(device);
    if (directRate > 0) {
      return directRate;
    }

    // UPower's DisplayDevice can report a zero rate even when BAT* devices have data.
    let totalRate = 0;
    let foundPhysicalRate = false;
    const batteries = BatteryService.laptopBatteries || [];
    for (let i = 0; i < batteries.length; i++) {
      const battery = batteries[i];
      if (!battery || (battery.nativePath && battery.nativePath.includes("DisplayDevice"))) {
        continue;
      }

      const rate = readDeviceRate(battery);
      if (rate > 0) {
        totalRate += rate;
        foundPhysicalRate = true;
      }
    }

    if (foundPhysicalRate) {
      return totalRate;
    }

    return directRate;
  }

  function readDeviceRate(device) {
    if (!device || device.changeRate === undefined || device.changeRate === null) {
      return -1;
    }

    const rate = Math.abs(Number(device.changeRate));
    return isNaN(rate) ? -1 : rate;
  }

  function formatRemainingTime() {
    if (root.monitor && root.monitor.sysfsOk) {
      return root.monitor.formatRelevantTime(false);
    }

    if (!isReady || !selectedDevice) {
      return "";
    }

    return formatDurationCompact(resolveRemainingSeconds(selectedDevice));
  }

  function resolveRemainingSeconds(device) {
    const directSeconds = readRemainingSeconds(device);
    if (directSeconds > 0) {
      return directSeconds;
    }

    const batteries = BatteryService.laptopBatteries || [];
    for (let i = 0; i < batteries.length; i++) {
      const battery = batteries[i];
      if (!battery || (battery.nativePath && battery.nativePath.includes("DisplayDevice"))) {
        continue;
      }

      const seconds = readRemainingSeconds(battery);
      if (seconds > 0) {
        return seconds;
      }
    }

    return 0;
  }

  function readRemainingSeconds(device) {
    if (!BatteryService.isDeviceReady(device)) {
      return 0;
    }

    if (BatteryService.isCharging(device) && device.timeToFull > 0) {
      return device.timeToFull;
    }
    if (!BatteryService.isCharging(device) && !BatteryService.isPluggedIn(device) && device.timeToEmpty > 0) {
      return device.timeToEmpty;
    }
    if (device.timeToFull > 0) {
      return device.timeToFull;
    }
    if (device.timeToEmpty > 0) {
      return device.timeToEmpty;
    }

    return 0;
  }

  function formatDurationCompact(seconds) {
    if (seconds <= 0) {
      return "";
    }

    const totalMinutes = Math.max(1, Math.round(seconds / 60));
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;

    if (hours > 0) {
      return minutes > 0 ? `${hours}h${minutes}m` : `${hours}h`;
    }

    return `${minutes}m`;
  }

  function toggleBatteryPanel() {
    if (!pluginApi) {
      return;
    }

    pluginApi.togglePanel(root.screen, root);
  }
}
