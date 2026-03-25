import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string valueCity:              cfg.city              ?? defaults.city              ?? "London"
  property string valueCountry:           cfg.country           ?? defaults.country           ?? "UK"
  property int    valueMethod:            cfg.method            ?? defaults.method            ?? 3
  property int    valueSchool:            cfg.school            ?? defaults.school            ?? 0
  property bool   valueShowCountdown:     cfg.showCountdown     ?? defaults.showCountdown     ?? true
  property bool   valueShowNotifications: cfg.showNotifications ?? defaults.showNotifications ?? true
  property bool   valuePlayAzan:          cfg.playAzan          ?? defaults.playAzan          ?? false
  property string valueAzanFile:          cfg.azanFile          ?? defaults.azanFile          ?? "azan1.mp3"
  property int    valueHijriDayOffset:    cfg.hijriDayOffset    ?? defaults.hijriDayOffset    ?? 0
  property int    valueWeekStartDay:      cfg.weekStartDay      ?? defaults.weekStartDay      ?? 1

  property bool previewing: false

  spacing: Style.marginL

  // ── Location ──────────────────────────────────────────────────────────────

  NHeader {
    label: pluginApi?.tr("settings.location.header")
    description: pluginApi?.tr("settings.location.desc")
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.city.label")
    description: pluginApi?.tr("settings.city.desc")
    placeholderText: "London"
    text: root.valueCity
    onTextChanged: root.valueCity = text
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.country.label")
    description: pluginApi?.tr("settings.country.desc")
    placeholderText: "UK"
    text: root.valueCountry
    onTextChanged: root.valueCountry = text
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.method.label")
    description: pluginApi?.tr("settings.method.desc")
    currentKey: String(root.valueMethod)
    model: [
      { "key": "1",  "name": "University of Islamic Sciences, Karachi" },
      { "key": "2",  "name": "Islamic Society of North America (ISNA)" },
      { "key": "3",  "name": "Muslim World League (MWL)" },
      { "key": "4",  "name": "Umm Al-Qura University, Makkah" },
      { "key": "5",  "name": "Egyptian General Authority of Survey" },
      { "key": "7",  "name": "Institute of Geophysics, Tehran" },
      { "key": "8",  "name": "Gulf Region" },
      { "key": "9",  "name": "Kuwait" },
      { "key": "10", "name": "Qatar" },
      { "key": "11", "name": "Majlis Ugama Islam Singapura" },
      { "key": "12", "name": "Union Organization Islamic de France" },
      { "key": "13", "name": "Diyanet İşleri Başkanlığı, Turkey" },
      { "key": "14", "name": "Spiritual Administration of Muslims of Russia" },
      { "key": "15", "name": "Moonsighting Committee Worldwide" },
      { "key": "16", "name": "Dubai (Experimental)" }
    ]
    onSelected: key => root.valueMethod = parseInt(key)
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.school.label")
    description: pluginApi?.tr("settings.school.desc")
    currentKey: String(root.valueSchool)
    model: [
      { "key": "0", "name": "Shafi / Maliki / Hanbali (Default)" },
      { "key": "1", "name": "Hanafi" }
    ]
    onSelected: key => root.valueSchool = parseInt(key)
  }

  NDivider { Layout.fillWidth: true }

  // ── Calibration ───────────────────────────────────────────────────────────

  NHeader {
    label: pluginApi?.tr("settings.calibration.header")
    description: pluginApi?.tr("settings.calibration.desc")
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.hijriDayOffset.label")
    description: pluginApi?.tr("settings.hijriDayOffset.desc")
    currentKey: String(root.valueHijriDayOffset)
    model: [
      { "key": "-1", "name": "−1 day" },
      { "key": "0",  "name": "Default (from API)" },
      { "key": "1",  "name": "+1 day" }
    ]
    onSelected: key => root.valueHijriDayOffset = parseInt(key)
  }

  NDivider { Layout.fillWidth: true }

  // ── Calendar ──────────────────────────────────────────────────────────────

  NHeader {
    label: pluginApi?.tr("settings.calendar.header")
    Layout.bottomMargin: -Style.marginM
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.weekStartDay.label")
    description: pluginApi?.tr("settings.weekStartDay.desc")
    currentKey: String(root.valueWeekStartDay)
    model: [
      { "key": "6", "name": "Saturday" },
      { "key": "0", "name": "Sunday"   },
      { "key": "1", "name": "Monday"   }
    ]
    onSelected: key => root.valueWeekStartDay = parseInt(key)
  }

  NDivider { Layout.fillWidth: true }

  // ── Display ───────────────────────────────────────────────────────────────

  NHeader {
    label: pluginApi?.tr("settings.display.header")
    Layout.bottomMargin: -Style.marginM
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showCountdown.label")
    description: pluginApi?.tr("settings.showCountdown.desc")
    checked: root.valueShowCountdown
    onToggled: checked => root.valueShowCountdown = checked
  }

  NDivider { Layout.fillWidth: true }

  // ── Notifications ─────────────────────────────────────────────────────────

  NHeader {
    label: pluginApi?.tr("settings.notifications.header")
    Layout.bottomMargin: -Style.marginM
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showNotifications.label")
    description: pluginApi?.tr("settings.notifications.desc")
    checked: root.valueShowNotifications
    onToggled: checked => root.valueShowNotifications = checked
  }

  NDivider { Layout.fillWidth: true }

  // ── Azan ──────────────────────────────────────────────────────────────────

  NHeader {
    label: pluginApi?.tr("settings.azan.header")
    Layout.bottomMargin: -Style.marginM
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.playAzan.label")
    description: pluginApi?.tr("settings.azan.desc")
    checked: root.valuePlayAzan
    onToggled: checked => {
      root.valuePlayAzan = checked
      if (!checked && root.previewing) {
        pluginApi?.mainInstance?.stopAzanFile()
        root.previewing = false
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    visible: root.valuePlayAzan
    spacing: Style.marginM
    Layout.alignment: Qt.AlignVCenter

    NComboBox {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.azanFile.label")
      description: pluginApi?.tr("settings.azanFile.desc")
      currentKey: root.valueAzanFile
      model: [
        { "key": "azan1.mp3", "name": pluginApi?.tr("settings.azan1") },
        { "key": "azan2.mp3", "name": pluginApi?.tr("settings.azan2") },
        { "key": "azan3.mp3", "name": pluginApi?.tr("settings.azan3") }
      ]
      onSelected: key => {
        root.valueAzanFile = key
        if (root.previewing) {
          pluginApi?.mainInstance?.stopAzanFile()
          Qt.callLater(() => pluginApi?.mainInstance?.playAzanFile(root.valueAzanFile))
        }
      }
    }

    NIconButton {
      Layout.alignment: Qt.AlignBottom
      Layout.bottomMargin: Style.marginS
      Layout.preferredHeight: Math.round(Style.baseWidgetSize * 1.1 * Style.uiScaleRatio)
      Layout.preferredWidth: Math.round(Style.baseWidgetSize * 1.1 * Style.uiScaleRatio)
      icon: root.previewing ? "player-stop-filled" : "player-play-filled"
      tooltipText: root.previewing
        ? pluginApi?.tr("settings.azan.stop")
        : pluginApi?.tr("settings.azan.preview")
      onClicked: {
        const main = pluginApi?.mainInstance
        if (!main) return
        if (root.previewing) {
          main.stopAzanFile()
          root.previewing = false
        } else {
          main.playAzanFile(root.valueAzanFile)
          root.previewing = true
        }
      }
    }
  }

  Connections {
    target: pluginApi?.mainInstance ?? null
    function onAzanPlayingChanged() {
      if (pluginApi?.mainInstance && !pluginApi.mainInstance.azanPlaying)
        root.previewing = false
    }
  }

  function saveSettings() {
    if (!pluginApi) return
    if (root.previewing) {
      pluginApi?.mainInstance?.stopAzanFile()
      root.previewing = false
    }
    pluginApi.pluginSettings.city              = root.valueCity.trim()
    pluginApi.pluginSettings.country           = root.valueCountry.trim()
    pluginApi.pluginSettings.method            = root.valueMethod
    pluginApi.pluginSettings.showCountdown     = root.valueShowCountdown
    pluginApi.pluginSettings.showNotifications = root.valueShowNotifications
    pluginApi.pluginSettings.playAzan          = root.valuePlayAzan
    pluginApi.pluginSettings.azanFile          = root.valueAzanFile
    pluginApi.pluginSettings.school            = root.valueSchool
    pluginApi.pluginSettings.hijriDayOffset    = root.valueHijriDayOffset
    pluginApi.pluginSettings.weekStartDay      = root.valueWeekStartDay
    pluginApi.saveSettings()
    Logger.d("Mawaqit", "Settings saved")
  }
}
