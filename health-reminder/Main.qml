import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property bool sedentaryEnabled: cfg.enableSedentaryReminder ?? defaults.enableSedentaryReminder ?? true
  readonly property bool hydrationEnabled: cfg.enableHydrationReminder ?? defaults.enableHydrationReminder ?? true
  readonly property int sedentaryIntervalMinutes: cfg.sedentaryIntervalMinutes ?? defaults.sedentaryIntervalMinutes ?? 45
  readonly property int hydrationIntervalMinutes: cfg.hydrationIntervalMinutes ?? defaults.hydrationIntervalMinutes ?? 30
  readonly property string sedentaryMessage: cfg.sedentaryMessage ?? defaults.sedentaryMessage ?? pluginApi?.tr("toast.sedentary")
  readonly property string hydrationMessage: cfg.hydrationMessage ?? defaults.hydrationMessage ?? pluginApi?.tr("toast.hydration")
  readonly property bool remindersPaused: cfg.remindersPaused ?? defaults.remindersPaused ?? false
  readonly property bool debugMode: cfg.debugMode ?? defaults.debugMode ?? false
  readonly property var medicationReminders: cfg.medicationReminders ?? defaults.medicationReminders ?? []

  property int nowTimestamp: Math.floor(Date.now() / 1000)
  property int lastSedentaryReminderAt: 0
  property int lastHydrationReminderAt: 0
  property var medicationTriggeredDates: ({})

  readonly property int sedentaryIntervalSeconds: Math.max(1, sedentaryIntervalMinutes) * 60
  readonly property int hydrationIntervalSeconds: Math.max(1, hydrationIntervalMinutes) * 60
  readonly property int pausedAtTimestamp: cfg.pausedAtTimestamp ?? defaults.pausedAtTimestamp ?? 0

  readonly property int sedentaryRemainingSeconds: remainingSeconds(lastSedentaryReminderAt, sedentaryIntervalSeconds, sedentaryEnabled)
  readonly property int hydrationRemainingSeconds: remainingSeconds(lastHydrationReminderAt, hydrationIntervalSeconds, hydrationEnabled)
  readonly property var activeMedicationReminders: normalizedMedicationReminders()

  IpcHandler {
    target: "plugin:health-reminder"

    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => {
          pluginApi.togglePanel(screen);
        });
      }
    }

    function pause() {
      root.setPaused(true);
    }

    function resume() {
      root.setPaused(false);
    }

    function reset() {
      root.resetReminderTimers();
    }

    function testSedentary() {
      root.sendSedentaryReminder(true);
    }

    function testHydration() {
      root.sendHydrationReminder(true);
    }
  }

  Timer {
    id: reminderTimer
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true

    onTriggered: {
      root.nowTimestamp = Math.floor(Date.now() / 1000);
      root.ensureInitialized();
      root.checkReminders();
    }
  }

  function ensureInitialized() {
    if (lastSedentaryReminderAt <= 0) {
      lastSedentaryReminderAt = nowTimestamp;
    }

    if (lastHydrationReminderAt <= 0) {
      lastHydrationReminderAt = nowTimestamp;
    }
  }

  function ensureSettingsObject() {
    if (!pluginApi) {
      return false;
    }

    if (!pluginApi.pluginSettings) {
      pluginApi.pluginSettings = {};
    }

    return true;
  }

  function remainingSeconds(lastTriggerAt, intervalSeconds, enabled) {
    if (!enabled) return 0;
    if (lastTriggerAt <= 0) return intervalSeconds;

    const referenceTimestamp = remindersPaused && pausedAtTimestamp > 0 ? pausedAtTimestamp : nowTimestamp;
    const elapsed = Math.max(0, referenceTimestamp - lastTriggerAt);
    return Math.max(0, intervalSeconds - elapsed);
  }

  function formatDuration(seconds) {
    const total = Math.max(0, seconds);
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const secs = total % 60;

    if (hours > 0) {
      return `${hours.toString().padStart(2, "0")}:${minutes.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
    }

    return `${minutes.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
  }

  function todayKey() {
    const date = new Date(nowTimestamp * 1000);
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, "0")}-${date.getDate().toString().padStart(2, "0")}`;
  }

  function currentClockTime() {
    const date = new Date(nowTimestamp * 1000);
    return `${date.getHours().toString().padStart(2, "0")}:${date.getMinutes().toString().padStart(2, "0")}`;
  }

  function isValidTimeText(value) {
    if (!value || typeof value !== "string") return false;
    return /^([01]\d|2[0-3]):([0-5]\d)$/.test(value.trim());
  }

  function normalizedMedicationReminders() {
    const source = medicationReminders || [];
    const list = [];

    for (let i = 0; i < source.length; i++) {
      const item = source[i] || {};
      const time = (item.time || "").trim();
      if (!isValidTimeText(time)) continue;

      list.push({
        "id": item.id || `med-${i}`,
        "name": item.name || pluginApi?.tr("panel.medication.defaultName"),
        "time": time,
        "enabled": item.enabled !== false,
        "message": item.message || ""
      });
    }

    return list;
  }

  function secondsUntilClockTime(timeText) {
    if (!isValidTimeText(timeText)) return 0;

    const parts = timeText.split(":");
    const hours = parseInt(parts[0], 10);
    const minutes = parseInt(parts[1], 10);
    const now = new Date(nowTimestamp * 1000);
    const next = new Date(now.getTime());
    next.setHours(hours, minutes, 0, 0);

    if (next.getTime() <= now.getTime()) {
      next.setDate(next.getDate() + 1);
    }

    return Math.max(0, Math.floor((next.getTime() - now.getTime()) / 1000));
  }

  function medicationRemainingSeconds(reminder) {
    if (!reminder || reminder.enabled === false) return 0;
    return secondsUntilClockTime(reminder.time);
  }

  function resetReminderTimers() {
    nowTimestamp = Math.floor(Date.now() / 1000);
    lastSedentaryReminderAt = nowTimestamp;
    lastHydrationReminderAt = nowTimestamp;
    medicationTriggeredDates = ({});

    if (ensureSettingsObject()) {
      pluginApi.pluginSettings.pausedAtTimestamp = 0;
    }
  }

  function setPaused(paused) {
    if (!ensureSettingsObject()) return;

    const currentTimestamp = Math.floor(Date.now() / 1000);

    if (paused) {
      pluginApi.pluginSettings.remindersPaused = true;
      pluginApi.pluginSettings.pausedAtTimestamp = currentTimestamp;
      pluginApi.saveSettings();
      return;
    }

    const previousPausedAt = pausedAtTimestamp > 0 ? pausedAtTimestamp : currentTimestamp;
    const pausedDuration = Math.max(0, currentTimestamp - previousPausedAt);

    if (lastSedentaryReminderAt > 0) {
      lastSedentaryReminderAt += pausedDuration;
    }

    if (lastHydrationReminderAt > 0) {
      lastHydrationReminderAt += pausedDuration;
    }

    pluginApi.pluginSettings.remindersPaused = paused;
    pluginApi.pluginSettings.pausedAtTimestamp = 0;
    pluginApi.saveSettings();
  }

  function setReminderEnabled(reminderType, enabled) {
    if (!ensureSettingsObject()) return;

    if (reminderType === "sedentary") {
      pluginApi.pluginSettings.enableSedentaryReminder = enabled;
    } else if (reminderType === "hydration") {
      pluginApi.pluginSettings.enableHydrationReminder = enabled;
    }

    pluginApi.saveSettings();
    resetReminderTimers();
  }

  function setMedicationReminderEnabled(index, enabled) {
    if (!ensureSettingsObject()) return;

    const items = normalizedMedicationReminders().slice();
    if (index < 0 || index >= items.length) return;

    items[index] = {
      "id": items[index].id,
      "name": items[index].name,
      "time": items[index].time,
      "enabled": enabled,
      "message": items[index].message
    };

    pluginApi.pluginSettings.medicationReminders = items;
    pluginApi.saveSettings();
  }

  function checkReminders() {
    if (!remindersPaused) {
      if (sedentaryEnabled && nowTimestamp - lastSedentaryReminderAt >= sedentaryIntervalSeconds) {
        sendSedentaryReminder(false);
      }

      if (hydrationEnabled && nowTimestamp - lastHydrationReminderAt >= hydrationIntervalSeconds) {
        sendHydrationReminder(false);
      }
    }

    checkMedicationReminders();
  }

  function checkMedicationReminders() {
    const currentTime = currentClockTime();
    const dateKey = todayKey();
    const nextTriggeredDates = {};

    for (const key in medicationTriggeredDates) {
      nextTriggeredDates[key] = medicationTriggeredDates[key];
    }

    for (let i = 0; i < activeMedicationReminders.length; i++) {
      const reminder = activeMedicationReminders[i];
      if (!reminder.enabled || reminder.time !== currentTime) continue;
      if (nextTriggeredDates[reminder.id] === dateKey) continue;

      sendMedicationReminder(reminder, false);
      nextTriggeredDates[reminder.id] = dateKey;
    }

    medicationTriggeredDates = nextTriggeredDates;
  }

  function sendSedentaryReminder(isManualTest) {
    if (!isManualTest && !sedentaryEnabled) return;

    const customMessage = (sedentaryMessage || "").trim();

    ToastService.showNotice(
      pluginApi?.tr("toast.title"),
      customMessage !== "" ? customMessage : pluginApi?.tr(isManualTest ? "toast.sedentaryTest" : "toast.sedentary"),
      "armchair"
    );
    lastSedentaryReminderAt = Math.floor(Date.now() / 1000);
  }

  function sendHydrationReminder(isManualTest) {
    if (!isManualTest && !hydrationEnabled) return;

    const customMessage = (hydrationMessage || "").trim();

    ToastService.showNotice(
      pluginApi?.tr("toast.title"),
      customMessage !== "" ? customMessage : pluginApi?.tr(isManualTest ? "toast.hydrationTest" : "toast.hydration"),
      "bottle"
    );
    lastHydrationReminderAt = Math.floor(Date.now() / 1000);
  }

  function sendMedicationReminder(reminder, isManualTest) {
    if (!reminder) return;
    if (!isManualTest && reminder.enabled === false) return;

    const customMessage = (reminder.message || "").trim();
    const body = customMessage !== ""
      ? customMessage
      : pluginApi?.tr(isManualTest ? "toast.medicationTest" : "toast.medication", { "name": reminder.name });

    ToastService.showNotice(
      pluginApi?.tr("toast.title"),
      body,
      "pill-filled"
    );
  }
}
