import QtQuick
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import Quickshell.Io

Item {
  id: root

  // --- CONFIGURATION: Change sound here ---
  readonly property string alarmSoundFile: Qt.resolvedUrl("alarm.mp3").toString().replace("file://", "")


  property var pluginApi: null

  onPluginApiChanged: {
    if (pluginApi) {
      settingsVersion++
      Logger.i("Pomodoro", "pluginApi available, loading settings")
    }
  }

  FileView {
    id: settingsFileWatcher
    path: Qt.resolvedUrl("settings.json")
    
    onTextChanged: {
      if (text && text.length > 0) {
        try {
          var newSettings = JSON.parse(text);
          if (pluginApi && pluginApi.pluginSettings) {
            if (newSettings.workDuration !== undefined)
              pluginApi.pluginSettings.workDuration = newSettings.workDuration;
            if (newSettings.shortBreakDuration !== undefined)
              pluginApi.pluginSettings.shortBreakDuration = newSettings.shortBreakDuration;
            if (newSettings.longBreakDuration !== undefined)
              pluginApi.pluginSettings.longBreakDuration = newSettings.longBreakDuration;
            if (newSettings.sessionsBeforeLongBreak !== undefined)
              pluginApi.pluginSettings.sessionsBeforeLongBreak = newSettings.sessionsBeforeLongBreak;
            if (newSettings.autoStartBreaks !== undefined)
              pluginApi.pluginSettings.autoStartBreaks = newSettings.autoStartBreaks;
            if (newSettings.autoStartWork !== undefined)
              pluginApi.pluginSettings.autoStartWork = newSettings.autoStartWork;
            if (newSettings.compactMode !== undefined)
              pluginApi.pluginSettings.compactMode = newSettings.compactMode;
              
            // Trigger update
            root.settingsVersion++;
            
            Logger.i("Pomodoro", "Settings reloaded from file");
          }
        } catch (e) {
          Logger.e("Pomodoro", "Failed to parse settings.json: " + e);
        }
      }
    }
  }

  IpcHandler {
    target: "plugin:pomodoro"

    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => {
          pluginApi.togglePanel(screen);
        });
      }
    }

    function start() {
      root.pomodoroStart();
    }

    function pause() {
      root.pomodoroPause();
    }

    function reset() {
      root.pomodoroResetSession();
    }

    function resetAll() {
      root.pomodoroResetAll();
    }

    function skip() {
      root.pomodoroSkip();
    }

    function stopAlarm() {
      root.pomodoroStopAlarm();
    }
  }

  readonly property int modeWork: 0
  readonly property int modeShortBreak: 1
  readonly property int modeLongBreak: 2

  property bool pomodoroRunning: false
  property int pomodoroMode: modeWork  // 0-1-2 = work, short-break, long-break
  property int pomodoroRemainingSeconds: 0
  property int pomodoroTotalSeconds: 0
  property int pomodoroOriginalTotal: 0
  property int pomodoroCompletedSessions: 0
  property bool pomodoroSoundPlaying: false

  property int settingsVersion: 0
  
  property int workDuration: _computeWorkDuration()
  property int shortBreakDuration: _computeShortBreakDuration()
  property int longBreakDuration: _computeLongBreakDuration()
  property int sessionsBeforeLongBreak: _computeSessionsBeforeLongBreak()
  property bool autoStartBreaks: _computeAutoStartBreaks()
  property bool autoStartWork: _computeAutoStartWork()
  property bool compactMode: _computeCompactMode()
  
  function _computeWorkDuration() { return (pluginApi?.pluginSettings?.workDuration ?? 25) * 60; }
  function _computeShortBreakDuration() { return (pluginApi?.pluginSettings?.shortBreakDuration ?? 5) * 60; }
  function _computeLongBreakDuration() { return (pluginApi?.pluginSettings?.longBreakDuration ?? 15) * 60; }
  function _computeSessionsBeforeLongBreak() { return pluginApi?.pluginSettings?.sessionsBeforeLongBreak ?? 4; }
  function _computeAutoStartBreaks() { return pluginApi?.pluginSettings?.autoStartBreaks ?? false; }
  function _computeAutoStartWork() { return pluginApi?.pluginSettings?.autoStartWork ?? false; }
  function _computeCompactMode() { return pluginApi?.pluginSettings?.compactMode ?? false; }
  
  onSettingsVersionChanged: {
    workDuration = _computeWorkDuration()
    shortBreakDuration = _computeShortBreakDuration()
    longBreakDuration = _computeLongBreakDuration()
    sessionsBeforeLongBreak = _computeSessionsBeforeLongBreak()
    autoStartBreaks = _computeAutoStartBreaks()
    autoStartWork = _computeAutoStartWork()
    compactMode = _computeCompactMode()
    Logger.i("Pomodoro", "Settings updated: autoStartBreaks=" + autoStartBreaks + ", autoStartWork=" + autoStartWork + ", compactMode=" + compactMode)
  }

  function getDurationForMode(mode) {
    if (mode === modeWork) return workDuration;
    if (mode === modeShortBreak) return shortBreakDuration;
    if (mode === modeLongBreak) return longBreakDuration;
    return workDuration;
  }

  Timer {
    id: updateTimer
    interval: 1000
    repeat: true
    running: root.pomodoroRunning
    triggeredOnStart: false

    onTriggered: {
      if (!root.pomodoroRunning)
        return;

      root.pomodoroRemainingSeconds = root.pomodoroRemainingSeconds - 1;
      
      if (root.pomodoroRemainingSeconds <= 0) {
        root.pomodoroOnFinished();
      }
    }
  }

  // ---  Alarm Limit Timer ---
  Timer {
    id: alarmLimitTimer
    interval: 5000 // 5 seconds
    repeat: false
    running: false
    onTriggered: {
       root.pomodoroStopAlarm();
    }
  }

  function pomodoroStart(stopSound = true) {
    // Stop any playing alarm sound when starting, unless explicitly asked not to (for auto-start)
    if (stopSound && root.pomodoroSoundPlaying) {
      SoundService.stopSound(root.alarmSoundFile); // Uses variable
      root.pomodoroSoundPlaying = false;
      alarmLimitTimer.stop();
    }
    
    if (root.pomodoroRemainingSeconds <= 0) {
      root.pomodoroRemainingSeconds = getDurationForMode(root.pomodoroMode);
      root.pomodoroOriginalTotal = root.pomodoroRemainingSeconds;
    } else if (root.pomodoroOriginalTotal <= 0) {
      root.pomodoroOriginalTotal = root.pomodoroRemainingSeconds;
    }
    
    root.pomodoroTotalSeconds = root.pomodoroRemainingSeconds;
    root.pomodoroRunning = true;
  }

  function pomodoroPause() {
    root.pomodoroRunning = false;
    SoundService.stopSound(root.alarmSoundFile); // Uses variable
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
  }

  function pomodoroResetSession() {
    root.pomodoroRunning = false;
    root.pomodoroRemainingSeconds = getDurationForMode(root.pomodoroMode);
    root.pomodoroTotalSeconds = 0;
    root.pomodoroOriginalTotal = 0;

    SoundService.stopSound(root.alarmSoundFile); // Uses variable
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
  }

  function pomodoroResetAll() {
    root.pomodoroRunning = false;
    root.pomodoroRemainingSeconds = 0;
    root.pomodoroTotalSeconds = 0;
    root.pomodoroOriginalTotal = 0;
    root.pomodoroCompletedSessions = 0;
    root.pomodoroMode = modeWork;

    SoundService.stopSound(root.alarmSoundFile); // Uses variable
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
  }

  function pomodoroSkip() {
    root.pomodoroRunning = false;
    SoundService.stopSound(root.alarmSoundFile); // Uses variable
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
    
    pomodoroAdvanceToNextPhase();
  }

  function pomodoroStopAlarm() {
    if (root.pomodoroSoundPlaying) {
      SoundService.stopSound(root.alarmSoundFile); // Uses variable
      root.pomodoroSoundPlaying = false;
      alarmLimitTimer.stop();
    }
  }

  function pomodoroSetMode(mode) {
    if (root.pomodoroRunning) {
      root.pomodoroPause();
    }
    root.pomodoroMode = mode;
    root.pomodoroRemainingSeconds = getDurationForMode(mode);
    root.pomodoroTotalSeconds = 0;
  }

  function pomodoroAdvanceToNextPhase() {
    if (root.pomodoroMode === modeWork) {
      if (root.pomodoroCompletedSessions + 1 >= root.sessionsBeforeLongBreak) {
        root.pomodoroMode = modeLongBreak;
      } else {
        root.pomodoroMode = modeShortBreak;
      }
    } else {
      if (root.pomodoroMode === modeLongBreak) {
        root.pomodoroCompletedSessions = 0;
      } else {
        root.pomodoroCompletedSessions++;
      }
      root.pomodoroMode = modeWork;
    }
    
    root.pomodoroRemainingSeconds = getDurationForMode(root.pomodoroMode);
    root.pomodoroTotalSeconds = 0;
    root.pomodoroOriginalTotal = 0;
  }

  function pomodoroOnFinished() {
    root.pomodoroRunning = false;
    root.pomodoroRemainingSeconds = 0;
    root.pomodoroSoundPlaying = true;

    // Play Sound (checking toggle setting)
    if (pluginApi?.pluginSettings?.playSound !== false) {
      SoundService.playSound(root.alarmSoundFile, { // Uses variable
        repeat: true,
        volume: 0.3 
      });
      // Start the alarm limit timer
      alarmLimitTimer.start();
    }

    var toastMessage;
    var shouldAutoStart = false;
    
    if (root.pomodoroMode === modeWork) {
      toastMessage = pluginApi?.tr("toast.work-finished") || "Work session complete! Time for a break.";
      shouldAutoStart = root.autoStartBreaks;
    } else if (root.pomodoroMode === modeLongBreak) {
      toastMessage = pluginApi?.tr("toast.long-break-finished") || "Long break over! Ready for a new cycle?";
      shouldAutoStart = root.autoStartWork;
    } else {
      toastMessage = pluginApi?.tr("toast.break-finished") || "Break over! Ready to focus?";
      shouldAutoStart = root.autoStartWork;
    }

    ToastService.showNotice(
      pluginApi?.tr("toast.title") || "Pomodoro",
      toastMessage,
      "clock"
    );

    pomodoroAdvanceToNextPhase();
    
    if (shouldAutoStart) {
      Qt.callLater(() => {
        // Pass false to keep sound playing!
        root.pomodoroStart(false);
      });
    }
  }
}
