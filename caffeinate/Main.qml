import QtQuick
import qs.Services.Power
import "DurationLanguage.js" as DurationLanguage

Item {
  id: root

  property var pluginApi: null
  property bool sessionActive: false

  readonly property var remainingSeconds: sessionActive ? IdleInhibitorService.timeout : null
  readonly property bool indefinite: sessionActive && IdleInhibitorService.timeout === null

  function refreshSessionState() {
    sessionActive = IdleInhibitorService.activeInhibitors.indexOf("manual") !== -1;
  }

  function sessionSnapshot() {
    return {
      "active": sessionActive,
      "remainingSeconds": remainingSeconds
    };
  }

  function startFinite(seconds) {
    const duration = Number(seconds);
    if (!isFinite(duration) || Math.floor(duration) !== duration || duration < 1 || duration
        > DurationLanguage.MAX_FINITE_SECONDS)
      return false;

    IdleInhibitorService.addManualInhibitor(duration);
    refreshSessionState();
    return true;
  }

  function startIndefinite() {
    IdleInhibitorService.addManualInhibitor(null);
    refreshSessionState();
    return true;
  }

  function endSession() {
    refreshSessionState();
    if (!sessionActive)
      return false;

    IdleInhibitorService.removeManualInhibitor();
    refreshSessionState();
    return true;
  }

  Component.onCompleted: refreshSessionState()

  Connections {
    target: IdleInhibitorService

    function onActiveInhibitorsChanged() {
      root.refreshSessionState();
    }

    function onIsInhibitedChanged() {
      root.refreshSessionState();
    }

    function onTimeoutChanged() {
      root.refreshSessionState();
    }
  }

  // Noctalia currently mutates activeInhibitors in place, which emits no change
  // signal when another inhibitor keeps isInhibited true. Poll only while idle
  // inhibition is active so built-in and plugin-started sessions stay in sync.
  Timer {
    interval: 1000
    repeat: true
    running: IdleInhibitorService.isInhibited || root.sessionActive
    onTriggered: root.refreshSessionState()
  }
}
