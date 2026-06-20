.pragma library

function escapeHtml(text) {
  return String(text || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function decodeEntities(text) {
  return String(text || "")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">");
}

function escapeAttr(text) {
  return escapeHtml(String(text || "")).replace(/\n/g, "");
}

function normalizeEscapes(rawText) {
  let text = String(rawText || "");
  for (let i = 0; i < 4; i++) {
    const next = text
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .replace(/\\r\\n/g, "\n")
      .replace(/\\n/g, "\n")
      .replace(/\\r/g, "\n")
      .replace(/\\t/g, " ")
      .replace(/\\\//g, "/")
      .replace(/\\\"/g, "\"")
      .replace(/\\\\/g, "\\");

    if (next === text) {
      break;
    }
    text = next;
  }
  return text;
}

function sanitizeUrl(urlText) {
  const raw = decodeEntities(String(urlText || "")).trim();
  if (raw.length === 0) {
    return "";
  }

  if (/^(https?:\/\/|steam:\/\/|mailto:)/i.test(raw)) {
    return raw;
  }

  if (/^www\./i.test(raw)) {
    return "https://" + raw;
  }

  return "";
}

function linkHtml(url, label) {
  const safeUrl = sanitizeUrl(url);
  if (safeUrl.length === 0) {
    return label;
  }
  return '<a href="' + escapeAttr(safeUrl) + '">' + label + "</a>";
}

function linkifyPlainUrls(htmlText) {
  const parts = String(htmlText || "").split(/(<[^>]+>)/g);
  for (let i = 0; i < parts.length; i++) {
    const chunk = parts[i];
    if (chunk.length === 0 || chunk.charAt(0) === "<") {
      continue;
    }

    parts[i] = chunk.replace(/(^|[\s(>])((?:https?:\/\/|www\.)[^\s<]+)/gi, function (_match, prefix, url) {
      const link = linkHtml(url, escapeHtml(url));
      if (link === escapeHtml(url)) {
        return prefix + escapeHtml(url);
      }
      return prefix + link;
    });
  }
  return parts.join("");
}

function toRichDescription(rawText) {
  const normalized = normalizeEscapes(rawText).trim();
  if (normalized.length === 0) {
    return "";
  }

  let text = escapeHtml(normalized);
  const blocks = [];

  function stash(blockHtml) {
    const token = "@@BLOCK_" + String(blocks.length) + "@@";
    blocks.push(blockHtml);
    return token;
  }

  text = text.replace(/\[code\]([\s\S]*?)\[\/code\]/gi, function (_m, body) {
    return stash('<pre><code>' + body + "</code></pre>");
  });

  text = text.replace(/\[quote(?:=[^\]]+)?\]([\s\S]*?)\[\/quote\]/gi, function (_m, body) {
    return stash('<blockquote>' + body + "</blockquote>");
  });

  text = text.replace(/\[img\]([\s\S]*?)\[\/img\]/gi, function (_m, url) {
    const label = "[image]";
    const linked = linkHtml(url, escapeHtml(label));
    return linked === escapeHtml(label) ? escapeHtml(label) : linked;
  });

  text = text.replace(/\[url=([^\]]+)\]([\s\S]*?)\[\/url\]/gi, function (_m, url, body) {
    const inner = String(body || "");
    const linked = linkHtml(url, inner);
    return linked === inner ? inner : linked;
  });

  text = text.replace(/\[url\]([\s\S]*?)\[\/url\]/gi, function (_m, url) {
    const label = escapeHtml(decodeEntities(String(url || "")));
    const linked = linkHtml(url, label);
    return linked === label ? label : linked;
  });

  text = text.replace(/\[b\]([\s\S]*?)\[\/b\]/gi, "<b>$1</b>");
  text = text.replace(/\[i\]([\s\S]*?)\[\/i\]/gi, "<i>$1</i>");
  text = text.replace(/\[u\]([\s\S]*?)\[\/u\]/gi, "<u>$1</u>");
  text = text.replace(/\[s\]([\s\S]*?)\[\/s\]/gi, "<s>$1</s>");
  text = text.replace(/\[h1\]([\s\S]*?)\[\/h1\]/gi, "<h1>$1</h1>");
  text = text.replace(/\[h2\]([\s\S]*?)\[\/h2\]/gi, "<h2>$1</h2>");
  text = text.replace(/\[h3\]([\s\S]*?)\[\/h3\]/gi, "<h3>$1</h3>");

  // Basic list handling: preserve items and drop list wrappers.
  text = text
    .replace(/\[list(?:=[^\]]*)?\]/gi, "")
    .replace(/\[\/list\]/gi, "")
    .replace(/\[\*\]/g, "\n- ");

  // Strip unsupported formatting tags but keep content.
  text = text.replace(/\[(?:center|left|right|spoiler|size(?:=[^\]]*)?|color(?:=[^\]]*)?|font(?:=[^\]]*)?|table|tr|td)\]/gi, "");
  text = text.replace(/\[\/(?:center|left|right|spoiler|size|color|font|table|tr|td)\]/gi, "");

  text = linkifyPlainUrls(text);
  text = text.replace(/\n{3,}/g, "\n\n").replace(/\n/g, "<br/>");

  for (let i = 0; i < blocks.length; i++) {
    text = text.replace("@@BLOCK_" + String(i) + "@@", blocks[i]);
  }

  return text.trim();
}
