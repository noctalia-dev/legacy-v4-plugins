.pragma library
function _p2(n) { return n < 10 ? "0" + n : "" + n }
function _stamp(now) {
    return {
        Y: String(now.getFullYear()),
        m: _p2(now.getMonth() + 1),
        d: _p2(now.getDate()),
        H: _p2(now.getHours()),
        M: _p2(now.getMinutes()),
        S: _p2(now.getSeconds())
    }
}
function expandPath(p, home) {
    if (!p || p.trim() === "") return ""
    if (p.startsWith("~/")) return home + "/" + p.substring(2)
    return p
}
function shellEscape(str) {
    return "'" + String(str).replace(/'/g, "'\\''") + "'"
}
function formatStem(fmt) {
    var t = _stamp(new Date())
    return fmt.trim()
        .replace(/%Y/g, t.Y).replace(/%m/g, t.m).replace(/%d/g, t.d)
        .replace(/%H/g, t.H).replace(/%M/g, t.M).replace(/%S/g, t.S)
        .replace(/[\/\\\n\r\0']/g, "_")
        .trim()
}
/**
 * buildFilename("annotate", ".png", settings?.filenameFormat)
 * Returns a full filename with extension.
 */
function buildFilename(toolName, ext, filenameFormat) {
    var fmt = filenameFormat ?? ""
    if (fmt.trim() !== "") {
        var stem = formatStem(fmt.trim())
        if (stem !== "") return stem + ext
    }
    var t = _stamp(new Date())
    return toolName + "-" + t.Y + "-" + t.m + "-" + t.d + "_" + t.H + "-" + t.M + "-" + t.S + ext
}
function screenshotDir(home, customPath) {
    var c = customPath ?? ""
    if (c.trim() !== "") return expandPath(c.trim().replace(/\/$/, ""), home)
    return home + "/Pictures/Screenshots"
}
function videoDir(home, customPath) {
    var c = customPath ?? ""
    if (c.trim() !== "") return expandPath(c.trim().replace(/\/$/, ""), home)
    return home + "/Videos"
}
