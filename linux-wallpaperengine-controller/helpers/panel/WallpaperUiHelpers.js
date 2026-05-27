.pragma library

function typeLabel(value, tr) {
  const key = String(value || "all").toLowerCase();
  if (key === "scene") return tr ? tr("panel.typeScene") : key;
  if (key === "video") return tr ? tr("panel.typeVideo") : key;
  if (key === "web") return tr ? tr("panel.typeWeb") : key;
  if (key === "application") return tr ? tr("panel.typeApplication") : key;
  return tr ? tr("panel.filterAll") : key;
}

function typeBadgeIcon(value) {
  const key = String(value || "all").toLowerCase();
  if (key === "scene") return "photo";
  if (key === "video") return "video";
  if (key === "web") return "globe";
  if (key === "application") return "apps";
  return "category";
}

function dynamicBadgeIcon(isDynamic) {
  return isDynamic ? "player-play" : "player-stop";
}

function sortLabel(value, tr) {
  if (value === "date") return tr ? tr("panel.sortDateAdded") : value;
  if (value === "size") return tr ? tr("panel.sortSize") : value;
  if (value === "recent") return tr ? tr("panel.sortRecent") : value;
  return tr ? tr("panel.sortName") : value;
}

function resolutionFilterLabel(value, tr) {
  if (value === "4k") return tr ? tr("panel.filterRes4k") : value;
  if (value === "unknown") return tr ? tr("panel.filterResUnknown") : value;
  return tr ? tr("panel.filterResAll") : value;
}
