import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  // ── Prayer data ───────────────────────────────────────────────────────────
  property var    prayerTimings:    null
  property string hijriDateStr:     ""
  property string gregorianDateStr: ""
  property int    hijriDayRaw:      0
  property int    hijriDay:         0
  property int    hijriMonth:       0
  property int    hijriYear:        0
  property string hijriMonthNameEn: ""
  property string hijriMonthNameAr: ""
  property int    hijriMonthDays:   30
  property bool   isRamadan:        hijriMonth === 9

  // ── Fetch state ───────────────────────────────────────────────────────────
  property bool   isLoading:    false
  property bool   hasError:     false
  property string errorMessage: ""
  property string lastFetchDate: ""

  // ── Countdown state ───────────────────────────────────────────────────────
  property int    secondsToNext:  -1
  property string nextPrayerName: ""

  // ── Azan state ────────────────────────────────────────────────────────────
  property bool azanPlaying: false

  // ── Settings ──────────────────────────────────────────────────────────────
  property var cfg:      pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string city:              cfg.city              ?? defaults.city              ?? "London"
  readonly property string country:           cfg.country           ?? defaults.country           ?? "UK"
  readonly property int    method:            cfg.method            ?? defaults.method            ?? 3
  readonly property int    school:            cfg.school            ?? defaults.school            ?? 0
  readonly property bool   showNotifications: cfg.showNotifications ?? defaults.showNotifications ?? true
  readonly property bool   playAzan:          cfg.playAzan          ?? defaults.playAzan          ?? false
  readonly property string azanFile:          cfg.azanFile          ?? defaults.azanFile          ?? "azan1.mp3"
  readonly property int    hijriDayOffset:    cfg.hijriDayOffset    ?? defaults.hijriDayOffset    ?? 0

  onHijriDayOffsetChanged: {
    if (hijriDayRaw > 0) {
      hijriDay = Math.max(1, Math.min(30, hijriDayRaw + hijriDayOffset))
      Logger.d("Mawaqit", "Hijri offset changed, day:", hijriDay)
    }
  }

  onCityChanged:    if (lastFetchDate) Qt.callLater(forceRefresh)
  onCountryChanged: if (lastFetchDate) Qt.callLater(forceRefresh)
  onMethodChanged:  if (lastFetchDate) Qt.callLater(forceRefresh)
  onSchoolChanged:  if (lastFetchDate) Qt.callLater(forceRefresh)

  readonly property var prayerKeys: {
    const base = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    return isRamadan ? ["Imsak"].concat(base) : base
  }
  readonly property var notificationKeys: ["Imsak", "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

  // ── Audio ─────────────────────────────────────────────────────────────────
  // Using paplay instead of QtMultimedia to avoid PipeWire session conflict
  // with the shell's native audio service introduced in v4.7.1
  Process {
    id: azanPlayer
    onExited: {
      root.azanPlaying = false
      Logger.d("Mawaqit", "Azan finished")
    }
  }

  Process {
    id: stopAzanProc
  }

  function preloadAzan() {}
  function playAzanFile(fileName) {
    if (!pluginApi?.pluginDir) return
    const filePath = pluginApi.pluginDir + "/assets/" + fileName
    azanPlayer.exec({
      command: ["paplay", filePath]
    })
    root.azanPlaying = true
  }
  function stopAzanFile() {
    stopAzanProc.exec({
      command: ["bash", "-c", "pkill -f 'paplay.*azan' 2>/dev/null || true"]
    })
    root.azanPlaying = false
  }

  // ── Clock-synced timer ────────────────────────────────────────────────────
  Timer {
    id: syncTimer; repeat: false; running: false
    onTriggered: { onClockTick(); updateTimer.start() }
  }
  property string lastTickMinute: ""
  Timer {
    id: updateTimer; interval: 1000; repeat: true; running: false
    onTriggered: {
      const now = new Date()
      const hhmm = `${now.getHours().toString().padStart(2,"0")}:${now.getMinutes().toString().padStart(2,"0")}`
      if (hhmm !== lastTickMinute) { lastTickMinute = hhmm; onClockTick() }
    }
  }

  function onClockTick() {
    const today = new Date().toISOString().substring(0, 10)
    if (today !== lastFetchDate) fetchOrProcess()
    else { checkPrayerTimes(); updateCountdown() }
  }

  function startSyncedTimer() {
    syncTimer.stop(); updateTimer.stop(); retryTimer.stop()
    checkPrayerTimes(); updateCountdown()
    const now = new Date()
    const secsLeft = now.getSeconds() === 0 ? 0 : (60 - now.getSeconds())
    const ms = Math.max(0, secsLeft * 1000 - now.getMilliseconds())
    if (ms === 0) { onClockTick(); updateTimer.start() }
    else { syncTimer.interval = ms; syncTimer.start() }
  }

  // ── Retry with backoff ────────────────────────────────────────────────────
  property int _retryCount: 0
  readonly property var _retryIntervals: [5, 10, 15, 30, 60]

  Timer {
    id: retryTimer; repeat: false; running: false
    onTriggered: { if (!_xhr) fetchOrProcess() }
  }

  function scheduleRetry() {
    const idx = Math.min(_retryCount, _retryIntervals.length - 1)
    Logger.d("Mawaqit", "Retry", _retryCount + 1, "in", _retryIntervals[idx], "s")
    _retryCount++
    retryTimer.interval = _retryIntervals[idx] * 1000
    retryTimer.restart()
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  property string lastNotifiedMinute: ""

  readonly property var prayerNamesAr: ({
    "Fajr": "الفجر", "Dhuhr": "الظهر", "Asr": "العصر",
    "Maghrib": "المغرب", "Isha": "العشاء", "Imsak": "الإمساك"
  })

  function checkPrayerTimes() {
    if (!prayerTimings) return
    const now = new Date()
    const hhmm = `${now.getHours().toString().padStart(2,"0")}:${now.getMinutes().toString().padStart(2,"0")}`
    if (hhmm === lastNotifiedMinute) return
    for (const key of notificationKeys) {
      if (prayerTimings[key] === hhmm) { lastNotifiedMinute = hhmm; onPrayerTime(key) }
    }
  }

  Process {
    id: notifProcess; running: false
    onExited: notifProcess.running = false
  }

  function sendNotification(title, body) {
    notifProcess.command = ["notify-send", "-a", "Mawaqit", "-u", "critical", "-t", "10000", title, body]
    notifProcess.running = true
  }

  function onPrayerTime(prayerKey) {
    const timeStr = prayerTimings?.[prayerKey] || ""
    if (prayerKey === "Imsak") {
      if (showNotifications) sendNotification("🌙 Imsak — " + timeStr, "حان وقت الإمساك")
      return
    }
    const arName = prayerNamesAr[prayerKey] || prayerKey
    if (showNotifications) sendNotification("🕌 " + prayerKey + " — " + timeStr, "حان الآن موعد صلاة " + arName)
    if (playAzan) playAzanFile(azanFile)
  }

  // ── Cache helpers (pluginSettings as store) ───────────────────────────────
  function saveCache(weekData) {
    try {
      pluginApi.pluginSettings._cacheData      = JSON.stringify(weekData)
      pluginApi.pluginSettings._cacheCity      = city
      pluginApi.pluginSettings._cacheCountry   = country
      pluginApi.pluginSettings._cacheMethod    = String(method)
      pluginApi.pluginSettings._cacheSchool    = String(school)
      pluginApi.pluginSettings._cacheSavedAt   = new Date().toISOString().substring(0, 10)
      pluginApi.saveSettings()
      Logger.d("Mawaqit", "Cache saved:", weekData.length, "days")
    } catch(e) { Logger.w("Mawaqit", "Cache save failed:", e.message) }
  }

  function getTodayFromCache() {
    try {
      const data = cfg._cacheData
      if (!data) return null
      if (cfg._cacheCity    !== city)           return null
      if (cfg._cacheCountry !== country)        return null
      if (cfg._cacheMethod  !== String(method)) return null
      if (cfg._cacheSchool  !== String(school)) return null
      const week = JSON.parse(data)
      if (!week || !week.length) return null
      const today = new Date().toISOString().substring(0, 10)
      for (const entry of week) {
        const parts = entry.date.split("-")
        const iso = `${parts[2]}-${parts[1]}-${parts[0]}`
        if (iso === today) return entry
      }
      return null
    } catch(e) {
      Logger.w("Mawaqit", "Cache read failed:", e.message)
      return null
    }
  }

  // ── Fetch logic ───────────────────────────────────────────────────────────
  property var _xhr: null

  function fetchOrProcess() {
    const cached = getTodayFromCache()
    if (cached) {
      Logger.d("Mawaqit", "Using cached data for today")
      processEntry(cached)
    } else {
      fetchWeek()
    }
  }

  function forceRefresh() {
    try {
      pluginApi.pluginSettings._cacheData = null
      const settings = pluginApi.pluginSettings
      for (const key in settings) { if (key.startsWith("_cal_")) delete settings[key] }
      pluginApi.saveSettings()
    } catch(e) {}
    fetchWeek()
  }

  function fetchPrayerTimes() { forceRefresh() }

  function fetchWeek() {
    if (_xhr) return
    isLoading = true; hasError = false
    const today = new Date()
    const from  = Qt.formatDate(today, "dd-MM-yyyy")
    const toD   = new Date(today); toD.setDate(toD.getDate() + 6)
    const to    = Qt.formatDate(toD, "dd-MM-yyyy")
    const url   = `https://api.aladhan.com/v1/timingsByCity/${from}?city=${encodeURIComponent(city)}&country=${encodeURIComponent(country)}&method=${method}&school=${school}&days=7`
    Logger.d("Mawaqit", "Fetching week from", from, "to", to)

    const xhr = new XMLHttpRequest()
    _xhr = xhr
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      _xhr = null; isLoading = false
      if (xhr.status === 200) {
        try {
          const json = JSON.parse(xhr.responseText)
          if (json.code === 200 && json.data && json.data.length > 0) {
            _retryCount = 0; retryTimer.stop()
            saveCache(json.data)
            const todayStr = new Date().toISOString().substring(0, 10)
            let todayEntry = null
            for (const entry of json.data) {
              const parts = entry.date.split("-")
              const iso = `${parts[2]}-${parts[1]}-${parts[0]}`
              if (iso === todayStr) { todayEntry = entry; break }
            }
            processEntry(todayEntry || json.data[0])
          } else {
            Logger.e("Mawaqit", "API error:", json.status)
            fetchSingleDay()
          }
        } catch(e) {
          Logger.e("Mawaqit", "Parse error:", e.message)
          fetchSingleDay()
        }
      } else if (xhr.status === 0) {
        Logger.e("Mawaqit", "Network unavailable, scheduling retry")
        hasError = !prayerTimings
        errorMessage = pluginApi?.tr("error.network")
        scheduleRetry()
      } else {
        Logger.w("Mawaqit", "HTTP error:", xhr.status)
        fetchSingleDay()
      }
    }
    xhr.open("GET", url)
    xhr.send()
  }

  function fetchSingleDay() {
    if (_xhr) return
    const url = `https://api.aladhan.com/v1/timingsByCity?city=${encodeURIComponent(city)}&country=${encodeURIComponent(country)}&method=${method}&school=${school}`
    const xhr = new XMLHttpRequest()
    _xhr = xhr
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      _xhr = null; isLoading = false
      if (xhr.status === 200) {
        try {
          const json = JSON.parse(xhr.responseText)
          if (json.code === 200 && json.data) {
            _retryCount = 0; retryTimer.stop()
            const entry = {
              date:    json.data.date.gregorian.date,
              timings: json.data.timings,
              hijri:   json.data.date.hijri,
              readable: json.data.date.readable
            }
            processEntry(entry)
          } else {
            onFetchFailed(json.status || "API error")
          }
        } catch(e) { onFetchFailed(e.message) }
      } else if (xhr.status === 0) {
        hasError = !prayerTimings
        errorMessage = pluginApi?.tr("error.network")
        scheduleRetry()
      } else {
        onFetchFailed("HTTP " + xhr.status)
      }
    }
    xhr.open("GET", url)
    xhr.send()
  }

  function onFetchFailed(reason) {
    Logger.e("Mawaqit", "Fetch failed:", reason)
    hasError = !prayerTimings
    errorMessage = pluginApi?.tr("error.network")
    scheduleRetry()
  }

  // ── Process a single day entry from API or cache ──────────────────────────
  function processEntry(entry) {
    try {
      const timings = entry.timings
      const hijri   = entry.hijri || entry.date?.hijri
      const readable = entry.readable || entry.date?.readable || ""

      const cleaned = {}
      for (const key in timings)
        cleaned[key] = timings[key].replace(/\s*\(.*\)/, "").trim()
      prayerTimings = cleaned

      if (hijri) {
        hijriDayRaw      = parseInt(hijri.day)
        hijriDay         = Math.max(1, Math.min(30, hijriDayRaw + hijriDayOffset))
        hijriMonth       = hijri.month.number
        hijriYear        = parseInt(hijri.year)
        hijriMonthNameEn = hijri.month.en
        hijriMonthNameAr = hijri.month.ar
        hijriMonthDays   = parseInt(hijri.month.days) || 30
        hijriDateStr     = hijri.date || ""
      }
      gregorianDateStr = readable
      lastFetchDate    = new Date().toISOString().substring(0, 10)
      hasError         = false

      updateCountdown()
      preloadAzan()
      startSyncedTimer()
      Logger.d("Mawaqit", "Data ready. hijriDay:", hijriDay, "Ramadan:", isRamadan)
    } catch(e) {
      Logger.e("Mawaqit", "processEntry error:", e.message)
      onFetchFailed(e.message)
    }
  }

  // ── Countdown ─────────────────────────────────────────────────────────────
  function updateCountdown() {
    if (!prayerTimings) { secondsToNext = -1; return }
    const now = new Date()
    const gracePeriodMs = 5 * 60 * 1000

    function timeToday(timeStr) {
      if (!timeStr) return null
      const parts = timeStr.split(":")
      const d = new Date(); d.setHours(parseInt(parts[0]), parseInt(parts[1]), 0, 0)
      return d
    }

    const prayers = []
    for (const key of prayerKeys) {
      const t = prayerTimings[key]; if (!t) continue
      const d = timeToday(t); if (d) prayers.push({ name: key, time: d })
    }
    if (prayers.length === 0) { secondsToNext = -1; return }

    for (let i = 0; i < prayers.length; i++) {
      const ms = now - prayers[i].time
      if (ms >= 0 && ms < gracePeriodMs) {
        nextPrayerName = prayers[i].name; secondsToNext = 0; return
      }
    }

    let nextIdx = -1
    for (let i = 0; i < prayers.length; i++) {
      if (prayers[i].time > now) { nextIdx = i; break }
    }

    let next
    if (nextIdx === -1) {
      next = { name: prayers[0].name, time: new Date(prayers[0].time) }
      next.time.setDate(next.time.getDate() + 1)
    } else {
      next = prayers[nextIdx]
    }

    const diff = Math.floor((next.time - now) / 1000)
    nextPrayerName = next.name
    secondsToNext  = diff > 0 ? diff : 0
  }

  // ── Startup ───────────────────────────────────────────────────────────────
  Component.onCompleted: {
    const cached = getTodayFromCache()
    if (cached) {
      Logger.d("Mawaqit", "Cache hit on startup — loading instantly")
      processEntry(cached)
      retryTimer.interval = 5000
      retryTimer.restart()
    } else {
      Logger.d("Mawaqit", "No cache — fetching immediately")
      retryTimer.interval = 500
      retryTimer.restart()
    }
  }
}
