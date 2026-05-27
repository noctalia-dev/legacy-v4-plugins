.pragma library

function basename(path) {
  const parts = String(path || "").split("/");
  return parts.length > 0 ? parts[parts.length - 1] : "";
}

function fileExt(path) {
  const raw = basename(path);
  const idx = raw.lastIndexOf(".");
  return idx >= 0 ? raw.substring(idx + 1).toLowerCase() : "";
}

function isVideoMotion(path) {
  const ext = fileExt(path);
  return ext === "mp4" || ext === "webm" || ext === "mov" || ext === "mkv";
}

function resolutionBadgeIcon(value) {
  const resolution = String(value || "").toLowerCase().trim();
  if (resolution.length === 0 || resolution === "unknown") {
    return "";
  }

  const match = resolution.match(/(\d+)\s*[x×]\s*(\d+)/);
  if (!match) {
    return "";
  }

  const width = Number(match[1]);
  const height = Number(match[2]);
  if (isNaN(width) || isNaN(height)) {
    return "";
  }

  const longestEdge = Math.max(width, height);
  if (longestEdge >= 7680) {
    return "badge-8k";
  }
  if (longestEdge >= 3840) {
    return "badge-4k";
  }
  return "";
}

function resolutionBadgeLabel(value) {
  const icon = resolutionBadgeIcon(value);
  if (icon === "badge-8k") {
    return "8K";
  }
  if (icon === "badge-4k") {
    return "4K";
  }
  return "";
}

function resolutionFilterKey(value) {
  const resolution = String(value || "").toLowerCase().trim();
  if (resolution.length === 0 || resolution === "unknown") {
    return "unknown";
  }

  const match = resolution.match(/(\d+)\s*[x×]\s*(\d+)/);
  if (!match) {
    return "unknown";
  }

  const width = Number(match[1]);
  const height = Number(match[2]);
  if (isNaN(width) || isNaN(height)) {
    return "unknown";
  }

  const longestEdge = Math.max(width, height);
  if (longestEdge >= 3840) {
    return "4k";
  }
  return "other";
}
