.pragma library

function translate(pluginApi, key, interpolations) {
  return pluginApi ? pluginApi.tr(key, interpolations) : ""
}

function formatDuration(durationMs) {
  const totalSeconds = Math.max(0, Math.floor(Number(durationMs || 0) / 1000))
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60

  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
  }

  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
}

function hasActiveOutputs(state) {
  return Boolean(state && (state.recording || state.replayBuffer || state.streaming))
}

function activeOutputs(pluginApi, state) {
  const outputs = []

  if (state?.recording) {
    outputs.push({
      label: translate(pluginApi, "bar.recording_label"),
      longLabel: translate(pluginApi, "panel.status.recording"),
      durationMs: Number(state.recordDurationMs || 0),
    })
  }

  if (state?.replayBuffer) {
    outputs.push({
      label: translate(pluginApi, "bar.replay_label"),
      longLabel: translate(pluginApi, "panel.status.replay"),
      durationMs: 0,
    })
  }

  if (state?.streaming) {
    outputs.push({
      label: translate(pluginApi, "bar.streaming_label"),
      longLabel: translate(pluginApi, "panel.status.streaming"),
      durationMs: Number(state.streamDurationMs || 0),
    })
  }

  return outputs
}

function activeOutputSummary(pluginApi, state, separator) {
  return activeOutputs(pluginApi, state).map(output => output.longLabel).join(separator || ", ")
}

function primaryIcon(state) {
  if (state?.recording) {
    return "player-record"
  }

  if (state?.streaming) {
    return "antenna-bars-5"
  }

  if (state?.replayBuffer) {
    return "history"
  }

  return ""
}

function accentBackgroundColor(state, Color, fallback) {
  if (state?.recording) {
    return Color.mError
  }

  if (state?.streaming) {
    return Color.mPrimary
  }

  if (state?.replayBuffer) {
    return Color.mSecondary
  }

  return fallback
}

function accentForegroundColor(state, Color, fallback) {
  if (state?.recording) {
    return Color.mOnError
  }

  if (state?.streaming) {
    return Color.mOnPrimary
  }

  if (state?.replayBuffer) {
    return Color.mOnSecondary
  }

  return fallback
}

function barDisplayText(pluginApi, state, barLabelMode, showElapsedInBar) {
  const outputs = activeOutputs(pluginApi, state)

  if (outputs.length === 0 || barLabelMode === "icon-only") {
    return ""
  }

  if (barLabelMode === "duration" && showElapsedInBar) {
    const timedOutputs = outputs.filter(output => output.durationMs > 0)

    if (timedOutputs.length === 1 && outputs.length === 1) {
      return `${timedOutputs[0].label} ${formatDuration(timedOutputs[0].durationMs)}`
    }
  }

  return outputs.map(output => output.label).join(" + ")
}

function shouldShowInBar(state, settings) {
  if (!state || !settings) {
    return false
  }

  return Boolean(
    settings.alwaysShowInBar
    || (state.recording && settings.showBarWhenRecording)
    || (state.replayBuffer && settings.showBarWhenReplay)
    || (state.streaming && settings.showBarWhenStreaming)
  )
}

function shouldShowInControlCenter(state, settings, connected) {
  if (!state || !settings) {
    return false
  }

  return Boolean(
    (state.recording && settings.showControlCenterWhenRecording)
    || (state.replayBuffer && settings.showControlCenterWhenReplay)
    || (state.streaming && settings.showControlCenterWhenStreaming)
    || (connected && settings.showControlCenterWhenReady)
  )
}

function primaryActionText(pluginApi, leftClickAction) {
  if (leftClickAction === "toggle-record") {
    return translate(pluginApi, "actions.primary.toggle_record")
  }

  if (leftClickAction === "toggle-stream") {
    return translate(pluginApi, "actions.primary.toggle_stream")
  }

  return translate(pluginApi, "actions.primary.open_controls")
}

function quickActionTooltip(pluginApi, state, connected, obsRunning, primaryActionLabel) {
  if (hasActiveOutputs(state)) {
    return translate(pluginApi, "control_center.tooltip.active", {
      outputs: activeOutputSummary(pluginApi, state, ", "),
      primaryAction: primaryActionLabel,
    })
  }

  if (connected) {
    return translate(pluginApi, "control_center.tooltip.ready", {
      primaryAction: primaryActionLabel,
    })
  }

  if (obsRunning) {
    return translate(pluginApi, "control_center.tooltip.needs_restart")
  }

  return translate(pluginApi, "control_center.tooltip.offline", {
    primaryAction: primaryActionLabel,
  })
}

function panelHeaderText(pluginApi, state, connected, obsRunning, websocketSupportMissing, websocketConfigMissing) {
  if (hasActiveOutputs(state)) {
    return translate(pluginApi, "panel.header.active", {
      outputs: activeOutputSummary(pluginApi, state, " + "),
    })
  }

  if (connected) {
    return translate(pluginApi, "panel.header.ready")
  }

  if (websocketSupportMissing) {
    return translate(pluginApi, "panel.header.qt_websockets_missing")
  }

  if (websocketConfigMissing) {
    return translate(pluginApi, "panel.header.config_missing")
  }

  if (obsRunning) {
    return translate(pluginApi, "panel.header.needs_restart")
  }

  return translate(pluginApi, "panel.header.offline")
}

function panelStatusText(pluginApi, state, connected, obsRunning, websocketSupportMissing, websocketConfigMissing) {
  if (hasActiveOutputs(state)) {
    return activeOutputSummary(pluginApi, state, " + ")
  }

  if (connected) {
    return translate(pluginApi, "panel.status.ready")
  }

  if (websocketSupportMissing) {
    return translate(pluginApi, "panel.status.qt_websockets_missing")
  }

  if (websocketConfigMissing) {
    return translate(pluginApi, "panel.status.config_missing")
  }

  if (obsRunning) {
    return translate(pluginApi, "panel.status.needs_restart")
  }

  return translate(pluginApi, "panel.status.offline")
}

function panelDisconnectedHint(pluginApi, websocketSupportMissing, websocketConfigMissing) {
  if (websocketSupportMissing) {
    return translate(pluginApi, "panel.status.qt_websockets_missing_hint")
  }

  if (websocketConfigMissing) {
    return translate(pluginApi, "panel.status.config_missing_hint")
  }

  return translate(pluginApi, "panel.status.disconnected_hint")
}

const TOAST_MESSAGES = {
  "record-started": {
    titleKey: "toast.record_started.title",
    bodyKey: "toast.record_started.body",
  },
  "record-started-launch": {
    titleKey: "toast.record_started_launch.title",
    bodyKey: "toast.record_started_launch.body",
  },
  "record-stopped": {
    titleKey: "toast.record_stopped.title",
    bodyKey: "toast.record_stopped.body",
  },
  "record-stopped-autoclose": {
    titleKey: "toast.record_stopped_autoclose.title",
    bodyKey: "toast.record_stopped_autoclose.body",
  },
  "stream-started": {
    titleKey: "toast.stream_started.title",
    bodyKey: "toast.stream_started.body",
  },
  "stream-started-launch": {
    titleKey: "toast.stream_started_launch.title",
    bodyKey: "toast.stream_started_launch.body",
  },
  "stream-stopped": {
    titleKey: "toast.stream_stopped.title",
    bodyKey: "toast.stream_stopped.body",
  },
  "stream-stopped-autoclose": {
    titleKey: "toast.stream_stopped_autoclose.title",
    bodyKey: "toast.stream_stopped_autoclose.body",
  },
  "replay-started": {
    titleKey: "toast.replay_started.title",
    bodyKey: "toast.replay_started.body",
  },
  "replay-started-launch": {
    titleKey: "toast.replay_started_launch.title",
    bodyKey: "toast.replay_started_launch.body",
  },
  "replay-stopped": {
    titleKey: "toast.replay_stopped.title",
    bodyKey: "toast.replay_stopped.body",
  },
  "replay-stopped-autoclose": {
    titleKey: "toast.replay_stopped_autoclose.title",
    bodyKey: "toast.replay_stopped_autoclose.body",
  },
  "replay-saved": {
    titleKey: "toast.replay_saved.title",
    bodyKey: "toast.replay_saved.body",
  },
  offline: {
    titleKey: "toast.offline.title",
    bodyKey: "toast.offline.body",
  },
}

function toastPayload(pluginApi, payload) {
  if (!payload) {
    return { title: "", body: "" }
  }

  const message = TOAST_MESSAGES[payload.event]

  if (!message) {
    return {
      title: payload.title || "",
      body: payload.body || "",
    }
  }

  return {
    title: translate(pluginApi, message.titleKey),
    body: translate(pluginApi, message.bodyKey),
  }
}
