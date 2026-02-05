import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property int editWorkDuration: 25
  property int editShortBreakDuration: 5
  property int editLongBreakDuration: 15
  property int editSessionsBeforeLongBreak: 4

  property bool editAutoStartBreaks: false
  property bool editAutoStartWork: false
  property bool editCompactMode: false
  
  // --- : Sound Property ---
  property bool editPlaySound: true

  spacing: Style.marginM

  onPluginApiChanged: {
    if (pluginApi) {
      loadSettings()
    }
  }

  Component.onCompleted: {

    if (pluginApi) {
      loadSettings()
    }
  }

  function loadSettings() {
    const settings = pluginApi?.pluginSettings
    const defaults = pluginApi?.manifest?.metadata?.defaultSettings

    root.editWorkDuration = settings?.workDuration ?? defaults?.workDuration ?? 25
    root.editShortBreakDuration = settings?.shortBreakDuration ?? defaults?.shortBreakDuration ?? 5
    root.editLongBreakDuration = settings?.longBreakDuration ?? defaults?.longBreakDuration ?? 15
    root.editSessionsBeforeLongBreak = settings?.sessionsBeforeLongBreak ?? defaults?.sessionsBeforeLongBreak ?? 4
    root.editAutoStartBreaks = settings?.autoStartBreaks ?? defaults?.autoStartBreaks ?? false
    root.editAutoStartWork = settings?.autoStartWork ?? defaults?.autoStartWork ?? false
    root.editCompactMode = settings?.compactMode ?? defaults?.compactMode ?? false

    
    // --- : Load Sound Setting ---
    root.editPlaySound = settings?.playSound ?? defaults?.playSound ?? true

    autoStartBreaksToggle.checked = root.editAutoStartBreaks
    autoStartWorkToggle.checked = root.editAutoStartWork
    compactModeToggle.checked = root.editCompactMode
    playSoundToggle.checked = root.editPlaySound


  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.work-duration") || "Work Duration"
      description: pluginApi?.tr("settings.work-duration-desc") || "Duration of each work session in minutes"
    }

    NSpinBox {
      id: workDurationSpinBox
      from: 5
      to: 180
      stepSize: 5
      value: root.editWorkDuration
      onValueChanged: if (value !== root.editWorkDuration) root.editWorkDuration = value
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.short-break-duration") || "Short Break Duration"
      description: pluginApi?.tr("settings.short-break-duration-desc") || "Duration of short breaks in minutes"
    }

    NSpinBox {
      id: shortBreakSpinBox
      from: 1
      to: 60
      stepSize: 1
      value: root.editShortBreakDuration
      onValueChanged: if (value !== root.editShortBreakDuration) root.editShortBreakDuration = value
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.long-break-duration") || "Long Break Duration"
      description: pluginApi?.tr("settings.long-break-duration-desc") || "Duration of long breaks in minutes"
    }

    NSpinBox {
      id: longBreakSpinBox
      from: 5
      to: 120
      stepSize: 5
      value: root.editLongBreakDuration
      onValueChanged: if (value !== root.editLongBreakDuration) root.editLongBreakDuration = value
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.sessions-before-long-break") || "Sessions Before Long Break"
      description: pluginApi?.tr("settings.sessions-before-long-break-desc") || "Number of work sessions before a long break"
    }

    NSpinBox {
      id: sessionsSpinBox
      from: 1
      to: 10
      stepSize: 1
      value: root.editSessionsBeforeLongBreak
      onValueChanged: if (value !== root.editSessionsBeforeLongBreak) root.editSessionsBeforeLongBreak = value
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: autoStartBreaksToggle.implicitHeight
    
    NToggle {
      id: autoStartBreaksToggle
      anchors.fill: parent
      label: pluginApi?.tr("settings.auto-start-breaks") || "Auto-start Breaks"
      description: pluginApi?.tr("settings.auto-start-breaks-desc") || "Automatically start break timer after work session"
      checked: root.editAutoStartBreaks
    }
    
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.editAutoStartBreaks = !root.editAutoStartBreaks
        autoStartBreaksToggle.checked = root.editAutoStartBreaks
      }
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: autoStartWorkToggle.implicitHeight
    
    NToggle {
      id: autoStartWorkToggle
      anchors.fill: parent
      label: pluginApi?.tr("settings.auto-start-work") || "Auto-start Work"
      description: pluginApi?.tr("settings.auto-start-work-desc") || "Automatically start work timer after break"
      checked: root.editAutoStartWork
    }
    
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.editAutoStartWork = !root.editAutoStartWork
        autoStartWorkToggle.checked = root.editAutoStartWork
      }
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: compactModeToggle.implicitHeight
    
    NToggle {
      id: compactModeToggle
      anchors.fill: parent
      label: pluginApi?.tr("settings.compact-mode") || "Compact Mode"
      description: pluginApi?.tr("settings.compact-mode-desc") || "Hide the circular progress bar for a cleaner look"
      checked: root.editCompactMode
    }
    
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.editCompactMode = !root.editCompactMode
        compactModeToggle.checked = root.editCompactMode
      }
    }
  }

  // --- : Play Sound Toggle ---
  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: playSoundToggle.implicitHeight

    NToggle {
      id: playSoundToggle
      anchors.fill: parent
      label: "Play Alarm Sound"
      description: "Play a sound when the timer finishes"
      checked: root.editPlaySound
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.editPlaySound = !root.editPlaySound
        playSoundToggle.checked = root.editPlaySound
      }
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("Pomodoro", "Cannot save settings: pluginApi is null")
      return
    }

    pluginApi.pluginSettings.workDuration = root.editWorkDuration
    pluginApi.pluginSettings.shortBreakDuration = root.editShortBreakDuration
    pluginApi.pluginSettings.longBreakDuration = root.editLongBreakDuration
    pluginApi.pluginSettings.sessionsBeforeLongBreak = root.editSessionsBeforeLongBreak
    pluginApi.pluginSettings.autoStartBreaks = root.editAutoStartBreaks
    pluginApi.pluginSettings.autoStartWork = root.editAutoStartWork
    pluginApi.pluginSettings.compactMode = root.editCompactMode
    
    // --- : Save Sound Setting ---
    pluginApi.pluginSettings.playSound = root.editPlaySound

    pluginApi.saveSettings()

    if (pluginApi.mainInstance) {
      pluginApi.mainInstance.settingsVersion++
    }


  }
}
