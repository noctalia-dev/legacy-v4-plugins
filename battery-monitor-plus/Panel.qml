import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Commons
import qs.Services.Hardware
import qs.Services.Networking
import qs.Services.Power
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property var monitor: pluginApi?.mainInstance
  readonly property string deviceNativePath: cfg.deviceNativePath ?? defaults.deviceNativePath ?? "__default__"
  readonly property var selectedDevice: BatteryService.isDevicePresent(BatteryService.findDevice(deviceNativePath)) ? BatteryService.findDevice(deviceNativePath) : BatteryService.primaryDevice
  readonly property var primaryDevice: selectedDevice
  readonly property bool showPowerProfiles: cfg.showPowerProfiles ?? defaults.showPowerProfiles ?? false
  readonly property bool showNoctaliaPerformance: cfg.showNoctaliaPerformance ?? defaults.showNoctaliaPerformance ?? false
  readonly property bool powerProfileAvailable: PowerProfileService.available
  readonly property var powerProfiles: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
  readonly property bool profilesAvailable: PowerProfileService.available
  readonly property int refreshIntervalSeconds: Math.max(1, cfg.refreshIntervalSeconds ?? defaults.refreshIntervalSeconds ?? 5)
  property int profileIndex: profileToIndex(PowerProfileService.profile)
  property int refreshNonce: 0

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  property real contentPreferredWidth: 440 * Style.uiScaleRatio
  property real contentPreferredHeight: 500 * Style.uiScaleRatio

  anchors.fill: parent

  Connections {
    target: PowerProfileService
    function onProfileChanged() {
      root.profileIndex = root.profileToIndex(PowerProfileService.profile);
    }
  }

  Timer {
    interval: root.refreshIntervalSeconds * 1000
    repeat: true
    running: true
    onTriggered: root.refreshNonce++
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: mainLayout
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.margin2M

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            pointSize: Style.fontSizeXXL
            color: (BatteryService.isCharging(root.primaryDevice) || BatteryService.isPluggedIn(root.primaryDevice)) ? Color.mPrimary : (BatteryService.isCriticalBattery(root.primaryDevice) || BatteryService.isLowBattery(root.primaryDevice)) ? Color.mError : Color.mOnSurface
            icon: BatteryService.getIcon(BatteryService.getPercentage(root.primaryDevice), BatteryService.isCharging(root.primaryDevice), BatteryService.isPluggedIn(root.primaryDevice), BatteryService.isDeviceReady(root.primaryDevice))
          }

          ColumnLayout {
            spacing: Style.marginXXS
            Layout.fillWidth: true

            NText {
              text: I18n.tr("common.battery")
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
              elide: Text.ElideRight
            }

            NText {
              text: statusText(root.primaryDevice)
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              Layout.fillWidth: true
              elide: Text.ElideRight
            }
          }

          NIconButton {
            icon: "settings"
            tooltipText: pluginApi?.tr("menu.settings")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              if (pluginApi) {
                BarService.openPluginSettings(pluginApi.panelOpenScreen, pluginApi.manifest);
              }
            }
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              if (pluginApi) {
                pluginApi.closePanel(pluginApi.panelOpenScreen);
              }
            }
          }
        }
      }

      NBox {
        Layout.fillWidth: true
        implicitHeight: detailsLayout.implicitHeight + Style.margin2L

        ColumnLayout {
          id: detailsLayout
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM

          Repeater {
            model: detailRows(root.primaryDevice, root.monitor ? root.monitor.refreshNonce : root.refreshNonce)

            delegate: RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM

              NText {
                Layout.preferredWidth: 150 * Style.uiScaleRatio
                text: modelData.label
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
              }

              NText {
                Layout.fillWidth: true
                text: modelData.value
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
              }
            }
          }
        }
      }

      NBox {
        Layout.fillWidth: true
        implicitHeight: chargeLayout.implicitHeight + Style.margin2L
        visible: BatteryService.laptopBatteries.length > 0 || BatteryService.bluetoothBatteries.length > 0

        ColumnLayout {
          id: chargeLayout
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginL

          Repeater {
            model: BatteryService.laptopBatteries
            delegate: ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                  icon: BatteryService.getIcon(BatteryService.getPercentage(modelData), BatteryService.isCharging(modelData), BatteryService.isPluggedIn(modelData), BatteryService.isDeviceReady(modelData))
                  color: (BatteryService.isCharging(modelData) || BatteryService.isPluggedIn(modelData)) ? Color.mPrimary : (BatteryService.isCriticalBattery(modelData) || BatteryService.isLowBattery(modelData)) ? Color.mError : Color.mOnSurface
                }

                NText {
                  readonly property string dName: BatteryService.getDeviceName(modelData)
                  text: dName ? dName : I18n.tr("common.battery")
                  color: (BatteryService.isCharging(modelData) || BatteryService.isPluggedIn(modelData)) ? Color.mPrimary : (BatteryService.isCriticalBattery(modelData) || BatteryService.isLowBattery(modelData)) ? Color.mError : Color.mOnSurface
                  pointSize: Style.fontSizeS
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }

                NText {
                  text: BatteryService.getTimeRemainingText(modelData)
                  pointSize: Style.fontSizeS
                  color: Color.mOnSurfaceVariant
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Rectangle {
                  Layout.fillWidth: true
                  height: Math.round(8 * Style.uiScaleRatio)
                  radius: Math.min(Style.radiusL, height / 2)
                  color: Color.mSurface

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * Math.max(0, Math.min(1, BatteryService.getPercentage(modelData) / 100))
                    color: Color.mPrimary
                  }
                }

                NText {
                  Layout.preferredWidth: 40 * Style.uiScaleRatio
                  horizontalAlignment: Text.AlignRight
                  text: `${BatteryService.getPercentage(modelData)}%`
                  color: (BatteryService.isCharging(modelData) || BatteryService.isPluggedIn(modelData)) ? Color.mPrimary : (BatteryService.isCriticalBattery(modelData) || BatteryService.isLowBattery(modelData)) ? Color.mError : Color.mOnSurface
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightBold
                }
              }
            }
          }

          NDivider {
            Layout.fillWidth: true
            visible: BatteryService.laptopBatteries.length > 0 && BatteryService.bluetoothBatteries.length > 0
          }

          Repeater {
            model: BatteryService.bluetoothBatteries
            delegate: ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                  icon: BluetoothService.getDeviceIcon(modelData)
                  color: Color.mOnSurface
                }

                NText {
                  readonly property string dName: BatteryService.getDeviceName(modelData)
                  text: dName ? dName : I18n.tr("common.bluetooth")
                  pointSize: Style.fontSizeS
                  color: Color.mOnSurface
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Rectangle {
                  Layout.fillWidth: true
                  height: Math.round(8 * Style.uiScaleRatio)
                  radius: Math.min(Style.radiusL, height / 2)
                  color: Color.mSurface

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * Math.max(0, Math.min(1, BatteryService.getPercentage(modelData) / 100))
                    color: Color.mPrimary
                  }
                }

                NText {
                  Layout.preferredWidth: 40 * Style.uiScaleRatio
                  horizontalAlignment: Text.AlignRight
                  text: `${BatteryService.getPercentage(modelData)}%`
                  color: Color.mPrimary
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightBold
                }
              }
            }
          }
        }
      }

      NBox {
        Layout.fillWidth: true
        height: controlsLayout.implicitHeight + Style.margin2L
        visible: root.showPowerProfiles || root.showNoctaliaPerformance

        ColumnLayout {
          id: controlsLayout
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM

          ColumnLayout {
            visible: root.powerProfileAvailable && root.showPowerProfiles

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NText {
                text: I18n.tr("battery.power-profile")
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
                Layout.fillWidth: true
              }

              NText {
                text: PowerProfileService.getName(root.profileIndex)
                color: Color.mOnSurfaceVariant
              }
            }

            NValueSlider {
              Layout.fillWidth: true
              from: 0
              to: 2
              stepSize: 1
              snapAlways: true
              heightRatio: 0.5
              value: root.profileIndex
              enabled: root.profilesAvailable
              onPressedChanged: (pressed, v) => {
                if (!pressed) {
                  setProfileByIndex(v);
                }
              }
              onMoved: v => {
                root.profileIndex = v;
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NIcon {
                icon: "powersaver"
                pointSize: Style.fontSizeS
                color: PowerProfileService.getIcon() === "powersaver" ? Color.mPrimary : Color.mOnSurfaceVariant
              }

              NIcon {
                icon: "balanced"
                pointSize: Style.fontSizeS
                color: PowerProfileService.getIcon() === "balanced" ? Color.mPrimary : Color.mOnSurfaceVariant
                Layout.fillWidth: true
              }

              NIcon {
                icon: "performance"
                pointSize: Style.fontSizeS
                color: PowerProfileService.getIcon() === "performance" ? Color.mPrimary : Color.mOnSurfaceVariant
              }
            }
          }

          NDivider {
            Layout.fillWidth: true
            visible: root.showPowerProfiles && PowerProfileService.available && root.showNoctaliaPerformance
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: root.showNoctaliaPerformance

            NText {
              text: I18n.tr("toast.noctalia-performance.label")
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NIcon {
              icon: PowerProfileService.noctaliaPerformanceMode ? "rocket" : "rocket-off"
              pointSize: Style.fontSizeL
              color: PowerProfileService.noctaliaPerformanceMode ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            NToggle {
              checked: PowerProfileService.noctaliaPerformanceMode
              onToggled: checked => PowerProfileService.noctaliaPerformanceMode = checked
            }
          }
        }
      }
    }
  }

  function profileToIndex(p) {
    return powerProfiles.indexOf(p) ?? 1;
  }

  function indexToProfile(idx) {
    return powerProfiles[idx] ?? PowerProfile.Balanced;
  }

  function setProfileByIndex(idx) {
    var prof = indexToProfile(idx);
    root.profileIndex = idx;
    PowerProfileService.setProfile(prof);
  }

  function detailRows(device, tick) {
    return [
      {
        "label": pluginApi?.tr("panel.status"),
        "value": statusText(device)
      },
      {
        "label": powerLabel(device),
        "value": formatPower(device, false, true)
      },
      {
        "label": timeLabel(device),
        "value": formatRemainingTime(device, true)
      },
      {
        "label": pluginApi?.tr("panel.batteryLevel"),
        "value": BatteryService.isDeviceReady(device) ? `${BatteryService.getPercentage(device)}%` : pluginApi?.tr("common.unavailable")
      },
      {
        "label": pluginApi?.tr("panel.batteryHealth"),
        "value": healthText(device)
      },
      {
        "label": pluginApi?.tr("panel.powerProfile"),
        "value": powerProfileText()
      }
    ];
  }

  function statusText(device) {
    if (root.monitor && root.monitor.sysfsOk) {
      return root.monitor.statusText();
    }

    if (!BatteryService.isDeviceReady(device)) {
      return pluginApi?.tr("status.noBattery");
    }

    if (BatteryService.isCharging(device)) {
      return pluginApi?.tr("status.charging");
    }

    if (device.state !== undefined && device.state === UPowerDeviceState.FullyCharged) {
      return pluginApi?.tr("status.fullyCharged");
    }

    if (BatteryService.isPluggedIn(device)) {
      return pluginApi?.tr("status.pluggedIn");
    }

    return pluginApi?.tr("status.discharging");
  }

  function formatPower(device, compact, showUnavailable) {
    if (root.monitor && root.monitor.sysfsOk) {
      return root.monitor.formatPower(compact, showUnavailable);
    }

    const rate = resolvePowerRate(device);
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

  function formatRemainingTime(device, showUnavailable) {
    if (root.monitor && root.monitor.sysfsOk) {
      return root.monitor.formatRelevantTime(showUnavailable);
    }

    if (!BatteryService.isDeviceReady(device)) {
      return showUnavailable ? pluginApi?.tr("common.unavailable") : "";
    }

    const seconds = resolveRemainingSeconds(device);
    const text = formatDurationCompact(seconds);
    return text || (showUnavailable ? pluginApi?.tr("common.unavailable") : "");
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

  function healthText(device) {
    let healthDevice = device && device.healthSupported ? device : (BatteryService.laptopBatteries.length > 0 ? BatteryService.laptopBatteries[0] : null);
    if (healthDevice && healthDevice.healthSupported) {
      return `${Math.round(healthDevice.healthPercentage)}%`;
    }

    return pluginApi?.tr("common.unavailable");
  }

  function powerLabel(device) {
    if (root.monitor && root.monitor.sysfsOk) {
      return root.monitor.isChargingHardware ? pluginApi?.tr("panel.chargingPower") : pluginApi?.tr("panel.currentPower");
    }

    return BatteryService.isCharging(device) ? pluginApi?.tr("panel.chargingPower") : pluginApi?.tr("panel.currentPower");
  }

  function timeLabel(device) {
    if (root.monitor && root.monitor.sysfsOk) {
      return root.monitor.isChargingHardware ? pluginApi?.tr("panel.timeUntilFull") : pluginApi?.tr("panel.remainingTime");
    }

    return BatteryService.isCharging(device) ? pluginApi?.tr("panel.timeUntilFull") : pluginApi?.tr("panel.remainingTime");
  }

  function powerProfileText() {
    if (!PowerProfileService.available) {
      return pluginApi?.tr("profile.unavailable");
    }

    switch (PowerProfileService.getIcon()) {
    case "powersaver":
      return pluginApi?.tr("profile.powerSaver");
    case "performance":
      return pluginApi?.tr("profile.performance");
    case "balanced":
      return pluginApi?.tr("profile.balanced");
    default:
      return pluginApi?.tr("profile.unknown");
    }
  }
}
