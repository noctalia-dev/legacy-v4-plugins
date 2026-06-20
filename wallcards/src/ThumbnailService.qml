import "Utils.js" as Utils
import QtQuick
import Quickshell.Io
import Qt.labs.folderlistmodel

Item {
  id: service

  property int maxThumbnailJobs: 4
  property var pendingJobs: []
  property int activeJobs: 0
  required property string cacheDir
  required property var imageFilter
  required property var videoFilter
  required property string wallpaperDir
  property var colorOrder: ["Red", "Orange", "Green", "Teal", "Blue", "Purple", "Pink", "Monochrome"]
  property var colorOrderColors: ["#FF4500", "#FFA500", "#32CD32", "#2EC4B6", "#1E90FF", "#8A2BE2", "#FF69B4", "#A9A9A9"]
  property int fileCount: files.length
  property var files: []
  property bool loading: true
  property int pendingProcesses: 0
  property int thumbnailRevision: 0

  signal ready

  function toLocalPath(urlStr) {
    return String(urlStr).replace(/^file:\/\//, "");
  }

  FolderListModel {
    id: thumbnailModel

    folder: service.wallpaperDir ? Qt.resolvedUrl("file://" + service.wallpaperDir) : ""
    nameFilters: Utils.nameFilters(service.imageFilter, service.videoFilter)
    showDirs: false
    sortField: FolderListModel.Name

    onStatusChanged: {
      if (status === FolderListModel.Ready) {
        service.createThumbnails();
      }
    }
  }

function createThumbnails() {
    var proc = processComponent.createObject(null, {
        command: ["mkdir", "-p", cacheDir]
    });
    proc.running = true;

    var items = [];
    var jobs = [];

    for (var i = 0; i < thumbnailModel.count; i++) {
        (function (idx) {
            var filePath = toLocalPath(thumbnailModel.get(idx, "filePath"));
            var fileName = thumbnailModel.get(idx, "fileName");
            var isVid = Utils.isVideo(fileName, service.videoFilter);
            var thumbName = isVid ? fileName + ".jpg" : fileName;
            var thumbnailPath = cacheDir + "/" + thumbName;

            var thumbnailCmd = isVid ? videoToThumbnailCmd(filePath, thumbnailPath) : imageToThumbnailCmd(filePath, thumbnailPath);
            var hexCmd = thumbnailHexValueCmd(thumbnailPath);

            const script = `
                [ -f "${thumbnailPath}"* ] && exit 0
                ${thumbnailCmd}
                mv "${thumbnailPath}" "${thumbnailPath}__x$(${hexCmd})"
            `;

            jobs.push({
                script: script,
                thumbnailPath: thumbnailPath
            });

            items.push({});
        })(i);
    }

    pendingJobs = jobs;
    activeJobs = 0;
    processNextJob();

    if (thumbnailModel.count === 0) {
        service.loading = false;
    }

    files = items;
}
function processNextJob() {
    while (activeJobs < maxThumbnailJobs && pendingJobs.length > 0) {
        var job = pendingJobs.shift();
        activeJobs++;
        service.pendingProcesses++;
        createSingleThumbnail(job, function() {
            activeJobs--;
            processNextJob();
        });
    }
}

function createSingleThumbnail(job, onFinished) {
    var proc = processComponent.createObject(null, {
        command: ["bash", "-c", job.script]
    });

    proc.exited.connect(function () {
        service.pendingProcesses--;
        service.thumbnailRevision++;

        if (service.pendingProcesses === 0) {
            filesModel.running = true;
        }

        proc.destroy();
        if (onFinished) onFinished();
    });

    proc.running = true;
}
  function imageToThumbnailCmd(filePath, thumbnailPath) {
    return `magick "${filePath}" \
      -resize x500 \
      -quality 95 \
      "${thumbnailPath}"
    `;
  }

  function videoToThumbnailCmd(filePath, thumbnailPath) {
    return `ffmpeg -y -i \
      "${filePath}" \
      -vf "select=eq(n\\,0),scale=-1:1080" \
      -frames:v 1 \
      -q:v 2 \
      "${thumbnailPath}" </dev/null 2>/dev/null`;
  }

  function thumbnailHexValueCmd(thumbnailPath) {
    return `magick "${thumbnailPath}" \
      -resize "1x1^" \
      -gravity center \
      -extent 1x1 \
      -depth 8 \
      -format "%[hex:p{0,0}]" info:- 2>/dev/null \
      | grep -oE '[0-9A-Fa-f]{6}' \
      | head -n 1`;
  }

  FolderListModel {
    id: filesModel

    nameFilters: ["*__x*"]
    showDirs: false
    sortField: FolderListModel.Name

    property bool running: false

    onRunningChanged: {
      if (running)
        folder = Qt.resolvedUrl("file://" + service.cacheDir);
    }

    onStatusChanged: {
      if (status === FolderListModel.Ready && running) {
        service.buildFileList();
        running = false;
      }
    }
  }

  function buildFileList() {
    // Ground truth needed to avoid showing thumbnails for files
    // that are no longer in the wallpaper directory.
    var existingFiles = new Set();
    for (let j = 0; j < thumbnailModel.count; j++) {
      existingFiles.add(thumbnailModel.get(j, "fileName"));
    }

    var items = [];

    for (let i = 0; i < filesModel.count; i++) {
      const filePath = toLocalPath(filesModel.get(i, "filePath"));
      const fileName = filesModel.get(i, "fileName");

      const idx = fileName.lastIndexOf("__x");
      if (idx === -1)
        continue;

      const thumbBase = fileName.substring(0, idx);
      const hexColor = fileName.substring(idx + 3);

      // Video thumbnails are named <original>.<vidext>.jpg__x<hex>
      // Strip trailing .jpg to recover the original video filename.
      var isVid = thumbBase.toLowerCase().endsWith(".jpg") && Utils.isVideo(thumbBase.substring(0, thumbBase.lastIndexOf(".")), service.videoFilter);
      var wallpaperName = isVid ? thumbBase.substring(0, thumbBase.lastIndexOf(".")) : thumbBase;

      if (!existingFiles.has(wallpaperName)) {
        continue;
      }

      items.push({
        fileName: wallpaperName,
        filePath: wallpaperDir + "/" + wallpaperName,
        thumbnail: filePath,
        hexCode: hexColor,
        filterColor: getFilterColor(hexColor),
        isVideo: isVid
      });
    }

    items.sort((a, b) => colorOrder.indexOf(a.filterColor) - colorOrder.indexOf(b.filterColor));

    files = items;
    service.loading = false;
    service.ready();
  }

  function getFilterColor(hexColor) {
    if (!hexColor)
      return "Monochrome";

    const cleaned = String(hexColor).trim().replace(/x/g, '').substring(0, 6);
    if (cleaned.length !== 6)
      return "Monochrome";

    const r = parseInt(cleaned.substring(0, 2), 16) / 255;
    const g = parseInt(cleaned.substring(2, 4), 16) / 255;
    const b = parseInt(cleaned.substring(4, 6), 16) / 255;
    if ([r, g, b].some(isNaN))
      return "Monochrome";

    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const d = max - min;

    let h = 0;
    let s = max === 0 ? 0 : d / max;
    let v = max;

    if (d !== 0) {
      if (max === r)
        h = (g - b) / d + (g < b ? 6 : 0);
      else if (max === g)
        h = (b - r) / d + 2;
      else
        h = (r - g) / d + 4;
      h = (h / 6) * 360;
    }

    if (s < 0.15 || v < 0.10)
      return "Monochrome";
    if (h >= 345 || h < 15)
      return "Red";
    if (h < 50)
      return "Orange";
    if (h < 160)
      return "Green";
    if (h < 200)
      return "Teal";
    if (h < 260)
      return "Blue";
    if (h < 315)
      return "Purple";
    if (h < 345)
      return "Pink";

    return "Monochrome";
  }

  Component {
    id: processComponent

    Process {}
  }
}
