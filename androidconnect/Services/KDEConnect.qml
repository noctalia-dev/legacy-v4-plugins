pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Services.UI

QtObject {
  id: root

  property list<var> devices: []
  property bool daemonAvailable: false
  property int pendingDeviceCount: 0
  property list<var> pendingDevices: []
  property bool deviceRefreshInProgress: false
  property int deviceRefreshGeneration: 0
  property double deviceLastRefreshAtMs: 0
  property var pairedStateGraceTimestamps: ({})
  readonly property int pairedStateGraceMs: 45000

  property var mainDevice: null
  property string mainDeviceId: ""
  property string busctlCmd: ""
  readonly property string usbSelectionSentinel: "__NOCTALIA_USB__"
  property bool scrcpyLaunching: false
  property bool scrcpyStopRequested: false
  property var scrcpyCommandArgs: []
  property var scrcpyPendingCommandArgs: []
  property string scrcpyLaunchError: ""
  property string scrcpyLastStderr: ""
  property string scrcpyDeviceId: ""
  property string scrcpyFeedDevicePath: ""
  property string scrcpyActiveSerial: ""
  property string scrcpyCleanupFeedDevicePath: ""
  readonly property bool scrcpyRunning: scrcpySessionProc.running
  property bool wirelessAdbBusy: false
  property var wirelessAdbCommandArgs: []
  property string wirelessAdbLastStdout: ""
  property string wirelessAdbLastStderr: ""
  property string adbDevicesStdout: ""
  property string adbDevicesStderr: ""
  property int adbDevicesExitCode: 0
  property double adbDevicesLastRefreshAtMs: 0
  property var adbDeviceStates: ({})
  property var adbConnectedSerials: []
  property bool adbHasUsbTransport: false
  property string adbDisplayInfoSerial: ""
  property string adbDisplayInfoStdout: ""
  property string adbDisplayInfoStderr: ""
  property int adbScreenWidth: 0
  property int adbScreenHeight: 0
  property string adbScreenSerial: ""
  property string adbScreenError: ""
  property string adbScreenStateSerial: ""
  property string adbScreenStateKnownSerial: ""
  property string adbScreenStateRaw: ""
  property string adbScreenStateError: ""
  property string adbScreenLockState: "unknown"
  property bool adbScreenInteractive: false
  property bool adbUnlockNeeded: true
  property string adbScreenTimeoutSerial: ""
  property string adbScreenTimeoutKnownSerial: ""
  property string adbScreenTimeoutRaw: ""
  property string adbScreenTimeoutError: ""
  property string adbScreenTimeoutValue: ""
  property string adbScreenBrightnessSerial: ""
  property string adbScreenBrightnessKnownSerial: ""
  property string adbScreenBrightnessRaw: ""
  property string adbScreenBrightnessError: ""
  property string adbScreenBrightnessValue: ""
  property string adbScreenBrightnessMode: ""
  property string adbScreenshotSerial: ""
  property string adbScreenshotPath: ""
  property string adbScreenshotError: ""
  readonly property bool adbScreenshotBusy: adbScreenshotProc.running
  property string adbScreenRecordingSerial: ""
  property string adbScreenRecordingRemotePath: ""
  property string adbScreenRecordingLocalPath: ""
  property string adbScreenRecordingError: ""
  property bool adbScreenRecordingStopRequested: false
  readonly property bool adbScreenRecordingActive: adbScreenRecordingProc.running
  readonly property bool adbScreenRecordingBusy: adbScreenRecordingProc.running || adbScreenRecordingFinalizeProc.running || adbScreenRecordingStopProc.running
  property string adbQueuedSerial: ""
  property var adbQueuedArgs: []
  property string adbQueuedKind: ""
  property string adbQueuedStdout: ""
  property string adbQueuedStderr: ""
  property var adbCommandQueue: []
  property bool reduceBackgroundRefresh: false
  readonly property int refreshIntervalMs: reduceBackgroundRefresh ? 20000 : 5000
  property double scrcpyLaunchStartedAtMs: 0

  property bool anyDevicesConnected: false

  signal wirelessAdbFinished(bool success, string message)
  signal adbDevicesRefreshed()
  signal adbScreenStateRefreshed(string serial, bool unlockNeeded, bool interactive, string lockState)
  signal adbScreenTimeoutRead(string serial, string value, bool success)
  signal adbScreenBrightnessRead(string serial, string mode, string value, bool success)

  onDevicesChanged: {
    updateMainDevice(true)
  }

  Component.onCompleted: {
    checkDaemon();
  }

  // Check if KDE Connect daemon is available
  function checkDaemon(): void {
    if (detectBusctlProc.running || daemonCheckProc.running || getDevicesProc.running || deviceRefreshInProgress)
      return;

    if (root.busctlCmd !== "") {
      daemonCheckProc.running = true;
      return;
    }

    detectBusctlProc.running = true;
  }

  // Refresh the list of devices
  function refreshDevices(): void {
    if (getDevicesProc.running || deviceRefreshInProgress)
      return;

    getDevicesProc.running = true;
  }

  function setMainDevice(deviceId: string): void {
    root.mainDeviceId = deviceId;
    updateMainDevice(true);
  }

  function setMainDeviceExact(deviceId: string): void {
    root.mainDeviceId = deviceId;
    updateMainDevice(false);
  }

  function updateMainDevice(checkReachable) {
    let newMain;
    if (checkReachable) {
      newMain = devices.find((device) => device.id === root.mainDeviceId && device.reachable);
      if (newMain === undefined)
        newMain = devices.find((device) => device.reachable);
      if (newMain === undefined)
        newMain = devices.length === 0 ? null : devices[0];
    } else {
      newMain = devices.find((device) => device.id === root.mainDeviceId);
      if (newMain === undefined)
        newMain = devices.length === 0 ? null : devices[0];
    }

    if (root.mainDevice !== newMain) {
      root.mainDevice = newMain;
    }

    if (newMain !== null && newMain !== undefined)
      root.mainDeviceId = newMain.id;

    anyDevicesConnected = devices.find((device) => device.reachable) !== undefined;
  }

  function notePairedObservation(deviceId: string, paired: bool): void {
    const trimmedDeviceId = String(deviceId || "").trim();
    if (trimmedDeviceId === "")
      return;

    if (!paired)
      return;

    const timestamps = Object.assign({}, pairedStateGraceTimestamps || {});
    timestamps[trimmedDeviceId] = Date.now();
    pairedStateGraceTimestamps = timestamps;
  }

  function shouldKeepPreviousPairedState(deviceId: string, currentPaired: bool, pairRequested: bool, verificationKey: string, previousPaired: bool): bool {
    if (currentPaired || !previousPaired || pairRequested)
      return false;

    if (String(verificationKey || "").trim() !== "")
      return false;

    const trimmedDeviceId = String(deviceId || "").trim();
    if (trimmedDeviceId === "")
      return false;

    const lastPairedAt = Number((pairedStateGraceTimestamps || {})[trimmedDeviceId] || 0);
    if (!isFinite(lastPairedAt) || lastPairedAt <= 0)
      return false;

    return (Date.now() - lastPairedAt) <= pairedStateGraceMs;
  }

  function triggerFindMyPhone(deviceId: string): void {
    startProcessComponent(findMyPhoneComponent, { deviceId: deviceId });
  }

  function browseFiles(deviceId: string): void {
    startProcessComponent(browseFilesComponent, { deviceId: deviceId });
  }

  // Share a file with a device
  function shareFile(deviceId: string, filePath: string): void {
    startProcessComponent(shareComponent, {
      deviceId: deviceId,
      fileUrl: normalizedFileShareUrl(filePath)
    });
  }

  function requestPairing(deviceId: string): void {
    startProcessComponent(requestPairingComponent, { deviceId: deviceId });
  }

  function unpairDevice(deviceId: string): void {
    startProcessComponent(unpairingComponent, { deviceId: deviceId });
  }

  function wakeUpDevice(deviceId: string): void {
    startProcessComponent(wakeUpDeviceComponent, { deviceId: deviceId });
  }

  function formatActionFailure(action: string, stderrText: string, exitCode: int): string {
    const actionLabel = String(action || "").trim() !== "" ? String(action).trim() : "Operation";
    const details = String(stderrText || "").trim();

    if (details !== "")
      return actionLabel + " failed: " + details;

    if (exitCode !== 0)
      return actionLabel + " failed (exit code " + exitCode + ").";

    return actionLabel + " failed.";
  }

  function escapeNotificationMarkdown(text: string): string {
    return String(text || "")
      .replace(/\\/g, "\\\\")
      .replace(/\[/g, "\\[")
      .replace(/\]/g, "\\]")
      .replace(/\(/g, "\\(")
      .replace(/\)/g, "\\)")
      .replace(/\*/g, "\\*")
      .replace(/_/g, "\\_")
      .replace(/`/g, "\\`");
  }

  function notificationFileUrl(path: string): string {
    const trimmedPath = String(path || "").trim();
    if (trimmedPath === "")
      return "";

    const encodedSegments = trimmedPath.split("/").map(segment => encodeURIComponent(segment));
    return "file://" + encodedSegments.join("/");
  }

  function notificationParentDirectory(path: string): string {
    const trimmedPath = String(path || "").trim();
    const lastSlash = trimmedPath.lastIndexOf("/");
    if (lastSlash <= 0)
      return "";
    return trimmedPath.slice(0, lastSlash);
  }

  function notificationHistoryLink(label: string, path: string): string {
    const fileUrl = notificationFileUrl(path);
    if (fileUrl === "")
      return "";
    return "[" + escapeNotificationMarkdown(label) + "](" + fileUrl + ")";
  }

  function notificationHistoryId(prefix: string): string {
    const trimmedPrefix = String(prefix || "androidconnect").trim();
    const safePrefix = trimmedPrefix !== ""
      ? trimmedPrefix.replace(/[^a-zA-Z0-9_-]+/g, "-")
      : "androidconnect";
    return safePrefix + "-" + String(Date.now()) + "-" + String(Math.random()).slice(2, 8);
  }

  function addHistoryNotification(summary: string, body: string, urgency = 1, options = {}): void {
    const resolvedSummary = String(summary || "").trim();
    const resolvedBody = String(body || "").trim();
    const resolvedOptions = options && typeof options === "object" ? options : ({});
    const fallbackSummary = resolvedSummary !== "" ? resolvedSummary : "AndroidConnect";
    const fallbackBody = resolvedBody !== "" ? resolvedBody : fallbackSummary;

    NotificationService.addToHistory({
      id: notificationHistoryId(resolvedOptions.idPrefix || "androidconnect"),
      summary: fallbackSummary,
      summaryMarkdown: String(resolvedOptions.summaryMarkdown || "").trim() || escapeNotificationMarkdown(fallbackSummary),
      body: fallbackBody,
      bodyMarkdown: String(resolvedOptions.bodyMarkdown || "").trim() || escapeNotificationMarkdown(fallbackBody),
      appName: String(resolvedOptions.appName || "AndroidConnect"),
      urgency: urgency < 0 || urgency > 2 ? 1 : urgency,
      expireTimeout: 0,
      timestamp: new Date(),
      originalImage: "",
      cachedImage: "",
      actionsJson: "[]",
      originalId: 0
    });
  }

  function showNoticeWithHistory(summary: string, body: string, icon = "", timeout = 3200, options = {}): void {
    ToastService.showNotice(summary, body, icon, timeout);
    addHistoryNotification(summary, body, 1, options);
  }

  function showWarningWithHistory(summary: string, body: string, timeout = 5000, options = {}): void {
    ToastService.showWarning(summary, body, timeout);
    addHistoryNotification(summary, body, 1, options);
  }

  function showErrorWithHistory(message: string, options = {}): void {
    const resolvedOptions = options && typeof options === "object" ? options : ({});
    const summary = String(resolvedOptions.summary || "AndroidConnect").trim() || "AndroidConnect";
    const body = String(message || "").trim() || summary;
    ToastService.showError(body);
    addHistoryNotification(summary, body, 2, resolvedOptions);
  }

  function savedMediaNotificationOptions(title: string, outputPath: string, idPrefix: string): var {
    const directoryPath = notificationParentDirectory(outputPath);
    const directoryLink = notificationHistoryLink("Open folder", directoryPath);
    const linkedTitle = notificationHistoryLink(title, directoryPath);
    const escapedPath = escapeNotificationMarkdown(outputPath);

    return {
      idPrefix: idPrefix,
      summaryMarkdown: linkedTitle !== "" ? linkedTitle : escapeNotificationMarkdown(title),
      bodyMarkdown: directoryLink !== ""
        ? escapedPath + "\n\n" + directoryLink
        : escapedPath
    };
  }

  function notifyActionFailure(action: string, stderrText: string, exitCode: int): void {
    const message = formatActionFailure(action, stderrText, exitCode);
    Logger.w("KDEConnect", message);
    showErrorWithHistory(message);
  }

  function startProcessComponent(component, properties = {}): void {
    const proc = component.createObject(root, properties);
    proc.running = true;
  }

  function launchScrcpySession(deviceId: string, commandString: string): bool {
    const trimmedCommand = (commandString || "").trim();
    if (trimmedCommand === "") {
      scrcpyLaunchError = "missing_command";
      return false;
    }

    if (scrcpyRunning)
      return false;

    const parsedCommand = parseCommandArgs(trimmedCommand);
    if (parsedCommand.error !== "") {
      scrcpyLaunchError = parsedCommand.error;
      return false;
    }

    const sinkMatch = trimmedCommand.match(/--v4l2-sink=(?:'([^']*)'|\"([^\"]*)\"|(\S+))/);
    const feedDevicePath = sinkMatch
      ? String(sinkMatch[1] || sinkMatch[2] || sinkMatch[3] || "").trim()
      : "";
    if (feedDevicePath === "") {
      scrcpyLaunchError = "Embedded mirror requires a V4L2 sink device.";
      return false;
    }

    scrcpyLaunching = true;
    scrcpyStopRequested = false;
    scrcpyLaunchError = "";
    scrcpyLastStderr = "";
    scrcpyDeviceId = deviceId;
    scrcpyFeedDevicePath = feedDevicePath;
    const serialMatch = trimmedCommand.match(/(?:^|\s)(?:-s|--serial)(?:=|\s+)(?:'([^']*)'|\"([^\"]*)\"|(\S+))/);
    let launchSerial = serialMatch
      ? String(serialMatch[1] || serialMatch[2] || serialMatch[3] || "")
      : "";
    if (launchSerial === "" && /(^|\s)(?:-d|--select-usb)\b/.test(trimmedCommand))
      launchSerial = root.usbSelectionSentinel;
    scrcpyActiveSerial = launchSerial;
    scrcpyLaunchStartedAtMs = Date.now();
    scrcpyCommandArgs = [];
    scrcpyPendingCommandArgs = parsedCommand.args;
    Logger.i("KDEConnect", "Preparing scrcpy session:",
      "deviceId=" + scrcpyDeviceId,
      "serial=" + (isUsbSelectionSerial(launchSerial) ? "usb" : launchSerial),
      "program=" + String(parsedCommand.args[0] || ""));
    scrcpyPreLaunchProc.running = true;
    return true;
  }

  function stopScrcpySession(): void {
    if (scrcpyPreLaunchProc.running) {
      scrcpyStopRequested = true;
      scrcpyPreLaunchProc.signal(15);
      return;
    }

    if (!scrcpyRunning)
      return;

    scrcpyStopRequested = true;
    scrcpySessionProc.signal(15);
  }

  function launchDetachedScrcpy(deviceSerial: string, commandString: string): bool {
    const trimmedSerial = String(deviceSerial || "").trim();
    if (trimmedSerial === "") {
      Logger.w("KDEConnect", "Cannot launch detached scrcpy: no device serial");
      return false;
    }

    const normalizedCmd = normalizeShellCommand(commandString);
    if (normalizedCmd === "") {
      Logger.w("KDEConnect", "Cannot launch detached scrcpy: empty command");
      return false;
    }

    const parsedArgs = parseCommandArgs(normalizedCmd);
    if (parsedArgs.error) {
      Logger.w("KDEConnect", "Cannot launch detached scrcpy:", parsedArgs.error);
      return false;
    }

    const commandArgs = ["scrcpy", "-s", trimmedSerial].concat(parsedArgs.args.slice(1));
    detachedScrcpyProc.command = commandArgs;
    detachedScrcpyProc.running = true;

    Logger.i("KDEConnect", "Launching detached scrcpy:", trimmedSerial);
    return true;
  }

  function forceStopScrcpyProcesses(feedDevicePath: string): void {
    scrcpyCleanupFeedDevicePath = String(feedDevicePath || "").trim();

    if (scrcpyRunning || scrcpyPreLaunchProc.running)
      stopScrcpySession();

    if (!scrcpyCleanupProc.running)
      scrcpyCleanupProc.running = true;
  }

  function shellQuote(value: string): string {
    return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
  }

  function normalizeShellCommand(commandString: string): string {
    return String(commandString || "").replace(/\s+/g, " ").trim();
  }

  function parseCommandArgs(commandString: string): var {
    const source = String(commandString || "").trim();
    const parsedArgs = [];
    let current = "";
    let quoteChar = "";
    let escaping = false;
    let tokenStarted = false;

    if (source === "")
      return { error: "missing_command", args: [] };

    for (let i = 0; i < source.length; ++i) {
      const ch = source.charAt(i);

      if (escaping) {
        current += ch;
        escaping = false;
        tokenStarted = true;
        continue;
      }

      if (quoteChar === "'") {
        if (ch === "'")
          quoteChar = "";
        else
          current += ch;
        tokenStarted = true;
        continue;
      }

      if (quoteChar === "\"") {
        if (ch === "\"") {
          quoteChar = "";
        } else if (ch === "\\") {
          escaping = true;
        } else {
          current += ch;
        }
        tokenStarted = true;
        continue;
      }

      if (ch === "\\") {
        escaping = true;
        tokenStarted = true;
        continue;
      }

      if (ch === "'" || ch === "\"") {
        quoteChar = ch;
        tokenStarted = true;
        continue;
      }

      if (/\s/.test(ch)) {
        if (tokenStarted) {
          parsedArgs.push(current);
          current = "";
          tokenStarted = false;
        }
        continue;
      }

      current += ch;
      tokenStarted = true;
    }

    if (escaping)
      return { error: "Command ends with an unfinished escape.", args: [] };

    if (quoteChar !== "")
      return { error: "Command has an unterminated quote.", args: [] };

    if (tokenStarted)
      parsedArgs.push(current);

    if (parsedArgs.length === 0 || String(parsedArgs[0] || "").trim() === "")
      return { error: "missing_command", args: [] };

    return { error: "", args: parsedArgs };
  }

  function isUsbSelectionSerial(serial: string): bool {
    return String(serial || "").trim() === root.usbSelectionSentinel;
  }

  function scrcpyCommandHasOption(commandString: string, optionPattern): bool {
    return optionPattern.test(normalizeShellCommand(commandString));
  }

  function appendScrcpyOption(commandString: string, optionPattern, optionText: string): string {
    if (scrcpyCommandHasOption(commandString, optionPattern))
      return normalizeShellCommand(commandString);

    return normalizeShellCommand(commandString + " " + optionText);
  }

  function applyConfiguredMirrorAudioMode(commandString: string, audioEnabled: bool): string {
    let command = normalizeShellCommand(commandString);
    if (command === "")
      return "";

    command = command.replace(/(^|\s)--no-audio\b/g, " ");
    command = normalizeShellCommand(command);

    if (!audioEnabled)
      command = appendScrcpyOption(command, /(^|\s)--no-audio\b/, "--no-audio");

    return command;
  }

  function buildScrcpyFeedCommand(commandString: string, videoDevice: string, deviceSerial: string): string {
    let command = normalizeShellCommand(commandString);
    const trimmedDevice = String(videoDevice || "").trim();
    const trimmedSerial = String(deviceSerial || "").trim();
    if (command === "" || trimmedDevice === "")
      return "";

    command = command
      .replace(/(^|\s)--no-window\b/g, " ")
      .replace(/(^|\s)--no-video-playback\b/g, " ")
      .replace(/(^|\s)--no-control\b/g, " ")
      .replace(/(^|\s)--max-size(?:=\S+|\s+\S+)/g, " ")
      .replace(/(^|\s)--crop(?:=\S+|\s+\S+)/g, " ")
      .replace(/(^|\s)--v4l2-sink(?:=\S+|\s+\S+)/g, " ")
      .replace(/(^|\s)-s(?:=\S+|\s+\S+)/g, " ")
      .replace(/(^|\s)--serial(?:=\S+|\s+\S+)/g, " ")
      .replace(/(^|\s)-d\b/g, " ")
      .replace(/(^|\s)-e\b/g, " ")
      .replace(/(^|\s)--select-usb\b/g, " ")
      .replace(/(^|\s)--select-tcpip\b/g, " ")
      .replace(/(^|\s)--tcpip(?:=\S+|\s+\S+)/g, " ")
      .replace(/(^|\s)--window-title(?:=\S+|\s+\S+)/g, " ")
      .replace(/(^|\s)--window-x(?:=\S+|\s+\S+)/g, " ")
      .replace(/(^|\s)--window-y(?:=\S+|\s+\S+)/g, " ")
      .replace(/(^|\s)--window-width(?:=\S+|\s+\S+)/g, " ")
      .replace(/(^|\s)--window-height(?:=\S+|\s+\S+)/g, " ")
      .replace(/(^|\s)--window-borderless\b/g, " ")
      .replace(/(^|\s)--always-on-top\b/g, " ");

    command = normalizeShellCommand(command);
    command += " --no-window";
    command += " --no-video-playback";
    command += " --no-control";
    command += " --v4l2-sink=" + shellQuote(trimmedDevice);
    if (isUsbSelectionSerial(trimmedSerial))
      command += " --select-usb";
    else if (trimmedSerial !== "")
      command += " --serial=" + shellQuote(trimmedSerial);
    return command;
  }

  function runWirelessAdbCommandArgs(commandArgs): bool {
    if (!Array.isArray(commandArgs) || commandArgs.length === 0) {
      wirelessAdbFinished(false, "missing_command");
      return false;
    }

    if (wirelessAdbBusy)
      return false;

    wirelessAdbBusy = true;
    wirelessAdbLastStdout = "";
    wirelessAdbLastStderr = "";
    wirelessAdbCommandArgs = commandArgs;
    wirelessAdbProc.running = true;
    return true;
  }

  function enableWirelessAdb(commandString: string): bool {
    const parsedCommand = parseCommandArgs(commandString);
    if (parsedCommand.error !== "") {
      wirelessAdbFinished(false, parsedCommand.error);
      return false;
    }

    return runWirelessAdbCommandArgs(parsedCommand.args);
  }

  function refreshAdbDevices(): bool {
    if (adbDevicesProc.running)
      return false;

    adbDevicesStdout = "";
    adbDevicesStderr = "";
    adbDevicesExitCode = 0;
    adbDevicesProc.running = true;
    return true;
  }

  function adbDeviceSerialConnected(serial: string): bool {
    const trimmedSerial = String(serial || "").trim();
    if (trimmedSerial === "")
      return false;

    return (adbConnectedSerials || []).indexOf(trimmedSerial) !== -1;
  }

  function adbConnectedSerialForHost(host: string): string {
    const trimmedHost = String(host || "").trim();
    if (trimmedHost === "")
      return "";

    const hostPrefix = trimmedHost + ":";
    const connectedSerials = adbConnectedSerials || [];
    for (let i = 0; i < connectedSerials.length; ++i) {
      const serial = String(connectedSerials[i] || "").trim();
      if (serial.indexOf(hostPrefix) === 0)
        return serial;
    }

    return "";
  }

  function pairWirelessAdb(host: string, port: string, pairingCode: string): bool {
    const trimmedHost = (host || "").trim();
    const trimmedPort = (port || "").trim();
    const trimmedCode = (pairingCode || "").trim();

    if (trimmedHost === "" || trimmedPort === "" || trimmedCode === "") {
      wirelessAdbFinished(false, "missing_pair_parameters");
      return false;
    }

    return runWirelessAdbCommandArgs([
      "adb",
      "pair",
      trimmedHost + ":" + trimmedPort,
      trimmedCode
    ]);
  }

  function pairWirelessAdbByQr(instanceName: string, pairingSecret: string, timeoutSeconds: int): bool {
    const trimmedInstance = (instanceName || "").trim();
    const trimmedSecret = (pairingSecret || "").trim();
    const timeout = Math.max(20, Math.min(180, Math.round(timeoutSeconds || 90)));

    if (trimmedInstance === "" || trimmedSecret === "") {
      wirelessAdbFinished(false, "missing_qr_parameters");
      return false;
    }

    const script = [
      "inst=\"$1\"",
      "secret=\"$2\"",
      "timeout_secs=\"$3\"",
      "discover_service_endpoint() {",
      "service_type=\"$1\"",
      "wanted_name=\"$2\"",
      "wanted_host=\"$3\"",
      "endpoint=\"\"",
      "if command -v avahi-browse >/dev/null 2>&1; then",
      "avahi_output=$(avahi-browse -rtkp \"$service_type\" 2>/dev/null || true)",
      "endpoint=$(printf '%s\\n' \"$avahi_output\" | awk -F';' -v type=\"$service_type\" -v name=\"$wanted_name\" -v host=\"$wanted_host\" '($1 == \"=\" || $1 == \"+\") && $5 == type { svc_name=$4; svc_host=$8; svc_port=$9; if (name != \"\" && svc_name != name) next; if (host != \"\" && index(svc_host, host) != 1) next; if (svc_host != \"\" && svc_port != \"\") { print svc_host \":\" svc_port; exit } }')",
      "fi",
      "if [ -n \"$endpoint\" ]; then",
      "printf '%s\\n' \"$endpoint\"",
      "return 0",
      "fi",
      "mdns_output=$(ADB_MDNS_OPENSCREEN=1 adb mdns services 2>&1 || true)",
      "if printf '%s\\n' \"$mdns_output\" | grep -q \"unknown host service 'mdns:\"; then",
      "return 1",
      "fi",
      "endpoint=$(printf '%s\\n' \"$mdns_output\" | awk -v type=\"$service_type\" -v name=\"$wanted_name\" -v host=\"$wanted_host\" '{ if (index($0, type) == 0) next; n=split($0, a, /[[:space:]]+/); svc_name=\"\"; svc_endpoint=\"\"; for (i=1; i<=n; ++i) { if (a[i] == type && i > 1) svc_name=a[i-1]; if (a[i] ~ /^[0-9.]+:[0-9]+$/) svc_endpoint=a[i]; } if (name != \"\" && svc_name != name) next; if (host != \"\" && index(svc_endpoint, host \":\") != 1) next; if (svc_endpoint != \"\") { print svc_endpoint; exit } }')",
      "[ -n \"$endpoint\" ] && printf '%s\\n' \"$endpoint\"",
      "}",
      "ADB_MDNS_OPENSCREEN=1 adb start-server >/dev/null 2>&1 || true",
      "deadline=$(( $(date +%s) + timeout_secs ))",
      "while [ \"$(date +%s)\" -lt \"$deadline\" ]; do",
      "pair_endpoint=$(discover_service_endpoint \"_adb-tls-pairing._tcp\" \"$inst\" \"\")",
      "if [ -n \"$pair_endpoint\" ]; then",
      "pair_host=${pair_endpoint%:*}",
      "pair_port=${pair_endpoint##*:}",
      "pair_output=$(adb pair \"$pair_host:$pair_port\" \"$secret\" 2>&1)",
      "pair_status=$?",
      "if [ \"$pair_status\" -ne 0 ]; then",
      "printf '%s\\n' \"$pair_output\" >&2",
      "exit \"$pair_status\"",
      "fi",
      "connect_deadline=$(( $(date +%s) + 25 ))",
      "while [ \"$(date +%s)\" -lt \"$connect_deadline\" ]; do",
      "connect_endpoint=$(discover_service_endpoint \"_adb-tls-connect._tcp\" \"\" \"$pair_host\")",
      "if [ -n \"$connect_endpoint\" ]; then",
      "connect_host=${connect_endpoint%:*}",
      "connect_port=${connect_endpoint##*:}",
      "connect_output=$(adb connect \"$connect_host:$connect_port\" 2>&1)",
      "connect_status=$?",
      "if [ \"$connect_status\" -ne 0 ]; then",
      "printf '%s\\n' \"$connect_output\" >&2",
      "exit \"$connect_status\"",
      "fi",
      "printf 'QR_OK host=%s pair_port=%s connect_port=%s\\n' \"$pair_host\" \"$pair_port\" \"$connect_port\"",
      "exit 0",
      "fi",
      "sleep 1",
      "done",
      "echo 'Timed out waiting for the Wireless ADB connect service after the QR scan.' >&2",
      "exit 124",
      "fi",
      "sleep 1",
      "done",
      "echo 'Timed out waiting for the phone to scan the Wireless ADB QR code.' >&2",
      "exit 124"
    ].join("\n");

    return runWirelessAdbCommandArgs([
      "bash",
      "-c",
      script,
      "--",
      trimmedInstance,
      trimmedSecret,
      String(timeout)
    ]);
  }

  function connectWirelessAdb(host: string, port: string): bool {
    const trimmedHost = (host || "").trim();
    const trimmedPort = (port || "").trim();

    if (trimmedHost === "" || trimmedPort === "") {
      wirelessAdbFinished(false, "missing_connect_parameters");
      return false;
    }

    return runWirelessAdbCommandArgs([
      "adb",
      "connect",
      trimmedHost + ":" + trimmedPort
    ]);
  }

  function autoConnectWirelessAdb(host: string, timeoutSeconds: int): bool {
    const trimmedHost = (host || "").trim();
    const timeout = Math.max(5, Math.min(60, Math.round(timeoutSeconds || 15)));

    if (trimmedHost === "") {
      wirelessAdbFinished(false, "missing_connect_host");
      return false;
    }

    const script = [
      "wanted_host=\"$1\"",
      "timeout_secs=\"$2\"",
      "discover_service_endpoint() {",
      "service_type=\"$1\"",
      "host=\"$2\"",
      "endpoint=\"\"",
      "if command -v avahi-browse >/dev/null 2>&1; then",
      "avahi_output=$(avahi-browse -rtkp \"$service_type\" 2>/dev/null || true)",
      "endpoint=$(printf '%s\\n' \"$avahi_output\" | awk -F';' -v type=\"$service_type\" -v host=\"$host\" '($1 == \"=\" || $1 == \"+\") && $5 == type { svc_addr=$8; svc_port=$9; if (host != \"\" && svc_addr != host) next; if (svc_addr != \"\" && svc_port != \"\") { print svc_addr \":\" svc_port; exit } }')",
      "fi",
      "if [ -n \"$endpoint\" ]; then",
      "printf '%s\\n' \"$endpoint\"",
      "return 0",
      "fi",
      "mdns_output=$(ADB_MDNS_OPENSCREEN=1 adb mdns services 2>&1 || true)",
      "if printf '%s\\n' \"$mdns_output\" | grep -q \"unknown host service 'mdns:\"; then",
      "return 1",
      "fi",
      "endpoint=$(printf '%s\\n' \"$mdns_output\" | awk -v type=\"$service_type\" -v host=\"$host\" '{ if (index($0, type) == 0) next; n=split($0, a, /[[:space:]]+/); svc_endpoint=\"\"; for (i=1; i<=n; ++i) { if (a[i] ~ /^[0-9.]+:[0-9]+$/) svc_endpoint=a[i]; } if (host != \"\" && index(svc_endpoint, host \":\") != 1) next; if (svc_endpoint != \"\") { print svc_endpoint; exit } }')",
      "[ -n \"$endpoint\" ] && printf '%s\\n' \"$endpoint\"",
      "}",
      "ADB_MDNS_OPENSCREEN=1 adb start-server >/dev/null 2>&1 || true",
      "deadline=$(( $(date +%s) + timeout_secs ))",
      "while [ \"$(date +%s)\" -lt \"$deadline\" ]; do",
      "connect_endpoint=$(discover_service_endpoint \"_adb-tls-connect._tcp\" \"$wanted_host\")",
      "if [ -n \"$connect_endpoint\" ]; then",
      "connect_host=${connect_endpoint%:*}",
      "connect_port=${connect_endpoint##*:}",
      "connect_output=$(adb connect \"$connect_host:$connect_port\" 2>&1)",
      "connect_status=$?",
      "if [ \"$connect_status\" -ne 0 ]; then",
      "printf '%s\\n' \"$connect_output\" >&2",
      "exit \"$connect_status\"",
      "fi",
      "printf 'AUTO_CONNECT_OK host=%s connect_port=%s\\n' \"$connect_host\" \"$connect_port\"",
      "exit 0",
      "fi",
      "sleep 1",
      "done",
      "echo 'Timed out waiting for the selected phone Wireless ADB connect service.' >&2",
      "exit 124"
    ].join("\n");

    return runWirelessAdbCommandArgs([
      "bash",
      "-c",
      script,
      "--",
      trimmedHost,
      String(timeout)
    ]);
  }

  function adbCommand(serial: string, args): var {
    return ["adb"]
      .concat(adbSelectorArgsForSerial(serial))
      .concat(args.map(arg => String(arg)));
  }

  function buildOutputPath(directoryName: string, filePrefix: string, extension: string): string {
    const homeDir = String(Quickshell.env("HOME") || "").trim();
    const baseDir = homeDir !== ""
      ? (homeDir + "/" + String(directoryName || "").trim() + "/AndroidConnect")
      : "/tmp/AndroidConnect";
    const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
    return baseDir + "/" + String(filePrefix || "capture").trim() + "-" + stamp + String(extension || "");
  }

  function takeAdbScreenshot(serial: string): bool {
    const trimmedSerial = String(serial || "").trim();
    if (trimmedSerial === "" || adbScreenshotProc.running)
      return false;

    adbScreenshotSerial = trimmedSerial;
    adbScreenshotPath = buildOutputPath("Pictures", "androidconnect-screenshot", ".png");
    adbScreenshotError = "";
    adbScreenshotProc.running = true;
    return true;
  }

  function startAdbScreenRecording(serial: string): bool {
    const trimmedSerial = String(serial || "").trim();
    if (trimmedSerial === "" || adbScreenRecordingBusy)
      return false;

    const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
    adbScreenRecordingSerial = trimmedSerial;
    adbScreenRecordingRemotePath = "/sdcard/Download/androidconnect-recording-" + stamp + ".mp4";
    adbScreenRecordingLocalPath = buildOutputPath("Videos", "androidconnect-recording", ".mp4");
    adbScreenRecordingError = "";
    adbScreenRecordingStopRequested = false;
    adbScreenRecordingProc.running = true;
    showNoticeWithHistory("Screen Recording", "Recording started.", "video");
    Logger.i("KDEConnect", "ADB screen recording started:",
      "serial=" + adbScreenRecordingSerial,
      "remote=" + adbScreenRecordingRemotePath,
      "local=" + adbScreenRecordingLocalPath);
    return true;
  }

  function stopAdbScreenRecording(): bool {
    if (!adbScreenRecordingProc.running || adbScreenRecordingStopProc.running)
      return false;

    adbScreenRecordingStopRequested = true;
    adbScreenRecordingStopProc.running = true;
    return true;
  }

  function adbSelectorArgsForSerial(serial: string): var {
    const trimmedSerial = String(serial || "").trim();
    if (isUsbSelectionSerial(trimmedSerial))
      return ["-d"];
    if (trimmedSerial !== "")
      return ["-s", trimmedSerial];
    return [];
  }

  function buildScrcpyPreLaunchCommand(serial: string, feedDevicePath: string): var {
    const adbPrefix = shellJoinArgs(["adb"].concat(adbSelectorArgsForSerial(serial)));
    const device = String(feedDevicePath || "").trim();
    const preLaunchStateScript = [
      "power=$(dumpsys power 2>/dev/null || true)",
      "policy=$(dumpsys window policy 2>/dev/null || true)",
      "interactive=false",
      "if printf '%s\\n' \"$power\" | grep -Eq 'mWakefulness=Awake|mInteractive=true|Display Power: state=ON'; then interactive=true; fi",
      "locked=unknown",
      "if printf '%s\\n' \"$policy\" | grep -Eq 'showing=true|mShowingLockscreen=true|isStatusBarKeyguard=true'; then locked=true;"
        + " elif printf '%s\\n' \"$policy\" | grep -Eq 'showing=false|mShowingLockscreen=false|isStatusBarKeyguard=false'; then locked=false; fi",
      "if [ \"$interactive\" != true ]; then input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true; sleep 0.05; fi",
      "if [ \"$locked\" = true ]; then input keyevent 82 >/dev/null 2>&1 || true; sleep 0.10; fi",
    ].join("; ");
    const script = [
      "device=" + shellQuote(device),
      "if [ -n \"$device\" ] && command -v v4l2-ctl >/dev/null 2>&1; then",
      "  v4l2-ctl -d \"$device\" -c keep_format=0 >/dev/null 2>&1 || true",
      "fi",
      "for pid in $(pgrep -x scrcpy || true); do",
      "  cmd=$(tr '\\0' '\\n' </proc/$pid/cmdline 2>/dev/null || true)",
      "  if [ -n \"$device\" ] && printf '%s\\n' \"$cmd\" | grep -Fqx -- \"--v4l2-sink=$device\"; then",
      "    kill -TERM \"$pid\" 2>/dev/null || true",
      "  fi",
      "done",
      adbPrefix + " shell sh -c " + shellQuote(preLaunchStateScript) + " >/dev/null 2>&1 || true"
    ].join("\n");

    return ["sh", "-lc", script];
  }

  function shellJoinArgs(args): string {
    return (Array.isArray(args) ? args : []).map(arg => shellQuote(String(arg))).join(" ");
  }

  function hasQueuedAdbTask(kind: string, serial: string): bool {
    const trimmedKind = String(kind || "").trim();
    const trimmedSerial = String(serial || "").trim();

    if (trimmedKind === "")
      return false;

    if (adbQueuedKind === trimmedKind && adbQueuedSerial === trimmedSerial)
      return true;

    const queuedTasks = adbCommandQueue || [];
    for (let i = 0; i < queuedTasks.length; ++i) {
      const task = queuedTasks[i];
      if (String(task.kind || "").trim() === trimmedKind
          && String(task.serial || "").trim() === trimmedSerial)
        return true;
    }

    return false;
  }

  function queueAdbTask(kind: string, serial: string, args): bool {
    const trimmedSerial = String(serial || "").trim();
    if (trimmedSerial === "") {
      Logger.w("KDEConnect", "Skipping ADB task without a selected device serial:", String(kind || "").trim());
      return false;
    }

    const normalizedArgs = args.map(arg => String(arg));
    const queuedTasks = (adbCommandQueue || []).slice(0);

    queuedTasks.push({
      kind: String(kind || "").trim(),
      serial: trimmedSerial,
      args: normalizedArgs
    });
    adbCommandQueue = queuedTasks;
    runNextAdbTask();
    return true;
  }

  function runNextAdbTask(): void {
    if (adbQueuedProc.running)
      return;

    const queuedTasks = adbCommandQueue || [];
    if (queuedTasks.length === 0)
      return;

    const nextTask = queuedTasks[0];
    adbQueuedKind = String(nextTask.kind || "").trim();
    adbQueuedSerial = String(nextTask.serial || "").trim();
    adbQueuedArgs = Array.isArray(nextTask.args) ? nextTask.args : [];
    adbQueuedStdout = "";
    adbQueuedStderr = "";
    adbQueuedProc.running = true;
  }

  function finishCurrentAdbTask(): void {
    const queuedTasks = (adbCommandQueue || []).slice(0);
    if (queuedTasks.length > 0)
      queuedTasks.shift();

    adbCommandQueue = queuedTasks;
    adbQueuedKind = "";
    adbQueuedSerial = "";
    adbQueuedArgs = [];
    adbQueuedStdout = "";
    adbQueuedStderr = "";

    Qt.callLater(function() {
      root.runNextAdbTask();
    });
  }

  function queryAdbDisplayInfo(serial: string): bool {
    const trimmedSerial = (serial || "").trim();
    if (trimmedSerial === ""
        || adbDisplayInfoSerial !== ""
        || hasQueuedAdbTask("display-info", trimmedSerial))
      return false;

    adbDisplayInfoSerial = trimmedSerial;
    adbDisplayInfoStdout = "";
    adbDisplayInfoStderr = "";
    adbScreenError = "";
    return queueAdbTask("display-info", trimmedSerial, ["shell", "wm", "size"]);
  }

  function hasFreshAdbScreenState(serial: string): bool {
    const trimmedSerial = String(serial || "").trim();
    return trimmedSerial !== ""
      && adbScreenStateKnownSerial === trimmedSerial
      && adbScreenStateError === "";
  }

  function hasFreshAdbScreenTimeout(serial: string): bool {
    const trimmedSerial = String(serial || "").trim();
    return trimmedSerial !== ""
      && adbScreenTimeoutKnownSerial === trimmedSerial
      && adbScreenTimeoutError === "";
  }

  function hasFreshAdbScreenBrightness(serial: string): bool {
    const trimmedSerial = String(serial || "").trim();
    return trimmedSerial !== ""
      && adbScreenBrightnessKnownSerial === trimmedSerial
      && adbScreenBrightnessError === "";
  }

  function queryAdbScreenState(serial: string): bool {
    const trimmedSerial = String(serial || "").trim();
    if (trimmedSerial === ""
        || adbScreenStateSerial !== ""
        || hasQueuedAdbTask("screen-state", trimmedSerial))
      return false;

    adbScreenStateSerial = trimmedSerial;
    adbScreenStateKnownSerial = "";
    adbScreenStateRaw = "";
    adbScreenStateError = "";
    return queueAdbTask("screen-state", trimmedSerial, [
      "shell",
      "sh",
      "-c",
      "power=$(dumpsys power 2>/dev/null || true)"
      + "; policy=$(dumpsys window policy 2>/dev/null || true)"
      + "; interactive=false"
      + "; if printf '%s\\n' \"$power\" | grep -Eq 'mWakefulness=Awake|mInteractive=true|Display Power: state=ON'; then interactive=true; fi"
      + "; locked=unknown"
      + "; if printf '%s\\n' \"$policy\" | grep -Eq 'showing=true|mShowingLockscreen=true|isStatusBarKeyguard=true'; then locked=true;"
      + " elif printf '%s\\n' \"$policy\" | grep -Eq 'showing=false|mShowingLockscreen=false|isStatusBarKeyguard=false'; then locked=false; fi"
      + "; unlockNeeded=false"
      + "; if [ \"$locked\" = true ]; then unlockNeeded=true; fi"
      + "; printf 'interactive=%s\\nlocked=%s\\nunlockNeeded=%s\\n' \"$interactive\" \"$locked\" \"$unlockNeeded\""
    ]);
  }

  function queryAdbScreenTimeout(serial: string): bool {
    const trimmedSerial = String(serial || "").trim();
    if (trimmedSerial === ""
        || adbScreenTimeoutSerial !== ""
        || hasQueuedAdbTask("screen-timeout", trimmedSerial))
      return false;

    adbScreenTimeoutSerial = trimmedSerial;
    adbScreenTimeoutKnownSerial = "";
    adbScreenTimeoutRaw = "";
    adbScreenTimeoutError = "";
    adbScreenTimeoutValue = "";
    return queueAdbTask("screen-timeout", trimmedSerial, [
      "shell",
      "sh",
      "-c",
      "settings get system screen_off_timeout 2>/dev/null || true"
    ]);
  }

  function queryAdbScreenBrightness(serial: string): bool {
    const trimmedSerial = String(serial || "").trim();
    if (trimmedSerial === ""
        || adbScreenBrightnessSerial !== ""
        || hasQueuedAdbTask("screen-brightness", trimmedSerial))
      return false;

    adbScreenBrightnessSerial = trimmedSerial;
    adbScreenBrightnessKnownSerial = "";
    adbScreenBrightnessRaw = "";
    adbScreenBrightnessError = "";
    adbScreenBrightnessValue = "";
    adbScreenBrightnessMode = "";
    return queueAdbTask("screen-brightness", trimmedSerial, [
      "shell",
      "sh",
      "-c",
      "brightness=$(settings get system screen_brightness 2>/dev/null || true)"
      + "; mode=$(settings get system screen_brightness_mode 2>/dev/null || true)"
      + "; printf 'brightness=%s\\nmode=%s\\n' \"$brightness\" \"$mode\""
    ]);
  }

  function setAdbScreenTimeout(serial: string, timeoutValue: string): bool {
    const trimmedSerial = String(serial || "").trim();
    const trimmedValue = String(timeoutValue || "").trim();
    if (trimmedSerial === "" || trimmedValue === "")
      return false;

    return queueAdbTask("screen-timeout-set", trimmedSerial, [
      "shell",
      "settings",
      "put",
      "system",
      "screen_off_timeout",
      trimmedValue
    ]);
  }

  function setAdbScreenBrightness(serial: string, brightnessValue: string): bool {
    const trimmedSerial = String(serial || "").trim();
    const trimmedBrightness = String(brightnessValue || "").trim();
    if (trimmedSerial === "" || trimmedBrightness === "")
      return false;

    let normalizedBrightness = Number(trimmedBrightness);
    if (!isFinite(normalizedBrightness))
      return false;

    normalizedBrightness = Math.max(0, Math.min(255, normalizedBrightness));

    return queueAdbTask("screen-brightness-set", trimmedSerial, [
      "shell",
      "cmd",
      "display",
      "set-brightness",
      (normalizedBrightness / 255).toFixed(4)
    ]);
  }

  function restoreAdbScreenTimeout(serial: string, timeoutValue: string): bool {
    const trimmedSerial = String(serial || "").trim();
    const trimmedValue = String(timeoutValue || "").trim();
    if (trimmedSerial === "")
      return false;

    if (/^\d+$/.test(trimmedValue))
      return setAdbScreenTimeout(trimmedSerial, trimmedValue);

    return queueAdbTask("screen-timeout-restore", trimmedSerial, [
      "shell",
      "settings",
      "delete",
      "system",
      "screen_off_timeout"
    ]);
  }

  function restoreAdbScreenBrightness(serial: string, modeValue: string, brightnessValue: string): bool {
    const trimmedSerial = String(serial || "").trim();
    const trimmedMode = String(modeValue || "").trim();
    const trimmedBrightness = String(brightnessValue || "").trim();
    if (trimmedSerial === "")
      return false;

    if (trimmedMode === "1") {
      return queueAdbTask("screen-brightness-restore", trimmedSerial, [
        "shell",
        "cmd",
        "display",
        "reset-brightness-configuration"
      ]);
    }

    if (/^\d+$/.test(trimmedBrightness)) {
      let normalizedBrightness = Number(trimmedBrightness);
      normalizedBrightness = Math.max(0, Math.min(255, normalizedBrightness));
      return queueAdbTask("screen-brightness-restore", trimmedSerial, [
        "shell",
        "cmd",
        "display",
        "set-brightness",
        (normalizedBrightness / 255).toFixed(4)
      ]);
    }

    return queueAdbTask("screen-brightness-restore", trimmedSerial, [
      "shell",
      "cmd",
      "display",
      "reset-brightness-configuration"
    ]);
  }

  function runAdbTap(serial: string, x: int, y: int): bool {
    return queueAdbTask("tap", serial, [
      "shell",
      "input",
      "tap",
      Math.max(0, Math.round(x)),
      Math.max(0, Math.round(y))
    ]);
  }

  function runAdbSwipe(serial: string, x1: int, y1: int, x2: int, y2: int, durationMs: int): bool {
    return queueAdbTask("swipe", serial, [
      "shell",
      "input",
      "swipe",
      Math.max(0, Math.round(x1)),
      Math.max(0, Math.round(y1)),
      Math.max(0, Math.round(x2)),
      Math.max(0, Math.round(y2)),
      Math.max(50, Math.round(durationMs))
    ]);
  }

  function runAdbKeyevent(serial: string, keyCode: int): bool {
    return queueAdbTask("keyevent", serial, [
      "shell",
      "input",
      "keyevent",
      Math.max(0, Math.round(keyCode))
    ]);
  }

  function encodeAdbInputText(text: string): string {
    const rawText = String(text || "");
    let encoded = "";

    for (let i = 0; i < rawText.length; ++i) {
      const ch = rawText.charAt(i);

      if (ch === " ") {
        encoded += "%s";
        continue;
      }

      if (/^[A-Za-z0-9._,:@\/+=-]$/.test(ch)) {
        encoded += ch;
        continue;
      }

      encoded += "\\" + ch;
    }

    return encoded;
  }

  function runAdbText(serial: string, text: string): bool {
    const encodedText = encodeAdbInputText(text);
    if (encodedText === "")
      return false;

    return queueAdbTask("text", serial, [
      "shell",
      "input",
      "text",
      encodedText
    ]);
  }

  function busctlCall(obj, itf, method, params = []) {
    let result = [ root.busctlCmd, "--user", "call", "--json=short", "org.kde.kdeconnect", obj, itf, method ];
    return result.concat(params);
  }

  function busctlGet(obj, itf, prop) {
    return [ root.busctlCmd, "--user", "get-property", "--json=short", "org.kde.kdeconnect", obj, itf, prop ];
  }

  function busctlData(text) {
    if (text === "")
      return "";

    try {
      let result = JSON.parse(text)?.data;
      if (Array.isArray(result) && Array.isArray(result[0]))
        return result[0]
      else
        return result;
    } catch (e) {
      Logger.e("KDEConnect", "Failed to parse busctl response: ", text)
      return null;
    }
  }

  function normalizedFileShareUrl(filePath: string): string {
    const rawPath = String(filePath || "").trim();
    if (rawPath === "")
      return "";

    if (rawPath.startsWith("file://"))
      return rawPath;

    return "file://" + encodeURI(rawPath);
  }

  function deviceNameForId(deviceId: string): string {
    const trimmedDeviceId = String(deviceId || "").trim();
    if (trimmedDeviceId === "")
      return "device";

    const matchedDevice = (devices || []).find(device => String(device?.id || "").trim() === trimmedDeviceId);
    const name = String(matchedDevice?.name || "").trim();
    return name !== "" ? name : trimmedDeviceId;
  }

  function formatProcessFailure(action: string, deviceId: string, stderrText: string, exitCode: int): string {
    const actionLabel = String(action || "").trim() !== "" ? String(action).trim() : "Operation";
    const targetLabel = deviceNameForId(deviceId);
    const details = String(stderrText || "").trim();

    if (details !== "")
      return actionLabel + " failed for " + targetLabel + ": " + details;

    if (exitCode !== 0)
      return actionLabel + " failed for " + targetLabel + " (exit code " + exitCode + ").";

    return actionLabel + " failed for " + targetLabel + ".";
  }

  function notifyProcessFailure(action: string, deviceId: string, stderrText: string, exitCode: int): void {
    const message = formatProcessFailure(action, deviceId, stderrText, exitCode);
    Logger.w("KDEConnect", message);
    showErrorWithHistory(message);
  }

  property Process detectBusctlProc: Process {
    command: ["which", "busctl"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.busctlCmd !== "") {
          root.daemonCheckProc.running = true
          return
        }

        let location = text.trim()
        if (location !== "") {
          root.busctlCmd = location
          root.daemonCheckProc.running = true
          Logger.i("KDEConnect", "Found busctl command:", location)
        }
      }
    }
  }

  // Check daemon
  property Process daemonCheckProc: Process {
    command: [root.busctlCmd, "--user", "status", "org.kde.kdeconnect"]
    onExited: (exitCode, exitStatus) => {
      root.daemonAvailable = exitCode == 0;
      if (root.daemonAvailable) {
        if (root.reduceBackgroundRefresh)
          return;
        forceOnNetworkChange.running = true;
      } else {
        root.devices = []
        root.mainDevice = null
      }
    }
  }

  property Process forceOnNetworkChange: Process {
  command: busctlCall("/modules/kdeconnect", "org.kde.kdeconnect.daemon", "forceOnNetworkChange")
  stdout: StdioCollector {
    onStreamFinished: {
      getDevicesProc.running = true;
    }
  }
}

  // Get device list
  property Process getDevicesProc: Process {
    command: busctlCall("/modules/kdeconnect", "org.kde.kdeconnect.daemon", "devices")
    stdout: StdioCollector {
      onStreamFinished: {
        const deviceIds = busctlData(text);
        const normalizedDeviceIds = Array.isArray(deviceIds) ? deviceIds : [];

        root.pendingDevices = [];
        root.pendingDeviceCount = normalizedDeviceIds.length;
        root.deviceRefreshGeneration += 1;
        const refreshGeneration = root.deviceRefreshGeneration;

        if (normalizedDeviceIds.length === 0) {
          root.deviceRefreshInProgress = false;
          root.devices = [];
          root.deviceLastRefreshAtMs = Date.now();
          root.updateMainDevice(true);
          return;
        }

        root.deviceRefreshInProgress = true;

        normalizedDeviceIds.forEach(deviceId => {
          const loader = deviceLoaderComponent.createObject(root, {
            deviceId: deviceId,
            refreshGeneration: refreshGeneration
          });
          loader.start();
        });
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0)
        root.deviceRefreshInProgress = false;
    }
  }

  // Component that loads all info for a single device
  property Component deviceLoaderComponent: Component {
    QtObject {
      id: loader
      property string deviceId: ""
      property int refreshGeneration: 0
      property var deviceData: ({
        id: deviceId,
        name: "",
        reachable: false,
        paired: false,
        pairRequested: false,
        verificationKey: "",
        activeProviderNames: [],
        reachableAddresses: [],
        charging: false,
        battery: -1,
        cellularNetworkType: "",
        cellularNetworkStrength: -1,
        notificationIds: []
      })
      property bool notificationsQueryFailed: false

      function start() {
        nameProc.running = true
      }

      property Process nameProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "name")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.name = busctlData(text);

            reachableProc.running = true;
          }
        }
      }

      property Process reachableProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "isReachable")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.reachable = busctlData(text);

            activeProviderNamesProc.running = true;
          }
        }
      }

      property Process activeProviderNamesProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "activeProviderNames")
        stdout: StdioCollector {
          onStreamFinished: {
            const providerNames = busctlData(text);
            loader.deviceData.activeProviderNames = Array.isArray(providerNames) ? providerNames : [];

            reachableAddressesProc.running = true;
          }
        }
      }

      property Process reachableAddressesProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "reachableAddresses")
        stdout: StdioCollector {
          onStreamFinished: {
            const addresses = busctlData(text);
            loader.deviceData.reachableAddresses = Array.isArray(addresses) ? addresses : [];

            pairingRequestedProc.running = true;
          }
        }
      }

      property Process pairingRequestedProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "isPairRequested")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.pairRequested = busctlData(text);

            verificationKeyProc.running = true;
          }
        }
      }

      property Process verificationKeyProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "verificationKey")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.verificationKey = busctlData(text);

            pairedProc.running = true;
          }
        }
      }

      property Process pairedProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "isPaired")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.paired = busctlData(text);

            if (loader.deviceData.paired)
              activeNotificationsProc.running = true;
            else
              finalize()
          }
        }
      }

      property Process activeNotificationsProc: Process {
        command: busctlCall("/modules/kdeconnect/devices/" + loader.deviceId + "/notifications", "org.kde.kdeconnect.device.notifications", "activeNotifications");
        stdout: StdioCollector {
          onStreamFinished: {
            let ids = busctlData(text);
            loader.deviceData.notificationIds = Array.isArray(ids) ? ids : [];
          }
        }

        onExited: (exitCode, exitStatus) => {
          loader.notificationsQueryFailed = exitCode !== 0;
          cellularNetworkTypeProc.running = true;
        }
      }

      property Process cellularNetworkTypeProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/connectivity_report", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkType")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.cellularNetworkType = busctlData(text);
            cellularNetworkStrengthProc.running = true;
          }
        }
      }

      property Process cellularNetworkStrengthProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/connectivity_report", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkStrength")
        stdout: StdioCollector {
          onStreamFinished: {
            const strength = busctlData(text);
            loader.deviceData.cellularNetworkStrength = strength;
            isChargingProc.running = true;
          }
        }
      }

      property Process isChargingProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/battery", "org.kde.kdeconnect.device.battery", "isCharging")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.charging = busctlData(text);
            batteryProc.running = true;
          }
        }
      }

      property Process batteryProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/battery", "org.kde.kdeconnect.device.battery", "charge")
        stdout: StdioCollector {
          onStreamFinished: {
            const charge = busctlData(text);
            if (!isNaN(charge)) {
              loader.deviceData.battery = charge;
            }

            finalize();
          }
        }
      }

      function mergePreviousDeviceData() {
        const previousDevice = root.devices.find(device => device.id === loader.deviceId);
        if (!previousDevice)
          return;

        if (root.shouldKeepPreviousPairedState(
              loader.deviceId,
              loader.deviceData.paired,
              loader.deviceData.pairRequested,
              loader.deviceData.verificationKey,
              Boolean(previousDevice.paired))) {
          loader.deviceData.paired = true;
          if (!loader.deviceData.pairRequested)
            loader.deviceData.pairRequested = Boolean(previousDevice.pairRequested);
          if (String(loader.deviceData.verificationKey || "").trim() === ""
              && String(previousDevice.verificationKey || "").trim() !== "") {
            loader.deviceData.verificationKey = previousDevice.verificationKey;
          }
        }

        if (Number(loader.deviceData.battery) < 0 && Number(previousDevice.battery) >= 0) {
          loader.deviceData.battery = previousDevice.battery;
          loader.deviceData.charging = previousDevice.charging;
        }

        if (String(loader.deviceData.cellularNetworkType || "").trim() === ""
            && String(previousDevice.cellularNetworkType || "").trim() !== "") {
          loader.deviceData.cellularNetworkType = previousDevice.cellularNetworkType;
        }

        if (loader.deviceData.activeProviderNames.length === 0
            && Array.isArray(previousDevice.activeProviderNames)) {
          loader.deviceData.activeProviderNames = previousDevice.activeProviderNames.slice(0);
        }

        if (loader.deviceData.reachableAddresses.length === 0
            && Array.isArray(previousDevice.reachableAddresses)) {
          loader.deviceData.reachableAddresses = previousDevice.reachableAddresses.slice(0);
        }

        if (Number(loader.deviceData.cellularNetworkStrength) < 0
            && Number(previousDevice.cellularNetworkStrength) >= 0) {
          loader.deviceData.cellularNetworkStrength = previousDevice.cellularNetworkStrength;
        }

        if (loader.notificationsQueryFailed && Array.isArray(previousDevice.notificationIds))
          loader.deviceData.notificationIds = previousDevice.notificationIds.slice(0);
      }

      function finalize() {
        if (loader.refreshGeneration !== root.deviceRefreshGeneration) {
          loader.destroy();
          return;
        }

        mergePreviousDeviceData();
        root.notePairedObservation(loader.deviceId, loader.deviceData.paired);
        root.pendingDevices = root.pendingDevices.concat([loader.deviceData]);

        if (root.pendingDevices.length === root.pendingDeviceCount) {
          let newDevices = root.pendingDevices
          newDevices.sort((a, b) => a.name.localeCompare(b.name))

          let prevMainDevice = root.devices.find((device) => device.id === root.mainDeviceId);
          let newMainDevice = newDevices.find((device) => device.id === root.mainDeviceId);

          let deviceNotReachableAnymore =
            prevMainDevice === undefined ||
            (
              (prevMainDevice?.reachable ?? false) &&
              !(newMainDevice?.reachable ?? false)
            ) ||
            (
              (prevMainDevice?.paired ?? false) &&
              !(newMainDevice?.paired ?? false)
            )

          root.devices = newDevices
          root.pendingDevices = []
          root.deviceRefreshInProgress = false;
          root.deviceLastRefreshAtMs = Date.now();
          updateMainDevice(deviceNotReachableAnymore);
        }

        loader.destroy();
      }
    }
  }

  // FindMyPhone component
  property Component findMyPhoneComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      command: busctlCall("/modules/kdeconnect/devices/" + deviceId + "/findmyphone", "org.kde.kdeconnect.device.findmyphone", "ring")
      stdout: StdioCollector {
        onStreamFinished: proc.destroy()
      }
    }
  }

  // SFTP Browse component
  property Component browseFilesComponent: Component {
    Process {
      id: mountProc
      property string deviceId: ""
      property string stderrText: ""
      command: busctlCall("/modules/kdeconnect/devices/" + deviceId + "/sftp", "org.kde.kdeconnect.device.sftp", "mountAndWait")
      stdout: StdioCollector {
        onStreamFinished: rootDirProc.running = true
      }
      stderr: StdioCollector {
        onStreamFinished: {
          mountProc.stderrText = text.trim();
        }
      }

      onExited: (exitCode, exitStatus) => {
        if (exitCode !== 0) {
          root.notifyProcessFailure("Browse device files", mountProc.deviceId, mountProc.stderrText, exitCode);
          mountProc.destroy();
        }
      }

      property Process rootDirProc: Process {
        property string stderrText: ""
        command: busctlCall("/modules/kdeconnect/devices/" + mountProc.deviceId + "/sftp", "org.kde.kdeconnect.device.sftp", "getDirectories")
        stdout: StdioCollector {
          onStreamFinished: {
            const dirs = busctlData(text);
            const directoryEntry = Array.isArray(dirs) && dirs.length > 0 && dirs[0] && typeof dirs[0] === "object"
              ? dirs[0]
              : null;
            const path = directoryEntry ? String(Object.keys(directoryEntry)[0] || "").trim() : "";
            if (path === "") {
              root.notifyProcessFailure("Browse device files", mountProc.deviceId, "No SFTP directories were returned.", 0);
              mountProc.destroy();
              return;
            }

            if (!Qt.openUrlExternally(root.normalizedFileShareUrl(path))) {
              root.notifyProcessFailure("Browse device files", mountProc.deviceId, "Failed to open the file manager for " + path + ".", 0);
            }

            mountProc.destroy();
          }
        }
        stderr: StdioCollector {
          onStreamFinished: {
            rootDirProc.stderrText = text.trim();
          }
        }

        onExited: (exitCode, exitStatus) => {
          if (exitCode !== 0) {
            root.notifyProcessFailure("Browse device files", mountProc.deviceId, rootDirProc.stderrText, exitCode);
            mountProc.destroy();
          }
        }
      }
    }
  }

  // Request Pairing Component
  property Component requestPairingComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      command: busctlCall("/modules/kdeconnect/devices/" + deviceId, "org.kde.kdeconnect.device", "requestPairing")
      stdout: StdioCollector {
        onStreamFinished: proc.destroy()
      }
    }
  }

  // Unpairing Component
  property Component unpairingComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      command: busctlCall("/modules/kdeconnect/devices/" + deviceId, "org.kde.kdeconnect.device", "unpair")
      stdout: StdioCollector {
        onStreamFinished: {
          KDEConnect.refreshDevices()
          proc.destroy()
        }
      }
    }
  }

  // Wake up Device Component
  property Component wakeUpDeviceComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      command: busctlCall("/modules/kdeconnect/devices/" + deviceId + "/remotecontrol", "org.kde.kdeconnect.device.remotecontrol", "sendCommand", [ "a{sv}", "1", "singleclick", "b", "true" ])
      stdout: StdioCollector {
        onStreamFinished: {
          KDEConnect.refreshDevices()
          proc.destroy()
        }
      }
    }
  }

  // Share file component
  property Component shareComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      property string fileUrl: ""
      property string stderrText: ""
      command: busctlCall(
        "/modules/kdeconnect/devices/" + deviceId + "/share",
        "org.kde.kdeconnect.device.share",
        "shareUrls",
        [ "as", "1", fileUrl ]
      )
      stdout: StdioCollector {}
      stderr: StdioCollector {
        onStreamFinished: {
          proc.stderrText = text.trim();
        }
      }

      onExited: (exitCode, exitStatus) => {
        if (exitCode !== 0)
          root.notifyProcessFailure("Send file", proc.deviceId, proc.stderrText, exitCode);

        proc.destroy();
      }
    }
  }

  property Process adbQueuedProc: Process {
    id: adbQueuedProc
    running: false
    command: root.adbCommand(root.adbQueuedSerial, root.adbQueuedArgs)

    stdout: StdioCollector {
      onStreamFinished: {
        root.adbQueuedStdout = text.trim();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.adbQueuedStderr = text.trim();
      }
    }

    onExited: (exitCode, exitStatus) => {
      const commandKind = root.adbQueuedKind;
      const commandSerial = root.adbQueuedSerial;
      const stdoutText = root.adbQueuedStdout;
      const stderrText = root.adbQueuedStderr;

      if (commandKind === "display-info") {
        root.adbDisplayInfoStdout = stdoutText;
        root.adbDisplayInfoStderr = stderrText;

        if (exitCode === 0) {
          const match = stdoutText.match(/(\d+)x(\d+)/);
          if (match) {
            root.adbScreenWidth = Number(match[1]);
            root.adbScreenHeight = Number(match[2]);
            root.adbScreenSerial = commandSerial;
            root.adbScreenError = "";
            Logger.i("KDEConnect", "ADB screen size:", root.adbScreenWidth, "x", root.adbScreenHeight, "for", root.adbScreenSerial);
          } else {
            root.adbScreenWidth = 0;
            root.adbScreenHeight = 0;
            root.adbScreenSerial = "";
            root.adbScreenError = stdoutText !== "" ? stdoutText : "unable_to_parse_wm_size";
            Logger.w("KDEConnect", "Could not parse adb wm size output:", stdoutText);
          }
        } else {
          root.adbScreenWidth = 0;
          root.adbScreenHeight = 0;
          root.adbScreenSerial = "";
          root.adbScreenError = stderrText !== "" ? stderrText : ("adb wm size exited with code " + exitCode);
          Logger.w("KDEConnect", "adb wm size failed:", root.adbScreenError);
        }

        root.adbDisplayInfoSerial = "";
      } else if (commandKind === "screen-state") {
        root.adbScreenStateRaw = stdoutText;

        if (exitCode === 0) {
          const interactiveMatch = stdoutText.match(/(?:^|\n)interactive=(true|false)/);
          const lockedMatch = stdoutText.match(/(?:^|\n)locked=(true|false|unknown)/);
          const unlockNeededMatch = stdoutText.match(/(?:^|\n)unlockNeeded=(true|false)/);

          root.adbScreenInteractive = interactiveMatch ? interactiveMatch[1] === "true" : false;
          root.adbScreenLockState = lockedMatch ? lockedMatch[1] : "unknown";
          root.adbUnlockNeeded = unlockNeededMatch ? unlockNeededMatch[1] === "true" : true;
          root.adbScreenStateKnownSerial = commandSerial;
          root.adbScreenStateError = "";
          root.adbScreenStateRefreshed(commandSerial, root.adbUnlockNeeded, root.adbScreenInteractive, root.adbScreenLockState);
          Logger.i("KDEConnect", "ADB screen state:",
            "serial=" + commandSerial,
            "interactive=" + root.adbScreenInteractive,
            "locked=" + root.adbScreenLockState,
            "unlockNeeded=" + root.adbUnlockNeeded);
        } else {
          root.adbScreenStateKnownSerial = "";
          root.adbScreenInteractive = false;
          root.adbScreenLockState = "unknown";
          root.adbUnlockNeeded = true;
          root.adbScreenStateError = stderrText !== "" ? stderrText : ("adb screen state exited with code " + exitCode);
          Logger.w("KDEConnect", "adb screen state failed:", root.adbScreenStateError);
        }

        root.adbScreenStateSerial = "";
      } else if (commandKind === "screen-timeout") {
        root.adbScreenTimeoutRaw = stdoutText;

        if (exitCode === 0) {
          root.adbScreenTimeoutValue = String(stdoutText || "").trim();
          root.adbScreenTimeoutKnownSerial = commandSerial;
          root.adbScreenTimeoutError = "";
          root.adbScreenTimeoutRead(commandSerial, root.adbScreenTimeoutValue, true);
          Logger.i("KDEConnect", "ADB screen timeout:",
            "serial=" + commandSerial,
            "value=" + root.adbScreenTimeoutValue);
        } else {
          root.adbScreenTimeoutKnownSerial = "";
          root.adbScreenTimeoutValue = "";
          root.adbScreenTimeoutError = stderrText !== "" ? stderrText : ("adb screen timeout exited with code " + exitCode);
          root.adbScreenTimeoutRead(commandSerial, "", false);
          Logger.w("KDEConnect", "adb screen timeout failed:", root.adbScreenTimeoutError);
        }

        root.adbScreenTimeoutSerial = "";
      } else if (commandKind === "screen-brightness") {
        root.adbScreenBrightnessRaw = stdoutText;

        if (exitCode === 0) {
          const brightnessMatch = stdoutText.match(/(?:^|\n)brightness=([^\n]*)/);
          const modeMatch = stdoutText.match(/(?:^|\n)mode=([^\n]*)/);
          root.adbScreenBrightnessValue = brightnessMatch ? String(brightnessMatch[1] || "").trim() : "";
          root.adbScreenBrightnessMode = modeMatch ? String(modeMatch[1] || "").trim() : "";
          root.adbScreenBrightnessKnownSerial = commandSerial;
          root.adbScreenBrightnessError = "";
          root.adbScreenBrightnessRead(commandSerial, root.adbScreenBrightnessMode, root.adbScreenBrightnessValue, true);
          Logger.i("KDEConnect", "ADB screen brightness:",
            "serial=" + commandSerial,
            "mode=" + root.adbScreenBrightnessMode,
            "brightness=" + root.adbScreenBrightnessValue);
        } else {
          root.adbScreenBrightnessKnownSerial = "";
          root.adbScreenBrightnessValue = "";
          root.adbScreenBrightnessMode = "";
          root.adbScreenBrightnessError = stderrText !== "" ? stderrText : ("adb screen brightness exited with code " + exitCode);
          root.adbScreenBrightnessRead(commandSerial, "", "", false);
          Logger.w("KDEConnect", "adb screen brightness failed:", root.adbScreenBrightnessError);
        }

        root.adbScreenBrightnessSerial = "";
      } else if (exitCode !== 0) {
        Logger.w("KDEConnect", "ADB input command failed:",
          "kind=" + commandKind,
          "serial=" + commandSerial,
          "exitCode=" + exitCode,
          "stderr=" + stderrText);
      }

      root.finishCurrentAdbTask();
    }
  }

  property Process adbScreenshotProc: Process {
    id: adbScreenshotProc
    running: false
    command: ["sh", "-lc",
      "file=" + root.shellQuote(root.adbScreenshotPath)
      + "; dir=$(dirname \"$file\")"
      + "; mkdir -p \"$dir\""
      + " && " + root.shellJoinArgs(root.adbCommand(root.adbScreenshotSerial, ["exec-out", "screencap", "-p"]))
      + " > \"$file\""
      + " && [ -s \"$file\" ]"
      + " || { status=$?; rm -f \"$file\" 2>/dev/null || true; exit \"$status\"; }"
    ]

    stderr: StdioCollector {
      onStreamFinished: {
        root.adbScreenshotError = text.trim();
      }
    }

    onExited: (exitCode, exitStatus) => {
      const outputPath = root.adbScreenshotPath;
      const errorText = root.adbScreenshotError;

      if (exitCode === 0) {
        showNoticeWithHistory(
          "Screenshot Saved",
          outputPath,
          "camera",
          3200,
          savedMediaNotificationOptions("Screenshot Saved", outputPath, "androidconnect-screenshot")
        );
        Logger.i("KDEConnect", "ADB screenshot saved:", outputPath);
      } else {
        root.notifyActionFailure("Take screenshot", errorText, exitCode);
      }

      root.adbScreenshotSerial = "";
      root.adbScreenshotPath = "";
      root.adbScreenshotError = "";
    }
  }

  property Process adbScreenRecordingProc: Process {
    id: adbScreenRecordingProc
    running: false
    command: root.adbCommand(root.adbScreenRecordingSerial, [
      "shell",
      "screenrecord",
      "--bit-rate",
      "16000000",
      root.adbScreenRecordingRemotePath
    ])

    stderr: StdioCollector {
      onStreamFinished: {
        root.adbScreenRecordingError = text.trim();
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (root.adbScreenRecordingRemotePath !== "" && root.adbScreenRecordingLocalPath !== "") {
        root.adbScreenRecordingFinalizeProc.running = true;
        return;
      }

      if (exitCode !== 0)
        root.notifyActionFailure("Screen recording", root.adbScreenRecordingError, exitCode);

      root.adbScreenRecordingSerial = "";
      root.adbScreenRecordingRemotePath = "";
      root.adbScreenRecordingLocalPath = "";
      root.adbScreenRecordingError = "";
      root.adbScreenRecordingStopRequested = false;
    }
  }

  property Process adbScreenRecordingStopProc: Process {
    id: adbScreenRecordingStopProc
    running: false
    command: root.adbCommand(root.adbScreenRecordingSerial, [
      "shell",
      "sh",
      "-c",
      "pkill -INT -x screenrecord >/dev/null 2>&1"
      + " || killall -2 screenrecord >/dev/null 2>&1"
      + " || { pid=$(pidof screenrecord 2>/dev/null | awk '{print $1}'); [ -n \"$pid\" ] && kill -2 \"$pid\" >/dev/null 2>&1; }"
    ])

    stderr: StdioCollector {
      onStreamFinished: {
        const details = text.trim();
        if (details !== "")
          root.adbScreenRecordingError = details;
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 && root.adbScreenRecordingProc.running) {
        root.adbScreenRecordingStopRequested = false;
        root.notifyActionFailure("Stop screen recording", root.adbScreenRecordingError, exitCode);
      }
    }
  }

  property Process adbScreenRecordingFinalizeProc: Process {
    id: adbScreenRecordingFinalizeProc
    running: false
    command: ["sh", "-lc",
      "file=" + root.shellQuote(root.adbScreenRecordingLocalPath)
      + "; remote=" + root.shellQuote(root.adbScreenRecordingRemotePath)
      + "; dir=$(dirname \"$file\")"
      + "; mkdir -p \"$dir\""
      + " && " + root.shellJoinArgs(root.adbCommand(root.adbScreenRecordingSerial, ["pull", root.adbScreenRecordingRemotePath, root.adbScreenRecordingLocalPath])) + " >/dev/null"
      + " && [ -s \"$file\" ]"
      + " && " + root.shellJoinArgs(root.adbCommand(root.adbScreenRecordingSerial, ["shell", "rm", "-f", root.adbScreenRecordingRemotePath])) + " >/dev/null 2>&1"
      + " || { status=$?; rm -f \"$file\" 2>/dev/null || true; exit \"$status\"; }"
    ]

    stderr: StdioCollector {
      onStreamFinished: {
        const details = text.trim();
        if (details !== "")
          root.adbScreenRecordingError = details;
      }
    }

    onExited: (exitCode, exitStatus) => {
      const outputPath = root.adbScreenRecordingLocalPath;

      if (exitCode === 0) {
        showNoticeWithHistory(
          "Screen Recording Saved",
          outputPath,
          "video",
          3200,
          savedMediaNotificationOptions("Screen Recording Saved", outputPath, "androidconnect-recording")
        );
        Logger.i("KDEConnect", "ADB screen recording saved:", outputPath);
      } else {
        root.notifyActionFailure("Screen recording", root.adbScreenRecordingError, exitCode);
      }

      root.adbScreenRecordingSerial = "";
      root.adbScreenRecordingRemotePath = "";
      root.adbScreenRecordingLocalPath = "";
      root.adbScreenRecordingError = "";
      root.adbScreenRecordingStopRequested = false;
    }
  }

  property Process scrcpyPreLaunchProc: Process {
    id: scrcpyPreLaunchProc
    running: false
    command: root.buildScrcpyPreLaunchCommand(root.scrcpyActiveSerial, root.scrcpyFeedDevicePath)

    stdout: StdioCollector {}

    stderr: StdioCollector {
      onStreamFinished: {
        root.scrcpyLastStderr = text.trim();
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (root.scrcpyStopRequested) {
        root.scrcpyLaunching = false;
        root.scrcpyStopRequested = false;
        root.scrcpyCommandArgs = [];
        root.scrcpyPendingCommandArgs = [];
        root.scrcpyDeviceId = "";
        root.scrcpyFeedDevicePath = "";
        root.scrcpyActiveSerial = "";
        root.scrcpyLaunchStartedAtMs = 0;
        Logger.i("KDEConnect", "Stopped scrcpy launch before process start");
        return;
      }

      if (exitCode !== 0) {
        root.scrcpyLaunching = false;
        root.scrcpyLaunchError = root.scrcpyLastStderr !== ""
          ? root.scrcpyLastStderr
          : ("scrcpy pre-launch failed with code " + exitCode);
        root.scrcpyPendingCommandArgs = [];
        Logger.e("KDEConnect", "scrcpy pre-launch failed:", root.scrcpyLaunchError);
        return;
      }

      root.scrcpyCommandArgs = Array.isArray(root.scrcpyPendingCommandArgs)
        ? root.scrcpyPendingCommandArgs
        : [];
      root.scrcpyPendingCommandArgs = [];
      Logger.i("KDEConnect", "Launching scrcpy session:",
        "deviceId=" + root.scrcpyDeviceId,
        "serial=" + (root.isUsbSelectionSerial(root.scrcpyActiveSerial) ? "usb" : root.scrcpyActiveSerial),
        "program=" + String(root.scrcpyCommandArgs[0] || ""));
      root.scrcpySessionProc.running = true;
    }
  }

  property Process scrcpySessionProc: Process {
    id: scrcpySessionProc
    running: false
    command: root.scrcpyCommandArgs

    stdout: StdioCollector {}

    stderr: StdioCollector {
      onStreamFinished: {
        root.scrcpyLastStderr = text.trim();
      }
    }

    onStarted: {
      root.scrcpyLaunching = false;
      root.adbScreenError = "";
      Logger.i("KDEConnect", "Started scrcpy session for device:", root.scrcpyDeviceId);
    }

    onExited: (exitCode, exitStatus) => {
      root.scrcpyLaunching = false;
      Logger.i("KDEConnect", "scrcpy session exited:",
        "exitCode=" + exitCode,
        "stopRequested=" + root.scrcpyStopRequested,
        "stderr=" + (root.scrcpyLastStderr || ""));

      if (!root.scrcpyStopRequested && exitCode !== 0) {
        const rawError = root.scrcpyLastStderr !== "" ? root.scrcpyLastStderr : ("scrcpy exited with code " + exitCode);
        if (root.scrcpyFeedDevicePath !== ""
            && (rawError.indexOf("Failed to open output") !== -1
                || rawError.indexOf("Failed to write header") !== -1
                || rawError.indexOf("Demuxer") !== -1)) {
          root.scrcpyLaunchError = "V4L2 sink " + root.scrcpyFeedDevicePath
            + " is unavailable. Recreate the v4l2loopback device node and try again.";
        } else {
          root.scrcpyLaunchError = rawError;
        }
        Logger.e("KDEConnect", "scrcpy session exited unexpectedly:", root.scrcpyLaunchError);
      }

      if (root.scrcpyStopRequested) {
        Logger.i("KDEConnect", "Stopped scrcpy session for device:", root.scrcpyDeviceId);
      }

      root.scrcpyStopRequested = false;
      root.scrcpyCommandArgs = [];
      root.scrcpyPendingCommandArgs = [];
      root.scrcpyDeviceId = "";
      root.scrcpyFeedDevicePath = "";
      root.scrcpyActiveSerial = "";
      root.scrcpyLaunchStartedAtMs = 0;
      root.adbScreenWidth = 0;
      root.adbScreenHeight = 0;
      root.adbScreenSerial = "";
      root.adbScreenStateSerial = "";
      root.adbScreenStateKnownSerial = "";
      root.adbScreenStateRaw = "";
      root.adbScreenStateError = "";
      root.adbScreenLockState = "unknown";
      root.adbScreenInteractive = false;
      root.adbUnlockNeeded = true;
      root.adbScreenTimeoutSerial = "";
      root.adbScreenTimeoutKnownSerial = "";
      root.adbScreenTimeoutRaw = "";
      root.adbScreenTimeoutError = "";
      root.adbScreenTimeoutValue = "";
      root.adbScreenBrightnessSerial = "";
      root.adbScreenBrightnessKnownSerial = "";
      root.adbScreenBrightnessRaw = "";
      root.adbScreenBrightnessError = "";
      root.adbScreenBrightnessValue = "";
      root.adbScreenBrightnessMode = "";
      root.adbDisplayInfoSerial = "";
      root.adbDisplayInfoStdout = "";
      root.adbDisplayInfoStderr = "";
      root.adbQueuedSerial = "";
      root.adbQueuedArgs = [];
      root.adbQueuedKind = "";
      root.adbQueuedStdout = "";
      root.adbQueuedStderr = "";
      root.adbCommandQueue = [];
    }
  }

  property Process scrcpyCleanupProc: Process {
    id: scrcpyCleanupProc
    running: false
    command: ["sh", "-lc",
      "device=" + root.shellQuote(root.scrcpyCleanupFeedDevicePath)
      + "; for pid in $(pgrep -x scrcpy || true); do"
      + " cmd=$(tr '\\0' '\\n' </proc/$pid/cmdline 2>/dev/null || true)"
      + "; if [ -n \"$device\" ] && printf '%s\\n' \"$cmd\" | grep -Fqx -- \"--v4l2-sink=$device\"; then"
      + " kill -TERM \"$pid\" 2>/dev/null || true; continue"
      + "; fi"
      + "; done"
      + "; sleep 0.35"
      + "; for pid in $(pgrep -x scrcpy || true); do"
      + " cmd=$(tr '\\0' '\\n' </proc/$pid/cmdline 2>/dev/null || true)"
      + "; if [ -n \"$device\" ] && printf '%s\\n' \"$cmd\" | grep -Fqx -- \"--v4l2-sink=$device\"; then"
      + " kill -KILL \"$pid\" 2>/dev/null || true; continue"
      + "; fi"
      + "; done"
    ]

    onExited: (exitCode, exitStatus) => {
      root.scrcpyCleanupFeedDevicePath = "";
    }
  }

  property Process detachedScrcpyProc: Process {
    id: detachedScrcpyProc
    running: false
    command: ["scrcpy"]

    stdout: StdioCollector {}

    stderr: StdioCollector {
      onStreamFinished: {
        const stderrText = text.trim();
        if (stderrText !== "")
          Logger.w("KDEConnect", "detached scrcpy stderr:", stderrText);
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0)
        Logger.i("KDEConnect", "detached scrcpy exited with code:", exitCode);
    }
  }

  property Process wirelessAdbProc: Process {
    id: wirelessAdbProc
    running: false
    command: root.wirelessAdbCommandArgs

    stdout: StdioCollector {
      onStreamFinished: {
        root.wirelessAdbLastStdout = text.trim();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.wirelessAdbLastStderr = text.trim();
      }
    }

    onExited: (exitCode, exitStatus) => {
      root.wirelessAdbBusy = false;

      const success = exitCode === 0;
      const message = success
        ? (root.wirelessAdbLastStdout !== "" ? root.wirelessAdbLastStdout : "ok")
        : (root.wirelessAdbLastStderr !== "" ? root.wirelessAdbLastStderr : ("command exited with code " + exitCode));

      root.wirelessAdbCommandArgs = [];
      root.wirelessAdbFinished(success, message);
    }
  }

  property Process adbDevicesProc: Process {
    id: adbDevicesProc
    running: false
    command: ["adb", "devices"]

    stdout: StdioCollector {
      onStreamFinished: {
        root.adbDevicesStdout = text.trim();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.adbDevicesStderr = text.trim();
      }
    }

    onExited: (exitCode, exitStatus) => {
      const connectedSerials = [];
      const deviceStates = ({});
      let hasUsbTransport = false;

      if (exitCode === 0 && root.adbDevicesStdout !== "") {
        const lines = root.adbDevicesStdout.split(/\r?\n/);
        for (let i = 0; i < lines.length; ++i) {
          const trimmedLine = String(lines[i] || "").trim();
          if (trimmedLine === ""
              || trimmedLine === "List of devices attached"
              || trimmedLine.indexOf("* daemon") === 0)
            continue;

          const columns = trimmedLine.split(/\s+/);
          const serial = String(columns[0] || "").trim();
          const state = String(columns[1] || "").trim();

          if (serial !== "")
            deviceStates[serial] = state;

          if (serial === "" || state !== "device")
            continue;

          connectedSerials.push(serial);
          if (serial.indexOf(":") === -1)
            hasUsbTransport = true;
        }
      } else if (exitCode !== 0) {
        Logger.w("KDEConnect", "Failed to refresh adb devices:",
          "exitCode=" + exitCode,
          "stderr=" + root.adbDevicesStderr);
      }

      root.adbDevicesExitCode = exitCode;
      root.adbDevicesLastRefreshAtMs = Date.now();
      root.adbDeviceStates = deviceStates;
      root.adbConnectedSerials = connectedSerials;
      root.adbHasUsbTransport = hasUsbTransport;
      root.adbDevicesRefreshed();
    }
  }

  Component.onDestruction: {
    stopScrcpySession();
  }

  // Periodic refresh timer
  property Timer refreshTimer: Timer {
    interval: root.refreshIntervalMs
    running: true
    repeat: true
    onTriggered: root.checkDaemon()
  }
}
