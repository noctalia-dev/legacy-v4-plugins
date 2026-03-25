.pragma library

/**
 * Render Markdown text to Qt-compatible rich text (HTML subset).
 * Uses a lightweight two-phase AST parser -> Renderer architecture.
 *
 * @param {string} text - Raw Markdown content
 * @param {Object} [theme] - Optional theme color overrides
 */
function render(text, theme) {
    if (!text) return "";

    // Theme colors with defaults
    const t = theme || {};
    const style = {
        inlineCodeBg: t.inlineCodeBg || "#ECEFF1",
        inlineCodeFg: t.inlineCodeFg || "#D81B60",
        quoteBorder: t.quoteBorder || "#83B4ED",
        quoteFg: t.quoteFg || "#546E7A",
        linkColor: t.linkColor || "#1565C0",
        taskDoneFg: t.taskDoneFg || "#9E9E9E",
        noteColor: t.noteColor || "#FFFFFF",
        lineBreakTag: "<br/>",
        paragraphBreakTag: "<br/><br/>"
    };

    // Precalculate opaque quote background
    let cR = 255, cG = 255, cB = 255;
    if (style.noteColor.length >= 7) {
        cR = parseInt(style.noteColor.substr(1, 2), 16);
        cG = parseInt(style.noteColor.substr(3, 2), 16);
        cB = parseInt(style.noteColor.substr(5, 2), 16);
    }
    cR = Math.max(0, Math.floor(cR * 0.985));
    cG = Math.max(0, Math.floor(cG * 0.985));
    cB = Math.max(0, Math.floor(cB * 0.985));
    style.opaqueQuoteBg = `#${(1 << 24 | cR << 16 | cG << 8 | cB).toString(16).slice(1)}`;

    // 1. Build AST
    const blocks = parseBlocks(text);

    // 2. Render to HTML
    return renderBlocks(blocks, style);
}

// ─── 1. PARSER ───────────────────────────────────────────────────────

/**
 * Escapes HTML characters.
 */
function escapeHtml(str) {
    return str.replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

/**
 * Tokenizes the text into block-level elements.
 */
function parseBlocks(text) {
    const lines = text.split(/\r?\n/);
    const tokens = [];
    let i = 0;

    // A helper to push a token and return it.
    function pushToken(type, content, meta) {
        const token = { type, content };
        if (meta) {
            for (const k in meta) token[k] = meta[k];
        }
        tokens.push(token);
        return token;
    }

    // A helper to collect lines for elements like codeblocks, blockquotes, etc.
    function collectLines(condition) {
        const collected = [];
        while (i < lines.length && condition(lines[i], i)) {
            collected.push(lines[i]);
            i++;
        }
        return collected;
    }

    while (i < lines.length) {
        const line = lines[i];

        // Empty line
        if (line.trim() === "") {
            pushToken("empty", "");
            i++;
            continue;
        }

        // Horizontal Rule
        if (/^(?:-[ \t]*){3,}|(?:_[ \t]*){3,}|(?:\*[ \t]*){3,}$/.test(line)) {
            pushToken("hr", "");
            i++;
            continue;
        }

        // Header (h1-h6)
        const hMatch = line.match(/^(#{1,6})\s+(.*)$/);
        if (hMatch) {
            pushToken("heading", hMatch[2].trim(), { level: hMatch[1].length });
            i++;
            continue;
        }

        // Fenced Code Block
        if (/^```/.test(line)) {
            const langMatch = line.match(/^```(\w*)/);
            const lang = langMatch ? langMatch[1] : "";
            i++; // skip opening ```
            const codeLines = collectLines((l) => !/^```/.test(l));
            pushToken("codeblock", codeLines.join("\n"), { lang });
            i++; // skip closing ```
            continue;
        }

        // Indented Code Block (4 spaces or 1 tab)
        // Must be separated from paragraphs usually, but here we just greedy match.
        // Look ahead to make sure previous token was empty or another codeblock.
        const isIndentedCode = /^(?: {4}|\t)/.test(line);
        const prevToken = tokens.length > 0 ? tokens[tokens.length - 1] : { type: "empty" };
        // Only allow indented code blocks if they are preceded by an empty line or another codeblock (in this implementation we greedily grab them).
        if (isIndentedCode && (prevToken.type === "empty" || prevToken.type === "codeblock")) {
            const indCodeLines = collectLines((l) => l.trim() === "" || /^(?: {4}|\t)/.test(l));
            // Remove the indentation from all lines
            let cleanedCode = indCodeLines.map((l) => l.replace(/^(?: {4}|\t)/, '')).join("\n");
            // Trim trailing empty lines
            cleanedCode = cleanedCode.replace(/\n+$/, '');
            pushToken("codeblock", cleanedCode, { lang: "" });
            continue;
        }


        // Blockquote
        if (/^>/.test(line)) {
            const bqLines = collectLines((l) => /^>/.test(l));
            // Clean the immediate `> ` prefix
            const cleanBqText = bqLines.map((l) => l.replace(/^>[ \t]?/, '')).join("\n");
            pushToken("blockquote", cleanBqText);
            continue;
        }

        // List item (Bullet / Ordered)
        // We group consecutive list items
        const listMatch = line.match(/^([ \t]*)([-*]|\d+\.)[ \t]+(.*)$/);
        if (listMatch) {
            const listItems = [];
            while (i < lines.length) {
                const lMatch = lines[i].match(/^([ \t]*)([-*]|\d+\.)[ \t]+(.*)$/);
                if (lMatch) {
                    const indent = lMatch[1] || "";
                    const bullet = lMatch[2];
                    const itemContent = lMatch[3];
                    const taskMatch = itemContent.match(/^\[([xX ]+)\][ \t]+(.*)$/);

                    listItems.push({
                        indent,
                        bullet,
                        text: taskMatch ? taskMatch[2] : itemContent,
                        isTask: !!taskMatch,
                        isDone: taskMatch ? taskMatch[1].toLowerCase() === 'x' : false
                    });
                    i++;
                } else {
                    // Stop if we hit an empty line or non-list-looking thing.
                    // For simplicity, we break if not matching list regex.
                    break;
                }
            }
            pushToken("list", "", { items: listItems });
            continue;
        }

        // Table
        // Must match Header line, separator line.
        if (i + 1 < lines.length && /^\|.*\|$/.test(line) && /^\|[ \-:|]+\|$/.test(lines[i + 1])) {
            const headerCols = line.split('|').slice(1, -1).map((c) => c.trim());
            const aligns = lines[i + 1].split('|').slice(1, -1).map((s) => {
                s = s.trim();
                if (s.indexOf(':') === 0 && s.lastIndexOf(':') === s.length - 1 && s.length > 1) return 'center';
                if (s.lastIndexOf(':') === s.length - 1) return 'right';
                if (s.indexOf(':') === 0) return 'left';
                return 'left';
            });
            i += 2;
            const rows = [];
            while (i < lines.length && /^\|.*\|$/.test(lines[i])) {
                const rowCols = lines[i].split('|').slice(1, -1).map((c) => c.trim());
                rows.push(rowCols);
                i++;
            }
            pushToken("table", "", { headers: headerCols, aligns, rows });
            continue;
        }

        // Setup Headers (Setext)
        if (i + 1 < lines.length && /^={3,}$/.test(lines[i + 1])) {
            pushToken("heading", line.trim(), { level: 1 });
            i += 2;
            continue;
        }
        if (i + 1 < lines.length && /^-{3,}$/.test(lines[i + 1])) {
            pushToken("heading", line.trim(), { level: 2 });
            i += 2;
            continue;
        }

        // Regular Paragraph Line
        // We greedily consume consecutive lines until an empty line or another block starts
        const pLines = collectLines((l) => {
            if (l.trim() === "") return false;
            // Break on block starters
            if (/^(?:-[ \t]*){3,}|(?:_[ \t]*){3,}|(?:\*[ \t]*){3,}$/.test(l)) return false;
            if (/^(#{1,6})\s+/.test(l)) return false;
            if (/^```/.test(l)) return false;
            if (/^>/.test(l)) return false;
            if (/^([ \t]*)([-*]|\d+\.)[ \t]+(.*)$/.test(l)) return false;
            return true;
        });
        pushToken("paragraph", pLines.join("\n"));
    }

    return tokens;
}

/**
 * Parses inline formatting like **bold**, *italic*, `code`, images, and links.
 */
function parseInline(text, style) {
    if (!text) return "";
    let t = escapeHtml(text);

    // Images: ![alt](url "title")
    t = t.replace(/!\[([^\]]*)\]\(([^)\s]+)(?:[ \t]+(?:&quot;|&#039;)(.*?)(?:&quot;|&#039;))?[ \t]*\)/g, (match, alt, url, title) => {
        return `<img src="${url}" title="${title || ''}" alt="${alt}" style="max-width: 100%;" />`;
    });

    // Links: [text](url "title")
    t = t.replace(/\[([^\]]+)\]\(([^)\s]+)(?:[ \t]+(?:&quot;|&#039;)(.*?)(?:&quot;|&#039;))?[ \t]*\)/g, (match, textInside, url, title) => {
        return `<a href="${url}" title="${title || ''}" style="color: ${style.linkColor};">${parseInline(textInside, style)}</a>`;
    });

    // Autolinks
    t = t.replace(/&lt;(https?:\/\/[^&]+)&gt;/g, `<a href="$1" style="color: ${style.linkColor};">$1</a>`);
    t = t.replace(/&lt;([^@\s]+@[^@\s]+\.[^@\s]+)&gt;/g, `<a href="mailto:$1" style="color: ${style.linkColor};">$1</a>`);

    // Code
    t = t.replace(/`([^`]+)`/g, (match, code) => {
        return `<span style="background-color: ${style.inlineCodeBg}; font-family: monospace; color: ${style.inlineCodeFg};">&nbsp;${code.trim()}&nbsp;</span>`;
    });

    // Bold
    t = t.replace(/\*\*(.*?)\*\*/g, "<b>$1</b>");
    t = t.replace(/\b__(.*?)__\b/g, "<b>$1</b>");

    // Italic
    t = t.replace(/\*(.*?)\*/g, "<i>$1</i>");
    t = t.replace(/\b_(.*?)_\b/g, "<i>$1</i>");

    // Strikethrough
    t = t.replace(/~~(.*?)~~/g, "<s>$1</s>");

    // Preserve explicit line breaks inside plain text paragraphs.
    t = t.replace(/\n/g, style.lineBreakTag);

    return t;
}

// ─── 2. RENDERER ─────────────────────────────────────────────────────

function renderBlocks(tokens, style) {
    const out = [];
    const spacerTable = '<table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin: 0; padding: 0;"><tr><td style="font-size: 1px; line-height: 8px; padding: 0;">&nbsp;</td></tr></table>';

    function hasIntrinsicBlockSpacing(token) {
        return token && (
            token.type === "heading" ||
            token.type === "hr" ||
            token.type === "codeblock" ||
            token.type === "blockquote" ||
            token.type === "table"
        );
    }

    for (let i = 0; i < tokens.length; i++) {
        const token = tokens[i];

        switch (token.type) {
            case "empty":
                // Block elements already define their own outer spacing, so
                // only add explicit paragraph gaps between plain text-ish blocks.
                const prevToken = i > 0 ? tokens[i - 1] : null;
                const nextToken = i + 1 < tokens.length ? tokens[i + 1] : null;
                if (!hasIntrinsicBlockSpacing(prevToken) && !hasIntrinsicBlockSpacing(nextToken)) {
                    out.push(style.paragraphBreakTag);
                }
                break;

            case "hr":
                out.push('<hr style="margin-top: 16px; margin-bottom: 16px;">');
                break;

            case "heading":
                let size, mt, mb;
                if (token.level === 1) { mt = 20; mb = 16; size = ''; }
                else if (token.level === 2) { mt = 18; mb = 14; size = ''; }
                else if (token.level === 3) { mt = 16; mb = 12; size = ''; }
                else if (token.level === 4) { mt = 14; mb = 10; size = ''; }
                else if (token.level === 5) { mt = 12; mb = 8; size = 'font-size: small; '; }
                else { mt = 12; mb = 8; size = 'font-size: small; '; } // h6

                out.push(`<h${token.level} style="${size}margin-top: ${mt}px; margin-bottom: ${mb}px;">${parseInline(token.content, style)}</h${token.level}>`);
                break;

            case "paragraph":
                out.push(parseInline(token.content, style));
                break;

            case "codeblock":
                const codeSpacer = '<table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin: 0; padding: 0;"><tr><td style="font-size: 1px; line-height: 12px; padding: 0;">&nbsp;</td></tr></table>';
                out.push(`${codeSpacer}<table width="100%" style="background-color: rgba(0,0,0,0.08);" border="0" cellpadding="10" style="margin-top: 4px; margin-bottom: 4px;"><tr><td><pre style="margin: 0;">${escapeHtml(token.content)}</pre></td></tr></table>${codeSpacer}`);
                break;

            case "blockquote":
                // Recursively parse the blockquote content.
                // We inject it into the specially themed table format that avoids Qt RichText rendering bugs.
                const childTokens = parseBlocks(token.content);
                const renderedChild = renderBlocks(childTokens, style);

                const bqHtml = `<table cellspacing="0" cellpadding="0" width="100%" bgcolor="${style.quoteBorder}" style="margin:0;"><tr><td style="padding-left: 4px;"><table cellspacing="0" cellpadding="0" width="100%" bgcolor="${style.opaqueQuoteBg}" style="margin:0;"><tr><td style="padding: 8px 12px; color:${style.quoteFg};">${renderedChild}</td></tr></table></td></tr></table>`;

                // Wrapping in spacer tables ensures paragraph margins are respected in Qt
                out.push(`${spacerTable}${bqHtml}${spacerTable}`);
                break;

            case "list":
                const listHtml = [];
                for (let j = 0; j < token.items.length; j++) {
                    const item = token.items[j];
                    const pxIndent = (item.indent.replace(/\t/g, "    ").length) * 8;

                    if (item.isTask) {
                        const tick = item.isDone ? '&#9745;' : '&#9744;';
                        const taskMod = item.isDone ? `color: ${style.taskDoneFg}; text-decoration: line-through;` : '';
                        listHtml.push(`<div style="margin-left: ${pxIndent}px; margin-top: 4px; margin-bottom: 4px; ${taskMod}">${tick} ${parseInline(item.text, style)}</div>`);
                    } else {
                        const isOrdered = /\d/.test(item.bullet);
                        const bulletStr = isOrdered ? item.bullet : "&bull;";
                        listHtml.push(`<div style="margin-left: ${pxIndent}px; margin-top: 4px; margin-bottom: 4px;">${bulletStr} ${parseInline(item.text, style)}</div>`);
                    }
                }
                out.push(listHtml.join('')); // Lists should be somewhat compact
                break;

            case "table":
                const tSpacer = '<table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin: 0; padding: 0;"><tr><td style="font-size: 1px; line-height: 12px; padding: 0;">&nbsp;</td></tr></table>';
                let tHtml = `${tSpacer}<table width="100%" border="1" cellpadding="4" cellspacing="0" style="border-collapse: collapse; border-color: #CFD8DC; margin-top: 8px; margin-bottom: 8px;"><tr style="background-color: rgba(0,0,0,0.05);">`;

                for (let th = 0; th < token.headers.length; th++) {
                    tHtml += `<th align="${token.aligns[th] || 'left'}"><b>${parseInline(token.headers[th], style)}</b></th>`;
                }
                tHtml += '</tr>';
                for (let tr = 0; tr < token.rows.length; tr++) {
                    tHtml += '<tr>';
                    for (let tc = 0; tc < token.headers.length; tc++) {
                        const cellData = token.rows[tr][tc] || "";
                        tHtml += `<td align="${token.aligns[tc] || 'left'}">${parseInline(cellData, style)}</td>`;
                    }
                    tHtml += '</tr>';
                }
                tHtml += `</table>${tSpacer}`;
                out.push(tHtml);
                break;
        }
    }

    // Between disjoint tokens, if we hit multiple empty lines or paragraphs we need native spacing.
    // E.g paragraph then paragraph should have a break.
    let finalText = "";
    for (let r = 0; r < out.length; r++) {
        if (r > 0 && out[r] !== style.paragraphBreakTag && out[r - 1] !== style.paragraphBreakTag &&
            !/^<table|^<hr|^<h/.test(out[r]) && !/(<\/table>|<\/hr>|<\/h[1-6]>)$/.test(out[r - 1])) {
            finalText += style.lineBreakTag;
        }
        finalText += out[r];
    }

    return finalText;
}
