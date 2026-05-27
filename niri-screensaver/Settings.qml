// Settings.qml - niri-screensaver plugin settings tab
//
// Edit-copy pattern: form fields write to local `edit*` properties; the shell
// calls saveSettings() when the user clicks Apply, at which point we copy the
// edit values back into pluginApi.pluginSettings and call saveSettings() on
// the plugin API. This matches the noctalia-plugins AGENTS.md convention.
//
// SPDX-License-Identifier: GPL-3.0-only
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

ColumnLayout {
  id: root
  property var pluginApi: null
  spacing: Style.marginL

  // ----- Settings access (cfg → defaults → hardcoded) -----
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // ----- Edit-copy properties -----
  property bool   editEnabled:        cfg.enabled        ?? defaults.enabled        ?? true
  property int    editIdleSeconds:    parseInt(cfg.idleSeconds   ?? defaults.idleSeconds   ?? 300)
  property int    editBatteryMinPercent: parseInt(cfg.batteryMinPercent ?? defaults.batteryMinPercent ?? 0)
  property string editIncludeEffects: cfg.includeEffects ?? defaults.includeEffects ?? ""
  property string editExcludeEffects: cfg.excludeEffects ?? defaults.excludeEffects ?? "dev_worm"
  property string editFadeInEffect:   cfg.fadeInEffect   ?? defaults.fadeInEffect   ?? ""
  property string editFadeOutEffect:  cfg.fadeOutEffect  ?? defaults.fadeOutEffect  ?? ""
  property bool   editRandomLogo:     cfg.randomLogo     ?? defaults.randomLogo     ?? false
  property string editLogoDir:        cfg.logoDir        ?? defaults.logoDir        ?? ""
  property string editLogoPath:       cfg.logoPath       ?? defaults.logoPath       ?? ""

  // Effective logo directory for the file dropdown: user override wins, otherwise
  // whichever bash DEFAULT_LOGO_CANDIDATES dir actually exists. Filled by the
  // detection Process below; empty until that returns.
  property string detectedSystemLogoDir: ""
  readonly property string effectiveLogoDir: (editLogoDir && editLogoDir !== "")
    ? editLogoDir
    : detectedSystemLogoDir
  property bool   editShowClock:      cfg.showClock      ?? defaults.showClock      ?? false
  property string editClockFormat:    cfg.clockFormat    ?? defaults.clockFormat    ?? "%H:%M"
  property bool   editShowNowPlaying: cfg.showNowPlaying ?? defaults.showNowPlaying ?? false
  property int    editNowPlayingDuration: parseInt(cfg.nowPlayingDuration ?? defaults.nowPlayingDuration ?? 3)

  // ----- CLI-missing banner (Main.qml runs detection on startup) -----
  readonly property var mainInstance: pluginApi?.mainInstance || null
  readonly property bool cliMissing: mainInstance && mainInstance.cliAvailable === false

  // ----- Save handler (called by the shell on Apply) -----
  function saveSettings() {
    if (!pluginApi) {
      Logger.e("NiriScreensaver", "saveSettings: pluginApi is null")
      return
    }
    pluginApi.pluginSettings.enabled        = root.editEnabled
    pluginApi.pluginSettings.idleSeconds    = root.editIdleSeconds
    pluginApi.pluginSettings.batteryMinPercent = root.editBatteryMinPercent
    pluginApi.pluginSettings.includeEffects = root.editIncludeEffects
    pluginApi.pluginSettings.excludeEffects = root.editExcludeEffects
    pluginApi.pluginSettings.fadeInEffect   = root.editFadeInEffect
    pluginApi.pluginSettings.fadeOutEffect  = root.editFadeOutEffect
    pluginApi.pluginSettings.randomLogo     = root.editRandomLogo
    pluginApi.pluginSettings.logoDir        = root.editLogoDir
    pluginApi.pluginSettings.logoPath       = root.editLogoPath
    pluginApi.pluginSettings.showClock      = root.editShowClock
    pluginApi.pluginSettings.clockFormat    = root.editClockFormat
    pluginApi.pluginSettings.showNowPlaying = root.editShowNowPlaying
    pluginApi.pluginSettings.nowPlayingDuration = root.editNowPlayingDuration
    pluginApi.saveSettings()
    Logger.i("NiriScreensaver", "settings saved")
  }

  // ----- Title -----
  NText {
    Layout.fillWidth: true
    text: pluginApi?.tr("settings.title")
    pointSize: Style.fontSizeXXL
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }
  NText {
    Layout.fillWidth: true
    text: pluginApi?.tr("settings.description")
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeM
    wrapMode: Text.WordWrap
  }

  // ----- CLI-missing banner -----
  NBox {
    Layout.fillWidth: true
    visible: root.cliMissing
    color: Color.mError
    Layout.preferredHeight: bannerCol.implicitHeight + Style.marginM * 2

    ColumnLayout {
      id: bannerCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginXS
      NText {
        text: pluginApi?.tr("settings.cli-missing.title")
        color: Color.mOnError
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL
      }
      NText {
        text: pluginApi?.tr("settings.cli-missing.desc")
        color: Color.mOnError
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }
  }

  // ----- Idle behavior -----
  NBox {
    Layout.fillWidth: true
    Layout.preferredHeight: idleCol.implicitHeight + Style.marginM * 2
    color: Color.mSurfaceVariant

    ColumnLayout {
      id: idleCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: pluginApi?.tr("settings.idle-section")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.enabled")
        description: pluginApi?.tr("settings.enabled-desc")
        checked: root.editEnabled
        defaultValue: root.defaults.enabled
        onToggled: checked => root.editEnabled = checked
      }

      NSpinBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.idle-seconds")
        description: pluginApi?.tr("settings.idle-seconds-desc")
        from: 30
        to: 7200
        stepSize: 30
        value: root.editIdleSeconds
        defaultValue: root.defaults.idleSeconds
        onValueChanged: root.editIdleSeconds = value
      }
    }
  }

  // ----- Power -----
  NBox {
    Layout.fillWidth: true
    Layout.preferredHeight: powerCol.implicitHeight + Style.marginM * 2
    color: Color.mSurfaceVariant

    ColumnLayout {
      id: powerCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: pluginApi?.tr("settings.power-section")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NSpinBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.battery-min-percent")
        description: pluginApi?.tr("settings.battery-min-percent-desc")
        from: 0
        to: 100
        stepSize: 5
        value: root.editBatteryMinPercent
        defaultValue: root.defaults.batteryMinPercent
        onValueChanged: root.editBatteryMinPercent = value
      }
    }
  }

  // ----- Logo -----
  NBox {
    Layout.fillWidth: true
    Layout.preferredHeight: logoCol.implicitHeight + Style.marginM * 2
    color: Color.mSurfaceVariant

    ColumnLayout {
      id: logoCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: pluginApi?.tr("settings.logo-section")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NComboBox {
        Layout.fillWidth: true
        minimumWidth: 320
        label: pluginApi?.tr("settings.logo-path")
        description: pluginApi?.tr("settings.logo-path-desc")
        model: logoOptions
        currentKey: root.editLogoPath
        defaultValue: root.defaults.logoPath
        enabled: !root.editRandomLogo
        onSelected: key => root.editLogoPath = key
      }

      NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.random-logo")
        description: pluginApi?.tr("settings.random-logo-desc")
        checked: root.editRandomLogo
        defaultValue: root.defaults.randomLogo
        onToggled: checked => root.editRandomLogo = checked
      }

      NTextInputButton {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.logo-dir")
        description: pluginApi?.tr("settings.logo-dir-desc")
        placeholderText: pluginApi?.tr("settings.placeholder.logo-dir")
        text: root.editLogoDir
        buttonIcon: "filepicker-folder"
        buttonTooltip: pluginApi?.tr("settings.logo-dir-browse")
        onInputEditingFinished: root.editLogoDir = text
        onButtonClicked: logoDirPicker.openFilePicker()
      }
    }
  }

  // ----- Effects -----
  NBox {
    Layout.fillWidth: true
    Layout.preferredHeight: fxCol.implicitHeight + Style.marginM * 2
    color: Color.mSurfaceVariant

    ColumnLayout {
      id: fxCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: pluginApi?.tr("settings.effects-section")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.include-effects")
        description: pluginApi?.tr("settings.include-effects-desc")
        placeholderText: pluginApi?.tr("settings.placeholder.include-effects")
        text: root.editIncludeEffects
        defaultValue: root.defaults.includeEffects
        onEditingFinished: root.editIncludeEffects = text
      }

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.exclude-effects")
        description: pluginApi?.tr("settings.exclude-effects-desc")
        placeholderText: pluginApi?.tr("settings.placeholder.exclude-effects")
        text: root.editExcludeEffects
        defaultValue: root.defaults.excludeEffects
        onEditingFinished: root.editExcludeEffects = text
      }

      NComboBox {
        Layout.fillWidth: true
        minimumWidth: 280
        label: pluginApi?.tr("settings.fade-in")
        description: pluginApi?.tr("settings.fade-in-desc")
        model: effectOptions
        currentKey: root.editFadeInEffect
        defaultValue: root.defaults.fadeInEffect
        onSelected: key => root.editFadeInEffect = key
      }

      NComboBox {
        Layout.fillWidth: true
        minimumWidth: 280
        label: pluginApi?.tr("settings.fade-out")
        description: pluginApi?.tr("settings.fade-out-desc")
        model: effectOptions
        currentKey: root.editFadeOutEffect
        defaultValue: root.defaults.fadeOutEffect
        onSelected: key => root.editFadeOutEffect = key
      }
    }
  }

  // ----- Clock -----
  NBox {
    Layout.fillWidth: true
    Layout.preferredHeight: clockCol.implicitHeight + Style.marginM * 2
    color: Color.mSurfaceVariant

    ColumnLayout {
      id: clockCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: pluginApi?.tr("settings.clock-section")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.show-clock")
        description: pluginApi?.tr("settings.show-clock-desc")
        checked: root.editShowClock
        defaultValue: root.defaults.showClock
        onToggled: checked => root.editShowClock = checked
      }

      NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.clock-format")
        description: pluginApi?.tr("settings.clock-format-desc")
        text: root.editClockFormat
        defaultValue: root.defaults.clockFormat
        onEditingFinished: root.editClockFormat = text
      }
    }
  }

  // ----- Now playing -----
  NBox {
    Layout.fillWidth: true
    Layout.preferredHeight: nowPlayingCol.implicitHeight + Style.marginM * 2
    color: Color.mSurfaceVariant

    ColumnLayout {
      id: nowPlayingCol
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: pluginApi?.tr("settings.now-playing-section")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.show-now-playing")
        description: pluginApi?.tr("settings.show-now-playing-desc")
        checked: root.editShowNowPlaying
        defaultValue: root.defaults.showNowPlaying
        onToggled: checked => root.editShowNowPlaying = checked
      }

      NSpinBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.now-playing-duration")
        description: pluginApi?.tr("settings.now-playing-duration-desc")
        from: 1
        to: 30
        stepSize: 1
        value: root.editNowPlayingDuration
        defaultValue: root.defaults.nowPlayingDuration
        onValueChanged: root.editNowPlayingDuration = value
      }
    }
  }

  // ----- Manual trigger -----
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NButton {
      text: pluginApi?.tr("settings.trigger-now")
      icon: "player-play"
      onClicked: {
        var argv = root.mainInstance ? root.mainInstance._launcherArgv()
                                     : ["niri-screensaver-launch", "launch"]
        triggerNowProcess.command = argv
        triggerNowProcess.running = true
      }
    }
    NButton {
      text: pluginApi?.tr("settings.stop")
      icon: "stop"
      outlined: true
      onClicked: {
        var argv = root.mainInstance ? root.mainInstance._killArgv()
                                     : ["niri-screensaver-launch", "kill"]
        stopNowProcess.command = argv
        stopNowProcess.running = true
      }
    }
  }

  Process {
    id: triggerNowProcess
    onExited: function (code) {
      if (code !== 0) Logger.w("NiriScreensaver", "trigger (Settings) exited with code", code)
    }
  }
  Process {
    id: stopNowProcess
    onExited: function (code) {
      if (code !== 0) Logger.w("NiriScreensaver", "stop (Settings) exited with code", code)
    }
  }

  // ---- Logo directory picker popup ----
  NFilePicker {
    id: logoDirPicker
    title: pluginApi?.tr("settings.logo-dir-picker-title")
    selectionMode: "folders"
    initialPath: (root.editLogoDir && root.editLogoDir !== "")
      ? root.editLogoDir
      : (root.detectedSystemLogoDir || (Quickshell.env("HOME") + "/.local/share/niri-screensaver/logos"))
    onAccepted: paths => {
      if (paths && paths.length > 0) root.editLogoDir = paths[0]
    }
  }

  // ---- TTE effect dropdown (fade-in / fade-out) plumbing ----
  //
  // Shells out to `niri-screensaver-ctl effects` and parses the unique
  // names out of the column-formatted output. The list feeds both fade
  // comboboxes; an empty key ("(none)") maps to no fade.
  Process {
    id: effectsDetectProcess
    stdout: StdioCollector {}
    onExited: function (code) {
      if (code !== 0) {
        Logger.w("NiriScreensaver", "effects detection exited with code", code)
        return
      }
      var text = String(stdout.text).trim()
      if (!text) return
      var seen = {}
      var names = text.split(/\s+/).filter(function (s) {
        if (!s || seen[s]) return false
        seen[s] = true
        return true
      })
      names.sort()
      effectOptions.clear()
      effectOptions.append({key: "", name: pluginApi?.tr("settings.effect-none")})
      for (var i = 0; i < names.length; i++) {
        effectOptions.append({key: names[i], name: names[i]})
      }
    }
  }

  ListModel { id: effectOptions }

  // ---- Logo file dropdown plumbing ----
  //
  // Detect the installed share/logos/ at startup by mirroring the bash
  // DEFAULT_LOGO_CANDIDATES list, then watch that dir (or the user's logoDir
  // override) via FolderListModel. The combobox's model is a ListModel rebuilt
  // from the folder model so we can prepend a "Default" entry and append any
  // out-of-dir editLogoPath the user may already have set.
  Process {
    id: logoDirDetectProcess
    stdout: StdioCollector {}
    onExited: function (code) {
      if (code !== 0) {
        Logger.w("NiriScreensaver", "logo dir detection exited with code", code)
        return
      }
      var p = String(stdout.text).trim()
      if (p !== "") root.detectedSystemLogoDir = p
    }
  }

  FolderListModel {
    id: logoFolderModel
    folder: root.effectiveLogoDir ? ("file://" + root.effectiveLogoDir) : ""
    nameFilters: ["*.txt"]
    showDirs: false
    showHidden: false
    sortField: FolderListModel.Name
    onCountChanged: root._rebuildLogoOptions()
    onStatusChanged: {
      if (status === FolderListModel.Ready) root._rebuildLogoOptions()
    }
  }

  ListModel { id: logoOptions }

  function _rebuildLogoOptions() {
    logoOptions.clear()
    logoOptions.append({key: "", name: pluginApi?.tr("settings.logo-path-default")})
    var seen = {"": true}
    for (var i = 0; i < logoFolderModel.count; i++) {
      var fileName = String(logoFolderModel.get(i, "fileName"))
      var filePath = String(logoFolderModel.get(i, "filePath"))
      var displayName = fileName.replace(/\.txt$/i, "")
      logoOptions.append({key: filePath, name: displayName})
      seen[filePath] = true
    }
    if (root.editLogoPath && !seen[root.editLogoPath]) {
      var orphanName = root.editLogoPath.split("/").pop().replace(/\.txt$/i, "")
      logoOptions.append({key: root.editLogoPath, name: orphanName})
    }
  }

  onEditLogoPathChanged: _rebuildLogoOptions()

  Component.onCompleted: {
    logoDirDetectProcess.command = ["sh", "-c",
      'for d in "$HOME/.local/share/niri-screensaver/logos" "/usr/share/niri-screensaver/logos"; do [ -d "$d" ] && echo "$d" && exit 0; done']
    logoDirDetectProcess.running = true
    _rebuildLogoOptions()

    // Seed the "(none)" entry so the comboboxes have something to show
    // before the effects-detection Process returns.
    effectOptions.append({key: "", name: pluginApi?.tr("settings.effect-none")})
    effectsDetectProcess.command = ["sh", "-c",
      "niri-screensaver-ctl effects 2>/dev/null | tail -n +3 | tr -s ' \\t' '\\n' | grep -v '^$'"]
    effectsDetectProcess.running = true
  }
}
