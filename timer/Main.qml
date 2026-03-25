import QtQuick
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import Quickshell.Io

Item {
  id: root

  property var pluginApi: null

  IpcHandler {
    target: "plugin:timer"
    
    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => {
          pluginApi.togglePanel(screen);
        });
      }
    }

    function start(duration_str: string) {
      if (duration_str && duration_str === "stopwatch") {
        root.stopwatchReset();
        root.timerStopwatchMode = true;
        root.stopwatchStart();
      } else if (duration_str && duration_str !== "") {
        const seconds = root.parseDuration(duration_str);
        if (seconds > 0) {
          root.countdownReset();
          root.cdRemainingSeconds = seconds;
          root.timerStopwatchMode = false;
          root.countdownStart();
        }
      } else {
        root.timerStart();
      }
    }

    function pause() {
      root.timerPause();
    }

    function reset() {
      root.timerReset();
    }
  }

  // View mode (which tab is active in the panel)
  property bool timerStopwatchMode: false

  // Countdown state
  property bool cdRunning: false
  property int cdRemainingSeconds: 0
  property int cdTotalSeconds: 0
  property int cdStartTimestamp: 0
  property int cdPausedAt: 0
  property bool cdSoundPlaying: false

  // Stopwatch state
  property bool swRunning: false
  property int swElapsedSeconds: 0
  property int swStartTimestamp: 0
  property int swPausedAt: 0

  // Backward-compatible computed properties (used by bar/CC widgets)
  readonly property bool timerRunning: timerStopwatchMode ? swRunning : cdRunning
  readonly property int timerRemainingSeconds: cdRemainingSeconds
  readonly property int timerTotalSeconds: cdTotalSeconds
  readonly property int timerElapsedSeconds: swElapsedSeconds
  readonly property bool timerSoundPlaying: cdSoundPlaying

  // Current timestamp
  property int timestamp: Math.floor(Date.now() / 1000)

  // Main timer loop
  Timer {
    id: updateTimer
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: {
      var now = new Date();
      root.timestamp = Math.floor(now.getTime() / 1000);

      // Update countdown if running
      if (root.cdRunning && root.cdStartTimestamp > 0) {
        const elapsed = root.timestamp - root.cdStartTimestamp;
        root.cdRemainingSeconds = root.cdTotalSeconds - elapsed;
        if (root.cdRemainingSeconds <= 0) {
          root.countdownOnFinished();
        }
      }

      // Update stopwatch if running
      if (root.swRunning && root.swStartTimestamp > 0) {
        const elapsed = root.timestamp - root.swStartTimestamp;
        root.swElapsedSeconds = root.swPausedAt + elapsed;
      }

      // Sync to next second
      var msIntoSecond = now.getMilliseconds();
      if (msIntoSecond > 100) {
        updateTimer.interval = 1000 - msIntoSecond + 10;
        updateTimer.restart();
      } else {
        updateTimer.interval = 1000;
      }
    }
  }

  Component.onCompleted: {
    // Sync start
    var now = new Date();
    var msUntilNextSecond = 1000 - now.getMilliseconds();
    updateTimer.interval = msUntilNextSecond + 10;
    updateTimer.restart();
  }

  // Countdown logic
  function countdownStart() {
    if (root.cdRemainingSeconds <= 0) return;
    root.cdTotalSeconds = root.cdRemainingSeconds;
    root.cdStartTimestamp = root.timestamp;
    root.cdPausedAt = 0;
    root.cdRunning = true;
  }

  function countdownPause() {
    if (root.cdRunning) {
      const currentTimestamp = Math.floor(Date.now() / 1000);
      const elapsed = currentTimestamp - root.cdStartTimestamp;
      const remaining = root.cdTotalSeconds - elapsed;
      root.cdPausedAt = Math.max(0, remaining);
      root.cdRemainingSeconds = root.cdPausedAt;
    }
    root.cdRunning = false;
    root.cdStartTimestamp = 0;
    SoundService.stopSound("alarm-beep.wav");
    root.cdSoundPlaying = false;
  }

  function countdownReset() {
    root.cdRunning = false;
    root.cdStartTimestamp = 0;
    root.cdRemainingSeconds = 0;
    root.cdTotalSeconds = 0;
    root.cdPausedAt = 0;
    SoundService.stopSound("alarm-beep.wav");
    root.cdSoundPlaying = false;
  }

  // Stopwatch logic
  function stopwatchStart() {
    root.swStartTimestamp = root.timestamp;
    root.swPausedAt = root.swElapsedSeconds;
    root.swRunning = true;
  }

  function stopwatchPause() {
    if (root.swRunning) {
      root.swPausedAt = root.swElapsedSeconds;
    }
    root.swRunning = false;
    root.swStartTimestamp = 0;
  }

  function stopwatchReset() {
    root.swRunning = false;
    root.swStartTimestamp = 0;
    root.swElapsedSeconds = 0;
    root.swPausedAt = 0;
  }

  // Convenience: operate on current mode
  function timerStart() {
    if (root.timerStopwatchMode) stopwatchStart();
    else countdownStart();
  }

  function timerPause() {
    if (root.timerStopwatchMode) stopwatchPause();
    else countdownPause();
  }

  function timerReset() {
    if (root.timerStopwatchMode) stopwatchReset();
    else countdownReset();
  }

  function parseDuration(duration_str) {
    if (!duration_str) return 0;
    
    // Default to minutes if just a number
    if (/^\d+$/.test(duration_str)) {
      return parseInt(duration_str) * 60;
    }

    var totalSeconds = 0;
    var regex = /(\d+)([hms])/g;
    var match;
    
    while ((match = regex.exec(duration_str)) !== null) {
      var value = parseInt(match[1]);
      var unit = match[2];
      
      if (unit === 'h') totalSeconds += value * 3600;
      else if (unit === 'm') totalSeconds += value * 60;
      else if (unit === 's') totalSeconds += value;
    }
    
    return totalSeconds;
  }

  function countdownOnFinished() {
    root.cdRunning = false;
    root.cdRemainingSeconds = 0;
    root.cdSoundPlaying = true;
    SoundService.playSound("alarm-beep.wav", {
      repeat: true,
      volume: 0.3
    });
    ToastService.showNotice(
      pluginApi?.tr("toast.title") || "Timer",
      pluginApi?.tr("toast.finished") || "Timer finished!",
      "hourglass",
      {
        onDismissed: () => {
          if (root.cdSoundPlaying) {
             root.countdownPause();
          }
        }
      }
    );
  }
}
