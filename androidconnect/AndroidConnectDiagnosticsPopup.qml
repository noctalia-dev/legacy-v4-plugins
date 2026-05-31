import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI
import "./Services"

Popup {
  id: popupRoot

  property var panelRoot: null

  parent: panelRoot
  modal: true
  dim: true
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
  anchors.centerIn: parent
  width: Math.min(760 * Style.uiScaleRatio, (panelRoot?.width || 760) - (Style.marginL * 2))
  height: Math.min(diagnosticsContentColumn.implicitHeight + (padding * 2), (panelRoot?.height || 720) - (Style.marginL * 2))
  padding: Style.marginL

  function trSafe(key, fallback) {
    if (!panelRoot)
      return fallback;

    return panelRoot.trSafe(key, fallback);
  }

  function displayValue(value, fallback) {
    const fallbackText = fallback === undefined ? "-" : String(fallback);
    if (value === undefined || value === null)
      return fallbackText;

    const text = String(value).trim();
    return text === "" ? fallbackText : text;
  }

  function boolText(value) {
    return Boolean(value)
      ? trSafe("panel.diagnostics.value-yes", "yes")
      : trSafe("panel.diagnostics.value-no", "no");
  }

  function stringListValue(value) {
    const values = panelRoot?.normalizedStringArray(value) || [];
    return values.length === 0
      ? trSafe("panel.diagnostics.value-none", "none")
      : values.join("\n");
  }

  function timestampText(timestampMs) {
    const value = Number(timestampMs || 0);
    if (value <= 0)
      return trSafe("panel.diagnostics.value-never", "never");

    const elapsedSeconds = Math.max(0, Math.round((Date.now() - value) / 1000));
    if (elapsedSeconds < 2)
      return trSafe("panel.diagnostics.value-now", "just now");
    if (elapsedSeconds < 60)
      return elapsedSeconds + "s ago";

    const elapsedMinutes = Math.round(elapsedSeconds / 60);
    if (elapsedMinutes < 60)
      return elapsedMinutes + "m ago";

    const elapsedHours = Math.round(elapsedMinutes / 60);
    return elapsedHours + "h ago";
  }

  function adbStateSummary() {
    const entries = panelRoot?.adbDeviceStateEntries() || [];
    if (entries.length === 0)
      return trSafe("panel.diagnostics.value-none", "none");

    return entries
      .map(entry => entry.serial + " = " + entry.state)
      .join("\n");
  }

  function connectedSerialsSummary() {
    const serials = KDEConnect.adbConnectedSerials || [];
    if (serials.length === 0)
      return trSafe("panel.diagnostics.value-none", "none");

    return serials.join("\n");
  }

  function resolvedAdbSummary() {
    const serial = String(panelRoot?.resolvedAdbSerial() || "").trim();
    if (serial === "")
      return trSafe("panel.diagnostics.value-adb-not-connected", "not connected");

    if (KDEConnect.isUsbSelectionSerial(serial))
      return trSafe("panel.diagnostics.value-usb", "USB");

    return serial;
  }

  function verdictText() {
    const deviceName = displayValue(KDEConnect.mainDevice?.name, trSafe("panel.diagnostics.value-no-device", "no device"));
    const kdeHost = displayValue(panelRoot?.selectedDevicePrimaryHost(), trSafe("panel.diagnostics.value-no-host", "no host"));
    return "Selected: " + deviceName
      + " | KDE: " + kdeHost
      + " | ADB: " + resolvedAdbSummary();
  }

  function verdictSeverity() {
    if (KDEConnect.mainDevice === null)
      return "error";

    if (String(panelRoot?.resolvedAdbSerial() || "").trim() === "")
      return "waiting";

    return "ok";
  }

  function verdictColor() {
    return panelRoot?.diagnosticSeverityColor(verdictSeverity()) || Color.mOnSurfaceVariant;
  }

  function deviceRows() {
    const device = KDEConnect.mainDevice;
    return [
      { label: trSafe("panel.diagnostics.row-selected-device", "Selected device"), value: displayValue(device?.name) },
      { label: trSafe("panel.diagnostics.row-selected-device-id", "Selected device ID"), value: displayValue(device?.id) },
      { label: trSafe("panel.diagnostics.row-selected-device-hosts", "Selected device hosts"), value: stringListValue(device?.reachableAddresses) },
      { label: trSafe("panel.diagnostics.row-selected-device-providers", "Selected device providers"), value: stringListValue(device?.activeProviderNames) },
      { label: trSafe("panel.diagnostics.row-device-count", "Known devices"), value: String((KDEConnect.devices || []).length) },
      { label: trSafe("panel.diagnostics.row-daemon", "kdeconnectd available"), value: boolText(KDEConnect.daemonAvailable) },
      { label: trSafe("panel.diagnostics.row-any-reachable", "Any reachable device"), value: boolText(KDEConnect.anyDevicesConnected) },
      { label: trSafe("panel.diagnostics.row-paired", "Selected paired"), value: boolText(device?.paired) },
      { label: trSafe("panel.diagnostics.row-reachable", "Selected reachable"), value: boolText(device?.reachable) },
      { label: trSafe("panel.diagnostics.row-pair-requested", "Pair requested"), value: boolText(device?.pairRequested) },
      { label: trSafe("panel.diagnostics.row-kde-refresh", "KDE refresh"), value: timestampText(KDEConnect.deviceLastRefreshAtMs) }
    ];
  }

  function adbRows() {
    const wirelessProfile = panelRoot?.selectedWirelessAdbProfile() || ({});
    return [
      { label: trSafe("panel.diagnostics.row-adb-refresh", "ADB refresh"), value: timestampText(KDEConnect.adbDevicesLastRefreshAtMs) },
      { label: trSafe("panel.diagnostics.row-adb-exit", "adb devices exit code"), value: String(KDEConnect.adbDevicesExitCode) },
      { label: trSafe("panel.diagnostics.row-usb-transport", "USB transport"), value: boolText(KDEConnect.adbHasUsbTransport) },
      { label: trSafe("panel.diagnostics.row-wireless-configured", "Wireless configured"), value: displayValue(panelRoot?.configuredWirelessAdbSerial()) },
      { label: trSafe("panel.diagnostics.row-wireless-connected", "Wireless connected"), value: displayValue(panelRoot?.connectedWirelessAdbSerial()) },
      { label: trSafe("panel.diagnostics.row-wireless-profile-host", "Wireless profile host"), value: displayValue(wirelessProfile.host) },
      { label: trSafe("panel.diagnostics.row-wireless-last-port", "Last known Wireless ADB port"), value: displayValue(wirelessProfile.lastConnectPort) },
      { label: trSafe("panel.diagnostics.row-selected-kde-host", "Selected KDE host"), value: displayValue(panelRoot?.selectedDevicePrimaryHost()) },
      { label: trSafe("panel.diagnostics.row-resolved-adb", "Resolved ADB serial"), value: displayValue(panelRoot?.resolvedAdbSerial()) },
      { label: trSafe("panel.diagnostics.row-adb-states", "ADB states"), value: adbStateSummary() },
      { label: trSafe("panel.diagnostics.row-adb-connected", "Connected serials"), value: connectedSerialsSummary() }
    ];
  }

  function mirrorRows() {
    return [
      { label: trSafe("panel.diagnostics.row-scrcpy-running", "scrcpy running"), value: boolText(KDEConnect.scrcpyRunning) },
      { label: trSafe("panel.diagnostics.row-scrcpy-launching", "scrcpy launching"), value: boolText(KDEConnect.scrcpyLaunching) },
      { label: trSafe("panel.diagnostics.row-scrcpy-active-serial", "scrcpy active serial"), value: displayValue(KDEConnect.scrcpyActiveSerial) },
      { label: trSafe("panel.diagnostics.row-current-mirror-serial", "Current mirror serial"), value: displayValue(panelRoot?.currentMirrorAdbSerial()) },
      { label: trSafe("panel.diagnostics.row-video-device", "Video device"), value: displayValue(panelRoot?.embeddedVideoDevice) },
      { label: trSafe("panel.diagnostics.row-video-check-known", "Video check known"), value: boolText(panelRoot?.embeddedVideoDeviceCheckKnown) },
      { label: trSafe("panel.diagnostics.row-video-accessible", "Video accessible"), value: boolText(panelRoot?.embeddedVideoDeviceAccessible) },
      { label: trSafe("panel.diagnostics.row-feed-available", "Preview feed available"), value: boolText(panelRoot?.activePhonePreview?.mirrorFeedAvailable) },
      { label: trSafe("panel.diagnostics.row-screen-size", "Android screen size"), value: KDEConnect.adbScreenWidth + " x " + KDEConnect.adbScreenHeight },
      { label: trSafe("panel.diagnostics.row-touch-active", "Touch input active"), value: boolText(panelRoot?.embeddedMirrorTouchActive()) }
    ];
  }

  function errorRows() {
    return [
      { label: trSafe("panel.diagnostics.row-scrcpy-error", "scrcpy launch error"), value: displayValue(KDEConnect.scrcpyLaunchError) },
      { label: trSafe("panel.diagnostics.row-scrcpy-stderr", "scrcpy stderr"), value: displayValue(KDEConnect.scrcpyLastStderr) },
      { label: trSafe("panel.diagnostics.row-adb-stderr", "adb stderr"), value: displayValue(KDEConnect.adbDevicesStderr) },
      { label: trSafe("panel.diagnostics.row-wireless-stderr", "Wireless ADB stderr"), value: displayValue(KDEConnect.wirelessAdbLastStderr) }
    ];
  }

  function reportText() {
    const sections = [
      { title: trSafe("panel.diagnostics.section-device", "KDE Connect Device"), rows: deviceRows() },
      { title: trSafe("panel.diagnostics.section-adb", "ADB"), rows: adbRows() },
      { title: trSafe("panel.diagnostics.section-mirror", "Mirror"), rows: mirrorRows() },
      { title: trSafe("panel.diagnostics.section-errors", "Last Errors"), rows: errorRows() }
    ];

    const lines = [];
    lines.push("Verdict: " + verdictText());
    lines.push("");
    for (let i = 0; i < sections.length; ++i) {
      lines.push("[" + sections[i].title + "]");
      const rows = sections[i].rows || [];
      for (let j = 0; j < rows.length; ++j)
        lines.push(rows[j].label + ": " + rows[j].value);
      if (i < sections.length - 1)
        lines.push("");
    }
    return lines.join("\n");
  }

  background: Rectangle {
    color: Color.mSurface
    radius: Style.radiusL
    border.color: Color.mOutline
    border.width: Style.borderM
  }

  contentItem: Flickable {
    id: diagnosticsFlickable
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    contentHeight: diagnosticsContentColumn.implicitHeight
    implicitHeight: Math.min(diagnosticsContentColumn.implicitHeight, (panelRoot?.height || 720) - (Style.marginL * 4))

    ScrollBar.vertical: ScrollBar {
      policy: ScrollBar.AsNeeded
    }

    ColumnLayout {
      id: diagnosticsContentColumn
      width: diagnosticsFlickable.width - Style.marginXS
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          Layout.fillWidth: true
          text: popupRoot.trSafe("panel.diagnostics.dialog-title", "AndroidConnect Diagnostics")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
          elide: Text.ElideRight
        }

        NButton {
          text: popupRoot.trSafe("panel.diagnostics.refresh", "Refresh")
          icon: "refresh"
          onClicked: {
            KDEConnect.refreshDevices();
            KDEConnect.refreshAdbDevices();
            panelRoot?.refreshEmbeddedVideoDeviceAccess();
          }
        }

        NButton {
          text: popupRoot.trSafe("panel.diagnostics.copy", "Copy")
          icon: "copy"
          onClicked: panelRoot?.copyTextToClipboard(
            popupRoot.reportText(),
            popupRoot.trSafe("panel.diagnostics.copy-success", "Diagnostics copied.")
          )
        }

        NIconButton {
          icon: "close"
          tooltipText: I18n.tr("common.close")
          colorBorder: Color.mOutline
          onClicked: popupRoot.close()
        }
      }

      NText {
        Layout.fillWidth: true
        text: popupRoot.trSafe("panel.diagnostics.dialog-description", "Raw connection state for KDE Connect, ADB, scrcpy, and the embedded video feed.")
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
      }

      Rectangle {
        Layout.fillWidth: true
        color: Qt.alpha(popupRoot.verdictColor(), 0.10)
        radius: Style.radiusM
        border.width: Style.borderS
        border.color: Qt.alpha(popupRoot.verdictColor(), 0.42)
        implicitHeight: verdictRow.implicitHeight + (Style.marginM * 1.2)

        RowLayout {
          id: verdictRow
          anchors.fill: parent
          anchors.margins: Style.marginM * 0.8
          spacing: Style.marginM

          NIcon {
            icon: popupRoot.verdictSeverity() === "ok"
              ? "circle-check"
              : (popupRoot.verdictSeverity() === "waiting" ? "wifi" : "exclamation-circle")
            pointSize: Style.fontSizeM
            color: popupRoot.verdictColor()
          }

          NText {
            Layout.fillWidth: true
            text: popupRoot.verdictText()
            color: Color.mOnSurface
            font.weight: Style.fontWeightBold
            wrapMode: Text.WordWrap
          }
        }
      }

      DiagnosticsSection {
        title: popupRoot.trSafe("panel.diagnostics.section-device", "KDE Connect Device")
        rows: popupRoot.deviceRows()
      }

      DiagnosticsSection {
        title: popupRoot.trSafe("panel.diagnostics.section-adb", "ADB")
        rows: popupRoot.adbRows()
      }

      DiagnosticsSection {
        title: popupRoot.trSafe("panel.diagnostics.section-mirror", "Mirror")
        rows: popupRoot.mirrorRows()
      }

      DiagnosticsSection {
        title: popupRoot.trSafe("panel.diagnostics.section-errors", "Last Errors")
        rows: popupRoot.errorRows()
      }
    }
  }

  component DiagnosticsSection: Rectangle {
    id: diagnosticsSection

    property string title: ""
    property var rows: []

    Layout.fillWidth: true
    color: Color.mSurfaceVariant
    radius: Style.radiusM
    border.width: Style.borderS
    border.color: Color.mOutline
    implicitHeight: diagnosticsSectionContent.implicitHeight + (Style.marginM * 1.6)

    ColumnLayout {
      id: diagnosticsSectionContent
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      NText {
        Layout.fillWidth: true
        text: diagnosticsSection.title
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        elide: Text.ElideRight
      }

      Repeater {
        model: diagnosticsSection.rows || []

        RowLayout {
          required property var modelData

          Layout.fillWidth: true
          spacing: Style.marginM

          NText {
            Layout.preferredWidth: 176 * Style.uiScaleRatio
            text: modelData.label
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
          }

          NText {
            Layout.fillWidth: true
            text: modelData.value
            pointSize: Style.fontSizeXS
            color: Color.mOnSurface
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 4
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}
