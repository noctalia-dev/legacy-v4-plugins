import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "./Services"
import Quickshell

// Panel Component
Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // SmartPanel
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool panelAnchorTop: true
  readonly property bool panelAnchorRight: true

  property real contentPreferredWidth: phoneSizeValue(560, 620, 680) * Style.uiScaleRatio
  property real contentPreferredHeight: deviceData.implicitHeight + (Style.marginM * 2)

  readonly property bool allowAttach: true
  readonly property color panelBackgroundColor: Color.mSurface
  readonly property color shellPrimaryTextColor: Color.mOnSurface
  readonly property color shellSecondaryTextColor: Color.mOnSurfaceVariant
  readonly property color shellPrimaryIconColor: Color.mPrimary
  readonly property color shellButtonBgColor: Color.mSurfaceVariant
  readonly property color shellButtonFgColor: Color.mPrimary
  readonly property color shellButtonBgHoverColor: Color.mHover
  readonly property color shellButtonFgHoverColor: Color.mOnHover
  readonly property color shellButtonBorderColor: Color.mOutline
  readonly property color shellButtonBorderHoverColor: Color.mOutline
  readonly property color shellButtonActiveBgColor: Color.mPrimary
  readonly property color shellButtonActiveFgColor: Color.mOnPrimary
  readonly property color shellButtonActiveBorderColor: Color.mPrimary
  readonly property color shellIconChipColor: Qt.alpha(Color.mPrimaryContainer, 0.8)
  readonly property color shellIconChipBorderColor: Qt.alpha(Color.mPrimary, 0.42)
  readonly property color shellIconChipFgColor: Color.mOnPrimaryContainer
  readonly property color shellStageColor: Qt.alpha(Color.mSurface, 0.94)
  readonly property color shellCardColor: Qt.alpha(Color.mSurfaceVariant, 0.84)
  readonly property color shellCardBorderColor: Style.boxBorderColor
  readonly property color shellNestedCardColor: Qt.alpha(Color.mSurface, 0.9)
  readonly property color shellNestedCardBorderColor: Qt.alpha(Color.mOutline, 0.56)
  readonly property color shellAccentCardColor: Qt.alpha(Color.mPrimaryContainer, 0.88)
  readonly property color shellAccentCardBorderColor: Qt.alpha(Color.mPrimary, 0.42)
  readonly property color shellAccentIconColor: Color.mOnPrimaryContainer
  readonly property color shellAccentTextColor: Color.mOnPrimaryContainer
  readonly property url androidBrandBadgeSource: Qt.resolvedUrl("./Assets/brand-badges/android.svg")
  readonly property url googleBrandBadgeSource: Qt.resolvedUrl("./Assets/brand-badges/google.svg")
  readonly property url motorolaBrandBadgeSource: Qt.resolvedUrl("./Assets/brand-badges/motorola.svg")
  readonly property url xiaomiBrandBadgeSource: Qt.resolvedUrl("./Assets/brand-badges/xiaomi.svg")
  readonly property bool blurEnabled: true
  readonly property string embeddedMirrorCommand: "scrcpy --no-audio --capture-orientation=@0 --max-size=960 --max-fps=60 --video-bit-rate=12M --video-codec=h264 --v4l2-buffer=0"
  readonly property string detachedMirrorCommand: "scrcpy --no-audio --max-size=1920 --max-fps=60 --video-bit-rate=12M --video-codec=h264"
  readonly property bool reduceBackgroundRefreshWhileMirroring: true
  readonly property string embeddedVideoDevice: "/dev/video10"
  readonly property real embeddedMirrorFallbackAspectRatio: 9 / 20
  readonly property int embeddedMirrorTargetMaxWidth: 432
  readonly property int embeddedMirrorTargetMaxHeight: 960
  property string wirelessAdbPairHost: cfg.wirelessAdbPairHost ?? defaults.wirelessAdbPairHost ?? ""
  property string wirelessAdbPairPort: cfg.wirelessAdbPairPort ?? defaults.wirelessAdbPairPort ?? ""
  property string wirelessAdbPairingCode: ""
  property string wirelessAdbConnectHost: cfg.wirelessAdbConnectHost ?? defaults.wirelessAdbConnectHost ?? ""
  property string wirelessAdbConnectPort: cfg.wirelessAdbConnectPort ?? defaults.wirelessAdbConnectPort ?? ""
  property var wirelessAdbDeviceProfiles: initialWirelessAdbDeviceProfiles()
  property string wirelessAdbStatusMessage: ""
  property string wirelessAdbQrInstanceName: ""
  property string wirelessAdbQrSecret: ""
  property bool wirelessAdbQrPendingLaunch: false
  property int wirelessAdbQrImageVersion: 0
  property bool wirelessAdbSessionPreferred: false
  property bool silentWirelessAdbAutoConnectPending: false
  property bool silentWirelessAdbAutoConnectRefreshPending: false
  property string silentWirelessAdbAutoConnectKey: ""
  property var silentWirelessAdbAutoConnectAttempts: ({})
  property bool lastKnownUsbTransport: false
  property var cachedDeviceTelemetry: initialCachedDeviceTelemetry()
  readonly property string tempInstanceToken: makeTempInstanceToken()
  readonly property string wirelessAdbQrImagePath: "/tmp/androidconnect-wireless-adb-" + tempInstanceToken + ".png"
  readonly property string embeddedMirrorLoopbackSetupCommand: "sudo modprobe -r v4l2loopback 2>/dev/null || true\nsudo modprobe v4l2loopback devices=1 video_nr=10 card_label=scrcpy-panel exclusive_caps=0 max_width=960 max_height=2160"
  readonly property real phoneBaseHeight: 732 * Style.uiScaleRatio
  readonly property real phoneBaseWidth: phoneBaseHeight * (597 / 1241)
  property int phoneSizePresetIndex: initialPhoneSizePresetIndex()
  readonly property real phoneSizeFactor: phoneSizeValue(0.60, 0.75, 1.0)
  readonly property int phoneSizePercent: phoneSizeValue(60, 75, 100)
  readonly property string phoneSizeLabel: phoneSizeValue("Small", "Med", "Large")
  readonly property real navButtonScaleFactor: phoneSizeValue(0.82, 0.91, 1.0)
  readonly property var panelResizeBezierCurve: [0.05, 0, 0.133, 0.06, 0.166, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]
  property bool phoneSizeAnimationEnabled: false
  property int phoneSizeStepDirection: initialPhoneSizeStepDirection()

  property bool deviceSwitcherOpen: false
  property var activePhonePreview: null
  property bool embeddedVideoDeviceAccessible: false
  property bool embeddedVideoDeviceCheckKnown: false
  property double embeddedVideoDeviceLastCheckAtMs: 0
  property bool embeddedMirrorAudioEnabled: false
  property double panelVisibleSinceMs: 0
  property bool panelStatusGraceElapsed: true
  property bool panelOpenUnlockPending: false
  property int panelOpenUnlockRetriesRemaining: 0
  readonly property int panelStatusGraceMs: 5000
  property bool keepScreenOnPending: false
  property bool keepScreenOnEnabled: false
  property string keepScreenOnSerial: ""
  property string keepScreenOnOriginalTimeout: ""
  readonly property int keepScreenOnTimeoutMs: 2147483647
  property bool dimScreenPending: false
  property bool dimScreenEnabled: false
  property string dimScreenSerial: ""
  property string dimScreenOriginalBrightness: ""
  property string dimScreenOriginalMode: ""
  readonly property int dimScreenBrightnessValue: 0
  property int embeddedMirrorFormatLockRetryCount: 0
  property int embeddedMirrorExpectedOutputWidth: 0
  property int embeddedMirrorExpectedOutputHeight: 0
  property int embeddedMirrorFormatMismatchRetryCount: 0
  property string embeddedMirrorFormatMismatchSerial: ""
  property bool embeddedMirrorCodecFallbackActive: false
  property string embeddedMirrorCodecFallbackSerial: ""
  property string embeddedMirrorShapeProbeSerial: ""
  property string embeddedMirrorShapeProbeDeviceId: ""
  property string embeddedMirrorShapeProbeBaseCommand: ""
  property string embeddedMirrorShapeProbeStdout: ""
  property string embeddedMirrorShapeProbeStderr: ""
  property int embeddedMirrorInputCropX: 0
  property int embeddedMirrorInputCropY: 0
  property int embeddedMirrorInputCropWidth: 0
  property int embeddedMirrorInputCropHeight: 0
  readonly property int embeddedMirrorWarmStopTimeoutMs: 120000

  anchors.fill: parent

  Timer {
    id: embeddedMirrorFeedWatchdog
    interval: 700
    repeat: true
    running: root.visible && root.embeddedMirrorFeedConfigured()
    onTriggered: {
      root.ensureEmbeddedVideoDeviceAccessFresh(root.embeddedVideoDeviceAccessible ? 1800 : 900);
    }
  }

  Timer {
    id: embeddedMirrorAutoStartTimer
    interval: 60
    repeat: false
    onTriggered: {
      root.attemptEmbeddedMirrorAutoStart();
    }
  }

  Timer {
    id: silentWirelessAdbAutoConnectTimer
    interval: 180
    repeat: false
    onTriggered: {
      root.attemptSilentWirelessAdbAutoConnect();
    }
  }

  Timer {
    id: embeddedMirrorFormatLockTimer
    interval: 100
    repeat: false
    onTriggered: {
      if (!root.visible
          || !root.embeddedMirrorFeedConfigured()
          || !KDEConnect.scrcpyRunning
          || embeddedMirrorFormatLockProc.running) {
        return;
      }

      embeddedMirrorFormatLockProc.running = true;
    }
  }

  Timer {
    id: embeddedMirrorFormatLockRetryTimer
    interval: 260
    repeat: false
    onTriggered: {
      if (!root.visible
          || !root.embeddedMirrorFeedConfigured()
          || !KDEConnect.scrcpyRunning
          || embeddedMirrorFormatLockProc.running
          || !root.activePhonePreview
          || !root.activePhonePreview.mirrorFeedEnabled) {
        return;
      }

      embeddedMirrorFormatLockProc.running = true;
    }
  }

  Timer {
    id: embeddedMirrorWarmStopTimer
    interval: root.embeddedMirrorWarmStopTimeoutMs
    repeat: false
    onTriggered: {
      if (root.visible)
        return;

      KDEConnect.forceStopScrcpyProcesses(root.embeddedVideoDevice);
    }
  }

  Timer {
    id: panelOpenUnlockTimer
    interval: 240
    repeat: false
    onTriggered: {
      if (!root.panelOpenUnlockPending || !root.visible || !root.embeddedMirrorModeEnabled()) {
        root.clearPanelOpenUnlockState();
        return;
      }

      if (!KDEConnect.scrcpyRunning || KDEConnect.scrcpyLaunching) {
        root.retryPanelOpenUnlock();
        return;
      }

      if (!root.embeddedMirrorTouchActive()) {
        root.scheduleTouchMappingRefresh();
        root.retryPanelOpenUnlock();
        return;
      }

      const serial = root.currentMirrorAdbSerial();
      if (serial === "") {
        root.clearPanelOpenUnlockState();
        return;
      }

      if (!KDEConnect.hasFreshAdbScreenState(serial)) {
        KDEConnect.queryAdbScreenState(serial);
        root.retryPanelOpenUnlock();
        return;
      }

      root.clearPanelOpenUnlockState();
      if (!KDEConnect.adbUnlockNeeded)
        return;

      root.sendAndroidUnlockOnly();
    }
  }

  Timer {
    id: panelStatusGraceTimer
    interval: root.panelStatusGraceMs
    repeat: false
    onTriggered: {
      root.panelStatusGraceElapsed = true;
    }
  }

  Timer {
    id: adbDevicesRefreshTimer
    interval: 2500
    repeat: true
    running: root.visible
    onTriggered: {
      KDEConnect.refreshAdbDevices();
    }
  }

  Component.onCompleted: {
    embeddedMirrorAudioEnabled = initialEmbeddedMirrorAudioEnabled();
    if (pluginApi) {
      Logger.i("KDEConnect", "Panel initialized");
    }
    root.syncBackgroundRefreshPolicy();
    KDEConnect.refreshAdbDevices();
    Qt.callLater(function() {
      root.refreshEmbeddedVideoDeviceAccess();
    });
  }

  onEmbeddedVideoDeviceChanged: {
    resetEmbeddedVideoDeviceAccess(false);
    Qt.callLater(function() {
      root.refreshEmbeddedVideoDeviceAccess();
    });
  }

  Connections {
    target: KDEConnect

    function onScrcpyRunningChanged() {
      root.syncBackgroundRefreshPolicy();
      if (root.visible && root.panelOpenUnlockPending && KDEConnect.scrcpyRunning)
        panelOpenUnlockTimer.restart();

      if (root.visible && root.panelOpenUnlockPending && KDEConnect.scrcpyRunning)
        root.refreshPanelOpenUnlockState();

      if (root.embeddedMirrorModeEnabled() && KDEConnect.scrcpyRunning && root.activePhonePreview) {
        root.scheduleTouchMappingRefresh();
      }

      if (root.visible && KDEConnect.scrcpyRunning)
        embeddedMirrorFormatLockTimer.restart();

      if (root.visible && !KDEConnect.scrcpyRunning && !KDEConnect.scrcpyLaunching)
        root.scheduleEmbeddedMirrorAutoStart();
    }

    function onAdbDevicesRefreshed() {
      const usbTransportLost = root.lastKnownUsbTransport && !KDEConnect.adbHasUsbTransport;
      root.lastKnownUsbTransport = KDEConnect.adbHasUsbTransport;

      if (KDEConnect.adbHasUsbTransport)
        root.wirelessAdbSessionPreferred = false;

      if (usbTransportLost
          && root.embeddedMirrorModeEnabled()
          && KDEConnect.scrcpyRunning
          && KDEConnect.isUsbSelectionSerial(KDEConnect.scrcpyActiveSerial)) {
        Logger.w("KDEConnect", "USB transport lost, stopping embedded feed session");
        KDEConnect.stopScrcpySession();
      }

      if (root.embeddedMirrorModeEnabled()
          && (KDEConnect.scrcpyRunning || KDEConnect.scrcpyLaunching)
          && (!root.mirrorSessionMatchesMainDevice()
              || !root.adbSerialMatchesSelectedDevice(KDEConnect.scrcpyActiveSerial))) {
        Logger.w("KDEConnect", "ADB transport no longer matches selected KDE Connect device, stopping embedded feed session");
        KDEConnect.stopScrcpySession();
      }

      if (root.embeddedMirrorModeEnabled() && KDEConnect.scrcpyRunning) {
        root.scheduleTouchMappingRefresh();
      }

      if (root.visible && root.panelOpenUnlockPending && KDEConnect.scrcpyRunning)
        root.refreshPanelOpenUnlockState();

      if (root.silentWirelessAdbAutoConnectRefreshPending
          && !KDEConnect.wirelessAdbBusy) {
        root.clearSilentWirelessAdbAutoConnectState();
      }

      if (!KDEConnect.scrcpyRunning && !KDEConnect.scrcpyLaunching)
        root.scheduleEmbeddedMirrorAutoStart();

      root.scheduleSilentWirelessAdbAutoConnect();
    }

    function onDevicesChanged() {
      const devices = KDEConnect.devices || [];
      for (let i = 0; i < devices.length; ++i)
        root.updateCachedTelemetryForDevice(devices[i]);

      root.scheduleEmbeddedMirrorAutoStart();
      root.scheduleSilentWirelessAdbAutoConnect();
    }

    function onMainDeviceChanged() {
      if (KDEConnect.mainDevice) {
        root.updateCachedTelemetryForDevice(KDEConnect.mainDevice);

        const mainDeviceId = String(KDEConnect.mainDevice.id || "").trim();
        if (pluginApi
            && Boolean(KDEConnect.mainDevice.reachable)
            && mainDeviceId !== ""
            && String(pluginApi.pluginSettings.mainDeviceId || "").trim() !== mainDeviceId) {
          pluginApi.pluginSettings.mainDeviceId = mainDeviceId;
          pluginApi.saveSettings();
        }
      }

      if (root.embeddedMirrorModeEnabled()
          && (KDEConnect.scrcpyRunning || KDEConnect.scrcpyLaunching)
          && !root.mirrorSessionMatchesMainDevice()) {
        Logger.i("KDEConnect", "Selected KDE Connect device changed, stopping embedded feed session");
        KDEConnect.stopScrcpySession();
      }

      if (wirelessAdbPopup.opened)
        root.loadWirelessAdbProfileForSelectedDevice(true);

      root.scheduleEmbeddedMirrorAutoStart();
      root.scheduleSilentWirelessAdbAutoConnect();
    }

    function onScrcpyLaunchErrorChanged() {
      if (!root.embeddedMirrorFeedConfigured()
          || KDEConnect.scrcpyLaunching
          || KDEConnect.scrcpyRunning
          || KDEConnect.scrcpyLaunchError === "")
        return;

      const errorText = String(KDEConnect.scrcpyLaunchError);
      const isFeedFailure = errorText.indexOf("V4L2 sink") !== -1
        || errorText.indexOf("/dev/video") !== -1
        || errorText.indexOf("Failed to open output") !== -1
        || errorText.indexOf("Failed to write header") !== -1
        || errorText.indexOf("Demuxer") !== -1;

      if (!isFeedFailure
          && root.embeddedMirrorErrorLooksCodecRelated(errorText)
          && !root.embeddedMirrorCodecFallbackActive) {
        const fallbackSerial = root.resolvedAdbSerial();
        if (fallbackSerial !== "") {
          root.embeddedMirrorCodecFallbackActive = true;
          root.embeddedMirrorCodecFallbackSerial = fallbackSerial;
          KDEConnect.scrcpyLaunchError = "";
          Logger.w("KDEConnect", "Embedded mirror codec launch failed; retrying once with h265:", errorText);
          root.scheduleEmbeddedMirrorAutoStart();
          return;
        }
      }

      if (!isFeedFailure)
        return;

      root.resetEmbeddedVideoDeviceAccess(false);
      Qt.callLater(function() {
        root.refreshEmbeddedVideoDeviceAccess();
      });
      Logger.w("KDEConnect", "Embedded feed failed:", errorText);
    }

    function onWirelessAdbFinished(success, message) {
      const silentAutoConnect = root.silentWirelessAdbAutoConnectPending;
      const silentAutoConnectStillSelected = !silentAutoConnect
        || root.silentWirelessAdbAutoConnectKey === root.selectedWirelessAdbAutoConnectKey();
      if (success) {
        const usedQrFlow = silentAutoConnectStillSelected ? root.applyWirelessAdbQrSuccess(message) : false;
        const usedAutoConnectFlow = silentAutoConnectStillSelected ? root.applyWirelessAdbAutoConnectSuccess(message) : false;
        if (silentAutoConnectStillSelected)
          root.wirelessAdbSessionPreferred = true;
        KDEConnect.refreshAdbDevices();
        const body = usedQrFlow
          ? root.trSafe("panel.wireless-adb.qr-success-description", "Wireless ADB paired and connected from the QR code.")
          : usedAutoConnectFlow
            ? root.trSafe("panel.wireless-adb.auto-connect-success-description", "Wireless ADB connected using the detected current port.")
            : (message && message !== "ok"
                ? message
                : root.trSafe("panel.wireless-adb.success-description", "ADB over TCP/IP enabled"));
        if (!silentAutoConnect) {
          root.wirelessAdbStatusMessage = body;
          KDEConnect.showNoticeWithHistory(root.trSafe("panel.wireless-adb.success-title", "Wireless ADB"), body, "wifi");
        }
        root.scheduleTouchMappingRefresh();
        if (silentAutoConnectStillSelected && wirelessAdbPopup.opened)
          wirelessAdbPopup.close();
      } else {
        const body = message === "missing_command"
          ? root.trSafe("panel.wireless-adb.missing-command-description", "Wireless ADB could not start the built-in adb tcpip helper.")
          : message === "missing_pair_parameters"
            ? root.trSafe("panel.wireless-adb.missing-pair-parameters-description", "Enter the phone IP, pairing port, and pairing code")
            : message === "missing_connect_parameters"
              ? root.trSafe("panel.wireless-adb.missing-connect-parameters-description", "Enter the phone IP and connect port")
              : message === "missing_connect_host"
                ? root.trSafe("panel.wireless-adb.missing-connect-host-description", "Select a reachable KDE Connect phone first so the plugin knows which host to scan.")
              : message === "missing_qr_parameters"
                ? root.trSafe("panel.wireless-adb.missing-qr-parameters-description", "Generate a fresh Wireless ADB QR code and try again.")
              : message;
        if (!silentAutoConnect || wirelessAdbPopup.opened) {
          root.wirelessAdbStatusMessage = body;
          KDEConnect.showWarningWithHistory(root.trSafe("panel.wireless-adb.error-title", "Wireless ADB"), body, 5000);
        }
      }

      if (silentAutoConnect) {
        if (success && silentAutoConnectStillSelected) {
          root.silentWirelessAdbAutoConnectRefreshPending = true;
          root.scheduleEmbeddedMirrorAutoStart();
        } else {
          root.clearSilentWirelessAdbAutoConnectState();
        }
      }
    }

    function onAdbScreenStateRefreshed(serial, unlockNeeded, interactive, lockState) {
      if (!root.visible || !root.panelOpenUnlockPending)
        return;

      if (String(serial || "").trim() !== root.currentMirrorAdbSerial())
        return;

      panelOpenUnlockTimer.restart();
    }

    function onAdbScreenTimeoutRead(serial, value, success) {
      if (!root.keepScreenOnPending)
        return;

      if (String(serial || "").trim() !== root.keepScreenOnSerial)
        return;

      root.keepScreenOnPending = false;
      if (!success)
        return;

      root.keepScreenOnEnabled = true;
      root.keepScreenOnOriginalTimeout = String(value || "").trim();
      KDEConnect.setAdbScreenTimeout(root.keepScreenOnSerial, String(root.keepScreenOnTimeoutMs));
    }

    function onAdbScreenBrightnessRead(serial, mode, value, success) {
      if (!root.dimScreenPending)
        return;

      if (String(serial || "").trim() !== root.dimScreenSerial)
        return;

      root.dimScreenPending = false;
      if (!success)
        return;

      root.dimScreenEnabled = true;
      root.dimScreenOriginalMode = String(mode || "").trim();
      root.dimScreenOriginalBrightness = String(value || "").trim();
      KDEConnect.setAdbScreenBrightness(root.dimScreenSerial, String(root.dimScreenBrightnessValue));
    }
  }

  Component.onDestruction: {
    root.restoreDimScreenState();
    root.restoreKeepScreenOnState();
    KDEConnect.reduceBackgroundRefresh = false;
    embeddedMirrorAutoStartTimer.stop();
    silentWirelessAdbAutoConnectTimer.stop();
    embeddedMirrorWarmStopTimer.stop();
    panelOpenUnlockTimer.stop();
    root.clearPanelOpenUnlockState();
    KDEConnect.forceStopScrcpyProcesses(root.embeddedVideoDevice);
  }

  onVisibleChanged: {
    root.syncBackgroundRefreshPolicy();
    if (visible) {
      embeddedMirrorWarmStopTimer.stop();
      root.panelVisibleSinceMs = Date.now();
      root.panelStatusGraceElapsed = false;
      panelStatusGraceTimer.restart();
      KDEConnect.refreshAdbDevices();
      if (KDEConnect.daemonAvailable)
        KDEConnect.refreshDevices();
      root.refreshEmbeddedVideoDeviceAccess();
      root.panelOpenUnlockPending = root.embeddedMirrorModeEnabled();
      root.panelOpenUnlockRetriesRemaining = 12;
      root.refreshPanelOpenUnlockState();
      if (KDEConnect.scrcpyRunning)
        panelOpenUnlockTimer.restart();
      if (KDEConnect.scrcpyRunning)
        embeddedMirrorFormatLockTimer.restart();
      root.scheduleEmbeddedMirrorAutoStart();
      root.scheduleSilentWirelessAdbAutoConnect();
    }
    if (!visible) {
      root.restoreDimScreenState();
      root.restoreKeepScreenOnState();
      root.panelVisibleSinceMs = 0;
      root.panelStatusGraceElapsed = true;
      embeddedMirrorAutoStartTimer.stop();
      silentWirelessAdbAutoConnectTimer.stop();
      embeddedMirrorFormatLockTimer.stop();
      panelStatusGraceTimer.stop();
      panelOpenUnlockTimer.stop();
      root.clearPanelOpenUnlockState();
      if (KDEConnect.scrcpyRunning || KDEConnect.scrcpyLaunching)
        embeddedMirrorWarmStopTimer.restart();
    }
  }

  onEmbeddedMirrorAudioEnabledChanged: root.persistEmbeddedMirrorAudioMode()

  function mainDeviceSetupComplete() {
    return KDEConnect.mainDevice !== null
      && Boolean(KDEConnect.mainDevice.paired)
      && Boolean(KDEConnect.mainDevice.reachable);
  }

  function mainDevicePairingInProgress() {
    if (KDEConnect.mainDevice === null || KDEConnect.mainDevice.paired)
      return false;

    return Boolean(KDEConnect.mainDevice.pairRequested)
      || String(KDEConnect.mainDevice.verificationKey || "").trim() !== "";
  }

  function deviceIsSelected(device) {
    return String(device?.id || "").trim() !== ""
      && String(device?.id || "").trim() === String(KDEConnect.mainDevice?.id || "").trim();
  }

  function deviceStatusTitle(device) {
    if (device === null || device === undefined)
      return root.trSafe("panel.device-status.unknown", "Unknown");

    if (Boolean(device.paired) && Boolean(device.reachable))
      return root.trSafe("panel.device-status.ready", "Paired and reachable");

    if (Boolean(device.pairRequested))
      return root.trSafe("panel.device-status.pair-requested", "Pairing requested");

    if (Boolean(device.paired))
      return root.trSafe("panel.device-status.unreachable", "Paired, not reachable");

    return root.trSafe("panel.device-status.not-paired", "Not paired");
  }

  function deviceStatusDetail(device) {
    if (root.deviceIsSelected(device))
      return root.trSafe("panel.device-status.selected", "Panel controls target this phone");

    if (Boolean(device?.paired) && Boolean(device?.reachable))
      return root.trSafe("panel.device-status.select-ready", "Switch panel controls to this phone");

    if (Boolean(device?.paired))
      return root.trSafe("panel.device-status.open-phone", "Open KDE Connect on the phone or keep both devices on the same network");

    return root.trSafe("panel.device-status.pair-first", "Pair this device before mirror and file actions are available");
  }

  function deviceStatusIcon(device) {
    if (Boolean(device?.paired) && Boolean(device?.reachable))
      return "circle-check";

    if (Boolean(device?.pairRequested))
      return "key";

    if (Boolean(device?.paired))
      return "wifi-off";

    return "device-mobile-off";
  }

  function diagnosticSeverityColor(severity) {
    const value = String(severity || "").trim();
    if (value === "ok")
      return Color.mPrimary;
    if (value === "waiting")
      return Color.mTertiary;
    if (value === "error")
      return Color.mError;
    return root.shellSecondaryTextColor;
  }

  function setupDiagnosticEntries() {
    const entries = [];
    const device = KDEConnect.mainDevice;
    const deviceName = String(device?.name || root.trSafe("panel.setup-required.phone-name", "Android Phone")).trim();
    const kdeReady = device !== null && Boolean(device.paired) && Boolean(device.reachable);
    const adbIssueTitle = root.adbSetupIssueTitle();
    const adbIssueSubtitle = root.adbSetupIssueSubtitle();

    if (device === null) {
      entries.push({
        icon: "device-mobile-search",
        title: root.trSafe("panel.diagnostics.kde-discovery-title", "KDE Connect discovery"),
        body: root.trSafe("panel.setup-required.step-1-discovery", "Open KDE Connect on the phone and keep it on the same network so the desktop can discover it."),
        severity: "waiting"
      });
    } else if (!Boolean(device.paired)) {
      entries.push({
        icon: "key",
        title: root.trSafe("panel.diagnostics.kde-pair-title", "KDE Connect pairing"),
        body: Boolean(device.pairRequested)
          ? root.trSafe("panel.pair-requested", "Confirm the pairing request on the phone. The mirror and device actions will come back automatically after approval.")
          : root.trSafe("panel.pair-description", "This device is temporarily reported as unpaired. Retry pairing here if KDE Connect did not recover on its own after reconnecting."),
        severity: Boolean(device.pairRequested) ? "waiting" : "error"
      });
    } else if (!Boolean(device.reachable)) {
      entries.push({
        icon: "wifi-off",
        title: root.trSafe("panel.diagnostics.kde-reachable-title", "KDE Connect reachability"),
        body: deviceName + " " + root.trSafe("panel.diagnostics.kde-reachable-body", "is paired but unreachable. Select another reachable device or keep the phone awake on the same network."),
        severity: "error"
      });
    } else {
      entries.push({
        icon: "circle-check",
        title: root.trSafe("panel.diagnostics.kde-ready-title", "KDE Connect ready"),
        body: deviceName + " " + root.trSafe("panel.diagnostics.kde-ready-body", "is paired and reachable."),
        severity: "ok"
      });
    }

    if (!kdeReady) {
      entries.push({
        icon: "device-mobile",
        title: root.trSafe("panel.diagnostics.adb-title", "ADB input and mirroring"),
        body: root.trSafe("panel.diagnostics.adb-waiting-body", "Waiting for KDE Connect reachability before checking ADB controls."),
        severity: "waiting"
      });
    } else if (root.silentWirelessAdbAutoConnectSuppressed()) {
      entries.push({
        icon: "wifi",
        title: root.trSafe("panel.diagnostics.adb-title", "ADB input and mirroring"),
        body: root.trSafe("panel.wireless-adb.auto-connect-running-description", "Scanning for the selected phone's current Wireless ADB port..."),
        severity: "waiting"
      });
    } else if ((adbIssueTitle || "").trim() !== "") {
      entries.push({
        icon: "device-mobile-off",
        title: adbIssueTitle,
        body: adbIssueSubtitle,
        severity: "error"
      });
    } else {
      entries.push({
        icon: "circle-check",
        title: root.trSafe("panel.diagnostics.adb-ready-title", "ADB ready"),
        body: root.trSafe("panel.diagnostics.adb-ready-body", "An authorized ADB transport is available for the selected phone."),
        severity: "ok"
      });
    }

    if (!root.embeddedVideoDeviceCheckKnown) {
      entries.push({
        icon: "video",
        title: root.trSafe("panel.diagnostics.v4l2-checking-title", "V4L2 loopback"),
        body: root.trSafe("panel.embedded-mirror.required-device-checking", "Checking required V4L2 device: ") + root.embeddedVideoDevice,
        severity: "waiting"
      });
    } else if (root.embeddedVideoDeviceAccessible) {
      entries.push({
        icon: "circle-check",
        title: root.trSafe("panel.diagnostics.v4l2-ready-title", "V4L2 loopback ready"),
        body: root.embeddedVideoDevice + " " + root.trSafe("panel.diagnostics.v4l2-ready-body", "is present and writable for the embedded video feed."),
        severity: "ok"
      });
    } else {
      entries.push({
        icon: "video",
        title: root.trSafe("panel.diagnostics.v4l2-missing-title", "V4L2 loopback unavailable"),
        body: root.embeddedVideoDevice + " " + root.trSafe("panel.diagnostics.v4l2-missing-body", "is missing or not writable. Copy the loopback setup command below if you want the embedded feed."),
        severity: "error"
      });
    }

    if ((root.embeddedMirrorCommand || "").trim() === "") {
      entries.push({
        icon: "exclamation-circle",
        title: root.trSafe("panel.scrcpy.not-configured-title", "scrcpy Not Configured"),
        body: root.trSafe("panel.scrcpy.not-configured-description", "Set a scrcpy command in the plugin settings"),
        severity: "error"
      });
    } else if (String(KDEConnect.scrcpyLaunchError || "").trim() !== "") {
      entries.push({
        icon: "exclamation-circle",
        title: root.trSafe("panel.embedded-mirror.error-title", "Mirror Error"),
        body: String(KDEConnect.scrcpyLaunchError || "").trim(),
        severity: "error"
      });
    } else {
      entries.push({
        icon: "circle-check",
        title: root.trSafe("panel.diagnostics.scrcpy-ready-title", "scrcpy command ready"),
        body: root.trSafe("panel.diagnostics.scrcpy-ready-body", "The embedded mirror command is configured and will launch after the required transports are ready."),
        severity: "ok"
      });
    }

    return entries;
  }

  function handlePhoneClick(preview) {
    if (KDEConnect.mainDevice === null || !root.mainDeviceSetupComplete())
      return;

    if (!KDEConnect.scrcpyRunning
        && !KDEConnect.scrcpyLaunching
        && !root.scrcpyLaunchPrerequisitesReady()) {
      KDEConnect.refreshAdbDevices();
      return;
    }

    ensureEmbeddedMirrorSession(preview);
  }

  function copyTextToClipboard(text, successMessage) {
    const trimmedText = String(text || "").trim();
    if (trimmedText === "")
      return;

    Quickshell.execDetached(["wl-copy", trimmedText]);
    KDEConnect.showNoticeWithHistory(
      root.trSafe("panel.setup-required.copy-title", "AndroidConnect"),
      successMessage || root.trSafe("panel.setup-required.copy-success", "Copied to clipboard."),
      "copy"
    );
  }

  function triggerMainDevicePairing() {
    if (KDEConnect.mainDevice === null || KDEConnect.mainDevice.paired)
      return;

    KDEConnect.requestPairing(KDEConnect.mainDevice.id);
    KDEConnect.mainDevice.pairRequested = true;
    KDEConnect.refreshDevices();
  }

  function setupRequiredPairingStepText() {
    if (KDEConnect.mainDevice === null) {
      return root.trSafe(
        "panel.setup-required.step-1-discovery",
        "1. Open KDE Connect on the phone and keep it on the same network so the desktop can discover it."
      );
    }

    if (KDEConnect.mainDevice.paired && KDEConnect.mainDevice.reachable) {
      return root.trSafe(
        "panel.setup-required.step-1-ready",
        "1. KDE Connect pairing is ready."
      );
    }

    if (KDEConnect.mainDevice.paired) {
      return root.trSafe(
        "panel.setup-required.step-1-known-paired",
        "1. KDE Connect knows about a paired phone entry, but the phone is not reachable yet."
      );
    }

    return root.trSafe(
      "panel.setup-required.step-1-pair",
      "1. Start KDE Connect pairing here, then approve it on the phone."
    );
  }

  function setupRequiredAdbStepText() {
    if (KDEConnect.mainDevice === null || !KDEConnect.mainDevice.paired) {
      return root.trSafe(
        "panel.setup-required.step-2-after-pair",
        "2. After pairing, enable USB debugging on the phone and authorize this computer once over USB."
      );
    }

    if (!KDEConnect.mainDevice.reachable) {
      return root.trSafe(
        "panel.setup-required.step-2-reachable",
        "2. Keep KDE Connect open on the phone and make sure both devices stay on the same network until the phone becomes reachable."
      );
    }

    if (root.silentWirelessAdbAutoConnectSuppressed())
      return "2. " + root.trSafe("panel.wireless-adb.auto-connect-running-description", "Scanning for the selected phone's current Wireless ADB port...");

    const adbIssueSubtitle = root.adbSetupIssueSubtitle();
    if ((adbIssueSubtitle || "").trim() !== "")
      return "2. " + adbIssueSubtitle;

    return root.trSafe(
      "panel.setup-required.step-2-ready",
      "2. USB debugging is ready."
    );
  }

  function setupRequiredLoopbackStepText() {
    if (!root.embeddedVideoDeviceCheckKnown) {
      return root.trSafe(
        "panel.setup-required.step-3-checking",
        "3. Checking the V4L2 loopback device for the embedded live feed."
      );
    }

    if (root.embeddedVideoDeviceAccessible) {
      return root.trSafe(
        "panel.setup-required.step-3-ready",
        "3. V4L2 loopback device detected: "
      ) + root.embeddedVideoDevice;
    }

    return root.trSafe(
      "panel.setup-required.step-3-missing",
      "3. Create the V4L2 loopback device if you want the embedded live feed."
    );
  }

  function setupRequiredLoopbackCommandVisible() {
    return root.embeddedMirrorModeEnabled()
      && root.embeddedMirrorFeedConfigured()
      && root.embeddedVideoDeviceCheckKnown
      && !root.embeddedVideoDeviceAccessible;
  }

  function embeddedMirrorRequiredFeedDeviceStatusText() {
    if (!root.embeddedMirrorFeedConfigured()) {
      return root.trSafe(
        "panel.embedded-mirror.required-device-not-configured",
        "Required V4L2 device is not configured."
      );
    }

    if (!root.embeddedVideoDeviceCheckKnown) {
      return root.trSafe(
        "panel.embedded-mirror.required-device-checking",
        "Checking required V4L2 device: "
      ) + root.embeddedVideoDevice;
    }

    if (root.embeddedVideoDeviceAccessible) {
      return root.trSafe(
        "panel.embedded-mirror.required-device-found",
        "Required V4L2 device found: "
      ) + root.embeddedVideoDevice;
    }

    return root.trSafe(
      "panel.embedded-mirror.required-device-missing",
      "Required V4L2 device not found: "
    ) + root.embeddedVideoDevice;
  }

  function scheduleEmbeddedMirrorAutoStart() {
    if (!root.visible
        || !embeddedMirrorModeEnabled()
        || !root.mainDeviceSetupComplete()
        || !root.scrcpyLaunchPrerequisitesReady()) {
      return;
    }

    embeddedMirrorAutoStartTimer.restart();
  }

  function selectedWirelessAdbAutoConnectKey() {
    const deviceId = selectedDeviceId();
    const host = selectedDevicePrimaryHost();
    if (deviceId === "" || host === "")
      return "";

    return deviceId + "|" + host;
  }

  function silentWirelessAdbAutoConnectInFlight() {
    return silentWirelessAdbAutoConnectPending
      || (KDEConnect.wirelessAdbBusy && silentWirelessAdbAutoConnectKey !== "");
  }

  function clearSilentWirelessAdbAutoConnectState() {
    silentWirelessAdbAutoConnectPending = false;
    silentWirelessAdbAutoConnectRefreshPending = false;
    silentWirelessAdbAutoConnectKey = "";
  }

  function selectedDeviceMissingAdb() {
    return root.mainDeviceSetupComplete()
      && KDEConnect.adbDevicesExitCode === 0
      && adbSerialsInStateForSelectedDevice("unauthorized").length === 0
      && adbSerialsInStateForSelectedDevice("offline").length === 0
      && resolvedAdbSerial() === "";
  }

  function silentWirelessAdbAutoConnectSuppressed() {
    const key = selectedWirelessAdbAutoConnectKey();
    const activeSilentMatchesSelection = silentWirelessAdbAutoConnectKey === ""
      || silentWirelessAdbAutoConnectKey === key;

    return selectedDeviceMissingAdb()
      && key !== ""
      && (shouldSilentWirelessAdbAutoConnect()
          || (activeSilentMatchesSelection
              && (silentWirelessAdbAutoConnectTimer.running
                  || silentWirelessAdbAutoConnectInFlight())));
  }

  function shouldSilentWirelessAdbAutoConnect() {
    const key = selectedWirelessAdbAutoConnectKey();
    if (key === "")
      return false;

    if (!root.visible
        || !embeddedMirrorModeEnabled()
        || !root.mainDeviceSetupComplete()
        || KDEConnect.adbDevicesExitCode !== 0
        || KDEConnect.scrcpyRunning
        || KDEConnect.scrcpyLaunching
        || KDEConnect.wirelessAdbBusy
        || wirelessAdbPopup.opened
        || resolvedAdbSerial() !== "")
      return false;

    return !Boolean((silentWirelessAdbAutoConnectAttempts || ({}))[key]);
  }

  function scheduleSilentWirelessAdbAutoConnect() {
    if (!shouldSilentWirelessAdbAutoConnect())
      return;

    silentWirelessAdbAutoConnectTimer.restart();
  }

  function attemptSilentWirelessAdbAutoConnect() {
    if (!shouldSilentWirelessAdbAutoConnect())
      return;

    const key = selectedWirelessAdbAutoConnectKey();
    const host = selectedDevicePrimaryHost();
    const attempts = Object.assign({}, silentWirelessAdbAutoConnectAttempts || ({}));
    attempts[key] = Date.now();
    silentWirelessAdbAutoConnectAttempts = attempts;
    silentWirelessAdbAutoConnectKey = key;
    silentWirelessAdbAutoConnectPending = true;
    wirelessAdbSessionPreferred = true;
    wirelessAdbPairHost = host;
    wirelessAdbConnectHost = host;
    wirelessAdbConnectPort = "";
    saveWirelessAdbDeviceProfile({ host: host });
    Logger.i("KDEConnect", "Trying silent Wireless ADB auto-detect for selected device:", host);
    const started = KDEConnect.autoConnectWirelessAdb(host, 12);
    if (!started) {
      const resetAttempts = Object.assign({}, silentWirelessAdbAutoConnectAttempts || ({}));
      delete resetAttempts[key];
      silentWirelessAdbAutoConnectAttempts = resetAttempts;
      clearSilentWirelessAdbAutoConnectState();
    }
  }

  function attemptEmbeddedMirrorAutoStart() {
    if (!root.visible
        || !embeddedMirrorModeEnabled()
        || !root.mainDeviceSetupComplete()
        || !root.activePhonePreview
        || !root.scrcpyLaunchPrerequisitesReady()) {
      return;
    }

    root.ensureEmbeddedMirrorSession(root.activePhonePreview);
  }


  function cyclePhoneSizePreset() {
    phoneSizeAnimationEnabled = true;
    if (phoneSizePresetIndex >= 2)
      phoneSizeStepDirection = -1;
    else if (phoneSizePresetIndex <= 0)
      phoneSizeStepDirection = 1;

    phoneSizePresetIndex = Math.max(0, Math.min(2, phoneSizePresetIndex + phoneSizeStepDirection));

    if (phoneSizePresetIndex >= 2)
      phoneSizeStepDirection = -1;
    else if (phoneSizePresetIndex <= 0)
      phoneSizeStepDirection = 1;

    persistPhoneSizePreset();
  }

  function phoneSizeValue(small, medium, large) {
    if (phoneSizePresetIndex === 0)
      return small;
    if (phoneSizePresetIndex === 1)
      return medium;
    return large;
  }

  function initialPhoneSizePresetIndex() {
    const explicitKey = String(cfg.phoneSizePresetKey ?? defaults.phoneSizePresetKey ?? "").trim().toLowerCase();
    if (explicitKey === "small")
      return 0;
    if (explicitKey === "medium")
      return 1;
    if (explicitKey === "large")
      return 2;

    const legacyIndex = Math.max(0, Math.min(2, Number(cfg.phoneSizePresetIndex ?? defaults.phoneSizePresetIndex ?? 0)));
    if (legacyIndex === 2)
      return 0;
    if (legacyIndex === 1)
      return 1;
    return 2;
  }

  function currentPhoneSizePresetKey() {
    return phoneSizeValue("small", "medium", "large");
  }

  function initialPhoneSizeStepDirection() {
    const storedDirection = Number(cfg.phoneSizeStepDirection ?? defaults.phoneSizeStepDirection ?? 0);
    if (storedDirection === -1 || storedDirection === 1)
      return storedDirection;

    return initialPhoneSizePresetIndex() >= 2 ? -1 : 1;
  }

  function initialEmbeddedMirrorAudioEnabled() {
    return Boolean(cfg.embeddedMirrorAudioEnabled ?? defaults.embeddedMirrorAudioEnabled ?? false);
  }

  function persistPhoneSizePreset() {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.phoneSizePresetKey = currentPhoneSizePresetKey();
    pluginApi.pluginSettings.phoneSizePresetIndex = phoneSizePresetIndex;
    pluginApi.pluginSettings.phoneSizeStepDirection = phoneSizeStepDirection;
    pluginApi.saveSettings();
  }

  function persistEmbeddedMirrorAudioMode() {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.embeddedMirrorAudioEnabled = embeddedMirrorAudioEnabled;
    pluginApi.saveSettings();
  }

  function trSafe(key, fallback) {
    const translated = pluginApi?.tr(key);
    if (translated === undefined || translated === null)
      return fallback;

    const text = String(translated);
    return (text === "" || text.startsWith("!!")) ? fallback : text;
  }

  function deviceBrandBadge(deviceName) {
    const brandName = String(deviceName || "").trim().toLowerCase();
    const isApple = brandName.indexOf("iphone") !== -1
      || brandName.indexOf("ipad") !== -1
      || brandName.indexOf("apple") !== -1;
    const isGoogle = brandName.indexOf("pixel") !== -1
      || brandName.indexOf("google") !== -1;
    const isMotorolaFamily = /\b(motorola|moto)\b/.test(brandName);
    const isXiaomiFamily = brandName.indexOf("xiaomi") !== -1
      || brandName.indexOf("redmi") !== -1
      || brandName.indexOf("poco") !== -1;
    const fallbackIcon = isApple
      ? "brand-apple"
      : (isGoogle ? "brand-google" : "brand-android");

    if (isGoogle) {
      return {
        source: googleBrandBadgeSource,
        fallbackIcon: fallbackIcon
      };
    }

    if (isXiaomiFamily) {
      return {
        source: xiaomiBrandBadgeSource,
        fallbackIcon: fallbackIcon
      };
    }

    if (isMotorolaFamily) {
      return {
        source: motorolaBrandBadgeSource,
        fallbackIcon: fallbackIcon
      };
    }

    if (brandName.indexOf("android") !== -1) {
      return {
        source: androidBrandBadgeSource,
        fallbackIcon: fallbackIcon
      };
    }

    return {
      source: "",
      fallbackIcon: fallbackIcon
    };
  }

  function adbDeviceStateEntries() {
    const states = KDEConnect.adbDeviceStates || ({});
    const entries = [];
    for (const serial in states) {
      if (!Object.prototype.hasOwnProperty.call(states, serial))
        continue;

      entries.push({
        serial: String(serial || "").trim(),
        state: String(states[serial] || "").trim()
      });
    }
    return entries;
  }

  function adbSerialsInState(targetState) {
    const desiredState = String(targetState || "").trim();
    if (desiredState === "")
      return [];

    return adbDeviceStateEntries()
      .filter(entry => entry.serial !== "" && entry.state === desiredState)
      .map(entry => entry.serial);
  }

  function normalizedStringArray(value) {
    const source = Array.isArray(value) ? value : [value];
    const result = [];
    for (let i = 0; i < source.length; ++i) {
      const text = String(source[i] || "").trim();
      if (text !== "" && result.indexOf(text) === -1)
        result.push(text);
    }
    return result;
  }

  function adbSerialHost(serial) {
    const trimmedSerial = String(serial || "").trim();
    if (trimmedSerial === "" || KDEConnect.isUsbSelectionSerial(trimmedSerial))
      return "";

    if (trimmedSerial.charAt(0) === "[") {
      const closeBracket = trimmedSerial.indexOf("]");
      if (closeBracket > 1 && trimmedSerial.charAt(closeBracket + 1) === ":")
        return trimmedSerial.slice(1, closeBracket);
    }

    const portSeparator = trimmedSerial.lastIndexOf(":");
    if (portSeparator <= 0)
      return "";

    return trimmedSerial.slice(0, portSeparator);
  }

  function selectedDeviceHosts() {
    return normalizedStringArray(KDEConnect.mainDevice?.reachableAddresses || []);
  }

  function selectedDevicePrimaryHost() {
    const hosts = selectedDeviceHosts();
    return hosts.length > 0 ? hosts[0] : "";
  }

  function hostBelongsToSelectedDevice(host) {
    const trimmedHost = String(host || "").trim();
    if (trimmedHost === "")
      return false;

    const hosts = selectedDeviceHosts();
    return hosts.length === 0 || hosts.indexOf(trimmedHost) !== -1;
  }

  function selectedDeviceUsbAdbAllowed() {
    if (!KDEConnect.adbHasUsbTransport)
      return false;

    const selectedHosts = selectedDeviceHosts();
    const reachableDevices = (KDEConnect.devices || [])
      .filter(device => Boolean(device?.paired) && Boolean(device?.reachable));

    return selectedHosts.length === 0 || reachableDevices.length <= 1;
  }

  function adbSerialMatchesSelectedDevice(serial) {
    const trimmedSerial = String(serial || "").trim();
    if (trimmedSerial === "")
      return false;

    if (KDEConnect.isUsbSelectionSerial(trimmedSerial) || adbSerialHost(trimmedSerial) === "")
      return selectedDeviceUsbAdbAllowed();

    return hostBelongsToSelectedDevice(adbSerialHost(trimmedSerial));
  }

  function adbSerialsInStateForSelectedDevice(targetState) {
    return adbSerialsInState(targetState).filter(serial => adbSerialMatchesSelectedDevice(serial));
  }

  function selectedDeviceWirelessAdbSerial() {
    const hosts = selectedDeviceHosts();
    for (let i = 0; i < hosts.length; ++i) {
      const serial = KDEConnect.adbConnectedSerialForHost(hosts[i]);
      if (serial !== "")
        return serial;
    }

    const configuredSerial = configuredWirelessAdbSerial();
    if (configuredSerial !== ""
        && KDEConnect.adbDeviceSerialConnected(configuredSerial)
        && adbSerialMatchesSelectedDevice(configuredSerial))
      return configuredSerial;

    return "";
  }

  function connectedWirelessAdbSerial() {
    return selectedDeviceWirelessAdbSerial();
  }

  function adbBlockingIssueTitle() {
    if (!root.mainDeviceSetupComplete())
      return "";

    if ((KDEConnect.scrcpyRunning || KDEConnect.scrcpyLaunching)
        && root.mirrorSessionMatchesMainDevice()
        && root.adbSerialMatchesSelectedDevice(KDEConnect.scrcpyActiveSerial))
      return "";

    if (KDEConnect.adbDevicesExitCode !== 0)
      return trSafe("panel.scrcpy.adb-missing-title", "adb Not Available");

    if (adbSerialsInStateForSelectedDevice("unauthorized").length > 0)
      return trSafe("panel.scrcpy.adb-authorize-title", "Authorize USB Debugging");

    if (adbSerialsInStateForSelectedDevice("offline").length > 0)
      return trSafe("panel.scrcpy.adb-offline-title", "Reconnect ADB");

    if (resolvedAdbSerial() === "")
      return trSafe("panel.scrcpy.adb-setup-title", "Connect ADB First");

    return "";
  }

  function adbSetupIssueTitle() {
    if (root.silentWirelessAdbAutoConnectSuppressed())
      return "";

    return adbBlockingIssueTitle();
  }

  function adbSetupIssueSubtitle() {
    const issueTitle = adbSetupIssueTitle();
    if (issueTitle === "")
      return "";

    if (KDEConnect.adbDevicesExitCode !== 0) {
      const stderrText = String(KDEConnect.adbDevicesStderr || "").trim();
      return stderrText !== ""
        ? stderrText
        : trSafe("panel.scrcpy.adb-missing-description", "Install Android platform-tools so the plugin can use adb for mirroring and input.");
    }

    if (adbSerialsInStateForSelectedDevice("unauthorized").length > 0)
      return trSafe("panel.scrcpy.adb-authorize-description", "Enable Developer options and USB debugging on the phone, connect it over USB, unlock it, and accept the USB debugging prompt for this computer.");

    if (adbSerialsInStateForSelectedDevice("offline").length > 0)
      return trSafe("panel.scrcpy.adb-offline-description", "adb can see the phone, but it is not ready yet. Reconnect the cable, unlock the phone, and accept the USB debugging prompt again.");

    if (resolvedAdbSerial() === "")
      return trSafe("panel.scrcpy.adb-setup-wireless-description", "Connect ADB for the selected phone. The panel will not reuse another phone's ADB session.");

    return "";
  }

  function scrcpyLaunchPrerequisitesReady() {
    if ((adbBlockingIssueTitle() || "").trim() !== "")
      return false;

    if (embeddedMirrorModeEnabled()) {
      if ((embeddedMirrorCommand || "").trim() === "")
        return false;

      if (embeddedMirrorFeedConfigured()) {
        if (!embeddedVideoDeviceCheckKnown) {
          if (!embeddedVideoDeviceCheckProc.running)
            refreshEmbeddedVideoDeviceAccess();
          return false;
        }

        if (!embeddedVideoDeviceAccessible)
          return false;
      }

      return true;
    }

    return false;
  }

  function initialCachedDeviceTelemetry() {
    const rawValue = cfg.cachedDeviceTelemetry ?? defaults.cachedDeviceTelemetry ?? ({});
    if (rawValue && typeof rawValue === "object")
      return rawValue;

    return ({});
  }

  function telemetryCacheKey(device) {
    return String(device?.id || "").trim();
  }

  function cachedTelemetryForDevice(device) {
    const key = telemetryCacheKey(device);
    if (key === "")
      return null;

    const cache = cachedDeviceTelemetry || ({});
    const entry = cache[key];
    return (entry && typeof entry === "object") ? entry : null;
  }

  function persistCachedDeviceTelemetry() {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.cachedDeviceTelemetry = cachedDeviceTelemetry;
    pluginApi.saveSettings();
  }

  function updateCachedTelemetryForDevice(device) {
    const key = telemetryCacheKey(device);
    if (key === "")
      return;

    const current = device || ({});
    const previous = cachedTelemetryForDevice(device) || ({});
    const next = {
      battery: Number(current.battery) >= 0 ? Number(current.battery) : previous.battery,
      charging: Number(current.battery) >= 0 ? Boolean(current.charging) : previous.charging,
      cellularNetworkType: String(current.cellularNetworkType || "").trim() !== ""
        ? String(current.cellularNetworkType).trim()
        : previous.cellularNetworkType,
      cellularNetworkStrength: Number(current.cellularNetworkStrength) >= 0
        ? Number(current.cellularNetworkStrength)
        : previous.cellularNetworkStrength,
      notificationCount: Array.isArray(current.notificationIds)
        ? current.notificationIds.length
        : previous.notificationCount
    };

    const changed = JSON.stringify(previous) !== JSON.stringify(next);
    if (!changed)
      return;

    cachedDeviceTelemetry = Object.assign({}, cachedDeviceTelemetry || ({}), {
      [key]: next
    });
    persistCachedDeviceTelemetry();
  }

  function effectiveBatteryValue(device) {
    const battery = Number(device?.battery);
    if (isFinite(battery) && battery >= 0)
      return battery;

    const cached = cachedTelemetryForDevice(device);
    const cachedBattery = Number(cached?.battery);
    return (isFinite(cachedBattery) && cachedBattery >= 0) ? cachedBattery : -1;
  }

  function effectiveChargingValue(device) {
    const liveBattery = Number(device?.battery);
    if (isFinite(liveBattery) && liveBattery >= 0)
      return Boolean(device?.charging);

    const cached = cachedTelemetryForDevice(device);
    return Boolean(cached?.charging);
  }

  function effectiveNetworkType(device) {
    const liveValue = String(device?.cellularNetworkType || "").trim();
    if (liveValue !== "")
      return liveValue;

    const cached = cachedTelemetryForDevice(device);
    return String(cached?.cellularNetworkType || "").trim();
  }

  function effectiveSignalStrength(device) {
    const liveValue = Number(device?.cellularNetworkStrength);
    if (isFinite(liveValue) && liveValue >= 0)
      return liveValue;

    const cached = cachedTelemetryForDevice(device);
    const cachedValue = Number(cached?.cellularNetworkStrength);
    return (isFinite(cachedValue) && cachedValue >= 0) ? cachedValue : -1;
  }

  function effectiveNotificationCount(device) {
    if (Array.isArray(device?.notificationIds))
      return device.notificationIds.length;

    const cached = cachedTelemetryForDevice(device);
    const cachedValue = Number(cached?.notificationCount);
    return isFinite(cachedValue) && cachedValue >= 0 ? cachedValue : 0;
  }

  function randomTokenFromAlphabet(length, alphabet) {
    const size = Math.max(1, Math.round(length || 1));
    const source = String(alphabet || "0123456789");
    let token = "";

    for (let i = 0; i < size; ++i) {
      token += source.charAt(Math.floor(Math.random() * source.length));
    }

    return token;
  }

  function makeTempInstanceToken() {
    return Date.now().toString(36)
      + "-"
      + randomTokenFromAlphabet(8, "abcdefghijklmnopqrstuvwxyz0123456789");
  }

  function initialWirelessAdbDeviceProfiles() {
    const rawValue = cfg.wirelessAdbDevices ?? defaults.wirelessAdbDevices ?? ({});
    const profiles = ({});
    if (!rawValue || typeof rawValue !== "object" || Array.isArray(rawValue))
      return profiles;

    for (const deviceId in rawValue) {
      if (!Object.prototype.hasOwnProperty.call(rawValue, deviceId))
        continue;

      const normalizedDeviceId = String(deviceId || "").trim();
      if (normalizedDeviceId === "")
        continue;

      const profile = normalizedWirelessAdbProfile(rawValue[deviceId]);
      if (profile !== null)
        profiles[normalizedDeviceId] = profile;
    }

    return profiles;
  }

  function normalizedWirelessAdbProfile(rawProfile) {
    if (!rawProfile || typeof rawProfile !== "object" || Array.isArray(rawProfile))
      return null;

    const profile = ({});
    const host = String(rawProfile.host || "").trim();
    const lastPairPort = String(rawProfile.lastPairPort || "").trim();
    const lastConnectPort = String(rawProfile.lastConnectPort || "").trim();
    const lastSerial = String(rawProfile.lastSerial || "").trim();
    const updatedAt = Number(rawProfile.updatedAt || 0);

    if (host !== "")
      profile.host = host;
    if (lastPairPort !== "")
      profile.lastPairPort = lastPairPort;
    if (lastConnectPort !== "")
      profile.lastConnectPort = lastConnectPort;
    if (lastSerial !== "")
      profile.lastSerial = lastSerial;
    if (isFinite(updatedAt) && updatedAt > 0)
      profile.updatedAt = updatedAt;

    return Object.keys(profile).length > 0 ? profile : null;
  }

  function selectedDeviceId() {
    return String(KDEConnect.mainDevice?.id || "").trim();
  }

  function selectedWirelessAdbProfile() {
    const deviceId = selectedDeviceId();
    if (deviceId === "")
      return ({});

    const profile = (wirelessAdbDeviceProfiles || ({}))[deviceId];
    return profile && typeof profile === "object" && !Array.isArray(profile)
      ? profile
      : ({});
  }

  function saveWirelessAdbDeviceProfile(patch) {
    if (!pluginApi)
      return;

    const deviceId = selectedDeviceId();
    if (deviceId === "")
      return;

    const cleanPatch = normalizedWirelessAdbProfile(patch);
    if (cleanPatch === null)
      return;

    const profiles = Object.assign({}, wirelessAdbDeviceProfiles || ({}));
    const currentProfile = profiles[deviceId] && typeof profiles[deviceId] === "object"
      ? profiles[deviceId]
      : ({});
    profiles[deviceId] = Object.assign({}, currentProfile, cleanPatch, {
      updatedAt: Date.now()
    });
    wirelessAdbDeviceProfiles = profiles;
    pluginApi.pluginSettings.wirelessAdbDevices = profiles;
  }

  function currentWirelessAdbProfilePatch(includePorts) {
    const host = (wirelessAdbConnectHost || "").trim() !== ""
      ? (wirelessAdbConnectHost || "").trim()
      : (wirelessAdbPairHost || "").trim();
    const patch = ({});

    if (host !== "")
      patch.host = host;

    if (includePorts) {
      const pairPort = (wirelessAdbPairPort || "").trim();
      const connectPort = (wirelessAdbConnectPort || "").trim();
      if (pairPort !== "")
        patch.lastPairPort = pairPort;
      if (connectPort !== "") {
        patch.lastConnectPort = connectPort;
        if (host !== "")
          patch.lastSerial = host + ":" + connectPort;
      }
    }

    const connectedSerial = KDEConnect.adbConnectedSerialForHost(host);
    if (connectedSerial !== "")
      patch.lastSerial = connectedSerial;

    return patch;
  }

  function escapeWirelessAdbQrValue(value) {
    return String(value || "").replace(/([\\;,:])/g, "\\$1");
  }

  function wirelessAdbQrPayload() {
    if ((wirelessAdbQrInstanceName || "").trim() === "" || (wirelessAdbQrSecret || "").trim() === "")
      return "";

    return "WIFI:T:ADB;S:"
      + escapeWirelessAdbQrValue(wirelessAdbQrInstanceName)
      + ";P:"
      + escapeWirelessAdbQrValue(wirelessAdbQrSecret)
      + ";;";
  }

  function wirelessAdbQrImageSource() {
    if (wirelessAdbQrImageVersion <= 0)
      return "";

    return "file://" + wirelessAdbQrImagePath + "?v=" + wirelessAdbQrImageVersion;
  }

  function persistWirelessAdbSettings() {
    if (!pluginApi)
      return;

    saveWirelessAdbDeviceProfile(currentWirelessAdbProfilePatch(true));
    pluginApi.pluginSettings.wirelessAdbPairHost = (wirelessAdbPairHost || "").trim();
    pluginApi.pluginSettings.wirelessAdbPairPort = (wirelessAdbPairPort || "").trim();
    pluginApi.pluginSettings.wirelessAdbConnectHost = (wirelessAdbConnectHost || "").trim();
    pluginApi.pluginSettings.wirelessAdbConnectPort = (wirelessAdbConnectPort || "").trim();
    pluginApi.saveSettings();
  }

  function loadWirelessAdbProfileForSelectedDevice(clearVolatilePorts) {
    const deviceId = selectedDeviceId();
    const selectedHost = selectedDevicePrimaryHost();
    const profile = selectedWirelessAdbProfile();
    const profileHost = String(profile.host || "").trim();
    const legacyHost = (wirelessAdbConnectHost || "").trim() !== ""
      ? (wirelessAdbConnectHost || "").trim()
      : (wirelessAdbPairHost || "").trim();
    const host = selectedHost !== ""
      ? selectedHost
      : (profileHost !== "" ? profileHost : (deviceId === "" ? legacyHost : ""));

    if (host !== "") {
      wirelessAdbPairHost = host;
      wirelessAdbConnectHost = host;
    } else if (deviceId !== "") {
      wirelessAdbPairHost = "";
      wirelessAdbConnectHost = "";
    }

    if (clearVolatilePorts) {
      wirelessAdbPairPort = "";
      wirelessAdbConnectPort = "";
    }

    if (selectedHost !== "")
      saveWirelessAdbDeviceProfile({ host: selectedHost });
  }

  function wirelessAdbDeviceContextText() {
    const deviceName = String(KDEConnect.mainDevice?.name || "").trim();
    const host = (wirelessAdbConnectHost || "").trim() !== ""
      ? (wirelessAdbConnectHost || "").trim()
      : (wirelessAdbPairHost || "").trim();

    if (deviceName === "" && host === "")
      return "";

    const prefix = deviceName !== ""
      ? deviceName
      : root.trSafe("panel.setup-required.phone-name", "Android Phone");
    const hostText = host !== "" ? (" - " + host) : "";
    return prefix + hostText + ". "
      + root.trSafe("panel.wireless-adb.random-port-note", "Wireless debugging ports can change each time. Enter the current port shown on the phone.");
  }

  function openWirelessAdbDialog() {
    loadWirelessAdbProfileForSelectedDevice(true);

    if ((wirelessAdbConnectHost || "").trim() === "" && (wirelessAdbPairHost || "").trim() !== "")
      wirelessAdbConnectHost = (wirelessAdbPairHost || "").trim();
    if ((wirelessAdbPairHost || "").trim() === "" && (wirelessAdbConnectHost || "").trim() !== "")
      wirelessAdbPairHost = (wirelessAdbConnectHost || "").trim();

    wirelessAdbPairingCode = "";
    wirelessAdbStatusMessage = "";
    wirelessAdbPopup.open();
  }

  function startWirelessAdbPairing() {
    const host = (wirelessAdbPairHost || "").trim();
    const port = (wirelessAdbPairPort || "").trim();
    const pairingCode = (wirelessAdbPairingCode || "").trim();

    if (host === "" || port === "" || pairingCode === "") {
      const body = trSafe("panel.wireless-adb.missing-pair-parameters-description", "Enter the phone IP, pairing port, and pairing code");
      wirelessAdbStatusMessage = body;
      KDEConnect.showWarningWithHistory(trSafe("panel.wireless-adb.error-title", "Wireless ADB"), body, 5000);
      return;
    }

    wirelessAdbConnectHost = host;

    wirelessAdbStatusMessage = "";
    persistWirelessAdbSettings();
    KDEConnect.pairWirelessAdb(host, port, pairingCode);
  }

  function startWirelessAdbConnect() {
    const host = (wirelessAdbConnectHost || "").trim() !== ""
      ? (wirelessAdbConnectHost || "").trim()
      : (wirelessAdbPairHost || "").trim();
    const port = (wirelessAdbConnectPort || "").trim();

    if (host === "" || port === "") {
      const body = trSafe("panel.wireless-adb.missing-connect-parameters-description", "Enter the phone IP and connect port");
      wirelessAdbStatusMessage = body;
      KDEConnect.showWarningWithHistory(trSafe("panel.wireless-adb.error-title", "Wireless ADB"), body, 5000);
      return;
    }

    wirelessAdbConnectHost = host;
    wirelessAdbStatusMessage = "";
    wirelessAdbSessionPreferred = true;
    persistWirelessAdbSettings();
    KDEConnect.connectWirelessAdb(host, port);
  }

  function startWirelessAdbAutoConnect() {
    const host = (wirelessAdbConnectHost || "").trim() !== ""
      ? (wirelessAdbConnectHost || "").trim()
      : ((wirelessAdbPairHost || "").trim() !== ""
          ? (wirelessAdbPairHost || "").trim()
          : selectedDevicePrimaryHost());

    if (host === "") {
      const body = trSafe("panel.wireless-adb.missing-connect-host-description", "Select a reachable KDE Connect phone first so the plugin knows which host to scan.");
      wirelessAdbStatusMessage = body;
      KDEConnect.showWarningWithHistory(trSafe("panel.wireless-adb.error-title", "Wireless ADB"), body, 5000);
      return;
    }

    wirelessAdbPairHost = host;
    wirelessAdbConnectHost = host;
    wirelessAdbConnectPort = "";
    wirelessAdbStatusMessage = trSafe("panel.wireless-adb.auto-connect-running-description", "Scanning for the selected phone's current Wireless ADB port...");
    wirelessAdbSessionPreferred = true;
    persistWirelessAdbSettings();
    KDEConnect.autoConnectWirelessAdb(host, 18);
  }

  function beginWirelessAdbQrPairing() {
    if (KDEConnect.wirelessAdbBusy || wirelessAdbQrEncodeProc.running)
      return;

    wirelessAdbQrInstanceName = "noctalia-" + randomTokenFromAlphabet(10, "abcdefghijklmnopqrstuvwxyz0123456789");
    wirelessAdbQrSecret = randomTokenFromAlphabet(10, "0123456789");
    wirelessAdbStatusMessage = trSafe(
      "panel.wireless-adb.qr-waiting-description",
      "Waiting for the phone to scan the QR code and publish its pairing service."
    );
    wirelessAdbQrPendingLaunch = true;
    wirelessAdbQrEncodeProc.running = true;
  }

  function applyWirelessAdbQrSuccess(message) {
    const match = String(message || "").match(/^QR_OK\s+host=(\S+)\s+pair_port=(\d+)\s+connect_port=(\d+)/);
    if (!match)
      return false;

    wirelessAdbPairHost = match[1];
    wirelessAdbConnectHost = match[1];
    wirelessAdbPairPort = match[2];
    wirelessAdbConnectPort = match[3];
    persistWirelessAdbSettings();
    return true;
  }

  function applyWirelessAdbAutoConnectSuccess(message) {
    const match = String(message || "").match(/^AUTO_CONNECT_OK\s+host=(\S+)\s+connect_port=(\d+)/);
    if (!match)
      return false;

    wirelessAdbPairHost = match[1];
    wirelessAdbConnectHost = match[1];
    wirelessAdbConnectPort = match[2];
    persistWirelessAdbSettings();
    return true;
  }

  function configuredWirelessAdbSerial() {
    const host = (wirelessAdbConnectHost || "").trim();
    const port = (wirelessAdbConnectPort || "").trim();
    if (host === "" || port === "")
      return "";

    return host + ":" + port;
  }

  function mirrorSessionMatchesMainDevice() {
    const sessionDeviceId = String(KDEConnect.scrcpyDeviceId || "").trim();
    const mainDeviceId = String(KDEConnect.mainDevice?.id || "").trim();
    return sessionDeviceId !== "" && mainDeviceId !== "" && sessionDeviceId === mainDeviceId;
  }

  function currentMirrorAdbSerial() {
    const activeSerial = String(KDEConnect.scrcpyActiveSerial || "").trim();
    if (KDEConnect.scrcpyRunning
        && activeSerial !== ""
        && mirrorSessionMatchesMainDevice()
        && adbSerialMatchesSelectedDevice(activeSerial))
      return activeSerial;

    return resolvedAdbSerial();
  }

  function resolvedAdbSerial() {
    const selectedWirelessSerial = selectedDeviceWirelessAdbSerial();
    if (selectedWirelessSerial !== "")
      return selectedWirelessSerial;

    if (KDEConnect.adbHasUsbTransport
        && !wirelessAdbSessionPreferred
        && selectedDeviceUsbAdbAllowed())
      return KDEConnect.usbSelectionSentinel;

    const wirelessSerial = configuredWirelessAdbSerial();
    if (wirelessSerial !== "") {
      if (wirelessAdbSessionPreferred
          && KDEConnect.adbDeviceSerialConnected(wirelessSerial)
          && adbSerialMatchesSelectedDevice(wirelessSerial))
        return wirelessSerial;

      if (!KDEConnect.adbHasUsbTransport
          && KDEConnect.adbDeviceSerialConnected(wirelessSerial)
          && adbSerialMatchesSelectedDevice(wirelessSerial))
        return wirelessSerial;
    }

    return "";
  }

  function syncBackgroundRefreshPolicy() {
    KDEConnect.reduceBackgroundRefresh = root.visible
      && root.reduceBackgroundRefreshWhileMirroring
      && KDEConnect.scrcpyRunning;
  }

  function embeddedMirrorModeEnabled() {
    return true;
  }

  function embeddedMirrorFeedConfigured() {
    return (embeddedVideoDevice || "").trim() !== "";
  }

  function evenFloor(value) {
    const numericValue = Number(value);
    if (!isFinite(numericValue))
      return 0;

    return Math.max(0, Math.floor(numericValue / 2) * 2);
  }

  function greatestCommonDivisor(a, b) {
    let left = Math.abs(Math.round(Number(a || 0)));
    let right = Math.abs(Math.round(Number(b || 0)));
    while (right !== 0) {
      const next = left % right;
      left = right;
      right = next;
    }

    return left > 0 ? left : 1;
  }

  function embeddedMirrorValidScreenDimension(width, height) {
    const screenWidth = Number(width || 0);
    const screenHeight = Number(height || 0);
    return isFinite(screenWidth)
      && isFinite(screenHeight)
      && screenWidth >= 16
      && screenHeight >= 16
      && screenWidth <= 20000
      && screenHeight <= 20000;
  }

  function embeddedMirrorAddScreenCandidate(candidates, width, height, source, priority) {
    const screenWidth = Math.round(Number(width || 0));
    const screenHeight = Math.round(Number(height || 0));
    if (!embeddedMirrorValidScreenDimension(screenWidth, screenHeight))
      return;

    candidates.push({
      width: screenWidth,
      height: screenHeight,
      source: String(source || "unknown"),
      priority: Number(priority || 0)
    });
  }

  function embeddedMirrorAddScreenMatch(candidates, text, regex, source, priority) {
    const match = String(text || "").match(regex);
    if (!match)
      return;

    embeddedMirrorAddScreenCandidate(candidates, match[1], match[2], source, priority);
  }

  function parseEmbeddedMirrorScreenSize(output) {
    const trimmedOutput = String(output || "").replace(/^loopback_format=.*$/gm, "");
    const candidates = [];
    embeddedMirrorAddScreenMatch(candidates, trimmedOutput, /Physical size:\s*(\d+)x(\d+)/i, "wm physical size", 100);
    embeddedMirrorAddScreenMatch(candidates, trimmedOutput, /Override size:\s*(\d+)x(\d+)/i, "wm override size", 95);
    embeddedMirrorAddScreenMatch(candidates, trimmedOutput, /mBaseDisplayInfo[^\n]*?real\s+(\d+)\s*x\s*(\d+)/i, "base display real size", 90);
    embeddedMirrorAddScreenMatch(candidates, trimmedOutput, /mBaseDisplayInfo[^\n]*?logical\s+(\d+)\s*x\s*(\d+)/i, "base display logical size", 88);
    embeddedMirrorAddScreenMatch(candidates, trimmedOutput, /DisplayInfo\{[^\n]*?real\s+(\d+)\s*x\s*(\d+)/i, "display real size", 86);
    embeddedMirrorAddScreenMatch(candidates, trimmedOutput, /DisplayInfo\{[^\n]*?app\s+(\d+)\s*x\s*(\d+)/i, "display app size", 80);
    embeddedMirrorAddScreenMatch(candidates, trimmedOutput, /\bapp\s+(\d+)\s*x\s*(\d+)/i, "app size", 70);
    embeddedMirrorAddScreenMatch(candidates, trimmedOutput, /\blogical\s+(\d+)\s*x\s*(\d+)/i, "logical size", 68);
    embeddedMirrorAddScreenMatch(candidates, trimmedOutput, /mCurrentDisplayRect=Rect\(\s*0\s*,\s*0\s*-\s*(\d+)\s*,\s*(\d+)\s*\)/i, "window display rect", 62);
    embeddedMirrorAddScreenMatch(candidates, trimmedOutput, /\bcur=(\d+)x(\d+)/i, "window current size", 58);
    embeddedMirrorAddScreenMatch(candidates, trimmedOutput, /\b(\d{3,5})\s*x\s*(\d{3,5})\b/i, "generic size", 10);

    if (candidates.length === 0)
      return ({ width: 0, height: 0, source: "unknown" });

    candidates.sort(function(a, b) {
      return Number(b.priority || 0) - Number(a.priority || 0);
    });

    return candidates[0];
  }

  function embeddedMirrorLoopbackAspectRatio(output) {
    const formatMatch = String(output || "").match(/^loopback_format=.*?(\d+)x(\d+)/m);
    if (!formatMatch)
      return embeddedMirrorFallbackAspectRatio;

    const width = Number(formatMatch[1]);
    const height = Number(formatMatch[2]);
    if (width <= 0 || height <= 0)
      return embeddedMirrorFallbackAspectRatio;

    return width / height;
  }

  function embeddedMirrorLoopbackSize(output) {
    const formatMatch = String(output || "").match(/^loopback_format=.*?(\d+)x(\d+)/m);
    if (!formatMatch)
      return ({ width: 9, height: 20 });

    const width = Number(formatMatch[1]);
    const height = Number(formatMatch[2]);
    if (width <= 0 || height <= 0)
      return ({ width: 9, height: 20 });

    return ({ width: width, height: height });
  }

  function embeddedMirrorCropResult(cropWidth, cropHeight, cropX, cropY) {
    return ({
      enabled: true,
      option: "--crop=" + cropWidth + ":" + cropHeight + ":" + cropX + ":" + cropY,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight
    });
  }

  function embeddedMirrorDisabledCrop() {
    return ({ enabled: false, option: "", x: 0, y: 0, width: 0, height: 0 });
  }

  function embeddedMirrorFullFrameForSize(width, height, targetWidth, targetHeight) {
    const sourceWidth = evenFloor(width);
    const sourceHeight = evenFloor(height);
    const maxWidth = evenFloor(targetWidth);
    const maxHeight = evenFloor(targetHeight);
    if (sourceWidth < 16 || sourceHeight < 16 || maxWidth < 16 || maxHeight < 16)
      return ({ enabled: false, option: "", width: 0, height: 0 });

    const scale = Math.min(maxWidth / sourceWidth, maxHeight / sourceHeight, 1);
    const outputWidth = evenFloor(sourceWidth * scale);
    const outputHeight = evenFloor(sourceHeight * scale);
    if (outputWidth < 16 || outputHeight < 16)
      return ({ enabled: false, option: "", width: 0, height: 0 });

    return ({
      enabled: true,
      option: "--max-size=" + Math.max(outputWidth, outputHeight),
      width: outputWidth,
      height: outputHeight
    });
  }

  function embeddedMirrorTargetEnvelopeForSize(width, height) {
    const portraitWidth = evenFloor(Math.min(embeddedMirrorTargetMaxWidth, embeddedMirrorTargetMaxHeight));
    const portraitHeight = evenFloor(Math.max(embeddedMirrorTargetMaxWidth, embeddedMirrorTargetMaxHeight));
    const landscapeWidth = portraitHeight;
    const landscapeHeight = portraitWidth;
    const sourceWidth = evenFloor(width);
    const sourceHeight = evenFloor(height);
    const portraitEnvelope = ({ width: portraitWidth, height: portraitHeight, orientation: "portrait" });
    const landscapeEnvelope = ({ width: landscapeWidth, height: landscapeHeight, orientation: "landscape" });
    if (sourceWidth < 16 || sourceHeight < 16)
      return portraitEnvelope;

    const sourceAspect = sourceWidth / sourceHeight;
    const portraitFrame = embeddedMirrorFullFrameForSize(sourceWidth, sourceHeight, portraitWidth, portraitHeight);
    const landscapeFrame = embeddedMirrorFullFrameForSize(sourceWidth, sourceHeight, landscapeWidth, landscapeHeight);
    const portraitArea = portraitFrame.enabled ? portraitFrame.width * portraitFrame.height : 0;
    const landscapeArea = landscapeFrame.enabled ? landscapeFrame.width * landscapeFrame.height : 0;
    if (portraitArea <= 0 && landscapeArea <= 0)
      return sourceAspect >= 1 ? landscapeEnvelope : portraitEnvelope;

    const preferredEnvelope = sourceAspect >= 1 ? landscapeEnvelope : portraitEnvelope;
    const alternateEnvelope = sourceAspect >= 1 ? portraitEnvelope : landscapeEnvelope;
    const preferredArea = sourceAspect >= 1 ? landscapeArea : portraitArea;
    const alternateArea = sourceAspect >= 1 ? portraitArea : landscapeArea;
    if (preferredArea >= alternateArea * 0.98)
      return preferredEnvelope;

    return alternateEnvelope;
  }

  function embeddedMirrorAlignedCropForSize(width, height, targetWidth, targetHeight, alignment) {
    const sourceWidth = evenFloor(width);
    const sourceHeight = evenFloor(height);
    const align = Math.max(2, Math.round(Number(alignment || 2)));
    const divisor = greatestCommonDivisor(targetWidth, targetHeight);
    const ratioWidth = Math.max(1, Math.round(Number(targetWidth || 0) / divisor));
    const ratioHeight = Math.max(1, Math.round(Number(targetHeight || 0) / divisor));
    const maxScale = Math.floor(Math.min(sourceWidth / ratioWidth, sourceHeight / ratioHeight));

    for (let scale = maxScale; scale > 0; --scale) {
      const cropWidth = ratioWidth * scale;
      const cropHeight = ratioHeight * scale;
      if (cropWidth < 16 || cropHeight < 16)
        break;

      if ((cropWidth % align) !== 0 || (cropHeight % align) !== 0)
        continue;

      const cropX = Math.max(0, Math.min(sourceWidth - cropWidth, evenFloor((sourceWidth - cropWidth) / 2)));
      const cropY = Math.max(0, Math.min(sourceHeight - cropHeight, evenFloor((sourceHeight - cropHeight) / 2)));
      return embeddedMirrorCropResult(cropWidth, cropHeight, cropX, cropY);
    }

    return embeddedMirrorDisabledCrop();
  }

  function embeddedMirrorCropForSize(width, height, targetAspectRatio, targetWidth, targetHeight) {
    const screenWidth = Math.round(Number(width || 0));
    const screenHeight = Math.round(Number(height || 0));
    const targetAspect = Number(targetAspectRatio || 0);
    const sourceWidth = evenFloor(screenWidth);
    const sourceHeight = evenFloor(screenHeight);
    if (sourceWidth < 16 || sourceHeight < 16 || targetAspect <= 0)
      return embeddedMirrorDisabledCrop();

    const sourceAspect = sourceWidth / sourceHeight;
    let cropX = 0;
    let cropY = 0;
    let cropWidth = sourceWidth;
    let cropHeight = sourceHeight;

    if (Math.abs(sourceAspect - targetAspect) <= 0.0005)
      return embeddedMirrorDisabledCrop();

    const alignedCrop = embeddedMirrorAlignedCropForSize(
      sourceWidth,
      sourceHeight,
      targetWidth,
      targetHeight,
      16
    );
    if (alignedCrop.enabled)
      return alignedCrop;

    if (sourceAspect > targetAspect) {
      cropWidth = evenFloor(sourceHeight * targetAspect);
      if (cropWidth < 16 || sourceWidth - cropWidth < 2)
        return embeddedMirrorDisabledCrop();

      cropX = evenFloor((screenWidth - cropWidth) / 2);
      cropX = Math.max(0, Math.min(screenWidth - cropWidth, cropX));
    } else {
      cropHeight = evenFloor(sourceWidth / targetAspect);
      if (cropHeight < 16 || sourceHeight - cropHeight < 2)
        return embeddedMirrorDisabledCrop();

      cropY = evenFloor((screenHeight - cropHeight) / 2);
      cropY = Math.max(0, Math.min(screenHeight - cropHeight, cropY));
    }

    return embeddedMirrorCropResult(cropWidth, cropHeight, cropX, cropY);
  }

  function embeddedMirrorLaunchShapeForSize(width, height) {
    const envelope = embeddedMirrorTargetEnvelopeForSize(width, height);
    const fullFrame = embeddedMirrorFullFrameForSize(
      width,
      height,
      envelope.width,
      envelope.height
    );
    if (fullFrame.enabled) {
      return ({
        mode: "full-frame",
        orientation: envelope.orientation,
        targetWidth: envelope.width,
        targetHeight: envelope.height,
        maxSizeOption: fullFrame.option,
        outputWidth: fullFrame.width,
        outputHeight: fullFrame.height,
        crop: embeddedMirrorDisabledCrop()
      });
    }

    const targetAspect = envelope.width > 0 && envelope.height > 0
      ? envelope.width / envelope.height
      : embeddedMirrorFallbackAspectRatio;
    const crop = embeddedMirrorCropForSize(
      width,
      height,
      targetAspect,
      envelope.width,
      envelope.height
    );

    return ({
      mode: crop.enabled ? "crop" : "default",
      orientation: envelope.orientation,
      targetWidth: envelope.width,
      targetHeight: envelope.height,
      maxSizeOption: "--max-size=" + Math.max(envelope.width, envelope.height),
      outputWidth: 0,
      outputHeight: 0,
      crop: crop
    });
  }

  function clearEmbeddedMirrorInputCrop() {
    embeddedMirrorInputCropX = 0;
    embeddedMirrorInputCropY = 0;
    embeddedMirrorInputCropWidth = 0;
    embeddedMirrorInputCropHeight = 0;
  }

  function applyEmbeddedMirrorInputCrop(crop) {
    if (!crop || !crop.enabled) {
      clearEmbeddedMirrorInputCrop();
      return;
    }

    embeddedMirrorInputCropX = Math.max(0, Math.round(Number(crop.x || 0)));
    embeddedMirrorInputCropY = Math.max(0, Math.round(Number(crop.y || 0)));
    embeddedMirrorInputCropWidth = Math.max(0, Math.round(Number(crop.width || 0)));
    embeddedMirrorInputCropHeight = Math.max(0, Math.round(Number(crop.height || 0)));
  }

  function applyEmbeddedMirrorExpectedOutput(width, height) {
    embeddedMirrorExpectedOutputWidth = Math.max(0, Math.round(Number(width || 0)));
    embeddedMirrorExpectedOutputHeight = Math.max(0, Math.round(Number(height || 0)));
  }

  function embeddedMirrorErrorLooksCodecRelated(errorText) {
    const text = String(errorText || "");
    return /codec|encoder|h\.?264|avc|MediaCodec|configure codec|could not open video|video encoder/i.test(text);
  }

  function embeddedMirrorCommandWithCodecFallback(commandString, serial) {
    const trimmedSerial = String(serial || "").trim();
    if (!embeddedMirrorCodecFallbackActive
        || trimmedSerial === ""
        || trimmedSerial !== String(embeddedMirrorCodecFallbackSerial || "").trim())
      return commandString;

    let command = KDEConnect.normalizeShellCommand(commandString);
    command = command.replace(/(^|\s)--video-codec(?:=\S+|\s+\S+)/g, " ");
    command = KDEConnect.normalizeShellCommand(command);
    return KDEConnect.appendScrcpyOption(command, /(^|\s)--video-codec(?:=|\s+)h265\b/, "--video-codec=h265");
  }

  function embeddedMirrorShapeProbeCommand() {
    const androidProbeScript = [
      "printf '__androidconnect_wm_size__\\n'",
      "wm size 2>&1 || true",
      "printf '__androidconnect_dumpsys_display__\\n'",
      "dumpsys display 2>/dev/null | grep -E \"mBaseDisplayInfo|DisplayInfo\\{|real [0-9]+ x [0-9]+|app [0-9]+ x [0-9]+|logical [0-9]+ x [0-9]+\" || true",
      "printf '__androidconnect_dumpsys_window__\\n'",
      "dumpsys window 2>/dev/null | grep -E \"mDisplayInfo|mBaseDisplayInfo|mCurrentDisplayRect|mUnrestrictedScreen|cur=[0-9]+x[0-9]+|app=[0-9]+x[0-9]+\" || true"
    ].join("; ");
    const adbCommand = KDEConnect.shellJoinArgs(
      ["adb"]
        .concat(KDEConnect.adbSelectorArgsForSerial(embeddedMirrorShapeProbeSerial))
        .concat(["shell", "sh", "-c", androidProbeScript])
    );

    return ["sh", "-lc",
      "device=" + KDEConnect.shellQuote(root.embeddedVideoDevice)
      + "; adb_output=$(" + adbCommand + " 2>&1); adb_status=$?"
      + "; printf '%s\\n' \"$adb_output\""
      + "; format_path=/sys/devices/virtual/video4linux/$(basename \"$device\")/format"
      + "; printf 'loopback_format='"
      + "; cat \"$format_path\" 2>/dev/null || true"
      + "; printf '\\n'"
      + "; exit \"$adb_status\""
    ];
  }

  function launchEmbeddedMirrorSession(baseCommand, serial, deviceId, launchShape) {
    let launchCommand = KDEConnect.buildScrcpyFeedCommand(
      baseCommand,
      embeddedVideoDevice,
      serial
    );
    if (launchCommand === "")
      return;

    const shape = launchShape || ({
      mode: "default",
      orientation: "portrait",
      targetWidth: Math.min(embeddedMirrorTargetMaxWidth, embeddedMirrorTargetMaxHeight),
      targetHeight: Math.max(embeddedMirrorTargetMaxWidth, embeddedMirrorTargetMaxHeight),
      maxSizeOption: "--max-size=" + embeddedMirrorTargetMaxHeight,
      outputWidth: 0,
      outputHeight: 0,
      crop: embeddedMirrorDisabledCrop()
    });
    const crop = shape.crop || null;
    const maxSizeOption = String(shape.maxSizeOption || "").trim();
    if (maxSizeOption !== "")
      launchCommand = KDEConnect.normalizeShellCommand(launchCommand + " " + maxSizeOption);

    if (crop && crop.enabled && crop.option !== "")
      launchCommand = KDEConnect.normalizeShellCommand(launchCommand + " " + crop.option);

    if (String(embeddedMirrorFormatMismatchSerial || "").trim() !== String(serial || "").trim()) {
      embeddedMirrorFormatMismatchSerial = String(serial || "").trim();
      embeddedMirrorFormatMismatchRetryCount = 0;
    }

    applyEmbeddedMirrorInputCrop(crop);
    applyEmbeddedMirrorExpectedOutput(shape.outputWidth || 0, shape.outputHeight || 0);
    Logger.i("KDEConnect", "Launching embedded scrcpy in feed mode",
      "mode=" + String(shape.mode || "default"),
      "orientation=" + String(shape.orientation || "unknown"),
      "target=" + Number(shape.targetWidth || 0) + "x" + Number(shape.targetHeight || 0),
      "expected=" + embeddedMirrorExpectedOutputWidth + "x" + embeddedMirrorExpectedOutputHeight,
      embeddedMirrorCodecFallbackActive && String(embeddedMirrorCodecFallbackSerial || "").trim() === String(serial || "").trim()
        ? "codecFallback=h265"
        : "codecFallback=none",
      maxSizeOption !== "" ? ("size=" + maxSizeOption) : "size=default",
      crop && crop.enabled ? ("crop=" + crop.option) : "crop=none");
    KDEConnect.launchScrcpySession(
      deviceId,
      launchCommand
    );
  }

  function queryEmbeddedMirrorShapeAndLaunch(baseCommand, serial, deviceId) {
    if (embeddedMirrorShapeProbeProc.running)
      return;

    embeddedMirrorShapeProbeSerial = serial;
    embeddedMirrorShapeProbeDeviceId = deviceId;
    embeddedMirrorShapeProbeBaseCommand = baseCommand;
    embeddedMirrorShapeProbeStdout = "";
    embeddedMirrorShapeProbeStderr = "";
    embeddedMirrorShapeProbeProc.running = true;
  }

  function scheduleTouchMappingRefresh() {
    Qt.callLater(function() {
      root.refreshEmbeddedMirrorTouchMapping();
    });
  }

  function clearPanelOpenUnlockState() {
    root.panelOpenUnlockPending = false;
    root.panelOpenUnlockRetriesRemaining = 0;
  }

  function retryPanelOpenUnlock() {
    if (root.panelOpenUnlockRetriesRemaining > 0) {
      root.panelOpenUnlockRetriesRemaining -= 1;
      panelOpenUnlockTimer.restart();
      return;
    }

    root.clearPanelOpenUnlockState();
  }

  function resetEmbeddedVideoDeviceAccess(checkKnown) {
    embeddedVideoDeviceAccessible = false;
    embeddedVideoDeviceCheckKnown = Boolean(checkKnown);
  }

  function refreshEmbeddedVideoDeviceAccess() {
    if (!embeddedMirrorFeedConfigured()) {
      resetEmbeddedVideoDeviceAccess(true);
      embeddedVideoDeviceLastCheckAtMs = Date.now();
      return;
    }

    if (embeddedVideoDeviceCheckProc.running)
      return;

    if (!embeddedVideoDeviceCheckKnown)
      resetEmbeddedVideoDeviceAccess(false);
    embeddedVideoDeviceCheckProc.running = true;
  }

  function ensureEmbeddedVideoDeviceAccessFresh(maxAgeMs) {
    if (!embeddedMirrorFeedConfigured() || embeddedVideoDeviceCheckProc.running)
      return;

    const maxAge = Math.max(0, Number(maxAgeMs || 0));
    const lastCheckedAt = Number(embeddedVideoDeviceLastCheckAtMs || 0);
    if (maxAge > 0 && lastCheckedAt > 0 && (Date.now() - lastCheckedAt) < maxAge)
      return;

    refreshEmbeddedVideoDeviceAccess();
  }

  function toggleEmbeddedMirrorAudioMode(preview) {
    if (!embeddedMirrorModeEnabled())
      return;

    embeddedMirrorAudioEnabled = !embeddedMirrorAudioEnabled;

    if (KDEConnect.scrcpyRunning && !KDEConnect.scrcpyLaunching)
      KDEConnect.stopScrcpySession();
  }

  function ensureEmbeddedMirrorSession(preview) {
    if (!embeddedMirrorModeEnabled() || KDEConnect.mainDevice === null)
      return;

    if (!scrcpyLaunchPrerequisitesReady())
      return;

    const serial = resolvedAdbSerial();
    if (serial === "")
      return;

    if (embeddedMirrorFeedConfigured() && !embeddedVideoDeviceCheckKnown && !embeddedVideoDeviceCheckProc.running) {
      refreshEmbeddedVideoDeviceAccess();
    }

    if (!KDEConnect.scrcpyRunning && !KDEConnect.scrcpyLaunching) {
      if (embeddedMirrorShapeProbeProc.running)
        return;

      if (embeddedMirrorCodecFallbackActive
          && String(embeddedMirrorCodecFallbackSerial || "").trim() !== serial) {
        embeddedMirrorCodecFallbackActive = false;
        embeddedMirrorCodecFallbackSerial = "";
      }

      let tunedEmbeddedCommand = KDEConnect.applyConfiguredMirrorAudioMode(
        embeddedMirrorCommand,
        embeddedMirrorAudioEnabled
      );
      tunedEmbeddedCommand = embeddedMirrorCommandWithCodecFallback(tunedEmbeddedCommand, serial);
      queryEmbeddedMirrorShapeAndLaunch(
        tunedEmbeddedCommand,
        serial,
        KDEConnect.mainDevice.id
      );
      return;
    }

    if (KDEConnect.scrcpyRunning) {
      refreshEmbeddedMirrorTouchMapping();
    }
  }

  function ensureDetachedMirrorSession() {
    if (!scrcpyLaunchPrerequisitesReady())
      return;

    const serial = resolvedAdbSerial();
    if (serial === "")
      return;

    Logger.i("KDEConnect", "Launching detached scrcpy window");
    KDEConnect.launchDetachedScrcpy(serial, detachedMirrorCommand);
  }

  function embeddedMirrorViewActive(preview) {
    return KDEConnect.scrcpyRunning
      && Boolean(preview?.mirrorDisplayVisible);
  }

  function embeddedMirrorFeedReattaching(preview) {
    const previewItem = preview || root.activePhonePreview || null;
    return Boolean(previewItem?.mirrorFeedAttachDelayActive);
  }

  function embeddedMirrorTouchActive() {
    return embeddedMirrorModeEnabled()
      && KDEConnect.scrcpyRunning
      && KDEConnect.adbDisplayInfoSerial === ""
      && KDEConnect.adbScreenError === ""
      && KDEConnect.adbScreenWidth > 0
      && KDEConnect.adbScreenHeight > 0;
  }

  function embeddedMirrorInputActive() {
    return embeddedMirrorModeEnabled()
      && KDEConnect.scrcpyRunning
      && mirrorSessionMatchesMainDevice()
      && currentMirrorAdbSerial() !== "";
  }

  function embeddedMirrorNavRowVisible() {
    return embeddedMirrorModeEnabled();
  }

  function refreshEmbeddedMirrorTouchMapping() {
    if (!embeddedMirrorModeEnabled()
        || !KDEConnect.scrcpyRunning)
      return;

    const serial = currentMirrorAdbSerial();
    if (serial === "")
      return;

    const hasValidMapping = KDEConnect.adbScreenWidth > 0
      && KDEConnect.adbScreenHeight > 0
      && KDEConnect.adbScreenError === ""
      && KDEConnect.adbDisplayInfoSerial === ""
      && KDEConnect.adbScreenSerial === serial;

    if (!hasValidMapping)
      KDEConnect.queryAdbDisplayInfo(serial);
  }

  function refreshPanelOpenUnlockState() {
    if (!root.panelOpenUnlockPending
        || !root.embeddedMirrorModeEnabled()
        || !KDEConnect.scrcpyRunning)
      return;

    const serial = currentMirrorAdbSerial();
    if (serial === "")
      return;

    KDEConnect.queryAdbScreenState(serial);
  }

  function embeddedMirrorDrawerStatusVisible(preview) {
    if (!embeddedMirrorModeEnabled())
      return false;

    if (!panelStatusGraceElapsed)
      return false;

    return String(embeddedMirrorDrawerStatusTitle(preview) || "").trim() !== ""
      || String(embeddedMirrorDrawerStatusSubtitle(preview) || "").trim() !== "";
  }

  function embeddedMirrorPhoneOverlayVisible() {
    if (!embeddedMirrorModeEnabled())
      return true;

    if (!panelStatusGraceElapsed)
      return false;

    return KDEConnect.scrcpyLaunching;
  }

  function embeddedMirrorPhoneStatusTitle(preview) {
    return embeddedMirrorPhoneOverlayVisible()
      ? embeddedMirrorStatusTitle(preview)
      : "";
  }

  function embeddedMirrorPhoneStatusSubtitle(preview) {
    return embeddedMirrorPhoneOverlayVisible()
      ? embeddedMirrorStatusSubtitle(preview)
      : "";
  }

  function embeddedMirrorDrawerStatusTitle(preview) {
    return embeddedMirrorStatusTitle(preview);
  }

  function embeddedMirrorDrawerStatusSubtitle(preview) {
    return embeddedMirrorStatusSubtitle(preview);
  }

  function embeddedMirrorStatusTitle(preview) {
    const adbIssueTitle = adbSetupIssueTitle();
    if (adbIssueTitle !== "")
      return adbIssueTitle;

    if (embeddedMirrorFeedConfigured() && embeddedVideoDeviceCheckKnown && !embeddedVideoDeviceAccessible)
      return trSafe("panel.embedded-mirror.feed-unavailable-title", "Video Feed Unavailable");

    if (KDEConnect.scrcpyLaunching)
      return trSafe("panel.embedded-mirror.starting-title", "Starting Embedded Mirror");

    if (KDEConnect.scrcpyLaunchError !== "")
      return trSafe("panel.embedded-mirror.error-title", "Mirror Error");

    if (embeddedMirrorFeedConfigured()
        && KDEConnect.scrcpyRunning
        && preview
        && !embeddedMirrorFeedReattaching(preview)
        && !preview.mirrorFeedAvailable
        && Number(KDEConnect.scrcpyLaunchStartedAtMs || 0) > 0
        && (Date.now() - Number(KDEConnect.scrcpyLaunchStartedAtMs || 0)) >= 5000)
      return trSafe("panel.embedded-mirror.feed-starting-title", "Waiting for Video Feed");

    if (embeddedMirrorFeedConfigured()
        && KDEConnect.scrcpyRunning
        && !embeddedMirrorFeedReattaching(preview)
        && !embeddedMirrorViewActive(preview)
        && Number(KDEConnect.scrcpyLaunchStartedAtMs || 0) > 0
        && (Date.now() - Number(KDEConnect.scrcpyLaunchStartedAtMs || 0)) >= 5000)
      return trSafe("panel.embedded-mirror.feed-starting-title", "Waiting for Video Feed");

    if (KDEConnect.scrcpyRunning && KDEConnect.adbScreenError !== "")
      return trSafe("panel.embedded-mirror.touch-error-title", "Touch Input Unavailable");

    if (KDEConnect.scrcpyRunning && !embeddedMirrorTouchActive())
      return trSafe("panel.embedded-mirror.touch-starting-title", "Preparing Touch Input");

    return "";
  }

  function embeddedMirrorStatusSubtitle(preview) {
    const adbIssueSubtitle = adbSetupIssueSubtitle();
    if (adbIssueSubtitle !== "")
      return adbIssueSubtitle;

    if (embeddedMirrorFeedConfigured() && embeddedVideoDeviceCheckKnown && !embeddedVideoDeviceAccessible)
      return trSafe("panel.embedded-mirror.feed-unavailable-description",
        "The V4L2 device cannot be opened. Make sure "
        + embeddedVideoDevice + " exists, is writable, and is backed by the scrcpy loopback device.");

    if (KDEConnect.scrcpyLaunching)
      return trSafe("panel.embedded-mirror.starting-description", "Launching scrcpy and preparing the live feed.");

    if (KDEConnect.scrcpyLaunchError !== "")
      return KDEConnect.scrcpyLaunchError;

    if (embeddedMirrorFeedConfigured()
        && KDEConnect.scrcpyRunning
        && preview
        && !embeddedMirrorFeedReattaching(preview)
        && !preview.mirrorFeedAvailable
        && Number(KDEConnect.scrcpyLaunchStartedAtMs || 0) > 0
        && (Date.now() - Number(KDEConnect.scrcpyLaunchStartedAtMs || 0)) >= 5000) {
      return trSafe("panel.embedded-mirror.feed-starting-description", "Waiting for the scrcpy video feed to appear in the embedded preview.");
    }

    if (embeddedMirrorFeedConfigured()
        && KDEConnect.scrcpyRunning
        && !embeddedMirrorFeedReattaching(preview)
        && !embeddedMirrorViewActive(preview)
        && Number(KDEConnect.scrcpyLaunchStartedAtMs || 0) > 0
        && (Date.now() - Number(KDEConnect.scrcpyLaunchStartedAtMs || 0)) >= 5000) {
      const feedError = preview && preview.mirrorFeedError !== ""
        ? (" Preview failed: " + preview.mirrorFeedError)
        : "";
      return trSafe("panel.embedded-mirror.feed-starting-description", "Waiting for the scrcpy video feed to appear in the embedded preview.")
        + feedError;
    }

    if (KDEConnect.scrcpyRunning && KDEConnect.adbScreenError !== "")
      return KDEConnect.adbScreenError;

    if (KDEConnect.scrcpyRunning && !embeddedMirrorTouchActive())
      return trSafe("panel.embedded-mirror.touch-starting-description", "Querying the Android display size so taps and swipes line up with the mirror.");

    return "";
  }

  Process {
    id: embeddedMirrorShapeProbeProc
    running: false
    command: root.embeddedMirrorShapeProbeCommand()

    stdout: StdioCollector {
      onStreamFinished: {
        root.embeddedMirrorShapeProbeStdout = String(text || "").trim();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.embeddedMirrorShapeProbeStderr = String(text || "").trim();
      }
    }

    onExited: (exitCode, exitStatus) => {
      const pendingSerial = root.embeddedMirrorShapeProbeSerial;
      const pendingDeviceId = root.embeddedMirrorShapeProbeDeviceId;
      const pendingBaseCommand = root.embeddedMirrorShapeProbeBaseCommand;
      const output = root.embeddedMirrorShapeProbeStdout;
      const stderrOutput = root.embeddedMirrorShapeProbeStderr;
      root.embeddedMirrorShapeProbeSerial = "";
      root.embeddedMirrorShapeProbeDeviceId = "";
      root.embeddedMirrorShapeProbeBaseCommand = "";
      root.embeddedMirrorShapeProbeStdout = "";
      root.embeddedMirrorShapeProbeStderr = "";

      if (!root.visible
          || !root.embeddedMirrorModeEnabled()
          || KDEConnect.mainDevice === null
          || String(KDEConnect.mainDevice.id || "").trim() !== pendingDeviceId
          || root.resolvedAdbSerial() !== pendingSerial
          || KDEConnect.scrcpyRunning
          || KDEConnect.scrcpyLaunching) {
        root.scheduleEmbeddedMirrorAutoStart();
        return;
      }

      let launchShape = null;
      if (exitCode === 0) {
        const screenSize = root.parseEmbeddedMirrorScreenSize(output);
        const loopbackSize = root.embeddedMirrorLoopbackSize(output);
        const loopbackAspect = root.embeddedMirrorLoopbackAspectRatio(output);
        launchShape = root.embeddedMirrorLaunchShapeForSize(
          screenSize.width,
          screenSize.height
        );
        const targetWidth = Number(launchShape.targetWidth || 0);
        const targetHeight = Number(launchShape.targetHeight || 0);
        const targetAspect = targetWidth > 0 && targetHeight > 0
          ? targetWidth / targetHeight
          : 0;
        Logger.i("KDEConnect", "Embedded mirror shape probe:",
          "screen=" + screenSize.width + "x" + screenSize.height,
          "screenSource=" + String(screenSize.source || "unknown"),
          "target=" + targetWidth + "x" + targetHeight,
          targetAspect > 0 ? ("targetAspect=" + targetAspect.toFixed(5)) : "targetAspect=unknown",
          "orientation=" + String(launchShape.orientation || "unknown"),
          "loopback=" + loopbackSize.width + "x" + loopbackSize.height,
          "loopbackAspect=" + loopbackAspect.toFixed(5),
          "mode=" + String(launchShape.mode || "default"),
          "expected=" + Number(launchShape.outputWidth || 0) + "x" + Number(launchShape.outputHeight || 0),
          String(launchShape.maxSizeOption || "") !== "" ? ("size=" + launchShape.maxSizeOption) : "size=default",
          launchShape.crop && launchShape.crop.enabled ? ("crop=" + launchShape.crop.option) : "crop=none");
      } else {
        Logger.w("KDEConnect", "Embedded mirror shape probe failed, launching with default sizing:",
          stderrOutput !== "" ? stderrOutput : output);
      }

      root.launchEmbeddedMirrorSession(
        pendingBaseCommand,
        pendingSerial,
        pendingDeviceId,
        launchShape
      );
    }
  }

  Process {
    id: embeddedVideoDeviceCheckProc
    running: false
    command: ["sh", "-lc",
      "device=" + KDEConnect.shellQuote(root.embeddedVideoDevice)
      + "; [ -c \"$device\" ] || exit 1"
      + "; [ -w \"$device\" ] || exit 1"
      + "; if command -v udevadm >/dev/null 2>&1; then"
      + " props=$(udevadm info -q property -n \"$device\" 2>/dev/null || true)"
      + "; if printf '%s\\n' \"$props\" | grep -Eq 'ID_V4L_CAPABILITIES=.*:video_(capture|output):'; then"
      + " exit 0"
      + "; fi"
      + "; fi"
      + "; if command -v v4l2-ctl >/dev/null 2>&1; then"
      + " v4l2-ctl -D -d \"$device\" 2>/dev/null | grep -Eq 'Video (Capture|Output)'"
      + "; else"
      + " [ -r \"$device\" ]"
      + "; fi"
    ]

    onExited: (exitCode, exitStatus) => {
      root.embeddedVideoDeviceAccessible = exitCode === 0;
      root.embeddedVideoDeviceCheckKnown = true;
      root.embeddedVideoDeviceLastCheckAtMs = Date.now();

      if (exitCode !== 0) {
        Logger.w("KDEConnect", "Embedded V4L2 device check failed:", root.embeddedVideoDevice);
      }
      if (!KDEConnect.scrcpyRunning && !KDEConnect.scrcpyLaunching)
        root.scheduleEmbeddedMirrorAutoStart();
    }
  }

  Process {
    id: embeddedMirrorFormatLockProc
    running: false
    command: ["sh", "-lc",
      "device=" + KDEConnect.shellQuote(root.embeddedVideoDevice)
      + "; expected_width=" + Math.max(0, Math.round(Number(root.embeddedMirrorExpectedOutputWidth || 0)))
      + "; expected_height=" + Math.max(0, Math.round(Number(root.embeddedMirrorExpectedOutputHeight || 0)))
      + "; expected_size=''"
      + "; if [ \"$expected_width\" -gt 0 ] && [ \"$expected_height\" -gt 0 ]; then expected_size=\"${expected_width}x${expected_height}\"; fi"
      + "; fmt_size() { printf '%s\\n' \"$1\" | sed -n 's/.*:\\([0-9][0-9]*\\)x\\([0-9][0-9]*\\).*/\\1x\\2/p' | head -n1; }"
      + "; [ -c \"$device\" ] || exit 2"
      + "; base=/sys/devices/virtual/video4linux/$(basename \"$device\")"
      + "; i=0; fmt=''; prev_fmt=''; stable_fmt=''; current_size=''"
      + "; while [ $i -lt 40 ]; do"
      + " fmt=$(cat \"$base/format\" 2>/dev/null || true)"
      + "; current_size=$(fmt_size \"$fmt\")"
      + "; if [ -n \"$expected_size\" ] && [ \"$current_size\" = \"$expected_size\" ]; then stable_fmt=\"$fmt\"; break; fi"
      + "; if [ -z \"$expected_size\" ] && [ -n \"$fmt\" ] && [ \"$fmt\" = \"$prev_fmt\" ]; then stable_fmt=\"$fmt\"; break; fi"
      + "; [ -n \"$fmt\" ] && prev_fmt=\"$fmt\""
      + "; i=$((i+1))"
      + "; sleep 0.05"
      + "; done"
      + "; [ -n \"$stable_fmt\" ] && fmt=\"$stable_fmt\" || fmt=\"$prev_fmt\""
      + "; [ -n \"$fmt\" ] || exit 3"
      + "; observed_size=$(fmt_size \"$fmt\")"
      + "; printf 'observed_format=%s\\n' \"$fmt\""
      + "; [ -z \"$observed_size\" ] || printf 'observed_size=%s\\n' \"$observed_size\""
      + "; [ -z \"$expected_size\" ] || printf 'expected_size=%s\\n' \"$expected_size\""
      + "; if [ -n \"$expected_size\" ] && [ -n \"$observed_size\" ] && [ \"$observed_size\" != \"$expected_size\" ]; then"
      + " printf 'format_mismatch=expected:%s observed:%s\\n' \"$expected_size\" \"$observed_size\""
      + "; v4l2-ctl -d \"$device\" -c keep_format=0 >/dev/null 2>&1 || true"
      + "; exit 6"
      + "; fi"
      + "; v4l2-ctl -d \"$device\" -c keep_format=1 >/dev/null 2>&1 || exit 4"
      + "; i=0; ready=0"
      + "; while [ $i -lt 60 ]; do"
      + " if v4l2-ctl -D -d \"$device\" >/dev/null 2>&1"
      + " && v4l2-ctl --list-formats-ext -d \"$device\" >/dev/null 2>&1; then ready=1; break; fi"
      + "; i=$((i+1))"
      + "; sleep 0.05"
      + "; done"
      + "; [ \"$ready\" = 1 ] || exit 5"
      + "; printf 'locked_format=%s\\n' \"$fmt\""
      + "; printf 'consumer_open_ready=1\\n'"
      + "; v4l2-ctl -d \"$device\" -C keep_format 2>/dev/null | sed 's/^/keep_format=/'"
    ]

    stdout: StdioCollector {
      onStreamFinished: {
        const output = String(text || "").trim();
        if (output !== "") {
          Logger.i("KDEConnect", "Embedded format lock output:\n" + output);
          if (root.activePhonePreview) {
            const lines = output.split("\n");
            for (let i = 0; i < lines.length; ++i) {
              const line = String(lines[i] || "").trim();
              if (line !== "")
                root.activePhonePreview.debugLog("formatLock " + line);
            }
          }
        }
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        const output = String(text || "").trim();
        if (output !== "") {
          Logger.w("KDEConnect", "Embedded format lock stderr:", output);
          if (root.activePhonePreview)
            root.activePhonePreview.debugLog("formatLock stderr=" + output);
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      Logger.i("KDEConnect", "Embedded format lock exited:", exitCode);
      if (root.activePhonePreview)
        root.activePhonePreview.debugLog("formatLock exitCode=" + exitCode);
      if (exitCode === 0 && root.activePhonePreview) {
        root.embeddedMirrorFormatLockRetryCount = 0;
        root.embeddedMirrorFormatMismatchRetryCount = 0;
        Qt.callLater(function() {
          if (root.activePhonePreview)
            root.activePhonePreview.probeNativeLoopback();
        });
      } else if (exitCode === 6
          && KDEConnect.scrcpyRunning
          && root.embeddedMirrorFormatMismatchRetryCount < 1) {
        root.embeddedMirrorFormatMismatchRetryCount += 1;
        Logger.w("KDEConnect", "Embedded format did not match expected size; restarting feed once");
        if (root.activePhonePreview)
          root.activePhonePreview.debugLog("formatLock mismatch restart=" + root.embeddedMirrorFormatMismatchRetryCount);
        KDEConnect.stopScrcpySession();
      } else if (exitCode === 5
          && root.activePhonePreview
          && root.activePhonePreview.mirrorFeedEnabled
          && root.embeddedMirrorFormatLockRetryCount < 3) {
        root.embeddedMirrorFormatLockRetryCount += 1;
        root.activePhonePreview.debugLog("formatLock retry attempt=" + root.embeddedMirrorFormatLockRetryCount);
        embeddedMirrorFormatLockRetryTimer.restart();
      } else {
        root.embeddedMirrorFormatLockRetryCount = 0;
      }
    }
  }

  Process {
    id: wirelessAdbQrEncodeProc
    running: false
    command: [
      "qrencode",
      "-o", root.wirelessAdbQrImagePath,
      "-s", "10",
      "-m", "1",
      root.wirelessAdbQrPayload()
    ]

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        root.wirelessAdbQrImageVersion += 1;
        if (root.wirelessAdbQrPendingLaunch) {
          root.wirelessAdbQrPendingLaunch = false;
          KDEConnect.pairWirelessAdbByQr(
            root.wirelessAdbQrInstanceName,
            root.wirelessAdbQrSecret,
            90
          );
        }
        return;
      }

      root.wirelessAdbQrPendingLaunch = false;
      const body = root.trSafe("panel.wireless-adb.qr-generate-error-description", "Failed to generate the Wireless ADB QR code.");
      root.wirelessAdbStatusMessage = body;
      KDEConnect.showWarningWithHistory(root.trSafe("panel.wireless-adb.error-title", "Wireless ADB"), body, 5000);
    }
  }

  function normalizedToDeviceCoordinate(value, maxValue, cropOffset, cropSize) {
    if (maxValue <= 0)
      return 0;

    const offset = Math.max(0, Math.min(maxValue - 1, Math.round(Number(cropOffset || 0))));
    const availableSize = Math.max(1, maxValue - offset);
    const span = cropSize > 0
      ? Math.max(1, Math.min(availableSize, Math.round(Number(cropSize || 0))))
      : maxValue;

    return Math.max(0, Math.min(maxValue - 1, offset + Math.round(value * span)));
  }

  function mirrorXCoordinate(value) {
    return normalizedToDeviceCoordinate(
      value,
      KDEConnect.adbScreenWidth,
      embeddedMirrorInputCropX,
      embeddedMirrorInputCropWidth
    );
  }

  function mirrorYCoordinate(value) {
    return normalizedToDeviceCoordinate(
      value,
      KDEConnect.adbScreenHeight,
      embeddedMirrorInputCropY,
      embeddedMirrorInputCropHeight
    );
  }

  function embeddedMirrorInputWidth() {
    return embeddedMirrorInputCropWidth > 0
      ? Math.min(embeddedMirrorInputCropWidth, KDEConnect.adbScreenWidth)
      : KDEConnect.adbScreenWidth;
  }

  function embeddedMirrorInputHeight() {
    return embeddedMirrorInputCropHeight > 0
      ? Math.min(embeddedMirrorInputCropHeight, KDEConnect.adbScreenHeight)
      : KDEConnect.adbScreenHeight;
  }

  function handleMirrorTap(xNorm, yNorm) {
    if (KDEConnect.adbScreenWidth <= 0 || KDEConnect.adbScreenHeight <= 0)
      return;

    KDEConnect.runAdbTap(
      currentMirrorAdbSerial(),
      mirrorXCoordinate(xNorm),
      mirrorYCoordinate(yNorm)
    );
  }

  function handleMirrorSwipe(x1Norm, y1Norm, x2Norm, y2Norm, durationMs) {
    if (KDEConnect.adbScreenWidth <= 0 || KDEConnect.adbScreenHeight <= 0)
      return;

    KDEConnect.runAdbSwipe(
      currentMirrorAdbSerial(),
      mirrorXCoordinate(x1Norm),
      mirrorYCoordinate(y1Norm),
      mirrorXCoordinate(x2Norm),
      mirrorYCoordinate(y2Norm),
      durationMs
    );
  }

  function handleMirrorScroll(xNorm, yNorm, deltaX, deltaY) {
    if (KDEConnect.adbScreenWidth <= 0 || KDEConnect.adbScreenHeight <= 0)
      return;

    const absDeltaX = Math.abs(deltaX);
    const absDeltaY = Math.abs(deltaY);
    if (absDeltaX === 0 && absDeltaY === 0)
      return;

    const startX = mirrorXCoordinate(xNorm);
    const startY = mirrorYCoordinate(yNorm);
    const horizontalScroll = absDeltaX > absDeltaY;
    const magnitude = Math.max(0.65, Math.min(2.4, horizontalScroll ? absDeltaX : absDeltaY));

    if (horizontalScroll) {
      const travelX = Math.max(72, Math.round(embeddedMirrorInputWidth() * 0.075 * magnitude));
      const halfTravelX = Math.max(24, Math.round(travelX / 2));
      const swipeStartX = Math.max(0, Math.min(KDEConnect.adbScreenWidth - 1, startX + (deltaX > 0 ? halfTravelX : -halfTravelX)));
      const swipeEndX = Math.max(0, Math.min(KDEConnect.adbScreenWidth - 1, startX + (deltaX > 0 ? -halfTravelX : halfTravelX)));
      KDEConnect.runAdbSwipe(
        currentMirrorAdbSerial(),
        swipeStartX,
        startY,
        swipeEndX,
        startY,
        115
      );
      return;
    }

    const travelY = Math.max(110, Math.round(embeddedMirrorInputHeight() * 0.11 * magnitude));
    const halfTravelY = Math.max(32, Math.round(travelY / 2));
    const swipeStartY = Math.max(0, Math.min(KDEConnect.adbScreenHeight - 1, startY + (deltaY < 0 ? halfTravelY : -halfTravelY)));
    const swipeEndY = Math.max(0, Math.min(KDEConnect.adbScreenHeight - 1, startY + (deltaY < 0 ? -halfTravelY : halfTravelY)));
    KDEConnect.runAdbSwipe(
      currentMirrorAdbSerial(),
      startX,
      swipeStartY,
      startX,
      swipeEndY,
      125
    );
  }

  function sendAndroidNavKey(keyCode) {
    KDEConnect.runAdbKeyevent(currentMirrorAdbSerial(), keyCode);
  }

  function sendKeyboardText(text) {
    if (!embeddedMirrorInputActive())
      return;

    KDEConnect.runAdbText(currentMirrorAdbSerial(), text);
  }

  function sendKeyboardKey(keyCode) {
    if (!embeddedMirrorInputActive())
      return;

    KDEConnect.runAdbKeyevent(currentMirrorAdbSerial(), keyCode);
  }

  function sendAndroidHomeOrUnlock() {
    if (!embeddedMirrorInputActive())
      return;

    const serial = currentMirrorAdbSerial();
    KDEConnect.runAdbKeyevent(serial, 224); // WAKEUP
    KDEConnect.runAdbKeyevent(serial, 3); // HOME
  }

  function sendAndroidUnlockOnly() {
    if (!embeddedMirrorInputActive())
      return;

    const serial = currentMirrorAdbSerial();
    if (serial === "")
      return;

    const hasFreshState = KDEConnect.hasFreshAdbScreenState(serial);
    const shouldWake = !hasFreshState || !KDEConnect.adbScreenInteractive;
    const shouldUnlock = hasFreshState && KDEConnect.adbScreenLockState === "true";

    if (shouldWake)
      KDEConnect.runAdbKeyevent(serial, 224); // WAKEUP
    if (shouldUnlock)
      KDEConnect.runAdbKeyevent(serial, 82); // MENU / dismiss keyguard
  }

  function takeMirrorScreenshot() {
    if (!embeddedMirrorInputActive())
      return;

    KDEConnect.takeAdbScreenshot(currentMirrorAdbSerial());
  }

  function toggleMirrorScreenRecording() {
    if (KDEConnect.adbScreenRecordingActive) {
      KDEConnect.stopAdbScreenRecording();
      return;
    }

    if (!embeddedMirrorInputActive())
      return;

    KDEConnect.startAdbScreenRecording(currentMirrorAdbSerial());
  }

  function toggleKeepScreenOnWhilePanelOpen() {
    const serial = String(keepScreenOnSerial || currentMirrorAdbSerial() || "").trim();
    if (serial === "")
      return;

    if (keepScreenOnEnabled) {
      restoreKeepScreenOnState();
      return;
    }

    keepScreenOnSerial = serial;
    if (KDEConnect.hasFreshAdbScreenTimeout(serial)) {
      keepScreenOnPending = false;
      keepScreenOnEnabled = true;
      keepScreenOnOriginalTimeout = String(KDEConnect.adbScreenTimeoutValue || "").trim();
      KDEConnect.setAdbScreenTimeout(serial, String(keepScreenOnTimeoutMs));
      return;
    }

    keepScreenOnPending = true;
    KDEConnect.queryAdbScreenTimeout(serial);
  }

  function toggleMirrorScreenDim() {
    const serial = String(dimScreenSerial || currentMirrorAdbSerial() || "").trim();
    if (serial === "")
      return;

    if (dimScreenEnabled) {
      restoreDimScreenState();
      return;
    }

    dimScreenSerial = serial;
    if (KDEConnect.hasFreshAdbScreenBrightness(serial)) {
      dimScreenPending = false;
      dimScreenEnabled = true;
      dimScreenOriginalMode = String(KDEConnect.adbScreenBrightnessMode || "").trim();
      dimScreenOriginalBrightness = String(KDEConnect.adbScreenBrightnessValue || "").trim();
      KDEConnect.setAdbScreenBrightness(serial, String(dimScreenBrightnessValue));
      return;
    }

    dimScreenPending = true;
    KDEConnect.queryAdbScreenBrightness(serial);
  }

  function restoreKeepScreenOnState() {
    const serial = String(keepScreenOnSerial || "").trim();
    keepScreenOnPending = false;
    if (serial !== "" && keepScreenOnEnabled)
      KDEConnect.restoreAdbScreenTimeout(serial, keepScreenOnOriginalTimeout);

    keepScreenOnEnabled = false;
    keepScreenOnSerial = "";
    keepScreenOnOriginalTimeout = "";
  }

  function restoreDimScreenState() {
    const serial = String(dimScreenSerial || "").trim();
    dimScreenPending = false;
    if (serial !== "" && dimScreenEnabled)
      KDEConnect.restoreAdbScreenBrightness(serial, dimScreenOriginalMode, dimScreenOriginalBrightness);

    dimScreenEnabled = false;
    dimScreenSerial = "";
    dimScreenOriginalMode = "";
    dimScreenOriginalBrightness = "";
  }

  component NavActionButton: Rectangle {
    id: navButton

    property string iconName: ""
    property string label: ""
    property string tooltipText: ""
    property bool actionEnabled: true
    property bool active: false
    property bool circular: false
    property real sizeScale: root.navButtonScaleFactor
    property real circularSize: 46 * Style.uiScaleRatio * sizeScale
    signal pressed

    implicitWidth: circular
      ? circularSize
      : navButtonContent.implicitWidth + (16 * Style.uiScaleRatio * sizeScale)
    implicitHeight: circular
      ? circularSize
      : 36 * Style.uiScaleRatio * sizeScale
    radius: circular ? width / 2 : 13 * Style.uiScaleRatio * sizeScale
    scale: navButton.circular
      ? (navMouse.pressed
          ? 0.94
          : (navMouse.containsMouse ? 1.08 : 1.0))
      : 1.0
    color: circular
      ? (navButton.active
          ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.18)
          : (navMouse.containsMouse
              ? Color.mHover
              : Color.mSurfaceVariant))
      : (navButton.active
          ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.16)
          : (navMouse.containsMouse
              ? Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.96)
              : Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.82)))
    border.width: Style.borderS
    border.color: circular
      ? (navButton.active
          ? Color.mPrimary
          : (navMouse.containsMouse
              ? Color.mOutline
              : Color.mOutline))
      : (navButton.active
          ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.52)
          : (navMouse.containsMouse
              ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.32)
              : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.22)))
    opacity: actionEnabled ? 1.0 : 0.55

    Behavior on color {
      ColorAnimation { duration: 120 }
    }

    Behavior on scale {
      NumberAnimation {
        duration: 130
        easing.type: Easing.OutCubic
      }
    }

    MouseArea {
      id: navMouse
      anchors.fill: parent
      enabled: navButton.actionEnabled
      hoverEnabled: navButton.actionEnabled
      cursorShape: navButton.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: {
        if (navButton.tooltipText !== "")
          TooltipService.show(navButton, navButton.tooltipText, "top");
      }
      onExited: {
        if (navButton.tooltipText !== "")
          TooltipService.hide(navButton);
      }
      onClicked: navButton.pressed()
    }

    RowLayout {
      id: navButtonContent
      anchors.centerIn: parent
      spacing: Style.marginXS * navButton.sizeScale

      NIcon {
        icon: navButton.iconName
        pointSize: (navButton.circular ? Style.fontSizeS : Style.fontSizeXS) * navButton.sizeScale
        color: navButton.actionEnabled
          ? (navButton.active
              ? Color.mPrimary
              : (navButton.circular
                  ? (navMouse.containsMouse ? Color.mOnHover : Color.mPrimary)
                  : Color.mOnSurface))
          : Color.mOnSurfaceVariant
      }

      NText {
        visible: !navButton.circular
        text: navButton.label
        pointSize: Style.fontSizeXXS * navButton.sizeScale
        font.weight: Style.fontWeightMedium
        color: navButton.actionEnabled ? Color.mOnSurface : Color.mOnSurfaceVariant
      }
    }
  }

  component PanelActionIconButton: NIconButton {
    id: panelActionIconButton

    property bool active: false

    baseSize: Style.baseWidgetSize * 0.8
    colorBg: active ? root.shellButtonActiveBgColor : root.shellButtonBgColor
    colorFg: active ? root.shellButtonActiveFgColor : root.shellButtonFgColor
    colorBgHover: active ? root.shellButtonActiveBgColor : root.shellButtonBgHoverColor
    colorFgHover: active ? root.shellButtonActiveFgColor : root.shellButtonFgHoverColor
    colorBorder: active ? root.shellButtonActiveBorderColor : root.shellButtonBorderColor
    colorBorderHover: active ? root.shellButtonActiveBorderColor : root.shellButtonBorderHoverColor
  }

  component PanelActionIconButtonAnimated: NIconButton {
    id: panelActionIconButtonAnimated

    property bool active: false
    property bool animatePulse: false

    baseSize: Style.baseWidgetSize * 0.8
    colorBg: active ? root.shellButtonActiveBgColor : root.shellButtonBgColor
    colorFg: active ? root.shellButtonActiveFgColor : root.shellButtonFgColor
    colorBgHover: active ? root.shellButtonActiveBgColor : root.shellButtonBgHoverColor
    colorFgHover: active ? root.shellButtonActiveFgColor : root.shellButtonFgHoverColor
    colorBorder: active ? root.shellButtonActiveBorderColor : root.shellButtonBorderColor
    colorBorderHover: active ? root.shellButtonActiveBorderColor : root.shellButtonBorderHoverColor

    SequentialAnimation on scale {
      loops: Animation.Infinite
      running: animatePulse && !active
      PauseAnimation { duration: 1000 }
      NumberAnimation {
        from: 0.92; to: 1.08
        duration: 350
        easing.type: Easing.InOutQuad
      }
      NumberAnimation {
        from: 1.08; to: 0.92
        duration: 350
        easing.type: Easing.InOutQuad
      }
    }

    SequentialAnimation on opacity {
      loops: Animation.Infinite
      running: animatePulse && !active
      PauseAnimation { duration: 1000 }
      NumberAnimation {
        from: 0.75; to: 1.0
        duration: 350
        easing.type: Easing.InOutQuad
      }
      NumberAnimation {
        from: 1.0; to: 0.75
        duration: 350
        easing.type: Easing.InOutQuad
      }
    }
  }

  component UtilityActionCard: NBox {
    id: utilityCard

    default property alias contentData: utilityCardContent.data

    Layout.fillWidth: true
    implicitHeight: utilityCardContent.implicitHeight + Style.margin2M

    GridLayout {
      id: utilityCardContent
      anchors.fill: parent
      anchors.margins: Style.marginM
      rows: 1
      flow: GridLayout.LeftToRight
      columnSpacing: Style.marginM
      rowSpacing: 0
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: deviceData

      function getBatteryIcon(percentage, isCharging) {
        if (percentage < 0) return "battery-exclamation"
        if (isCharging) return "battery-charging-2"
        if (percentage < 5) return "battery"
        if (percentage < 25) return "battery-1"
        if (percentage < 50) return "battery-2"
        if (percentage < 75) return "battery-3"
        return "battery-4"
      }

      function getCellularTypeIcon(type) {
        const normalizedType = String(type || "").trim().toUpperCase();
        if (normalizedType === "")
          return "wave-square";

        if (normalizedType.indexOf("5G") !== -1 || normalizedType.indexOf("NR") !== -1)
          return "signal-5g";

        if (normalizedType.indexOf("LTE") !== -1)
          return "signal-lte";

        if (normalizedType.indexOf("4G") !== -1)
          return "signal-4g";

        if (normalizedType.indexOf("HSPA") !== -1 || normalizedType.indexOf("H+") !== -1 || normalizedType === "H")
          return "signal-h";

        if (normalizedType.indexOf("UMTS") !== -1
            || normalizedType.indexOf("WCDMA") !== -1
            || normalizedType.indexOf("EVDO") !== -1
            || normalizedType.indexOf("CDMA2000") !== -1
            || normalizedType === "CDMA"
            || normalizedType.indexOf("3G") !== -1) {
          return "signal-3g";
        }

        if (normalizedType.indexOf("EDGE") !== -1 || normalizedType === "E")
          return "signal-e";

        if (normalizedType.indexOf("GPRS") !== -1 || normalizedType === "G")
          return "signal-g";

        if (normalizedType.indexOf("GSM") !== -1
            || normalizedType.indexOf("IDEN") !== -1
            || normalizedType.indexOf("2G") !== -1) {
          return "signal-2g";
        }

        return "wave-square";
      }

      function getCellularStrengthIcon(strength) {
        switch (strength) {
          case 0:
            return "antenna-bars-1"
          case 1:
            return "antenna-bars-2"
          case 2:
            return "antenna-bars-3"
          case 3:
            return "antenna-bars-4"
          case 4:
            return "antenna-bars-5"
          default:
            return "antenna-bars-off"
        }
      }

      function getSignalStrengthText(strength) {
        switch (strength) {
          case 0:
            return pluginApi?.tr("panel.signal.very-weak")
          case 1:
            return pluginApi?.tr("panel.signal.weak")
          case 2:
            return pluginApi?.tr("panel.signal.fair")
          case 3:
            return pluginApi?.tr("panel.signal.good")
          case 4:
            return pluginApi?.tr("panel.signal.excellent")
          default:
            return pluginApi?.tr("panel.unknown")
        }
      }

      anchors {
        fill: parent
        margins: Style.marginM
      }
      spacing: Style.marginM

      Loader {
        Layout.fillWidth: true
        Layout.fillHeight: !root.mainDeviceSetupComplete()
        Layout.alignment: Qt.AlignTop
        active: true
        sourceComponent:  (KDEConnect.busctlCmd === null || KDEConnect.busctlCmd === "")       ? busctlNotFoundCard               :
                          (!KDEConnect.daemonAvailable)                                        ? kdeConnectDaemonNotRunningCard   :
                          (deviceSwitcherOpen)                                                 ? deviceSwitcherCard               :
                          (root.mainDeviceSetupComplete())                                     ? deviceConnectedCard              :
                          (root.mainDevicePairingInProgress())                                 ? noDevicePairedCard               :
                          (KDEConnect.mainDevice !== null || KDEConnect.devices.length > 0)    ? setupRequiredCard                :
                          (KDEConnect.devices.length === 0)                                    ? noDevicesAvailableCard           :
                          null
      }

      Component {
        id: deviceConnectedCard

        Rectangle {
          Layout.fillWidth: true
          color: "transparent"
          radius: Style.radiusL
          implicitHeight: contentLayout.implicitHeight + (Style.marginS * 2)

          ColumnLayout {
            id: contentLayout
            anchors {
              fill: parent
              margins: Style.marginS
            }
            spacing: Style.marginM

            NFilePicker {
              id: shareFilePicker
              title: pluginApi?.tr("panel.send-file-picker")
              selectionMode: "files"
              initialPath: Quickshell.env("HOME")
              nameFilters: ["*"]
              onAccepted: paths => {
                if (paths.length > 0) {
                  for (const path of paths) {
                    KDEConnect.shareFile(KDEConnect.mainDevice.id, path)
                  }
                }
              }
            }

            Loader {
              Layout.fillWidth: true
              Layout.fillHeight: true
              active: KDEConnect.mainDevice !== null
              sourceComponent: deviceStatsWithPhone
            }

          }

          Component {
            id: deviceStatsWithPhone

            ColumnLayout {
              spacing: Style.marginXS
              Layout.fillWidth: true

              Component.onCompleted: {
                root.scheduleEmbeddedMirrorAutoStart();
              }

              Rectangle {
                id: remoteStageCard
                Layout.fillWidth: true
                implicitHeight: remoteStageContent.implicitHeight + (Style.marginS * 2)
                radius: Style.radiusL
                color: "transparent"
                border.width: 0
                border.color: "transparent"

                ColumnLayout {
                  id: remoteStageContent
                  anchors.fill: parent
                  anchors.margins: Style.marginS
                  spacing: Style.marginXS

                  NBox {
                    id: headerBox
                    Layout.fillWidth: true
                    implicitHeight: headerContent.implicitHeight + Style.margin2M

                    ColumnLayout {
                      id: headerContent
                      anchors.fill: parent
                      anchors.margins: Style.marginM
                      spacing: Style.marginM

                      RowLayout {
                        Layout.fillWidth: true

                        Rectangle {
                          readonly property var brandBadge: root.deviceBrandBadge(KDEConnect.mainDevice?.name || "")
                          readonly property bool brandBadgeFrameless: brandBadge.source !== ""
                          readonly property bool resizeControlVisible: brandBadgeMouse.containsMouse
                          readonly property string resizeTooltipText: root.trSafe("panel.phone-size.tooltip", "Phone size: ")
                            + root.phoneSizeLabel + " (" + root.phoneSizePercent + "%)"
                          Layout.alignment: Qt.AlignVCenter
                          Layout.preferredWidth: 34 * Style.uiScaleRatio
                          Layout.preferredHeight: 34 * Style.uiScaleRatio
                          radius: width / 2
                          color: resizeControlVisible
                            ? "transparent"
                            : (brandBadgeFrameless ? "transparent" : root.shellIconChipColor)
                          border.width: resizeControlVisible || brandBadgeFrameless ? 0 : Style.borderS
                          border.color: resizeControlVisible || brandBadgeFrameless ? "transparent" : root.shellIconChipBorderColor

                          Image {
                            anchors.centerIn: parent
                            visible: parent.brandBadge.source !== "" && !parent.resizeControlVisible
                            source: parent.brandBadge.source
                            width: parent.brandBadgeFrameless ? parent.width : parent.width * 0.72
                            height: parent.brandBadgeFrameless ? parent.height : parent.height * 0.72
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                          }

                          NIcon {
                            anchors.centerIn: parent
                            visible: parent.brandBadge.source === "" && !parent.resizeControlVisible
                            icon: parent.brandBadge.fallbackIcon
                            pointSize: Style.fontSizeS
                            color: root.shellPrimaryTextColor
                          }

                          Rectangle {
                            anchors.centerIn: parent
                            visible: parent.resizeControlVisible
                            width: parent.width
                            height: parent.height
                            radius: width / 2
                            color: root.shellButtonBgHoverColor
                            border.width: Style.borderS
                            border.color: root.shellButtonBorderHoverColor

                            NIcon {
                              anchors.centerIn: parent
                              icon: "resize"
                              pointSize: Style.fontSizeS
                              color: root.shellButtonFgHoverColor
                            }
                          }

                          MouseArea {
                            id: brandBadgeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                              TooltipService.show(parent, parent.resizeTooltipText, "top");
                            }
                            onExited: {
                              TooltipService.hide(parent);
                            }
                            onClicked: {
                              TooltipService.hide(parent);
                              root.cyclePhoneSizePreset();
                            }
                          }
                        }

                        NText {
                          text: KDEConnect.mainDevice.name
                          pointSize: Style.fontSizeL * 1.55
                          font.weight: Style.fontWeightBold
                          color: root.shellPrimaryTextColor
                          Layout.fillWidth: true
                          elide: Text.ElideRight
                        }

                        RowLayout {
                          Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                          spacing: Style.marginXS

	                          PanelActionIconButton {
	                            readonly property bool multipleDevices: KDEConnect.devices.length > 1
	                            icon: "swipe"
                            tooltipText: multipleDevices ? pluginApi?.tr("panel.other-devices") : ""
                            onClicked: {
                              deviceSwitcherOpen = !deviceSwitcherOpen
                            }
                            enabled: KDEConnect.daemonAvailable && multipleDevices
	                            opacity: multipleDevices ? 1.0 : 0.0
	                          }

	                          PanelActionIconButton {
	                            icon: "info"
	                            tooltipText: root.trSafe("panel.diagnostics.tooltip", "Open diagnostics")
	                            onClicked: diagnosticsPopup.open()
	                          }

	                          PanelActionIconButton {
	                            icon: "maximize"
                            tooltipText: root.trSafe("panel.detached-mirror.tooltip", "Open in window")
                            onClicked: {
                              root.ensureDetachedMirrorSession();
                              pluginApi?.closePanel(screen, root);
                            }
                          }

                          PanelActionIconButton {
                            visible: root.embeddedMirrorModeEnabled()
                            icon: root.embeddedMirrorAudioEnabled ? "volume" : "volume-off"
                            tooltipText: root.embeddedMirrorAudioEnabled
                              ? root.trSafe("panel.embedded-mirror.audio-disable", "Disable embedded audio")
                              : root.trSafe("panel.embedded-mirror.audio-enable", "Enable embedded audio")
                            enabled: !KDEConnect.scrcpyLaunching
                            onClicked: root.toggleEmbeddedMirrorAudioMode()
                          }

                          PanelActionIconButtonAnimated {
                            icon: "wifi"
                            animatePulse: !KDEConnect.adbHasUsbTransport && root.connectedWirelessAdbSerial() === ""
                            tooltipText: KDEConnect.wirelessAdbBusy
                              ? root.trSafe("panel.wireless-adb.busy-tooltip", "Wireless ADB command is running")
                              : root.trSafe("panel.wireless-adb.tooltip", "Open Wireless ADB tools")
                            onClicked: root.openWirelessAdbDialog()
                          }

                          PanelActionIconButton {
                            icon: "device-mobile-search"
                            tooltipText: pluginApi?.tr("panel.browse-device")
                            onClicked: KDEConnect.browseFiles(KDEConnect.mainDevice.id)
                          }

                          PanelActionIconButton {
                            icon: "device-mobile-share"
                            tooltipText: pluginApi?.tr("panel.send-file")
                            onClicked: shareFilePicker.open()
                          }

                          PanelActionIconButton {
                            icon: "radar"
                            tooltipText: pluginApi?.tr("panel.find-device")
                            onClicked: KDEConnect.triggerFindMyPhone(KDEConnect.mainDevice.id)
                          }
                        }
                      }
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Style.marginS

                    ColumnLayout {
                      id: phoneColumn
                      Layout.alignment: Qt.AlignTop
                      spacing: Style.marginXS

                      Item {
                        id: phonePreviewContainer
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: root.phoneBaseWidth * root.phoneSizeFactor
                        Layout.preferredHeight: root.phoneBaseHeight * root.phoneSizeFactor
                        implicitWidth: Layout.preferredWidth
                        implicitHeight: Layout.preferredHeight

                        Behavior on Layout.preferredWidth {
                          enabled: root.phoneSizeAnimationEnabled
                          NumberAnimation {
                            duration: Style.animationNormal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.panelResizeBezierCurve
                          }
                        }

                        Behavior on Layout.preferredHeight {
                          enabled: root.phoneSizeAnimationEnabled
                          NumberAnimation {
                            duration: Style.animationNormal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.panelResizeBezierCurve
                          }
                        }

                        PhoneDisplay {
                          id: phonePreview
                          anchors.fill: parent
                          mirrorFeedEnabled: KDEConnect.scrcpyRunning
                          showHomeIndicator: !KDEConnect.scrcpyRunning
                          scrcpyStartedAtMs: KDEConnect.scrcpyLaunchStartedAtMs
                          mirrorDeviceIdMatch: root.embeddedVideoDevice
                          mirrorDeviceDescriptionMatch: "scrcpy-panel"
                          mirrorContentWidth: KDEConnect.adbScreenWidth
                          mirrorContentHeight: KDEConnect.adbScreenHeight
                          interactiveScreen: root.embeddedMirrorTouchActive()
                          showStatusOverlay: root.embeddedMirrorPhoneOverlayVisible()
                          statusTitle: root.embeddedMirrorPhoneStatusTitle(phonePreview)
                          statusSubtitle: root.embeddedMirrorPhoneStatusSubtitle(phonePreview)
                          busy: KDEConnect.scrcpyLaunching
                            || (KDEConnect.scrcpyRunning
                                && (!phonePreview.mirrorFeedAvailable
                                    || KDEConnect.adbDisplayInfoSerial !== ""))

                          Component.onCompleted: {
                            root.activePhonePreview = phonePreview;
                            root.scheduleEmbeddedMirrorAutoStart();
                          }

                          Component.onDestruction: {
                            if (root.activePhonePreview === phonePreview)
                              root.activePhonePreview = null;
                          }

                          onClicked: root.handlePhoneClick(phonePreview)
                          onTapRequested: (x, y) => root.handleMirrorTap(x, y)
                          onSwipeRequested: (x1, y1, x2, y2, durationMs) => root.handleMirrorSwipe(x1, y1, x2, y2, durationMs)
                          onScrollRequested: (x, y, deltaX, deltaY) => root.handleMirrorScroll(x, y, deltaX, deltaY)
                          onTextRequested: text => root.sendKeyboardText(text)
                          onKeyRequested: keyCode => root.sendKeyboardKey(keyCode)
                          onHomeRequested: root.sendAndroidHomeOrUnlock()
                          onRecentsRequested: root.sendAndroidNavKey(187)
                        }

                      }

                      RowLayout {
                        id: navRow
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: phonePreviewContainer.width
                        Layout.fillWidth: false
                        spacing: Style.marginS
                        visible: root.embeddedMirrorNavRowVisible()

                        Item { Layout.fillWidth: true }

                        NavActionButton {
                          circular: true
                          iconName: "arrow-back"
                          label: root.trSafe("panel.embedded-mirror.nav-back", "Back")
                          tooltipText: root.trSafe("panel.embedded-mirror.nav-back-tooltip", "Back, mouse right click")
                          actionEnabled: root.embeddedMirrorInputActive()
                          onPressed: root.sendAndroidNavKey(4)
                        }

                        Item { Layout.fillWidth: true }

                        NavActionButton {
                          circular: true
                          iconName: "home"
                          label: root.trSafe("panel.embedded-mirror.nav-home", "Home")
                          tooltipText: root.trSafe("panel.embedded-mirror.nav-home-tooltip", "Home, Home key")
                          actionEnabled: root.embeddedMirrorInputActive()
                          onPressed: root.sendAndroidNavKey(3)
                        }

                        Item { Layout.fillWidth: true }

                        NavActionButton {
                          circular: true
                          iconName: "layout-grid"
                          label: root.trSafe("panel.embedded-mirror.nav-recents", "Recents")
                          tooltipText: root.trSafe("panel.embedded-mirror.nav-recents-tooltip", "Task picker, mouse wheel press")
                          actionEnabled: root.embeddedMirrorInputActive()
                          onPressed: root.sendAndroidNavKey(187)
                        }

                        Item { Layout.fillWidth: true }
                      }

                    }

                    ColumnLayout {
                      id: rightInfoColumn
                      Layout.alignment: Qt.AlignTop
                      Layout.fillWidth: true
                      Layout.topMargin: 12 * Style.uiScaleRatio
                      spacing: Style.marginL * 1.1

                      ColumnLayout {
                        id: deviceSummaryColumn
                        Layout.fillWidth: true
                        spacing: Style.marginL * 1.1

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.marginS

                          NIcon {
                            icon: deviceData.getBatteryIcon(root.effectiveBatteryValue(KDEConnect.mainDevice), root.effectiveChargingValue(KDEConnect.mainDevice))
                            pointSize: Style.fontSizeXL * 1.2075
                            color: root.shellPrimaryIconColor
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 38 * Style.uiScaleRatio
                          }

                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginXXS

                            NText {
                              text: pluginApi?.tr("panel.card.battery")
                              pointSize: Style.fontSizeS * 1.15
                              color: root.shellSecondaryTextColor
                            }

                            NText {
                              text: root.effectiveBatteryValue(KDEConnect.mainDevice) < 0
                                ? pluginApi?.tr("panel.unknown")
                                : (root.effectiveBatteryValue(KDEConnect.mainDevice) + "%")
                              pointSize: Style.fontSizeL * 1.288
                              font.weight: Style.fontWeightBold
                              color: root.shellPrimaryTextColor
                            }
                          }
                        }

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.marginS

                          NIcon {
                            icon: deviceData.getCellularTypeIcon(root.effectiveNetworkType(KDEConnect.mainDevice))
                            pointSize: Style.fontSizeXL * 1.2075
                            color: root.shellPrimaryIconColor
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 38 * Style.uiScaleRatio
                          }

                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginXXS

                            NText {
                              text: pluginApi?.tr("panel.card.network")
                              pointSize: Style.fontSizeS * 1.15
                              color: root.shellSecondaryTextColor
                            }

                            NText {
                              text: root.effectiveNetworkType(KDEConnect.mainDevice) || pluginApi?.tr("panel.unknown")
                              pointSize: Style.fontSizeL * 1.288
                              font.weight: Style.fontWeightBold
                              color: root.shellPrimaryTextColor
                            }
                          }
                        }

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.marginS

                          NIcon {
                            icon: deviceData.getCellularStrengthIcon(root.effectiveSignalStrength(KDEConnect.mainDevice))
                            pointSize: Style.fontSizeXL * 1.2075
                            color: root.shellPrimaryIconColor
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 38 * Style.uiScaleRatio
                          }

                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginXXS

                            NText {
                              text: root.trSafe("panel.card.signal", "Signal")
                              pointSize: Style.fontSizeS * 1.15
                              color: root.shellSecondaryTextColor
                            }

                            NText {
                              text: deviceData.getSignalStrengthText(root.effectiveSignalStrength(KDEConnect.mainDevice))
                                || pluginApi?.tr("panel.unknown")
                              pointSize: Style.fontSizeL * 1.288
                              font.weight: Style.fontWeightBold
                              color: root.shellPrimaryTextColor
                            }
                          }
                        }

                        UtilityActionCard {
                          id: mirrorUtilityCard
                          visible: root.embeddedMirrorModeEnabled()

                          PanelActionIconButton {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "camera"
                            tooltipText: root.trSafe("panel.embedded-mirror.screenshot", "Take Screenshot")
                            enabled: root.embeddedMirrorInputActive() && !KDEConnect.adbScreenshotBusy
                            onClicked: root.takeMirrorScreenshot()
                          }

                          PanelActionIconButton {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "video"
                            tooltipText: KDEConnect.adbScreenRecordingActive
                              ? root.trSafe("panel.embedded-mirror.record-stop", "Stop Recording")
                              : root.trSafe("panel.embedded-mirror.record-start", "Start Recording")
                            enabled: KDEConnect.adbScreenRecordingActive
                              || (root.embeddedMirrorInputActive() && !KDEConnect.adbScreenRecordingBusy)
                            active: KDEConnect.adbScreenRecordingActive
                            onClicked: root.toggleMirrorScreenRecording()
                          }

                          PanelActionIconButton {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "moon"
                            tooltipText: root.trSafe("panel.embedded-mirror.keep-screen-on", "Keep Screen Awake")
                            enabled: (root.embeddedMirrorInputActive() && !root.keepScreenOnPending)
                              || root.keepScreenOnEnabled
                            active: root.keepScreenOnEnabled || root.keepScreenOnPending
                            onClicked: root.toggleKeepScreenOnWhilePanelOpen()
                          }

                          PanelActionIconButton {
                            Layout.alignment: Qt.AlignHCenter
                            icon: root.dimScreenEnabled ? "sun-dim" : "sun"
                            tooltipText: root.dimScreenEnabled
                              ? root.trSafe("panel.embedded-mirror.screen-restore", "Restore Screen Brightness")
                              : root.trSafe("panel.embedded-mirror.screen-dim", "Set Screen to Minimum Brightness")
                            enabled: root.embeddedMirrorInputActive() || root.dimScreenEnabled
                            active: root.dimScreenEnabled || root.dimScreenPending
                            onClicked: root.toggleMirrorScreenDim()
                          }
                        }

                      }

                      Rectangle {
                        id: embeddedMirrorStatusCard
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: Math.min(
                          implicitHeight,
                          Math.max(
                            root.phoneSizeValue(104, 118, 132) * Style.uiScaleRatio,
                            phonePreviewContainer.height
                              - rightInfoColumn.Layout.topMargin
                              - deviceSummaryColumn.implicitHeight
                              - (mirrorUtilityCard.visible
                                  ? (mirrorUtilityCard.implicitHeight + rightInfoColumn.spacing)
                                  : 0)
                              - rightInfoColumn.spacing
                          )
                        )
                        Layout.maximumHeight: Layout.preferredHeight
                        Layout.topMargin: root.embeddedMirrorDrawerStatusVisible(phonePreview) ? Style.marginS : 0
                        visible: root.embeddedMirrorDrawerStatusVisible(phonePreview)
                        implicitHeight: Math.max(
                          drawerStatusContent.implicitHeight + (Style.marginM * 1.8),
                          root.phoneSizeValue(104, 118, 132) * Style.uiScaleRatio
                        )
                        radius: Style.radiusL
                        color: root.shellCardColor
                        border.width: Style.borderS
                        border.color: root.shellCardBorderColor
                        clip: true

                        ColumnLayout {
                          id: drawerStatusContent
                          anchors.fill: parent
                          anchors.margins: Style.marginM
                          spacing: Style.marginXS

                          NText {
                            Layout.fillWidth: true
                            text: root.embeddedMirrorDrawerStatusTitle(phonePreview)
                            pointSize: Style.fontSizeS * root.phoneSizeValue(1.02, 1.1, 1.1)
                            font.weight: Style.fontWeightBold
                            color: root.shellPrimaryTextColor
                            visible: text !== ""
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                          }

                          NText {
                            Layout.fillWidth: true
                            text: root.embeddedMirrorDrawerStatusSubtitle(phonePreview)
                            pointSize: Style.fontSizeXS * root.phoneSizeValue(1.0, 1.06, 1.06)
                            color: root.shellSecondaryTextColor
                            visible: text !== ""
                            wrapMode: Text.WordWrap
                          }

                          Rectangle {
                            Layout.fillWidth: true
                            visible: root.setupRequiredLoopbackCommandVisible()
                            color: root.shellNestedCardColor
                            radius: Style.radiusM
                            border.width: Style.borderS
                            border.color: root.shellNestedCardBorderColor
                            implicitHeight: drawerLoopbackCommandColumn.implicitHeight + (Style.marginM * 1.2)

                            ColumnLayout {
                              id: drawerLoopbackCommandColumn
                              anchors.fill: parent
                              anchors.margins: Style.marginM * 0.9
                              spacing: Style.marginXS

                              RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginS

                                NIcon {
                                  icon: "copy"
                                  pointSize: Style.fontSizeM
                                  color: root.shellAccentIconColor
                                }

                                NText {
                                  Layout.fillWidth: true
                                  text: root.trSafe("panel.setup-required.command-label", "Click to copy the loopback setup command")
                                  pointSize: Style.fontSizeS
                                  color: root.shellAccentTextColor
                                  wrapMode: Text.WordWrap
                                }
                              }

                              NText {
                                Layout.fillWidth: true
                                text: root.embeddedMirrorLoopbackSetupCommand
                                pointSize: Style.fontSizeXS
                                color: root.shellPrimaryTextColor
                                wrapMode: Text.WrapAnywhere
                                font.family: "monospace"
                              }
                            }

                            MouseArea {
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.copyTextToClipboard(
                                  root.embeddedMirrorLoopbackSetupCommand,
                                  root.trSafe("panel.setup-required.command-copied", "Loopback setup command copied.")
                                );
                              }
                            }
                          }

                          Item {
                            Layout.fillHeight: true
                            visible: true
                          }
                        }
                      }

                      Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.embeddedMirrorDrawerStatusVisible(phonePreview)
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      Component {
        id: noDevicePairedCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumHeight: implicitHeight
          color: root.shellStageColor
          radius: Style.radiusL
          implicitHeight: noDevicePairedContent.implicitHeight + (Style.marginL * 2.4)

          ColumnLayout {
            id: noDevicePairedContent
            anchors {
              fill: parent
              margins: Style.marginL * 1.2
            }
            spacing: Style.marginL * 1.1

            RowLayout {
              Layout.fillWidth: true
              NText {
                text: KDEConnect.mainDevice?.name || root.trSafe("panel.unknown", "Unknown")
                pointSize: Style.fontSizeXXL
                font.weight: Style.fontWeightBold
                color: root.shellPrimaryTextColor
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: pairStateColumn.implicitHeight + (Style.marginL * 1.8)
              color: root.shellCardColor
              radius: Style.radiusL
              border.width: Style.borderS
              border.color: root.shellCardBorderColor

              ColumnLayout {
                id: pairStateColumn
                anchors.fill: parent
                anchors.margins: Style.marginL * 1.1
                spacing: Style.marginM

                Item {
                  Layout.fillWidth: true
                  implicitHeight: pairHeader.implicitHeight

                  RowLayout {
                    id: pairHeader
                    anchors.centerIn: parent
                    spacing: Style.marginM

                    Rectangle {
                      width: 48 * Style.uiScaleRatio
                      height: width
                      radius: width / 2
                      color: KDEConnect.mainDevice.pairRequested ? root.shellAccentCardColor : root.shellIconChipColor
                      border.width: Style.borderS
                      border.color: KDEConnect.mainDevice.pairRequested ? root.shellAccentCardBorderColor : root.shellIconChipBorderColor

                      NIcon {
                        anchors.centerIn: parent
                        icon: KDEConnect.mainDevice.pairRequested ? "key" : "device-mobile"
                        pointSize: Style.fontSizeXL
                        color: KDEConnect.mainDevice.pairRequested ? root.shellAccentIconColor : root.shellIconChipFgColor
                      }
                    }

                    ColumnLayout {
                      spacing: Style.marginXXS

                      NText {
                        text: KDEConnect.mainDevice.pairRequested
                          ? root.trSafe("panel.pair-requested-title", "Pairing Request Sent")
                          : root.trSafe("panel.pair-needed-title", "Pairing Needed")
                        pointSize: Style.fontSizeL * 1.06
                        font.weight: Style.fontWeightBold
                        color: root.shellPrimaryTextColor
                      }

                      NText {
                        text: KDEConnect.mainDevice.pairRequested
                          ? root.trSafe("panel.pair-requested-subtitle", "Approve the request on the phone to restore controls.")
                          : root.trSafe("panel.pair-needed-subtitle", "KDE Connect reported this device as temporarily unpaired.")
                        pointSize: Style.fontSizeS * 1.02
                        color: root.shellSecondaryTextColor
                      }
                    }
                  }
                }

                NText {
                  Layout.fillWidth: true
                  text: KDEConnect.mainDevice.pairRequested
                    ? root.trSafe("panel.pair-requested", "Confirm the pairing request on the phone. The mirror and device actions will come back automatically after approval.")
                    : root.trSafe("panel.pair-description", "This device is temporarily reported as unpaired. Retry pairing here if KDE Connect did not recover on its own after reconnecting.")
                  color: root.shellSecondaryTextColor
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }

                NButton {
                  text: root.trSafe("panel.pair", "Pair with Device")
                  Layout.alignment: Qt.AlignHCenter
                  Layout.minimumWidth: 220 * Style.uiScaleRatio
                  enabled: !KDEConnect.mainDevice.pairRequested
                  icon: "key"
                  onClicked: {
                    KDEConnect.requestPairing(KDEConnect.mainDevice.id)
                    KDEConnect.mainDevice.pairRequested = true
                    KDEConnect.refreshDevices()
                  }
                }

                Rectangle {
                  Layout.alignment: Qt.AlignHCenter
                  visible: KDEConnect.mainDevice.pairRequested && String(KDEConnect.mainDevice.verificationKey || "").trim() !== ""
                  color: root.shellAccentCardColor
                  radius: Style.radiusM
                  border.width: Style.borderS
                  border.color: root.shellAccentCardBorderColor
                  implicitWidth: verificationRow.implicitWidth + (Style.marginM * 1.4)
                  implicitHeight: verificationRow.implicitHeight + (Style.marginS * 1.4)

                  RowLayout {
                    id: verificationRow
                    anchors.centerIn: parent
                    spacing: Style.marginS

                    NIcon {
                      icon: "key"
                      pointSize: Style.fontSizeL
                      color: root.shellAccentIconColor
                    }

                    NText {
                      text: KDEConnect.mainDevice.verificationKey
                      pointSize: Style.fontSizeL
                      font.weight: Style.fontWeightBold
                      color: root.shellAccentTextColor
                    }
                  }
                }

                NBusyIndicator {
                  Layout.alignment: Qt.AlignHCenter
                  visible: KDEConnect.mainDevice.pairRequested
                  size: Style.baseWidgetSize * 0.5
                  running: KDEConnect.mainDevice.pairRequested
                }

                NText {
                  Layout.fillWidth: true
                  visible: KDEConnect.mainDevice.pairRequested
                  text: root.trSafe("panel.pair-waiting", "Waiting for the phone to accept the pairing request.")
                  pointSize: Style.fontSizeS
                  color: root.shellSecondaryTextColor
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }
          }
        }
      }

      Component {
        id: setupRequiredCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumHeight: implicitHeight
          color: root.shellStageColor
          radius: Style.radiusL
          implicitHeight: setupRequiredContent.implicitHeight + (Style.marginL * 2.4)

          ColumnLayout {
            id: setupRequiredContent
            anchors {
              fill: parent
              margins: Style.marginL * 1.2
            }
            spacing: Style.marginL * 1.1

            NText {
              text: root.trSafe("panel.setup-required.phone-name", "Android Phone")
              pointSize: Style.fontSizeXXL
              font.weight: Style.fontWeightBold
              color: root.shellPrimaryTextColor
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: setupRequiredColumn.implicitHeight + (Style.marginL * 1.8)
              color: root.shellCardColor
              radius: Style.radiusL
              border.width: Style.borderS
              border.color: root.shellCardBorderColor

              ColumnLayout {
                id: setupRequiredColumn
                anchors.fill: parent
                anchors.margins: Style.marginL * 1.1
                spacing: Style.marginM

                Item {
                  Layout.fillWidth: true
                  implicitHeight: setupRequiredHeader.implicitHeight

                  RowLayout {
                    id: setupRequiredHeader
                    anchors.centerIn: parent
                    spacing: Style.marginM

                    Rectangle {
                      width: 48 * Style.uiScaleRatio
                      height: width
                      radius: width / 2
                      color: root.shellIconChipColor
                      border.width: Style.borderS
                      border.color: root.shellIconChipBorderColor

                      NIcon {
                        anchors.centerIn: parent
                        icon: "device-mobile-off"
                        pointSize: Style.fontSizeXL
                        color: root.shellIconChipFgColor
                      }
                    }

                    ColumnLayout {
                      spacing: Style.marginXXS

                      NText {
                        text: root.trSafe("panel.setup-required.title", "Finish Setup to Connect")
                        pointSize: Style.fontSizeL * 1.06
                        font.weight: Style.fontWeightBold
                        color: root.shellPrimaryTextColor
                      }

                      NText {
                        text: root.trSafe("panel.setup-required.subtitle", "Link the phone first, then the mirror controls and status will appear here.")
                        pointSize: Style.fontSizeS * 1.02
                        color: root.shellSecondaryTextColor
                        wrapMode: Text.WordWrap
                      }
                    }
                  }
                }

                Repeater {
                  model: root.setupDiagnosticEntries()

                  Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    color: root.shellNestedCardColor
                    radius: Style.radiusM
                    border.width: Style.borderS
                    border.color: Qt.alpha(root.diagnosticSeverityColor(modelData.severity), 0.44)
                    implicitHeight: diagnosticRow.implicitHeight + (Style.marginM * 1.15)

                    RowLayout {
                      id: diagnosticRow
                      anchors.fill: parent
                      anchors.margins: Style.marginM * 0.82
                      spacing: Style.marginM

                      Rectangle {
                        width: 34 * Style.uiScaleRatio
                        height: width
                        radius: width / 2
                        color: Qt.alpha(root.diagnosticSeverityColor(modelData.severity), 0.14)
                        border.width: Style.borderS
                        border.color: Qt.alpha(root.diagnosticSeverityColor(modelData.severity), 0.36)

                        NIcon {
                          anchors.centerIn: parent
                          icon: modelData.icon
                          pointSize: Style.fontSizeM
                          color: root.diagnosticSeverityColor(modelData.severity)
                        }
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginXXS

                        NText {
                          Layout.fillWidth: true
                          text: modelData.title
                          pointSize: Style.fontSizeS
                          font.weight: Style.fontWeightBold
                          color: root.shellPrimaryTextColor
                          elide: Text.ElideRight
                        }

                        NText {
                          Layout.fillWidth: true
                          text: modelData.body
                          pointSize: Style.fontSizeXS
                          color: root.shellSecondaryTextColor
                          wrapMode: Text.WordWrap
                          maximumLineCount: 3
                          elide: Text.ElideRight
                        }
                      }
                    }
                  }
                }

                NButton {
                  Layout.alignment: Qt.AlignHCenter
                  Layout.minimumWidth: 190 * Style.uiScaleRatio
                  text: root.trSafe("panel.diagnostics.open-button", "Open Diagnostics")
                  icon: "info"
                  onClicked: diagnosticsPopup.open()
                }

                NButton {
                  Layout.alignment: Qt.AlignHCenter
                  Layout.minimumWidth: 240 * Style.uiScaleRatio
                  visible: KDEConnect.mainDevice !== null && !KDEConnect.mainDevice.paired
                  enabled: !root.mainDevicePairingInProgress()
                  text: root.trSafe("panel.setup-required.pair-button", "Start KDE Connect Pairing")
                  icon: "key"
                  onClicked: root.triggerMainDevicePairing()
                }

                Rectangle {
                  Layout.alignment: Qt.AlignHCenter
                  visible: root.mainDevicePairingInProgress() && String(KDEConnect.mainDevice?.verificationKey || "").trim() !== ""
                  color: root.shellAccentCardColor
                  radius: Style.radiusM
                  border.width: Style.borderS
                  border.color: root.shellAccentCardBorderColor
                  implicitWidth: setupVerificationRow.implicitWidth + (Style.marginM * 1.4)
                  implicitHeight: setupVerificationRow.implicitHeight + (Style.marginS * 1.4)

                  RowLayout {
                    id: setupVerificationRow
                    anchors.centerIn: parent
                    spacing: Style.marginS

                    NIcon {
                      icon: "key"
                      pointSize: Style.fontSizeL
                      color: root.shellAccentIconColor
                    }

                    NText {
                      text: KDEConnect.mainDevice?.verificationKey || ""
                      pointSize: Style.fontSizeL
                      font.weight: Style.fontWeightBold
                      color: root.shellAccentTextColor
                    }
                  }
                }

                NBusyIndicator {
                  Layout.alignment: Qt.AlignHCenter
                  visible: root.mainDevicePairingInProgress()
                  size: Style.baseWidgetSize * 0.5
                  running: root.mainDevicePairingInProgress()
                }

                NText {
                  Layout.fillWidth: true
                  visible: root.mainDevicePairingInProgress()
                  text: root.trSafe("panel.setup-required.pair-waiting", "Approve the KDE Connect pairing request on the phone to continue.")
                  color: root.shellSecondaryTextColor
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }

                Rectangle {
                  Layout.alignment: Qt.AlignHCenter
                  Layout.fillWidth: true
                  visible: root.setupRequiredLoopbackCommandVisible()
                  color: root.shellNestedCardColor
                  radius: Style.radiusM
                  border.width: Style.borderS
                  border.color: root.shellNestedCardBorderColor
                  implicitHeight: loopbackCommandColumn.implicitHeight + (Style.marginM * 1.2)

                  ColumnLayout {
                    id: loopbackCommandColumn
                    anchors.fill: parent
                    anchors.margins: Style.marginM * 0.9
                    spacing: Style.marginXS

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.marginS

                      NIcon {
                        icon: "copy"
                        pointSize: Style.fontSizeM
                        color: root.shellAccentIconColor
                      }

                      NText {
                        Layout.fillWidth: true
                        text: root.trSafe("panel.setup-required.command-label", "Click to copy the loopback setup command")
                        pointSize: Style.fontSizeS
                        color: root.shellAccentTextColor
                        wrapMode: Text.WordWrap
                      }
                    }

                    NText {
                      Layout.fillWidth: true
                      text: root.embeddedMirrorLoopbackSetupCommand
                      pointSize: Style.fontSizeXS
                      color: root.shellPrimaryTextColor
                      wrapMode: Text.WrapAnywhere
                      font.family: "monospace"
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.copyTextToClipboard(
                        root.embeddedMirrorLoopbackSetupCommand,
                        root.trSafe("panel.setup-required.command-copied", "Loopback setup command copied.")
                      );
                    }
                  }
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }
          }
        }
      }

      Component {
        id: noDevicesAvailableCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: emptyState
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "device-mobile-off"
              pointSize: Style.fontSizeXXL * 1.5
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            Item {}

            NText {
              text: pluginApi?.tr("panel.kdeconnect-error.no-devices")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }


      Component {
        id: busctlNotFoundCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: emptyState
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "exclamation-circle"
              pointSize: Style.fontSizeXXL * 1.5
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            Item {}

            NText {
              text: pluginApi?.tr("panel.busctl-error.unavailable-title")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            NText {
              text: pluginApi?.tr("panel.busctl-error.unavailable-desc")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }

      Component {
        id: kdeConnectDaemonNotRunningCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: emptyState
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "exclamation-circle"
              pointSize: Style.fontSizeXXL * 1.5
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            Item {}

            NText {
              text: pluginApi?.tr("panel.kdeconnect-error.unavailable-title")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            NText {
              text: pluginApi?.tr("panel.kdeconnect-error.unavailable-desc")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }

      Component {
        id: deviceSwitcherCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          NScrollView{
            horizontalPolicy: ScrollBar.AlwaysOff
            verticalPolicy: ScrollBar.AsNeeded
            contentWidth: parent.width
            reserveScrollbarSpace: false
            gradientColor: Color.mSurface

	            ColumnLayout {
	              id: emptyState
	              anchors.fill: parent
	              anchors.margins: Style.marginM
	              spacing: Style.marginM

	              RowLayout {
	                Layout.fillWidth: true
	                spacing: Style.marginM

	                NText {
	                  Layout.fillWidth: true
	                  text: root.trSafe("panel.device-switcher.title", "Connected Devices")
	                  pointSize: Style.fontSizeL
	                  font.weight: Style.fontWeightBold
	                  color: root.shellPrimaryTextColor
	                  elide: Text.ElideRight
	                }

	                NButton {
	                  text: root.trSafe("panel.device-switcher.refresh", "Refresh")
	                  icon: "refresh"
	                  onClicked: KDEConnect.refreshDevices()
	                }
	              }

	              Repeater {
	                model: KDEConnect.devices

	                Rectangle {
	                  required property var modelData
	                  readonly property bool selected: root.deviceIsSelected(modelData)

	                  Layout.fillWidth: true
	                  color: selected
	                    ? Qt.alpha(root.shellPrimaryIconColor, 0.10)
	                    : root.shellNestedCardColor
	                  radius: Style.radiusM
	                  border.width: Style.borderS
	                  border.color: selected
	                    ? Qt.alpha(root.shellPrimaryIconColor, 0.46)
	                    : root.shellNestedCardBorderColor
	                  implicitHeight: deviceSwitcherRow.implicitHeight + (Style.marginM * 1.12)

	                  RowLayout {
	                    id: deviceSwitcherRow
	                    anchors.fill: parent
	                    anchors.leftMargin: Style.marginM * 0.82
	                    anchors.rightMargin: Style.marginM * 0.82
	                    anchors.topMargin: Style.marginM * 0.82
	                    anchors.bottomMargin: Style.marginM * 0.82
	                    spacing: Style.marginM

	                    Rectangle {
	                      readonly property var brandBadge: root.deviceBrandBadge(modelData.name || "")
	                      readonly property bool brandBadgeFrameless: brandBadge.source !== ""

	                      width: 42 * Style.uiScaleRatio
	                      height: width
	                      radius: width / 2
	                      color: brandBadgeFrameless ? "transparent" : root.shellIconChipColor
	                      border.width: brandBadgeFrameless ? 0 : Style.borderS
	                      border.color: brandBadgeFrameless ? "transparent" : root.shellIconChipBorderColor

	                      Image {
	                        visible: parent.brandBadge.source !== ""
	                        source: parent.brandBadge.source
	                        width: parent.brandBadgeFrameless ? parent.width : parent.width * 0.72
	                        height: parent.brandBadgeFrameless ? parent.height : parent.height * 0.72
	                        anchors.centerIn: parent
	                        fillMode: Image.PreserveAspectFit
	                        smooth: true
	                      }

	                      NIcon {
	                        visible: parent.brandBadge.source === ""
	                        anchors.centerIn: parent
	                        icon: parent.brandBadge.fallbackIcon
	                        pointSize: Style.fontSizeL
	                        color: root.shellIconChipFgColor
	                      }
	                    }

	                    ColumnLayout {
	                      Layout.fillWidth: true
	                      spacing: Style.marginXXS

	                      RowLayout {
	                        Layout.fillWidth: true
	                        spacing: Style.marginS

	                        NText {
	                          Layout.fillWidth: true
	                          text: modelData.name || root.trSafe("panel.setup-required.phone-name", "Android Phone")
	                          pointSize: Style.fontSizeM
	                          font.weight: Style.fontWeightBold
	                          color: root.shellPrimaryTextColor
	                          elide: Text.ElideRight
	                        }

	                      }

	                      RowLayout {
	                        Layout.fillWidth: true
	                        spacing: Style.marginS

	                        NIcon {
	                          icon: root.deviceStatusIcon(modelData)
	                          pointSize: Style.fontSizeS
	                          color: root.diagnosticSeverityColor(Boolean(modelData.paired) && Boolean(modelData.reachable) ? "ok" : (Boolean(modelData.pairRequested) ? "waiting" : "error"))
	                        }

	                        NText {
	                          Layout.fillWidth: true
	                          text: root.deviceStatusTitle(modelData)
	                          pointSize: Style.fontSizeXS
	                          font.weight: Style.fontWeightMedium
	                          color: root.shellSecondaryTextColor
	                          elide: Text.ElideRight
	                        }
	                      }

	                      NText {
	                        Layout.fillWidth: true
	                        text: root.deviceStatusDetail(modelData)
	                        pointSize: Style.fontSizeXXS
	                        color: root.shellSecondaryTextColor
	                        wrapMode: Text.WordWrap
	                        maximumLineCount: 2
	                        elide: Text.ElideRight
	                      }
	                    }
	                  }

	                  MouseArea {
	                    anchors.fill: parent
	                    hoverEnabled: true
	                    cursorShape: Qt.PointingHandCursor

	                    onClicked: {
	                      KDEConnect.setMainDeviceExact(modelData.id);
	                      deviceSwitcherOpen = false;

	                      pluginApi.pluginSettings.mainDeviceId = modelData.id;
	                      pluginApi.saveSettings();
	                    }
	                  }
	                }
	              }

              Item {
                Layout.fillHeight: true
              }
            }
          }
        }
      }
    }
	  }

	  AndroidConnectDiagnosticsPopup {
	    id: diagnosticsPopup
	    panelRoot: root
	  }

	  Popup {
	    id: wirelessAdbPopup
	    parent: root
    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent
    width: Math.min(620 * Style.uiScaleRatio, root.width - (Style.marginL * 2))
    height: Math.min(wirelessAdbContentColumn.implicitHeight + (padding * 2), root.height - (Style.marginL * 2))
    padding: Style.marginL

    onOpened: {
      Qt.callLater(() => {
        if (pairHostInput.inputItem) {
          pairHostInput.inputItem.forceActiveFocus();
        }
      });
    }

    background: Rectangle {
      color: Color.mSurface
      radius: Style.radiusL
      border.color: Color.mOutline
      border.width: Style.borderM
    }

    contentItem: Flickable {
      id: wirelessAdbFlickable
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      contentWidth: width
      contentHeight: wirelessAdbContentColumn.implicitHeight
      implicitHeight: Math.min(wirelessAdbContentColumn.implicitHeight, root.height - (Style.marginL * 4))

      ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
      }

      ColumnLayout {
        id: wirelessAdbContentColumn
        width: wirelessAdbFlickable.width - Style.marginXS
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true

          NText {
            text: root.trSafe("panel.wireless-adb.dialog-title", "Wireless ADB")
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            colorBorder: Color.mOutline
            onClicked: wirelessAdbPopup.close()
          }
        }

        NText {
          text: root.trSafe("panel.wireless-adb.dialog-description", "Pair from Android's Wireless debugging screen, then connect with the current adb port shown on the phone.")
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }

        NText {
          Layout.fillWidth: true
          text: root.wirelessAdbDeviceContextText()
          visible: text !== ""
          color: root.shellSecondaryTextColor
          wrapMode: Text.WordWrap
        }

        Rectangle {
          Layout.fillWidth: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          implicitHeight: qrStep.implicitHeight + (Style.marginM * 2)

          ColumnLayout {
            id: qrStep
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NText {
              text: root.trSafe("panel.wireless-adb.qr-step-title", "1. Pair with QR code")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: root.trSafe("panel.wireless-adb.qr-section-description", "On the phone, open Wireless debugging and choose Pair device with QR code, then scan this image.")
              color: Color.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM

              Rectangle {
                Layout.preferredWidth: 176 * Style.uiScaleRatio
                Layout.preferredHeight: 176 * Style.uiScaleRatio
                radius: Style.radiusM
                color: Color.mSurface
                border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.5)
                border.width: Style.borderS

                Image {
                  anchors.fill: parent
                  anchors.margins: Style.marginM
                  source: root.wirelessAdbQrImageSource()
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                  visible: source !== ""
                }

                NText {
                  anchors.centerIn: parent
                  width: parent.width - (Style.marginM * 2)
                  text: root.trSafe("panel.wireless-adb.qr-placeholder", "Tap Start QR to generate a pairing code.")
                  visible: root.wirelessAdbQrImageSource() === ""
                  color: Color.mOnSurfaceVariant
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                  text: root.trSafe("panel.wireless-adb.qr-helper-description", "The plugin will wait for the scan, pair automatically, then connect ADB for the selected phone.")
                  color: Color.mOnSurfaceVariant
                  wrapMode: Text.WordWrap
                  Layout.fillWidth: true
                }

                NButton {
                  text: KDEConnect.wirelessAdbBusy
                    ? root.trSafe("panel.wireless-adb.qr-waiting-button", "Waiting for scan...")
                    : (root.wirelessAdbQrImageSource() !== ""
                        ? root.trSafe("panel.wireless-adb.qr-refresh-button", "Refresh QR")
                        : root.trSafe("panel.wireless-adb.qr-button", "Start QR Pairing"))
                            icon: "qrcode"
                  enabled: !wirelessAdbQrEncodeProc.running && !KDEConnect.wirelessAdbBusy
                  onClicked: root.beginWirelessAdbQrPairing()
                }

                NText {
                  text: root.trSafe("panel.wireless-adb.qr-footer-description", "Leave this popup open until the phone finishes the scan.")
                  color: Color.mOnSurfaceVariant
                  wrapMode: Text.WordWrap
                  Layout.fillWidth: true
                }
              }
            }
          }
        }

        NTextInput {
          id: pairHostInput
          Layout.fillWidth: true
          label: root.trSafe("panel.wireless-adb.host-label", "Phone IP")
          placeholderText: "192.168.1.120"
          text: root.wirelessAdbPairHost
          onTextChanged: {
            root.wirelessAdbPairHost = text;
            root.wirelessAdbConnectHost = text;
          }
          onEditingFinished: root.persistWirelessAdbSettings()
        }

        Rectangle {
          Layout.fillWidth: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          implicitHeight: pairStep.implicitHeight + (Style.marginM * 2)

          ColumnLayout {
            id: pairStep
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NText {
              text: root.trSafe("panel.wireless-adb.pair-step-title", "2. Pair with code")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: root.trSafe("panel.wireless-adb.pair-section-description", "On the phone, open Wireless debugging and choose Pair device with pairing code.")
              color: Color.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM

              NTextInput {
                Layout.preferredWidth: 150 * Style.uiScaleRatio
                label: root.trSafe("panel.wireless-adb.pair-port-label", "Pair port")
                placeholderText: "37099"
                text: root.wirelessAdbPairPort
                onTextChanged: root.wirelessAdbPairPort = text
                onEditingFinished: root.persistWirelessAdbSettings()
              }

              NTextInput {
                Layout.fillWidth: true
                label: root.trSafe("panel.wireless-adb.pair-code-label", "Pairing code")
                placeholderText: "123456"
                text: root.wirelessAdbPairingCode
                onTextChanged: root.wirelessAdbPairingCode = text
              }
            }

            RowLayout {
              Layout.fillWidth: true

              Item {
                Layout.fillWidth: true
              }

              NButton {
                text: root.trSafe("panel.wireless-adb.pair-button", "Pair")
                icon: "key"
                enabled: !KDEConnect.wirelessAdbBusy
                  && (root.wirelessAdbPairHost || "").trim() !== ""
                  && (root.wirelessAdbPairPort || "").trim() !== ""
                  && (root.wirelessAdbPairingCode || "").trim() !== ""
                onClicked: root.startWirelessAdbPairing()
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          implicitHeight: connectStep.implicitHeight + (Style.marginM * 2)

          ColumnLayout {
            id: connectStep
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NText {
              text: root.trSafe("panel.wireless-adb.connect-step-title", "3. Connect after pairing")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: root.trSafe("panel.wireless-adb.connect-section-description", "Use the current adb port shown on the phone. Android may change this port after reconnecting Wireless debugging.")
              color: Color.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            NTextInput {
              Layout.fillWidth: true
              label: root.trSafe("panel.wireless-adb.connect-port-label", "ADB port")
              placeholderText: "43127"
              text: root.wirelessAdbConnectPort
              onTextChanged: root.wirelessAdbConnectPort = text
              onEditingFinished: root.persistWirelessAdbSettings()
            }

            RowLayout {
              Layout.fillWidth: true

              NText {
                text: (root.wirelessAdbPairHost || "").trim() !== ""
                  ? (root.trSafe("panel.wireless-adb.host-label", "Phone IP") + ": " + root.wirelessAdbPairHost)
                  : ""
                color: Color.mOnSurfaceVariant
                Layout.fillWidth: true
                visible: text !== ""
                elide: Text.ElideRight
              }

              NButton {
                text: root.trSafe("panel.wireless-adb.auto-connect-button", "Auto-detect")
                icon: "wifi"
                enabled: !KDEConnect.wirelessAdbBusy
                  && (((root.wirelessAdbConnectHost || "").trim() !== "") || ((root.wirelessAdbPairHost || "").trim() !== ""))
                onClicked: root.startWirelessAdbAutoConnect()
              }

              NButton {
                text: root.trSafe("panel.wireless-adb.connect-button", "Connect")
                icon: "plug-connected"
                enabled: !KDEConnect.wirelessAdbBusy
                  && (((root.wirelessAdbConnectHost || "").trim() !== "") || ((root.wirelessAdbPairHost || "").trim() !== ""))
                  && (root.wirelessAdbConnectPort || "").trim() !== ""
                onClicked: root.startWirelessAdbConnect()
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          visible: root.wirelessAdbStatusMessage !== "" || KDEConnect.wirelessAdbBusy
          color: Color.mSurfaceVariant
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          implicitHeight: statusColumn.implicitHeight + (Style.marginM * 2)

          ColumnLayout {
            id: statusColumn
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NText {
              text: KDEConnect.wirelessAdbBusy
                ? root.trSafe("panel.wireless-adb.running-status", "Running adb command...")
                : root.trSafe("panel.wireless-adb.status-title", "Last result")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: KDEConnect.wirelessAdbBusy
                ? root.trSafe("panel.wireless-adb.running-description", "Keep this panel open until adb finishes.")
                : root.wirelessAdbStatusMessage
              color: Color.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }
      }
    }
  }
}
