function getExtension(fileName) {
    return fileName.substring(fileName.lastIndexOf(".") + 1).toLowerCase();
}

function isVideo(fileName, filterVideos) {
    return filterVideos.indexOf(getExtension(fileName)) !== -1;
}

function isImage(fileName, filterImages) {
    return filterImages.indexOf(getExtension(fileName)) !== -1;
}

function nameFilters(filterImages, filterVideos) {
    return (filterImages || []).concat(filterVideos || []).map((ext) => "*." + ext);
}

var mpvpaperKill = "killall -9 mpvpaper 2>/dev/null || true";

var mpvpaperOptions = [
    "loop",
    "--no-audio",
    "--hwdec=auto",
    "--profile=high-quality",
    "--video-sync=display-resample",
    "--interpolation",
    "--tscale=oversample"
].join(" ");

function mpvpaperRun(filePath, duration) {
    return "sleep " + duration / 1000 + " && mpvpaper -o '" + mpvpaperOptions + "' '*' \"" + filePath + "\" >/dev/null 2>&1 & disown";
}

function wallpaperCommand(entry, duration) {
    if (entry.isVideo)
        return mpvpaperKill + "; " + mpvpaperRun(entry.filePath, duration);
    return mpvpaperKill;
}
