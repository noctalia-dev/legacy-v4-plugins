.pragma library

var allowedBadgeKeys = ["type", "dynamic", "music", "reactive", "approved", "resolution", "compatibility"];

function normalizedDefaultOrder(rawOrder) {
  const input = Array.isArray(rawOrder) ? rawOrder : allowedBadgeKeys;
  const output = [];
  for (const raw of input) {
    const key = String(raw || "").trim();
    if (allowedBadgeKeys.indexOf(key) >= 0 && output.indexOf(key) < 0) {
      output.push(key);
    }
  }
  for (const key of allowedBadgeKeys) {
    if (output.indexOf(key) < 0) {
      output.push(key);
    }
  }
  return output;
}

function normalizedDefaultEnabled(rawState) {
  const source = rawState && typeof rawState === "object" ? rawState : ({});
  const output = {};
  for (const key of allowedBadgeKeys) {
    output[key] = source[key] ?? true;
  }
  return output;
}

function normalizeBadgeOrder(rawOrder, fallbackOrder) {
  return normalizedDefaultOrder(Array.isArray(rawOrder) ? rawOrder : fallbackOrder);
}

function normalizeBadgeEnabled(rawState, fallbackState) {
  const fallback = normalizedDefaultEnabled(fallbackState);
  const source = rawState && typeof rawState === "object" ? rawState : fallback;
  const output = {};
  for (const key of allowedBadgeKeys) {
    output[key] = source[key] ?? fallback[key] ?? true;
  }
  return output;
}

function filterVisibleBadgeOrder(order, enabledState, fallbackState) {
  const normalizedOrder = normalizeBadgeOrder(order, allowedBadgeKeys);
  const normalizedEnabled = normalizeBadgeEnabled(enabledState, fallbackState);
  const output = [];
  for (const key of normalizedOrder) {
    if (normalizedEnabled[key]) {
      output.push(key);
    }
  }
  return output;
}

function settingsBadgeLabel(key, tr) {
  const value = String(key || "");
  if (value === "type") return tr ? tr("settings.badges.items.type") : value;
  if (value === "dynamic") return tr ? tr("settings.badges.items.dynamic") : value;
  if (value === "music") return tr ? tr("settings.badges.items.music") : value;
  if (value === "reactive") return tr ? tr("settings.badges.items.reactive") : value;
  if (value === "approved") return tr ? tr("settings.badges.items.approved") : value;
  if (value === "resolution") return tr ? tr("settings.badges.items.resolution") : value;
  if (value === "compatibility") return tr ? tr("settings.badges.items.compatibility") : value;
  return value;
}

function settingsBadgeIcon(key) {
  const value = String(key || "");
  if (value === "type") return "apps";
  if (value === "dynamic") return "player-play";
  if (value === "music") return "volume";
  if (value === "reactive") return "wave-sine";
  if (value === "approved") return "rosette-discount-check";
  if (value === "resolution") return "aspect-ratio";
  if (value === "compatibility") return "settings-cog";
  return "tag";
}

function settingsBadgeDescription(key, tr) {
  const value = String(key || "");
  if (value === "type") return tr ? tr("settings.badges.details.type") : "";
  if (value === "dynamic") return tr ? tr("settings.badges.details.dynamic") : "";
  if (value === "music") return tr ? tr("settings.badges.details.music") : "";
  if (value === "reactive") return tr ? tr("settings.badges.details.reactive") : "";
  if (value === "approved") return tr ? tr("settings.badges.details.approved") : "";
  if (value === "resolution") return tr ? tr("settings.badges.details.resolution") : "";
  if (value === "compatibility") return tr ? tr("settings.badges.details.compatibility") : "";
  return "";
}
