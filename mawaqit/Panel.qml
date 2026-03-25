import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 360 * Style.uiScaleRatio
  readonly property real maxHeight: 680 * Style.uiScaleRatio
  property real contentPreferredHeight: Math.min(contentColumn.implicitHeight + Style.marginL * 2, maxHeight)
  property bool panelReady: false
  Behavior on contentPreferredHeight {
    enabled: panelReady
    NumberAnimation { duration: 180; easing.type: Easing.InOutCubic }
  }
  readonly property bool allowAttach: true

  anchors.fill: parent

  Timer {
    id: readyTimer; interval: 400; repeat: false; running: false
    onTriggered: panelReady = true
  }
  Component.onCompleted: readyTimer.start()

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property bool use12h: Settings.data.location.use12hourFormat

  readonly property var    mainInstance:     pluginApi?.mainInstance
  readonly property var    prayerTimings:    mainInstance?.prayerTimings    ?? null
  readonly property bool   isRamadan:        mainInstance?.isRamadan        ?? false
  readonly property bool   isLoading:        mainInstance?.isLoading        ?? false
  readonly property bool   hasError:         mainInstance?.hasError         ?? false
  readonly property string errorMessage:     mainInstance?.errorMessage     ?? ""
  readonly property int    secondsToNext:    mainInstance?.secondsToNext    ?? -1
  readonly property string nextPrayerName:   mainInstance?.nextPrayerName   ?? ""
  readonly property int    hijriDay:         mainInstance?.hijriDay         ?? 0
  readonly property int    hijriDayRaw:      mainInstance?.hijriDayRaw      ?? hijriDay
  readonly property int    hijriDayOffset:   mainInstance?.hijriDayOffset   ?? 0
  readonly property int    hijriMonth:       mainInstance?.hijriMonth       ?? 0
  readonly property int    hijriYear:        mainInstance?.hijriYear        ?? 0
  readonly property string hijriMonthNameAr: mainInstance?.hijriMonthNameAr ?? ""
  readonly property string hijriMonthNameEn: mainInstance?.hijriMonthNameEn ?? ""
  readonly property int    hijriMonthDays:   mainInstance?.hijriMonthDays   ?? 30
  readonly property string gregorianDateStr: mainInstance?.gregorianDateStr ?? ""

  readonly property bool prayerNow: secondsToNext === 0 && nextPrayerName !== ""

  // ── Week / Jumu'ah ────────────────────────────────────────────────────
  readonly property int  weekStartDay: parseInt(cfg.weekStartDay ?? defaults.weekStartDay ?? 1)
  readonly property bool isJumuah:     new Date().getDay() === 5

  readonly property color countdownColor: {
    if (nextPrayerName === "Imsak"   && isRamadan) return Color.mSecondary
    if (nextPrayerName === "Maghrib" && isRamadan) return Color.mTertiary
    return Color.mPrimary
  }

  // ── Daily Hadith ──────────────────────────────────────────────────────
  readonly property var hadithPool: [
    { text: "إنما الأعمال بالنيات",                                                      src: "البخاري" },
    { text: "المسلم من سلم المسلمون من لسانه ويده",                                      src: "البخاري" },
    { text: "لا يؤمن أحدكم حتى يحب لأخيه ما يحب لنفسه",                                src: "البخاري" },
    { text: "الطهور شطر الإيمان",                                                         src: "مسلم"    },
    { text: "خيركم من تعلم القرآن وعلمه",                                                src: "البخاري" },
    { text: "الدين النصيحة",                                                              src: "مسلم"    },
    { text: "من كان يؤمن بالله واليوم الآخر فليقل خيراً أو ليصمت",                      src: "البخاري" },
    { text: "البر حسن الخلق",                                                             src: "مسلم"    },
    { text: "إن الله رفيق يحب الرفق في الأمر كله",                                       src: "البخاري" },
    { text: "الكلمة الطيبة صدقة",                                                         src: "البخاري" },
    { text: "خير الناس أنفعهم للناس",                                                    src: "الطبراني" },
    { text: "إن الله جميل يحب الجمال",                                                   src: "مسلم"    },
    { text: "أحب الأعمال إلى الله أدومها وإن قل",                                        src: "البخاري" },
    { text: "اتق الله حيثما كنت",                                                         src: "الترمذي" },
    { text: "إن من أحبكم إليّ وأقربكم مني مجلساً يوم القيامة أحاسنكم أخلاقاً",          src: "الترمذي" },
    { text: "من صام رمضان إيماناً واحتساباً غُفر له ما تقدم من ذنبه",                   src: "البخاري" },
    { text: "أفضل الصيام بعد رمضان شهر الله المحرم",                                    src: "مسلم"    },
    { text: "ابتغوا ليلة القدر في الوتر من العشر الأواخر من رمضان",                      src: "البخاري" },
    { text: "تبسمك في وجه أخيك صدقة",                                                    src: "الترمذي" },
    { text: "الصلوات الخمس كفارة لما بينهن ما اجتنبت الكبائر",                           src: "مسلم"    },

    // ── Hisn al-Muslim ────────────────────────────────────────────────
    { text: "أعوذُ بكلماتِ اللهِ التّامّاتِ مِن شرِّ ما خَلَق",                          src: "حصن المسلم" },
    { text: "بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ", src: "حصن المسلم" },
    { text: "سُبْحَانَ اللهِ وَبِحَمْدِهِ",                                               src: "حصن المسلم" },
    { text: "حَسْبِيَ اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ عَلَيهِ تَوَكَّلتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ", src: "حصن المسلم" },
    { text: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالفَقْرِ وَأَعُوذُ بِكَ مِنْ عَذَابِ القَبْرِ لاَ إِلَهَ إِلاَّ أَنْتَ", src: "حصن المسلم" },
    { text: "الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ", src: "حصن المسلم" },
    { text: "بِسْمِ اللهِ تَوَكَّلْتُ عَلَى اللهِ وَلاَ حَوْلَ وَلاَ قُوَّةَ إِلاَّ بِاللهِ", src: "حصن المسلم" },
    { text: "بِسْمِ اللهِ وَالصَّلاَةُ وَالسَّلاَمُ عَلَى رَسُولِ اللهِ اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ", src: "حصن المسلم" },
    { text: "لاَ إِلَهَ إِلاَّ اللهُ العَظِيمُ الحَلِيمُ لاَ إِلَهَ إِلاَّ اللهُ رَبُّ العَرْشِ العَظِيمِ لاَ إِلَهَ إِلاَّ اللهُ رَبُّ السَّمَاوَاتِ وَرَبُّ الأَرْضِ وَرَبُّ العَرْشِ الكَرِيمِ", src: "حصن المسلم" },
    { text: "اللَّهُمَّ لاَ سَهْلَ إِلاَّ مَا جَعَلْتَهُ سَهْلاً وَأَنْتَ تَجْعَلُ الْحَزْنَ إِذَا شِئْتَ سَهْلاً", src: "حصن المسلم" }
  ]

  readonly property var dailyHadith: {
    if (!hadithPool || hadithPool.length === 0) return null
    const now = new Date()
    const start = new Date(now.getFullYear(), 0, 0)
    const dayOfYear = Math.floor((now - start) / 86400000)
    return hadithPool[dayOfYear % hadithPool.length]
  }

  // ── Last 10 nights of Ramadan ─────────────────────────────────────────
  readonly property bool showLast10Nights: {
    if (!isRamadan || prayerTimings === null || hijriDay < 20) return false
    if (hijriDay < 29)   return true
    if (hijriDay === 29) return hijriMonthDays === 30
    return true // day 30
  }

  FontLoader {
    id: decoFont
    source: pluginApi?.pluginDir ? (pluginApi.pluginDir + "/DecoType.ttf") : ""
  }
  readonly property bool decoFontReady: decoFont.status === FontLoader.Ready

  function toArabicNumerals(n) {
    return String(n).replace(/[0-9]/g, d => "٠١٢٣٤٥٦٧٨٩"[d])
  }

  readonly property string hijriDateAr: {
    if (!hijriDay || !hijriMonthNameAr || !hijriYear) return ""
    return `${toArabicNumerals(hijriDay)} ${hijriMonthNameAr.trim()} ${toArabicNumerals(hijriYear)}`
  }

  readonly property string hijriDateEn: {
    if (!hijriDay || !hijriMonthNameEn || !hijriYear) return ""
    return `${hijriDay} ${hijriMonthNameEn} ${hijriYear} AH`
  }

  // ── Islamic events map ─────────────────────────────────────────────────
  readonly property var islamicEvents: ({
    "1-1":  "Islamic New Year",  "1-10": "Ashura",
    "3-12": "Mawlid an-Nabi",   "7-27": "Isra wal Miraj",
    "9-1":  "Start of Ramadan",
    "9-21": "Laylat al-Qadr",  "9-23": "Laylat al-Qadr",
    "9-25": "Laylat al-Qadr",  "9-27": "Laylat al-Qadr",
    "9-29": "Laylat al-Qadr",  "10-1": "Eid al-Fitr",
    "12-9": "Day of Arafah",   "12-10": "Eid al-Adha"
  })

  // ── Arabic names for Islamic events ──────────────────────────────────
  readonly property var islamicEventsAr: ({
    "1-1":  "رأس السنة الهجرية", "1-10": "عاشوراء",
    "3-12": "المولد النبوي",      "7-27": "الإسراء والمعراج",
    "9-1":  "بداية رمضان",
    "9-21": "ليلة القدر",  "9-23": "ليلة القدر",
    "9-25": "ليلة القدر",  "9-27": "ليلة القدر",
    "9-29": "ليلة القدر",  "10-1": "عيد الفطر",
    "12-9": "يوم عرفة",    "12-10": "عيد الأضحى"
  })

  function getEvent(m, d) {
    const key = m + "-" + d
    if (islamicEvents[key]) return islamicEvents[key]
    if ((d === 13 || d === 14 || d === 15) && m !== 9 && m !== 10 && m !== 12) return "Ayyam al-Bid"
    if (d === 29) return "Laylat al-Shakk"
    return ""
  }

  function getEventAr(m, d) {
    const key = m + "-" + d
    if (islamicEventsAr[key]) return islamicEventsAr[key]
    if ((d === 13 || d === 14 || d === 15) && m !== 9 && m !== 10 && m !== 12) return "أيام البيض"
    if (d === 29) return "ليلة الشك"
    return ""
  }

  // ── Hint tiers ────────────────────────────────────────────────────────
  readonly property var hintTier1: ({ "1-1": "Islamic New Year" })
  readonly property var hintTier2: ({
    "1-10": "Ashura", "3-12": "Mawlid an-Nabi",
    "7-27": "Isra wal Miraj", "12-9": "Day of Arafah"
  })
  readonly property var hintTier4: ({
    "9-1":  "Start of Ramadan", "9-20": "Laylat al-Qadr",
    "9-22": "Laylat al-Qadr",  "9-24": "Laylat al-Qadr",
    "9-26": "Laylat al-Qadr",  "9-28": "Laylat al-Qadr",
    "10-1": "Eid al-Fitr",     "12-10": "Eid al-Adha"
  })

  readonly property var arabicGreetings: ({
    "9-1":  "رمضان كريم",
    "10-1": "عيدكم مبارك",
    "12-10": "عيدكم مبارك"
  })

  readonly property var hintNamesAr: ({
    "Islamic New Year": "رأس السنة الهجرية",
    "Ashura":           "عاشوراء",
    "Mawlid an-Nabi":   "المولد النبوي",
    "Isra wal Miraj":   "الإسراء والمعراج",
    "Start of Ramadan": "بداية رمضان",
    "Laylat al-Qadr":   "ليلة القدر",
    "Eid al-Fitr":      "عيد الفطر",
    "Day of Arafah":    "يوم عرفة",
    "Eid al-Adha":      "عيد الأضحى",
    "Ayyam al-Bid":     "أيام البيض"
  })

  function getHintEvent(m, d, daysAway) {
    const key = m + "-" + d
    if (arabicGreetings[key] && daysAway === 0) return { name: arabicGreetings[key], daysAway: 0, tier: 0 }
    if (hintTier1[key] && daysAway <= 7)  return { name: hintNamesAr[hintTier1[key]] || hintTier1[key], daysAway: daysAway, tier: 1 }
    if (hintTier2[key] && daysAway <= 3)  return { name: hintNamesAr[hintTier2[key]] || hintTier2[key], daysAway: daysAway, tier: 2 }
    if ((d === 13 || d === 14 || d === 15) && m !== 9 && m !== 10 && m !== 12 && daysAway <= 3)
      return { name: "أيام البيض", daysAway: daysAway, tier: 3 }
    if (d === 29 && daysAway === 0) return { name: "ليلة الشك", daysAway: 0, tier: 4 }
    if (hintTier4[key] && daysAway === 0) return { name: hintNamesAr[hintTier4[key]] || hintTier4[key], daysAway: 0, tier: 4 }
    return null
  }

  readonly property var upcomingEvent: {
    if (!hijriDay || !hijriMonth || !hijriYear) return null
    const todayKey = hijriMonth + "-" + hijriDay
    if (isJumuah && !arabicGreetings[todayKey]) return { name: "جمعة مباركة", daysAway: 0, tier: 0 }
    let best = null
    let d = hijriDay, m = hijriMonth, y = hijriYear
    let monthLen = hijriMonthDays || ((m % 2 !== 0) ? 30 : 29)
    for (let i = 0; i <= 30; i++) {
      const candidate = getHintEvent(m, d, i)
      if (candidate) {
        if (!best || candidate.daysAway < best.daysAway ||
            (candidate.daysAway === best.daysAway && candidate.tier < best.tier))
          best = candidate
      }
      if (best && best.daysAway === 0 && best.tier <= 2) break
      d++
      if (d > monthLen) {
        d = 1; m++
        if (m > 12) { m = 1; y++ }
        monthLen = (m % 2 !== 0) ? 30 : 29
      }
    }
    return best
  }

  // ── Calendar persistent cache ────────────────────────────────────────
  property var memoryCalCache: ({})

  function saveCalCache(m, y, data) {
    try {
      const key = "_cal_" + y + "_" + m
      pluginApi.pluginSettings[key] = JSON.stringify({ timestamp: Date.now(), data: data })
      pluginApi.saveSettings()
      memoryCalCache[key] = data
    } catch(e) { Logger.w("Mawaqit", "Cal cache save failed:", e.message) }
  }

  function loadCalCache(m, y) {
    try {
      const key = "_cal_" + y + "_" + m
      if (memoryCalCache[key]) return memoryCalCache[key]
      const raw = cfg[key]
      if (!raw) return null
      const entry = JSON.parse(raw)
      if (!entry?.data || !entry?.timestamp) return null
      if (Date.now() - entry.timestamp > 2592000000) return null
      memoryCalCache[key] = entry.data
      return entry.data
    } catch(e) { return null }
  }

  function invalidateCalCache(m, y) {
    try {
      const key = "_cal_" + y + "_" + m
      delete memoryCalCache[key]
      delete pluginApi.pluginSettings[key]
      pluginApi.saveSettings()
    } catch(e) {}
  }

  function pruneCalCache() {
    try {
      const cutoff = Date.now() - 31536000000
      const settings = pluginApi.pluginSettings
      let pruned = 0
      for (const key in settings) {
        if (!key.startsWith("_cal_")) continue
        try {
          const entry = JSON.parse(settings[key])
          if (entry?.timestamp && entry.timestamp < cutoff) { delete settings[key]; delete memoryCalCache[key]; pruned++ }
        } catch(e) { delete settings[key]; pruned++ }
      }
      if (pruned > 0) { pluginApi.saveSettings(); Logger.d("Mawaqit", "Pruned", pruned, "cal cache entries") }
    } catch(e) {}
  }

  function formatLastSynced(timestamp) {
    if (!timestamp) return ""
    const d = new Date(timestamp)
    return "Sync: " + d.toLocaleDateString(undefined, { day: "2-digit", month: "short" })
         + ", " + d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })
  }

  Timer {
    interval: 1000; running: secondsToNext > 0; repeat: true
    onTriggered: {
      mainInstance?.updateCountdown()
      if (mainInstance && mainInstance.secondsToNext === 0)
        mainInstance.checkPrayerTimes()
    }
  }

  function formatTime(rawTime) {
    if (!rawTime) return "--:--"
    if (!use12h) return rawTime
    const parts = rawTime.split(":")
    let h = parseInt(parts[0]); const m = parts[1]
    const ampm = h >= 12 ? "PM" : "AM"; h = h % 12 || 12
    return `${h}:${m} ${ampm}`
  }

  function formatCountdown(secs) {
    if (secs <= 0) return ""
    const h = Math.floor(secs / 3600)
    const m = Math.floor((secs % 3600) / 60)
    const s = secs % 60
    if (h > 0) return `${h}h ${m.toString().padStart(2,"0")}m ${s.toString().padStart(2,"0")}s`
    if (m > 0) return `${m}m ${s.toString().padStart(2,"0")}s`
    return `${s}s`
  }

  readonly property var prayerOrder: [
    { key: "Imsak",   labelKey: "panel.imsak",   icon: "moon"       },
    { key: "Fajr",    labelKey: "panel.fajr",    icon: "sunrise"    },
    { key: "Sunrise", labelKey: "panel.sunrise", icon: "sun"        },
    { key: "Dhuhr",   labelKey: isJumuah ? "panel.jumuah" : "panel.dhuhr", icon: isJumuah ? "sun-high" : "sun-high" },
    { key: "Asr",     labelKey: "panel.asr",     icon: "sun-low"    },
    { key: "Maghrib", labelKey: "panel.maghrib", icon: "sunset"     },
    { key: "Isha",    labelKey: "panel.isha",    icon: "moon-stars" }
  ]

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: contentColumn
      anchors { fill: parent; margins: Style.marginL }
      spacing: Style.marginM

      // ── Header ─────────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true; spacing: Style.marginM
        NIcon { icon: "building-mosque"; pointSize: Style.fontSizeXL; color: Color.mPrimary; Layout.alignment: Qt.AlignVCenter }
        NText { text: pluginApi?.tr("panel.title"); pointSize: Style.fontSizeL; font.weight: Font.Bold; color: Color.mOnSurface; Layout.alignment: Qt.AlignVCenter }
        Item { Layout.fillWidth: true }
        NIconButton {
          icon: "refresh"
          tooltipText: tabBar.currentIndex === 0
            ? pluginApi?.tr("panel.refresh")
            : pluginApi?.tr("calendar.refresh")
          enabled: tabBar.currentIndex === 0 ? !isLoading : !calItem.calLoading
          onClicked: {
            if (tabBar.currentIndex === 0) mainInstance?.fetchPrayerTimes()
            else calItem.fetchCalendar(true)
          }
          Layout.alignment: Qt.AlignVCenter
        }
        NIconButton {
          icon: "settings"; tooltipText: pluginApi?.tr("menu.settings")
          onClicked: { const screen = pluginApi?.panelOpenScreen; if (screen) { pluginApi.closePanel(screen); Qt.callLater(() => BarService.openPluginSettings(screen, pluginApi.manifest)) } }
          Layout.alignment: Qt.AlignVCenter
        }
        NIconButton {
          icon: "x"; tooltipText: pluginApi?.tr("panel.close")
          onClicked: { const screen = pluginApi?.panelOpenScreen; if (screen) pluginApi.closePanel(screen) }
          Layout.alignment: Qt.AlignVCenter
        }
      }

      // ── Date row ───────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true; spacing: Style.marginS
        visible: gregorianDateStr !== ""
        NText { text: gregorianDateStr; pointSize: Style.fontSizeS; color: Color.mSecondary; Layout.alignment: Qt.AlignVCenter }
        Item { Layout.fillWidth: true }
        Text {
          visible: decoFontReady && hijriDateAr !== ""
          text: hijriDateAr; font.family: decoFont.name; font.pointSize: Style.fontSizeXL
          color: isRamadan ? Color.mPrimary : Color.mSecondary
          verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignRight
        }
        NText { visible: !decoFontReady && hijriDateEn !== ""; text: hijriDateEn; pointSize: Style.fontSizeS; color: isRamadan ? Color.mPrimary : Color.mSecondary; Layout.alignment: Qt.AlignVCenter }
      }

      // ── Tab bar ────────────────────────────────────────────────────────
      NTabBar {
        id: tabBar
        Layout.fillWidth: true; distributeEvenly: true
        color: "transparent"
        currentIndex: tabView.currentIndex
        NTabButton { text: pluginApi?.tr("panel.tab.prayers"); tabIndex: 0; checked: tabBar.currentIndex === 0 }
        NTabButton { text: pluginApi?.tr("panel.tab.calendar"); tabIndex: 1; checked: tabBar.currentIndex === 1 }
      }

      // ── Hint banner ────────────────────────────────────────────────────
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: eventHintRow.implicitHeight + Style.marginS * 2
        color: Qt.alpha(Color.mTertiary, 0.10); radius: Style.radiusM
        visible: upcomingEvent !== null
        RowLayout {
          id: eventHintRow
          anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                    leftMargin: Style.marginM; rightMargin: Style.marginM }
          spacing: Style.marginS
          NText {
            text: {
              const d = upcomingEvent?.daysAway ?? -1
              if (d === 0) return pluginApi?.tr("panel.today")
              if (d === 1) return pluginApi?.tr("panel.tomorrow")
              return "in " + d + " days"
            }
            pointSize: Style.fontSizeXS; color: Color.mTertiary; opacity: 0.6
          }
          Item { Layout.fillWidth: true }
          Text {
            text: upcomingEvent?.name ?? ""
            font.family: decoFontReady ? decoFont.name : ""
            font.pointSize: Style.fontSizeM
            color: Color.mTertiary
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignRight
          }
        }
      }

      // ── Tab view ───────────────────────────────────────────────────────
      NTabView {
        id: tabView
        Layout.fillWidth: true
        Layout.preferredHeight: tabBar.currentIndex === 0 ? prayerTab.implicitHeight : calItem.implicitHeight
        currentIndex: tabBar.currentIndex

        onCurrentIndexChanged: {
          if (currentIndex === 1 && !calItem.calReady && hijriDay > 0 && gregorianDateStr !== "")
            Qt.callLater(calItem.initCalendar)
        }

        // ══ Tab 0: Prayer Times ═══════════════════════════════════════════
        ColumnLayout {
          id: prayerTab
          spacing: Style.marginM

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: countdownColumn.implicitHeight + Style.marginM * 2
            color: Qt.alpha(countdownColor, 0.12); radius: Style.radiusL
            visible: prayerTimings !== null && nextPrayerName !== "" && secondsToNext >= 0
            ColumnLayout {
              id: countdownColumn
              anchors.centerIn: parent; spacing: Style.marginXS
              Text {
                Layout.alignment: Qt.AlignHCenter
                visible: prayerNow && decoFontReady
                text: {
                  if (!nextPrayerName) return ""
                  const arNames = { "Fajr": "الفجر", "Dhuhr": isJumuah ? "الجمعة" : "الظهر", "Asr": "العصر",
                    "Maghrib": "المغرب", "Isha": "العشاء", "Imsak": "الإمساك" }
                  const arName = arNames[nextPrayerName] || ""
                  return arName ? `حان الآن موعد صلاة ${arName}` : ""
                }
                font.family: decoFontReady ? decoFont.name : ""; font.pointSize: Style.fontSizeL
                color: countdownColor; horizontalAlignment: Text.AlignHCenter
              }
              NText {
                Layout.alignment: Qt.AlignHCenter
                text: {
                  if (!nextPrayerName) return ""
                  let label = nextPrayerName
                  if (nextPrayerName === "Dhuhr" && isJumuah)
                    label = pluginApi?.tr("panel.jumuah")
                  return prayerNow ? `${label} — ${pluginApi?.tr("panel.now")}` : `${label} in`
                }
                pointSize: Style.fontSizeS; color: countdownColor; opacity: prayerNow ? 0.7 : 1.0
              }
              NText {
                Layout.alignment: Qt.AlignHCenter; visible: !prayerNow
                text: formatCountdown(secondsToNext); pointSize: Style.fontSizeXXL; font.weight: Font.Bold; color: countdownColor
              }
            }
          }

          Item {
            Layout.fillWidth: true; implicitHeight: Style.baseWidgetSize; visible: isLoading || hasError
            NBusyIndicator { anchors.centerIn: parent; visible: isLoading; running: isLoading }
            NText { anchors.centerIn: parent; visible: hasError && !isLoading; text: errorMessage || pluginApi?.tr("error.generic"); color: Color.mError; pointSize: Style.fontSizeS; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; width: parent.width }
          }

          NScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(prayerListColumn.implicitHeight, root.maxHeight * 0.6)
            horizontalPolicy: ScrollBar.AlwaysOff; reserveScrollbarSpace: false
            visible: prayerTimings !== null
            ColumnLayout {
              id: prayerListColumn
              width: parent.width; spacing: Style.marginS
              Repeater {
                model: root.prayerOrder
                delegate: Rectangle {
                  required property var modelData
                  readonly property string rawTime:          prayerTimings?.[modelData.key] || ""
                  readonly property bool   isNext:           modelData.key === nextPrayerName
                  readonly property bool   isImsak:          isRamadan && modelData.key === "Imsak"
                  readonly property bool   isMaghribRamadan: isRamadan && modelData.key === "Maghrib"
                  readonly property color  rowColor:  { if (isNext) return Qt.alpha(countdownColor, 0.15); if (isImsak) return Qt.alpha(Color.mSecondary, 0.08); if (isMaghribRamadan) return Qt.alpha(Color.mTertiary, 0.08); return Color.mSurfaceVariant }
                  readonly property color  itemColor: { if (isNext) return countdownColor; if (isImsak) return Color.mSecondary; if (isMaghribRamadan) return Color.mTertiary; return Color.mOnSurface }
                  readonly property bool   isBold: isNext || isImsak || isMaghribRamadan
                  Layout.fillWidth: true; implicitWidth: parent.width
                  implicitHeight: rowLayout.implicitHeight + Style.marginS * 2
                  radius: Style.radiusM; color: rowColor
                  Behavior on color { ColorAnimation { duration: 300 } }
                  RowLayout {
                    id: rowLayout
                    anchors { fill: parent; leftMargin: Style.marginM; rightMargin: Style.marginM; topMargin: Style.marginS; bottomMargin: Style.marginS }
                    spacing: Style.marginM
                    NIcon { icon: modelData.icon; pointSize: Style.fontSizeM; color: itemColor; Layout.alignment: Qt.AlignVCenter }
                    NText { text: pluginApi?.tr(modelData.labelKey); pointSize: Style.fontSizeM; font.weight: isBold ? Style.fontWeightSemiBold : Style.fontWeightRegular; color: itemColor; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
                    NText { text: rawTime ? formatTime(rawTime) : "—"; pointSize: Style.fontSizeM; font.weight: isBold ? Style.fontWeightBold : Style.fontWeightRegular; color: itemColor; Layout.alignment: Qt.AlignVCenter }
                  }
                }
              }
            }
          }

          Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: prayerTimings === null && !isLoading && !hasError
            ColumnLayout {
              anchors.centerIn: parent; spacing: Style.marginM
              NIcon { icon: "building-mosque"; pointSize: Style.fontSizeXXXL; color: Color.mSecondary; Layout.alignment: Qt.AlignHCenter }
              NText { text: pluginApi?.tr("panel.configure"); color: Color.mSecondary; pointSize: Style.fontSizeM; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter }
            }
          }
        }

        // ══ Tab 1: Calendar ═══════════════════════════════════════════════
        Item {
          id: calItem

          property int  viewMonth:    1
          property int  viewYear:     1446
          property int  viewFirstJDN: 0
          property int  anchorJDN:    0
          property var  calData:      null
          property var  calXhr:       null
          property bool calLoading:   false
          property bool prunedOnce:   false
          readonly property bool calReady:       anchorJDN > 0
          readonly property bool isCurrentMonth: viewMonth === hijriMonth && viewYear === hijriYear

          function toJDN(y, m, d) {
            const a = Math.floor((14 - m) / 12)
            const yy = y + 4800 - a; const mm = m + 12 * a - 3
            return d + Math.floor((153*mm+2)/5) + 365*yy + Math.floor(yy/4) - Math.floor(yy/100) + Math.floor(yy/400) - 32045
          }
          function jdnOffset() {
            const ws = root.weekStartDay
            return (ws + 6) % 7
          }
          function jdnToWeekday(jdn) { return (jdn % 7 - jdnOffset() + 7) % 7 }
          function jumuahColumn() { return (4 - jdnOffset() + 7) % 7 }
          function parseToJDN(str) {
            const mo = {"Jan":1,"Feb":2,"Mar":3,"Apr":4,"May":5,"Jun":6,"Jul":7,"Aug":8,"Sep":9,"Oct":10,"Nov":11,"Dec":12}
            const p = str.split(" "); if (p.length < 3) return 0
            return toJDN(parseInt(p[2]), mo[p[1]], parseInt(p[0]))
          }
          function isLeapHijri(y) { return [2,5,7,10,13,16,18,21,24,26,29].indexOf(y % 30) !== -1 }

          function getDaysInMonth(m, y) {
            if (calItem.calData && calItem.calData.length > 0) return calItem.calData.length
            if (isCurrentMonth) return hijriMonthDays
            if (m === 12) return isLeapHijri(y) ? 30 : 29
            return (m % 2 !== 0) ? 30 : 29
          }

          readonly property int calFirstDayIdx: jdnToWeekday(viewFirstJDN)

          readonly property var monthNamesEn: ["Muharram","Safar","Rabi al-Awwal","Rabi ath-Thani",
            "Jumada al-Ula","Jumada al-Akhira","Rajab","Shaban","Ramadan","Shawwal","Dhu al-Qadah","Dhu al-Hijjah"]

          ListModel { id: dayModel }

          function updateGrid() {
            dayModel.clear()
            const total   = getDaysInMonth(viewMonth, viewYear)
            const firstWD = calFirstDayIdx
            for (let i = 0; i < firstWD; i++)
              dayModel.append({ day: 0, isToday: false, isPast: false, isFriday: false, event: "", greg: "" })
            for (let d = 1; d <= total; d++) {
              const wd     = (firstWD + d - 1) % 7
              const apiIdx = d - 1 - root.hijriDayOffset
              const greg   = (calItem.calData && calItem.calData[apiIdx] && apiIdx >= 0 && apiIdx < calItem.calData.length)
                             ? (calItem.calData[apiIdx].gregorian?.day ?? "") : ""
              dayModel.append({ day: d,
                                isToday:  isCurrentMonth && d === hijriDay,
                                isPast:   isCurrentMonth && d < hijriDay,
                                isFriday: wd === calItem.jumuahColumn(),
                                event:    getEvent(viewMonth, d),
                                greg:     greg })
            }
            const filledCount = dayModel.count
            if (filledCount > 0) {
              const needed = Math.ceil(filledCount / 7) * 7
              for (let p = filledCount; p < needed; p++)
                dayModel.append({ day: 0, isToday: false, isPast: false, isFriday: false, event: "", greg: "" })
            }
          }

          function fetchCalendar(force) {
            const key = "_cal_" + viewYear + "_" + viewMonth
            if (!force && memoryCalCache[key]) { calItem.calData = memoryCalCache[key]; updateGrid(); return }
            if (!force) {
              const cached = loadCalCache(viewMonth, viewYear)
              if (cached) { calItem.calData = cached; updateGrid(); return }
            } else {
              invalidateCalCache(viewMonth, viewYear)
              calItem.calData = null
            }
            if (calItem.calXhr) { calItem.calXhr.abort(); calItem.calXhr = null }
            calItem.calLoading = true
            const m = viewMonth, y = viewYear
            const xhr = new XMLHttpRequest()
            calItem.calXhr = xhr
            xhr.open("GET", `https://api.aladhan.com/v1/hToGCalendar/${m}/${y}`)
            xhr.onreadystatechange = function() {
              if (xhr.readyState !== XMLHttpRequest.DONE) return
              calItem.calXhr = null; calItem.calLoading = false
              if (xhr.status === 200) {
                try {
                  const res = JSON.parse(xhr.responseText)
                  if (res.code === 200 && res.data) {
                    calItem.calData = res.data
                    saveCalCache(m, y, res.data)
                    updateGrid()
                  }
                } catch(e) { Logger.e("Mawaqit", "Cal parse error:", e.message) }
              } else { Logger.e("Mawaqit", "Cal fetch failed HTTP:", xhr.status) }
            }
            xhr.send()
          }

          function initCalendar() {
            if (!gregorianDateStr || hijriDay <= 0 || hijriMonth <= 0) return
            const todayJDN = parseToJDN(gregorianDateStr); if (todayJDN <= 0) return
            const now = new Date()
            const realJDN = toJDN(now.getFullYear(), now.getMonth() + 1, now.getDate())
            if (todayJDN !== realJDN) return
            if (!prunedOnce) { pruneCalCache(); prunedOnce = true }
            anchorJDN    = todayJDN - (hijriDay - 1)
            viewFirstJDN = anchorJDN
            viewMonth    = hijriMonth; viewYear = hijriYear; calItem.calData = null
            updateGrid()
            fetchCalendar(false)
          }

          function navigate(dir) {
            if (!calReady) { initCalendar(); return }
            let m = viewMonth, y = viewYear, jdn = viewFirstJDN
            if (dir === "reset") { jdn = anchorJDN; m = hijriMonth; y = hijriYear }
            else if (dir === "next") {
              const days = getDaysInMonth(m, y); jdn += days
              m++; if (m > 12) { m = 1; y++ }
            } else {
              m--; if (m < 1) { m = 12; y-- }
              jdn -= getDaysInMonth(m, y)
            }
            calItem.calData = null; viewFirstJDN = jdn; viewMonth = m; viewYear = y
            updateGrid(); fetchCalendar(false)
          }

          Connections {
            target: root
            function onHijriDayChanged()         { if (calItem.calReady) Qt.callLater(calItem.initCalendar) }
            function onGregorianDateStrChanged() { if (calItem.calReady) Qt.callLater(calItem.initCalendar) }
            function onHijriDayOffsetChanged()   { if (calItem.calReady) Qt.callLater(calItem.initCalendar) }
            function onHijriYearChanged()        { root.memoryCalCache = ({}) }
            function onHijriMonthChanged()       { root.memoryCalCache = ({}) }
          }

          implicitWidth:  parent.width
          implicitHeight: calReady ? calColumn.implicitHeight : 80 * Style.uiScaleRatio
          width:          parent.width
          height:         implicitHeight

          NBusyIndicator { visible: !calItem.calReady; running: !calItem.calReady; anchors.centerIn: parent }

          ColumnLayout {
            id: calColumn
            width: parent.width; spacing: Style.marginM
            visible: calItem.calReady

            // Nav row
            RowLayout {
              Layout.fillWidth: true
              NIconButton { icon: "chevron-left";  onClicked: calItem.navigate("prev");  Layout.alignment: Qt.AlignVCenter }
              Item { Layout.fillWidth: true }
              ColumnLayout {
                spacing: 1; Layout.alignment: Qt.AlignHCenter
                NText {
                  Layout.alignment: Qt.AlignHCenter
                  text: calItem.monthNamesEn[calItem.viewMonth - 1] + "  " + calItem.viewYear
                  pointSize: Style.fontSizeM; font.weight: Font.Bold
                  color: calItem.viewMonth === 9 ? Color.mPrimary : Color.mOnSurface
                }
                RowLayout {
                  Layout.alignment: Qt.AlignHCenter; spacing: 4; opacity: 0.6
                  NBusyIndicator {
                    visible: calItem.calLoading; running: calItem.calLoading
                    implicitWidth: 10 * Style.uiScaleRatio; implicitHeight: 10 * Style.uiScaleRatio
                  }
                  NIcon {
                    visible: !calItem.calLoading
                    icon: calItem.calData ? "shield-check" : "calculator"
                    pointSize: Style.fontSizeXS * 0.85
                    color: calItem.calData ? Color.mPrimary : Color.mSecondary
                  }
                  NText {
                    text: {
                      if (calItem.calLoading) return "Syncing..."
                      if (!calItem.calData || calItem.calData.length === 0) return ""
                      const f = calItem.calData[0]?.gregorian
                      const l = calItem.calData[calItem.calData.length - 1]?.gregorian
                      if (!f || !l) return ""
                      return f.month?.en === l.month?.en
                        ? f.month.en + " " + f.year
                        : f.month.en + " – " + l.month.en + " " + l.year
                    }
                    pointSize: Style.fontSizeXS; color: Color.mSecondary
                  }
                }
              }
              Item { Layout.fillWidth: true }
              NIconButton { icon: "chevron-right"; onClicked: calItem.navigate("next"); Layout.alignment: Qt.AlignVCenter }
            }

            // Back to today
            NText {
              visible: !calItem.isCurrentMonth
              text: "↩ " + pluginApi?.tr("calendar.today")
              pointSize: Style.fontSizeXS; color: Color.mPrimary; Layout.alignment: Qt.AlignHCenter
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calItem.navigate("reset") }
            }

            // Weekday headers
            Row {
              Layout.fillWidth: true
              Repeater {
                model: {
                  const all = ["Mo","Tu","We","Th","Fr","Sa","Su"]
                  const offset = calItem.jdnOffset()
                  return Array.from({length: 7}, (_, i) => all[(offset + i) % 7])
                }
                delegate: Item {
                  required property string modelData
                  required property int    index
                  width: calColumn.width / 7; height: 20 * Style.uiScaleRatio
                  NText {
                    anchors.centerIn: parent; text: modelData; pointSize: Style.fontSizeXS
                    color: index === calItem.jumuahColumn() ? Color.mPrimary : Color.mSecondary
                    font.weight: Font.Medium
                  }
                }
              }
            }

            NDivider { Layout.fillWidth: true }

            // Day grid
            Grid {
              Layout.fillWidth: true; columns: 7; spacing: 0
              opacity: calItem.calLoading ? 0.6 : 1.0
              Behavior on opacity { NumberAnimation { duration: 200 } }

              Repeater {
                model: dayModel
                delegate: Item {
                  required property var model
                  readonly property real cellSize: calColumn.width / 7
                  width: cellSize; height: cellSize

                  Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 6; height: width; radius: width / 2
                    color: model.isToday ? Color.mPrimary : "transparent"

                    NText {
                      anchors.centerIn: parent
                      text: model.day > 0 ? String(model.day) : ""
                      pointSize: Style.fontSizeS; font.weight: model.isToday ? Font.Bold : Font.Normal
                      color: model.isToday    ? Color.mOnPrimary
                           : model.isPast     ? Qt.alpha(Color.mOnSurface, 0.3)
                           : model.isFriday   ? Color.mPrimary
                           : model.event !== "" ? Color.mTertiary
                           : Color.mOnSurface
                    }

                    Rectangle {
                      visible: model.event !== "" && !model.isToday && model.day > 0
                      width: 4; height: 4; radius: 2
                      color: model.isPast ? Qt.alpha(Color.mTertiary, 0.3) : Color.mTertiary
                      anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                      anchors.horizontalCenter: parent.horizontalCenter
                    }
                  }

                  NText {
                    visible: model.day > 0 && model.greg !== ""
                    anchors.top: parent.top; anchors.right: parent.right
                    anchors.topMargin: 1; anchors.rightMargin: 2
                    text: model.greg; pointSize: Style.fontSizeXS * 0.75
                    color: model.isToday ? Qt.alpha(Color.mOnPrimary, 0.6) : Qt.alpha(Color.mSecondary, 0.6)
                  }

                  MouseArea {
                    anchors.fill: parent; hoverEnabled: model.event !== "" && model.day > 0
                    onEntered: { if (model.event !== "") TooltipService.show(parent, getEventAr(calItem.viewMonth, model.day) || model.event, BarService.getTooltipDirection(pluginApi?.panelOpenScreen?.name)) }
                    onExited: TooltipService.hide()
                  }
                }
              }
            }

            // Today's event
            Text {
              readonly property string todayEvAr: calItem.isCurrentMonth ? getEventAr(hijriMonth, hijriDay) : ""
              visible: todayEvAr !== "" && !root.showLast10Nights
              text: "🌙 " + todayEvAr
              font.family: decoFontReady ? decoFont.name : ""
              font.pointSize: Style.fontSizeM
              color: Color.mTertiary
              horizontalAlignment: Text.AlignHCenter
              Layout.alignment: Qt.AlignHCenter
            }

            // ── Last 10 nights of Ramadan banner ──────────────────────────
            Rectangle {
              visible: calItem.isCurrentMonth && root.showLast10Nights
              Layout.fillWidth: true
              implicitHeight: last10Text.implicitHeight + Style.marginM * 2
              color: Qt.alpha(Color.mPrimary, 0.08); radius: Style.radiusM

              Text {
                id: last10Text
                anchors {
                  left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                  leftMargin: Style.marginM; rightMargin: Style.marginM
                }
                text: "العشر الأواخر\nأفضل ليالي رمضان، فيها ليلة القدر خير من ألف شهر"
                font.family: decoFontReady ? decoFont.name : ""
                font.pointSize: Style.fontSizeM
                color: Color.mPrimary
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
              }
            }

            // Daily Hadith
            ColumnLayout {
              visible: root.dailyHadith !== null && !root.showLast10Nights
              Layout.fillWidth: true
              spacing: 2

              NDivider { Layout.fillWidth: true; opacity: 0.4 }

              Text {
                Layout.fillWidth: true
                text: root.dailyHadith?.text ?? ""
                font.family: decoFontReady ? decoFont.name : ""
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurface
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.85
              }
              NText {
                Layout.alignment: Qt.AlignHCenter
                text: root.dailyHadith?.src ? ("― " + root.dailyHadith.src) : ""
                pointSize: Style.fontSizeXS
                color: Color.mSecondary
                opacity: 0.6
              }
            }

            // Last-synced label
            NText {
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              text: {
                if (calItem.calLoading) return "Syncing..."
                const key = "_cal_" + calItem.viewYear + "_" + calItem.viewMonth
                const raw = cfg[key]
                if (!raw) return ""
                try { return formatLastSynced(JSON.parse(raw).timestamp) } catch(e) { return "" }
              }
              pointSize: Style.fontSizeXS * 0.85
              color: Color.mSecondary
              opacity: 0.5
            }
          }
        }
      }
    }
  }
}
