import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.Hardware

Item {
  id: root

  property var pluginApi: null

  property bool sysfsOk: false
  property string sysfsStatus: ""
  property real sysfsPowerWatts: -1
  property int sysfsTimeToEmpty: 0
  property int sysfsTimeToFull: 0
  property int sysfsCapacity: -1
  property string sysfsSource: ""
  property string sysfsError: ""
  property int refreshNonce: 0

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property int refreshIntervalSeconds: Math.max(1, cfg.refreshIntervalSeconds ?? defaults.refreshIntervalSeconds ?? 5)
  readonly property string deviceNativePath: cfg.deviceNativePath ?? defaults.deviceNativePath ?? "__default__"
  readonly property bool isChargingHardware: sysfsStatus === "Charging"
  readonly property bool isDischargingHardware: sysfsStatus === "Discharging"

  Component.onCompleted: scanSysfs()

  Timer {
    interval: root.refreshIntervalSeconds * 1000
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: root.scanSysfs()
  }

  Process {
    id: sysfsScanProcess
    running: false
    stdout: StdioCollector {
      id: sysfsStdout
    }
    stderr: StdioCollector {
      id: sysfsStderr
    }

    onExited: function (exitCode, exitStatus) {
      root.applySysfsSnapshot(sysfsStdout.text || "", sysfsStderr.text || "");
    }
  }

  function scanSysfs() {
    if (!pluginApi || !pluginApi.pluginDir || sysfsScanProcess.running) {
      return;
    }

    sysfsScanProcess.command = ["sh", `${pluginApi.pluginDir}/scripts/read_battery_sysfs.sh`, root.deviceNativePath];
    sysfsScanProcess.running = true;
  }

  function applySysfsSnapshot(stdoutText, stderrText) {
    let parsed = null;
    try {
      parsed = JSON.parse((stdoutText || "").trim());
    } catch (e) {
      root.sysfsOk = false;
      root.sysfsError = stderrText || String(e);
      root.refreshNonce++;
      Logger.w("BatteryMonitorPlus", "Failed to parse sysfs battery data:", root.sysfsError);
      return;
    }

    root.sysfsOk = parsed.ok === true;
    root.sysfsStatus = parsed.status || "";
    root.sysfsPowerWatts = numberOr(parsed.powerWatts, -1);
    root.sysfsTimeToEmpty = Math.round(numberOr(parsed.timeToEmpty, 0));
    root.sysfsTimeToFull = Math.round(numberOr(parsed.timeToFull, 0));
    root.sysfsCapacity = Math.round(numberOr(parsed.capacity, -1));
    root.sysfsSource = parsed.source || "";
    root.sysfsError = parsed.error || "";
    root.refreshNonce++;
  }

  function numberOr(value, fallback) {
    const parsed = Number(value);
    return isNaN(parsed) ? fallback : parsed;
  }

  function statusText() {
    if (!sysfsOk) {
      return pluginApi?.tr("status.noBattery");
    }

    if (sysfsStatus === "Charging") {
      return pluginApi?.tr("status.charging");
    }
    if (sysfsStatus === "Discharging") {
      return pluginApi?.tr("status.discharging");
    }
    if (sysfsStatus === "Full") {
      return pluginApi?.tr("status.fullyCharged");
    }
    if (sysfsStatus === "Not charging" || sysfsStatus === "Unknown") {
      return pluginApi?.tr("status.pluggedIn");
    }

    return sysfsStatus || pluginApi?.tr("status.noBattery");
  }

  function formatPower(compact, showUnavailable) {
    if (!sysfsOk || sysfsPowerWatts <= 0) {
      return showUnavailable ? pluginApi?.tr("common.unavailable") : "";
    }

    return `${sysfsPowerWatts.toFixed(1)}${compact ? "W" : " W"}`;
  }

  function formatRelevantTime(showUnavailable) {
    const seconds = sysfsStatus === "Charging" ? sysfsTimeToFull : sysfsTimeToEmpty;
    const text = formatDurationCompact(seconds);
    return text || (showUnavailable ? pluginApi?.tr("common.unavailable") : "");
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
}
