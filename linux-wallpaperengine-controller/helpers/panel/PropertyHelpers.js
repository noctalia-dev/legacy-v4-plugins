.pragma library

function stripHtml(rawText) {
  return String(rawText || "")
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;?/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizePropertyLabel(value, translatePropertyLabelKey) {
  const raw = String(value || "").trim();
  if (raw.length === 0) {
    return "";
  }

  const looksLikeKey = /^[a-z0-9_]+$/i.test(raw) && raw.indexOf("_") >= 0;
  if (!looksLikeKey) {
    return raw;
  }

  const normalizedKey = raw
    .replace(/^ui_browse_properties_/i, "")
    .replace(/^ui_/i, "")
    .replace(/^properties_/i, "");

  if (normalizedKey.toLowerCase() === "scheme_color" && translatePropertyLabelKey) {
    return translatePropertyLabelKey("panel.propertyLabelThemeColor");
  }

  return normalizedKey
    .split("_")
    .filter(part => part.length > 0)
    .map(part => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(" ");
}

function cleanedPropertyLabel(rawText, fallbackKey, translatePropertyLabelKey) {
  const stripped = stripHtml(rawText)
    .replace(/^[\-–—•·*_#\s]+/, "")
    .replace(/^[^\p{L}\p{N}]+/u, "")
    .trim();
  if (stripped.length > 0) {
    return normalizePropertyLabel(stripped, translatePropertyLabelKey);
  }
  return normalizePropertyLabel(String(fallbackKey || ""), translatePropertyLabelKey);
}

function extractImageSourcesFromHtml(rawText) {
  const html = String(rawText || "");
  const sources = [];
  const imageRegex = /<img\b[^>]*\bsrc\s*=\s*['"]?([^'" >]+)[^>]*>/gi;
  let match;
  while ((match = imageRegex.exec(html)) !== null) {
    const source = String(match[1] || "").trim();
    if (source.length > 0) {
      sources.push(source);
    }
  }
  return sources;
}

function isNoisePropertyKey(value) {
  const key = String(value || "").toLowerCase().trim();
  if (key.length === 0) {
    return true;
  }
  return key.indexOf("imgsrc") === 0
    || key.indexOf("brahref") === 0
    || key.indexOf("centerbrahref") === 0
    || key.indexOf("bigweixin") === 0
    || key.indexOf("viewer_4") >= 0
    || key.indexOf("photogz") >= 0
    || key.indexOf("mqpic") >= 0
    || key.indexOf("width") >= 0 && key.indexOf("height") >= 0;
}

function isNoisePropertyLabel(value) {
  const label = String(value || "").toLowerCase().trim();
  if (label.length === 0) {
    return true;
  }
  return label.indexOf("imgsrc") >= 0
    || label.indexOf("photogz") >= 0
    || label.indexOf("mqpic") >= 0
    || label.indexOf("viewer_4") >= 0;
}

function comboChoicesFor(definition) {
  const rawChoices = definition && definition.choices || [];
  const normalized = [];
  for (let i = 0; i < rawChoices.length; i++) {
    const choice = rawChoices[i];
    const key = String(choice && (choice.key ?? choice.value) || "").trim();
    const name = String(choice && (choice.name ?? choice.label ?? choice.text) || key).trim();
    if (key.length === 0) {
      continue;
    }
    normalized.push({ key: key, name: name.length > 0 ? name : key });
  }
  return normalized;
}

function numberOr(value, fallback) {
  const parsed = Number(value);
  return isNaN(parsed) ? fallback : parsed;
}

function formatSliderValue(value, step) {
  const numericValue = numberOr(value, 0);
  const numericStep = Math.max(numberOr(step, 1), 0.001);
  let decimals = 0;
  if (numericStep < 1) {
    const stepText = String(numericStep);
    if (stepText.indexOf("e-") >= 0) {
      decimals = Number(stepText.split("e-")[1]) || 0;
    } else if (stepText.indexOf(".") >= 0) {
      decimals = stepText.split(".")[1].length;
    }
  }
  return numericValue.toFixed(Math.min(decimals, 6));
}

function parsePropertyValue(rawValue, type, createColor) {
  const trimmed = String(rawValue || "").trim();
  if (type === "boolean") {
    return trimmed === "1";
  }
  if (type === "slider") {
    const parsed = Number(trimmed);
    return isNaN(parsed) ? 0 : parsed;
  }
  if (type === "combo") {
    return String(trimmed);
  }
  if (type === "textinput" || type === "scene texture") {
    return trimmed.replace(/^"|"$/g, "");
  }
  if (type === "color") {
    const hexMatch = trimmed.match(/^#?([0-9a-f]{6}|[0-9a-f]{8})$/i);
    if (hexMatch && createColor) {
      const hex = hexMatch[1];
      const hasAlpha = hex.length === 8;
      const r = parseInt(hex.substring(0, 2), 16) / 255;
      const g = parseInt(hex.substring(2, 4), 16) / 255;
      const b = parseInt(hex.substring(4, 6), 16) / 255;
      const a = hasAlpha ? parseInt(hex.substring(6, 8), 16) / 255 : 1;
      return createColor(r, g, b, a);
    }

    const parts = trimmed.split(",").map(part => Number(String(part).trim()));
    if (parts.length >= 3 && parts.every(part => !isNaN(part))) {
      const maxChannel = Math.max(parts[0], parts[1], parts[2]);
      const alphaValue = parts.length >= 4 ? parts[3] : 1;
      if (createColor) {
        if (maxChannel > 1) {
          return createColor(
            parts[0] / 255,
            parts[1] / 255,
            parts[2] / 255,
            alphaValue > 1 ? alphaValue / 255 : alphaValue
          );
        }
        return createColor(parts[0], parts[1], parts[2], alphaValue);
      }
    }
    return createColor ? createColor(1, 1, 1, 1) : trimmed;
  }
  return trimmed;
}

function serializePropertyValue(value, type) {
  if (type === "boolean") {
    return value ? "1" : "0";
  }
  if (type === "slider") {
    return String(value);
  }
  if (type === "combo") {
    return String(value);
  }
  if (type === "textinput" || type === "scene texture") {
    return String(value);
  }
  if (type === "color") {
    const color = value;
    const r = Math.round((color && color.r !== undefined ? color.r : 1) * 255);
    const g = Math.round((color && color.g !== undefined ? color.g : 1) * 255);
    const b = Math.round((color && color.b !== undefined ? color.b : 1) * 255);
    const a = Math.round((color && color.a !== undefined ? color.a : 1) * 255);
    if (a < 255) {
      return String(r) + "," + String(g) + "," + String(b) + "," + String(a);
    }
    return String(r) + "," + String(g) + "," + String(b);
  }
  return String(value);
}

function ensureColorValue(value, parseColorValue, createColor) {
  if (value === undefined || value === null || value === "") {
    return createColor ? createColor(1, 1, 1, 1) : value;
  }
  if (typeof value === "string") {
    return parseColorValue ? parseColorValue(value, "color") : value;
  }
  if (value.r !== undefined && value.g !== undefined && value.b !== undefined) {
    return createColor ? createColor(value.r, value.g, value.b, value.a !== undefined ? value.a : 1) : value;
  }
  return createColor ? createColor(1, 1, 1, 1) : value;
}

function isWritablePropertyType(type) {
  const normalizedType = String(type || "").toLowerCase().trim();
  return normalizedType === "boolean"
    || normalizedType === "slider"
    || normalizedType === "combo"
    || normalizedType === "textinput"
    || normalizedType === "color";
}

function resolvePropertyImageSource(rawValue, wallpaperPath) {
  const value = String(rawValue || "").trim().replace(/^"|"$/g, "");
  if (value.length === 0) {
    return "";
  }
  if (/^(https?:\/\/|file:\/\/|qrc:\/|data:|image:)/i.test(value)) {
    return value;
  }
  if (value.charAt(0) === "/") {
    return "file://" + value;
  }

  const normalizedWallpaperPath = String(wallpaperPath || "").trim().replace(/\/+$/g, "");
  if (normalizedWallpaperPath.length === 0) {
    return value;
  }
  return "file://" + normalizedWallpaperPath + "/" + value.replace(/^\.?\//, "");
}

function parseWallpaperPropertiesOutput(rawText, helpers) {
  const lines = String(rawText || "").split(/\r?\n/);
  const definitions = [];
  const helperApi = helpers || ({});
  const translatePropertyLabelKey = helperApi.translatePropertyLabelKey;
  const createColor = helperApi.createColor;
  let current = null;
  let parsingValues = false;

  function commitCurrent() {
    if (!current) {
      return;
    }
    if (["boolean", "slider", "combo", "textinput", "scene texture", "color", "text"].indexOf(current.type) === -1) {
      current = null;
      parsingValues = false;
      return;
    }

    const rawLabel = String(current.label || "");
    const imageSources = extractImageSourcesFromHtml(rawLabel);
    current.label = cleanedPropertyLabel(rawLabel, current.key, translatePropertyLabelKey);
    if (imageSources.length > 0) {
      const displayLabel = isNoisePropertyKey(current.key) || isNoisePropertyLabel(current.label)
        ? ""
        : current.label;
      for (let imageIndex = 0; imageIndex < imageSources.length; imageIndex++) {
        const imageSource = String(imageSources[imageIndex] || "").trim();
        if (imageSource.length === 0) {
          continue;
        }
        definitions.push({
          key: current.key + "#image" + String(imageIndex),
          type: "image",
          label: displayLabel,
          defaultValue: imageSource,
          imageSource: imageSource
        });
      }
      current = null;
      parsingValues = false;
      return;
    }

    if (current.type === "text") {
      if (current.label.length === 0 || isNoisePropertyLabel(current.label)) {
        current = null;
        parsingValues = false;
        return;
      }
      definitions.push({
        key: current.key,
        type: "text",
        label: current.label,
        defaultValue: ""
      });
      current = null;
      parsingValues = false;
      return;
    }

    if (current.type === "scene texture") {
      const imageSource = String(current.defaultValue || "").trim().replace(/^"|"$/g, "");
      if (imageSource.length > 0) {
        definitions.push({
          key: current.key,
          type: "image",
          label: current.label,
          defaultValue: imageSource,
          imageSource: imageSource
        });
      }
      current = null;
      parsingValues = false;
      return;
    }

    if (isNoisePropertyKey(current.key) || isNoisePropertyLabel(current.label)) {
      current = null;
      parsingValues = false;
      return;
    }

    definitions.push(current);
    current = null;
    parsingValues = false;
  }

  for (const rawLine of lines) {
    const line = String(rawLine || "");
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      commitCurrent();
      continue;
    }

    if (trimmed.indexOf("Unknown object type found:") === 0
        || trimmed.indexOf("ScriptEngine [evaluate]:") === 0
        || trimmed.indexOf("Text objects are not supported yet") === 0
        || trimmed.indexOf("Applying override value for ") === 0) {
      continue;
    }

    const headerMatch = trimmed.match(/^([^\s].*?)\s+-\s+(slider|boolean|combo|textinput|color|text|scene texture)$/i);
    if (headerMatch) {
      commitCurrent();
      current = {
        key: headerMatch[1].trim(),
        type: headerMatch[2].toLowerCase(),
        label: undefined,
        min: undefined,
        max: undefined,
        step: undefined,
        defaultValue: "",
        choices: []
      };
      parsingValues = false;
      continue;
    }

    if (!current) {
      continue;
    }

    if (trimmed.indexOf("Text:") === 0) {
      current.label = trimmed.substring(5).trim();
      parsingValues = false;
      continue;
    }
    if (trimmed.indexOf("Min:") === 0) {
      const parsedMin = Number(trimmed.substring(4).trim());
      current.min = isNaN(parsedMin) ? undefined : parsedMin;
      parsingValues = false;
      continue;
    }
    if (trimmed.indexOf("Max:") === 0) {
      const parsedMax = Number(trimmed.substring(4).trim());
      current.max = isNaN(parsedMax) ? undefined : parsedMax;
      parsingValues = false;
      continue;
    }
    if (trimmed.indexOf("Step:") === 0) {
      const parsedStep = Number(trimmed.substring(5).trim());
      current.step = isNaN(parsedStep) ? undefined : parsedStep;
      parsingValues = false;
      continue;
    }
    if (trimmed.indexOf("Value:") === 0) {
      current.defaultValue = parsePropertyValue(trimmed.substring(6).trim(), current.type, createColor);
      parsingValues = false;
      continue;
    }
    if (trimmed === "Values:") {
      current.choices = [];
      parsingValues = true;
      continue;
    }

    if (parsingValues && current.type === "combo") {
      const choiceMatch = trimmed.match(/^(.+?)\s*=\s*(.+)$/);
      if (choiceMatch) {
        current.choices.push({
          key: choiceMatch[1].trim(),
          name: stripHtml(choiceMatch[2]).trim(),
          label: stripHtml(choiceMatch[2]).trim(),
          value: choiceMatch[1].trim(),
          text: stripHtml(choiceMatch[2]).trim()
        });
      } else {
        current.choices.push({
          key: trimmed,
          name: stripHtml(trimmed).trim(),
          label: stripHtml(trimmed).trim(),
          value: trimmed,
          text: stripHtml(trimmed).trim()
        });
      }
    }
  }

  commitCurrent();
  return definitions;
}
