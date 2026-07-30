var UNIT_SECONDS = {
  "s": 1,
  "sec": 1,
  "second": 1,
  "seconds": 1,
  "m": 60,
  "min": 60,
  "minute": 60,
  "minutes": 60,
  "h": 3600,
  "hr": 3600,
  "hour": 3600,
  "hours": 3600,
  "d": 86400,
  "day": 86400,
  "days": 86400,
  "w": 604800,
  "wk": 604800,
  "week": 604800,
  "weeks": 604800
};

var UNSUPPORTED_UNITS = {
  "ms": true,
  "millisecond": true,
  "milliseconds": true,
  "month": true,
  "months": true,
  "year": true,
  "years": true
};

var MAX_FINITE_SECONDS = 52 * 604800;

var DISPLAY_UNITS = [
  ["w", 604800],
  ["d", 86400],
  ["h", 3600],
  ["m", 60],
  ["s", 1]
];

function result(state, code) {
  return {
    "state": state,
    "code": code
  };
}

function formatDuration(seconds) {
  var remaining = Math.max(0, Math.floor(seconds));
  var parts = [];

  for (var index = 0; index < DISPLAY_UNITS.length; index++) {
    var value = Math.floor(remaining / DISPLAY_UNITS[index][1]);
    if (value > 0) {
      parts.push(value + DISPLAY_UNITS[index][0]);
      remaining %= DISPLAY_UNITS[index][1];
    }
  }

  return parts.length > 0 ? parts.join(" ") : "0s";
}

function formatBarDuration(seconds) {
  var remaining = Math.max(0, Math.floor(seconds));
  var parts = [];
  var hasHigherUnit = false;

  for (var index = 0; index < DISPLAY_UNITS.length; index++) {
    var value = Math.floor(remaining / DISPLAY_UNITS[index][1]);
    var isSeconds = index === DISPLAY_UNITS.length - 1;
    if (value > 0 || hasHigherUnit || isSeconds) {
      parts.push(value + DISPLAY_UNITS[index][0]);
      hasHigherUnit = true;
    }
    remaining %= DISPLAY_UNITS[index][1];
  }

  return parts.join(" ");
}

function formatCompactBarDuration(seconds) {
  var remaining = Math.max(0, Math.floor(seconds));
  return formatDuration(Math.max(60, Math.ceil(remaining / 60) * 60));
}

function finalizeDuration(totalSeconds) {
  var effectiveSeconds = Math.floor(totalSeconds + 0.5);
  if (effectiveSeconds < 1)
    return result("invalid", "below-minimum");
  if (effectiveSeconds > MAX_FINITE_SECONDS)
    return result("invalid", "above-maximum");

  return {
    "state": "valid",
    "seconds": effectiveSeconds,
    "normalized": formatDuration(effectiveSeconds)
  };
}

function consumeBoundary(text, position) {
  var start = position;

  while (position < text.length) {
    var rest = text.slice(position);
    var whitespace = rest.match(/^\s+/);
    if (whitespace) {
      position += whitespace[0].length;
      continue;
    }

    var andWord = rest.match(/^and(?=$|\s|[.,+\-\d])/);
    if (andWord) {
      position += andWord[0].length;
      continue;
    }

    if (text[position] === "," || text[position] === "+"
        || text[position] === "-") {
      position++;
      continue;
    }

    break;
  }

  return {
    "position": position,
    "consumed": position > start
  };
}

function parseNamedUnits(text) {
  var position = 0;
  var totalSeconds = 0;
  var componentCount = 0;

  while (position < text.length) {
    if (componentCount > 0) {
      var boundary = consumeBoundary(text, position);
      position = boundary.position;
      if (position >= text.length) {
        return result("incomplete", "missing-component");
      }
    }

    var rest = text.slice(position);
    if (position === 0 && rest[0] === "-")
      return result("invalid", "negative-duration");

    var numberMatch = rest.match(/^(?:\d+(?:[.,]\d+)?|[.,]\d+)/);
    if (!numberMatch) {
      return result(
        "invalid",
        /[\/\\!?;@#$%^&*()[\]{}]/.test(rest[0])
          ? "unexpected-token"
          : "expected-number"
      );
    }

    var quantity = Number(numberMatch[0].replace(",", "."));
    position += numberMatch[0].length;

    var unitSpacing = text.slice(position).match(/^\s*/);
    position += unitSpacing[0].length;
    if (position >= text.length)
      return result("incomplete", "missing-unit");

    var unitMatch = text.slice(position).match(/^[a-z]+/);
    if (!unitMatch)
      return result("invalid", "unexpected-token");

    var unit = unitMatch[0];
    if (UNIT_SECONDS[unit] === undefined && unit.endsWith("and")) {
      var unitBeforeAnd = unit.slice(0, -3);
      if (UNIT_SECONDS[unitBeforeAnd] !== undefined)
        unit = unitBeforeAnd;
    }
    if (UNSUPPORTED_UNITS[unit])
      return result("invalid", "unsupported-unit");
    if (UNIT_SECONDS[unit] === undefined)
      return result("invalid", "unsupported-unit");

    totalSeconds += quantity * UNIT_SECONDS[unit];
    componentCount++;
    position += unit.length;
  }

  return finalizeDuration(totalSeconds);
}

function parseClock(text) {
  if (text[0] === "-")
    return result("invalid", "negative-duration");

  var normalized = text.replace(/\s*:\s*/g, ":");
  if (normalized[normalized.length - 1] === ":")
    return result("incomplete", "missing-clock-field");

  var fields = normalized.split(":");
  if (fields.length !== 2 && fields.length !== 3)
    return result("invalid", "clock-field-count");

  for (var index = 0; index < fields.length; index++) {
    if (fields[index] !== "" && !/^\d+$/.test(fields[index]))
      return result("invalid", "clock-numeric-field");
  }

  var hours = 0;
  var minutes = 0;
  var seconds = 0;

  if (fields.length === 2) {
    if (fields[1] === "")
      return result("incomplete", "missing-clock-field");
    if (fields[1].length > 2)
      return result("invalid", "clock-field-width");

    hours = fields[0] === "" ? 0 : Number(fields[0]);
    minutes = Number(fields[1]);
  } else {
    if (fields[2] === "")
      return result("incomplete", "missing-clock-field");
    if (fields[1] === "" && fields[0] !== "")
      return result("invalid", "clock-empty-field");
    if (fields[1].length > 2 || fields[2].length > 2)
      return result("invalid", "clock-field-width");

    hours = fields[0] === "" ? 0 : Number(fields[0]);
    minutes = fields[1] === "" ? 0 : Number(fields[1]);
    seconds = Number(fields[2]);
  }

  if (minutes >= 60)
    return result("invalid", "clock-minute-range");
  if (seconds >= 60)
    return result("invalid", "clock-second-range");

  return finalizeDuration(hours * 3600 + minutes * 60 + seconds);
}

function parse(expression) {
  var text = expression === null || expression === undefined
    ? ""
    : String(expression).trim().toLowerCase();

  if (text === "")
    return result("incomplete", "empty-expression");

  if (text.indexOf(":") !== -1)
    return parseClock(text);

  return parseNamedUnits(text);
}
