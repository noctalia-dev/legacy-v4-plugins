function formatDuration(seconds) {
  var total = Number(seconds || 0);
  if (!isFinite(total) || total <= 0) {
    return "";
  }

  var hrs = Math.floor(total / 3600);
  var mins = Math.floor((total % 3600) / 60);
  var secs = Math.floor(total % 60);

  if (hrs > 0) {
    return hrs + ":" + String(mins).padStart(2, "0") + ":" + String(secs).padStart(2, "0");
  }
  return mins + ":" + String(secs).padStart(2, "0");
}

function formatRelativeTime(value) {
  var text = String(value || "").trim();
  if (text.length === 0) {
    return "";
  }

  var timestamp = new Date(text).getTime();
  if (!isFinite(timestamp)) {
    return text;
  }

  var diffMs = Date.now() - timestamp;
  if (!isFinite(diffMs)) {
    return text;
  }
  if (diffMs < 0) {
    diffMs = 0;
  }

  var minutes = Math.floor(diffMs / 60000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return minutes + "m ago";

  var hours = Math.floor(minutes / 60);
  if (hours < 24) return hours + "h ago";

  var days = Math.floor(hours / 24);
  if (days < 7) return days + "d ago";

  return text.slice(0, 10);
}
