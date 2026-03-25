import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  property bool isPlaying: false
  property string currentEntryId: ""
  property string currentTitle: ""
  property string currentUrl: ""
  property string currentUploader: ""
  property int currentDuration: 0
  property real currentSpeed: 1.0
  property int currentPid: 0
  property bool isPaused: false
  property real currentPosition: 0
  property string currentEndReason: ""
  property string currentUpdatedAt: "0"
  property string lastError: ""
  property string lastNotice: ""

  property string currentProvider: "youtube"
  property string currentSortBy: "date"
  property string downloadDirectory: Quickshell.env("HOME") + "/Music/Noctalia"
  property int downloadCacheMaxMb: 0
  readonly property string previewMetadataMode: pluginApi?.pluginSettings?.previewMetadataMode
      ?? root.defaults.previewMetadataMode
      ?? "always"
  readonly property bool showUploaderMetadata: pluginApi?.pluginSettings?.showUploaderMetadata
      ?? root.defaults.showUploaderMetadata
      ?? true
  readonly property bool showAlbumMetadata: pluginApi?.pluginSettings?.showAlbumMetadata
      ?? root.defaults.showAlbumMetadata
      ?? true
  readonly property bool showDurationMetadata: pluginApi?.pluginSettings?.showDurationMetadata
      ?? root.defaults.showDurationMetadata
      ?? true
  readonly property bool showRatingMetadata: pluginApi?.pluginSettings?.showRatingMetadata
      ?? root.defaults.showRatingMetadata
      ?? true
  readonly property bool showTagMetadata: pluginApi?.pluginSettings?.showTagMetadata
      ?? root.defaults.showTagMetadata
      ?? true
  readonly property bool showPlayStatsMetadata: pluginApi?.pluginSettings?.showPlayStatsMetadata
      ?? root.defaults.showPlayStatsMetadata
      ?? true
  readonly property bool showStatusMetadata: pluginApi?.pluginSettings?.showStatusMetadata
      ?? root.defaults.showStatusMetadata
      ?? true
  readonly property bool showPreviewChips: pluginApi?.pluginSettings?.showPreviewChips
      ?? root.defaults.showPreviewChips
      ?? true
  readonly property string previewThumbnailSize: pluginApi?.pluginSettings?.previewThumbnailSize
      ?? root.defaults.previewThumbnailSize
      ?? "comfortable"
  readonly property bool showHomeRecent: pluginApi?.pluginSettings?.showHomeRecent
      ?? root.defaults.showHomeRecent
      ?? true
  readonly property bool showHomeTop: pluginApi?.pluginSettings?.showHomeTop
      ?? root.defaults.showHomeTop
      ?? true
  readonly property bool showHomeTags: pluginApi?.pluginSettings?.showHomeTags
      ?? root.defaults.showHomeTags
      ?? true
  readonly property bool showHomeArtists: pluginApi?.pluginSettings?.showHomeArtists
      ?? root.defaults.showHomeArtists
      ?? true
  readonly property bool showHomePlaylists: pluginApi?.pluginSettings?.showHomePlaylists
      ?? root.defaults.showHomePlaylists
      ?? true
  readonly property bool autoSaveMp3AfterPlayback: pluginApi?.pluginSettings?.autoSaveMp3AfterPlayback
      ?? root.defaults.autoSaveMp3AfterPlayback
      ?? false
  property string ytPlayerClient: "android"

  property var libraryEntries: []
  property var playlistEntries: []
  property var queueEntries: []
  property bool queueActive: false
  property string pendingPlaylistCreateName: ""
  property string pendingPlaylistCreateEntryId: ""
  property string pendingQueueLaunchEntryId: ""
  property var pendingQueueLaunchEntry: null
  property string lastHandledQueueUpdate: ""
  property bool pendingAutoplaySaved: false
  property bool pendingAutoplaySavedShuffle: false
  property bool queueBatchBusy: false
  property var queueBatchEntries: []
  property int queueBatchIndex: 0
  property string queueBatchFinalAction: ""
  property string queueBatchDoneNotice: ""
  property string queueControlAction: ""
  property string queueCommandAction: ""
  property bool queueLaunchBusy: false

  property bool playbackBusy: false
  property string playbackCommandAction: ""
  property bool playbackStarting: false
  property string playbackStartingProvider: ""
  property string playbackStartingMessage: ""
  property bool statusBusy: false
  property bool libraryBusy: false
  property bool downloadBusy: false
  property bool queueBusy: false
  property bool pauseBusy: false
  property bool positionBusy: false
  property bool seekBusy: false
  property bool speedBusy: false
  property bool providerBusy: false
  property string providerSuccessNotice: ""
  property bool playlistsBusy: false
  property bool importBusy: false
  property real pendingSeekPosition: -1

  readonly property string helperPath: Qt.resolvedUrl("musicctl.sh").toString().replace("file://", "")
  readonly property string cacheDir: Quickshell.env("MUSIC_CACHE_DIR")
      || ((Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/noctalia/plugins/music-search")
  readonly property string statePath: root.cacheDir + "/state.json"
  readonly property string libraryPath: root.cacheDir + "/library.json"
  readonly property string settingsPath: root.cacheDir + "/settings.json"
  readonly property string playlistsPath: root.cacheDir + "/playlists.json"
  readonly property string queuePath: root.cacheDir + "/queue.json"

  Component.onCompleted: root.refreshStatus()
  onPluginApiChanged: root.refreshStatus()

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false

    onLoaded: root.applyState(text())
    onTextChanged: root.applyState(text())
  }

  FileView {
    id: libraryFile
    path: root.libraryPath
    watchChanges: true
    printErrors: false

    onLoaded: root.applyLibrary(text())
    onTextChanged: root.applyLibrary(text())
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false

    onLoaded: root.applySettings(text())
    onTextChanged: root.applySettings(text())
  }

  FileView {
    id: playlistsFile
    path: root.playlistsPath
    watchChanges: true
    printErrors: false

    onLoaded: root.applyPlaylists(text())
    onTextChanged: root.applyPlaylists(text())
  }

  FileView {
    id: queueFile
    path: root.queuePath
    watchChanges: true
    printErrors: false

    onLoaded: root.applyQueue(text())
    onTextChanged: root.applyQueue(text())
  }

  Timer {
    id: statusTimer
    interval: 5000
    repeat: true
    running: true
    triggeredOnStart: true

    onTriggered: root.refreshStatus()
  }

  Process {
    id: playbackProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      var commandAction = String(root.playbackCommandAction || "");
      root.playbackCommandAction = "";
      root.playbackBusy = false;
      root.playbackStarting = false;
      root.playbackStartingProvider = "";
      root.playbackStartingMessage = "";

      var output = String(playbackProcess.stdout.text || "").trim();
      var stderrText = String(playbackProcess.stderr.text || "").trim();

      if (output.length > 0) {
        root.applyState(output);
      } else if (stderrText.length > 0 && exitCode !== 0) {
        root.lastError = stderrText;
      }

      if (commandAction === "play" && exitCode === 0 && root.autoSaveMp3AfterPlayback) {
        root.maybeAutoDownloadCurrentTrack();
      }

      if (commandAction === "play" && exitCode !== 0) {
        root.queueLaunchBusy = false;
      }

      if (exitCode !== 0 && root.lastError === "") {
        root.lastError = root.pluginApi?.tr("errors.playbackFailed");
      }

      root.refreshStatus();
    }
  }

  Process {
    id: statusProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function () {
      root.statusBusy = false;
      root.applyState(String(statusProcess.stdout.text || "").trim());
    }
  }

  Process {
    id: libraryProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.libraryBusy = false;

      var output = String(libraryProcess.stdout.text || "").trim();
      var stderrText = String(libraryProcess.stderr.text || "").trim();
      if (exitCode === 0 && output.length > 0) {
        root.applyLibrary(output);
        root.lastError = "";
        root.lastNotice = root.pluginApi?.tr("notices.libraryUpdated");
      } else if (exitCode !== 0 && stderrText.length > 0) {
        root.lastNotice = "";
        root.lastError = stderrText;
      } else if (exitCode !== 0 && root.lastError === "") {
        root.lastNotice = "";
        root.lastError = root.pluginApi?.tr("errors.libraryFailed");
      }
    }
  }

  Process {
    id: downloadProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.downloadBusy = false;

      var output = String(downloadProcess.stdout.text || "").trim();
      var stderrText = String(downloadProcess.stderr.text || "").trim();

      if (exitCode === 0) {
        root.lastError = "";
        root.lastNotice = output.length > 0 ? (root.pluginApi?.tr("notices.savedMp3To", {"path": output})) : (root.pluginApi?.tr("notices.savedMp3"));
      } else {
        root.lastNotice = "";
        root.lastError = stderrText.length > 0 ? stderrText : (root.pluginApi?.tr("errors.mp3SaveFailed"));
      }
    }
  }

  Process {
    id: queueProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.queueBusy = false;

      var action = String(root.queueCommandAction || "");
      root.queueCommandAction = "";
      var output = String(queueProcess.stdout.text || "").trim();
      var stderrText = String(queueProcess.stderr.text || "").trim();

      if (exitCode === 0) {
        if (output.length > 0) {
          root.applyQueue(output);
        }
        root.lastError = "";
        if (action === "enqueue") {
          root.lastNotice = root.pluginApi?.tr("notices.addedToQueue");
        } else if (action === "remove") {
          root.lastNotice = "Removed queued track.";
        } else if (action === "remove-silent") {
          root.lastNotice = "";
        } else if (action === "clear") {
          root.lastNotice = "Queue cleared.";
        } else if (action === "load-library") {
          if (root.pendingAutoplaySaved || root.pendingAutoplaySavedShuffle) {
            var shouldShuffle = root.pendingAutoplaySavedShuffle;
            root.pendingAutoplaySaved = false;
            root.pendingAutoplaySavedShuffle = false;
            if (root.queueEntries.length > 0) {
              root.startQueue();
              if (!root.isPlaying) {
                root.lastNotice = shouldShuffle ? "Playing shuffled saved tracks." : "Playing saved tracks.";
              }
            } else {
              root.lastNotice = "Saved library is empty.";
            }
          } else {
            root.lastNotice = root.queueEntries.length > 0 ? "Queue loaded." : "Queue is empty.";
          }
        } else {
          root.lastNotice = "";
        }
      } else {
        root.pendingAutoplaySaved = false;
        root.pendingAutoplaySavedShuffle = false;
        root.lastNotice = "";
        root.lastError = stderrText.length > 0 ? stderrText : (root.pluginApi?.tr("errors.queueFailed"));
      }
    }
  }

  Process {
    id: queueBatchProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      var output = String(queueBatchProcess.stdout.text || "").trim();
      var stderrText = String(queueBatchProcess.stderr.text || "").trim();
      if (exitCode !== 0) {
        root.finishQueueBatch(stderrText.length > 0 ? stderrText : (root.pluginApi?.tr("errors.queuePlaylistTrackFailed")), "");
        return;
      }

      if (output.length > 0) {
        root.applyQueue(output);
      }
      root.queueBatchIndex += 1;
      root.runNextQueueBatchStep();
    }
  }

  Process {
    id: queueControlProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      var action = root.queueControlAction;
      var stderrText = String(queueControlProcess.stderr.text || "").trim();
      root.queueControlAction = "";

      if (!root.queueBatchBusy) {
        if (exitCode !== 0 && stderrText.length > 0) {
          root.lastError = stderrText;
        }
        return;
      }

      if (exitCode !== 0) {
        root.finishQueueBatch(stderrText.length > 0 ? stderrText : (root.pluginApi?.tr("errors.queueActionFailed", {"action": action})), "");
        return;
      }

      if (action === "clear") {
        var output = String(queueControlProcess.stdout.text || "").trim();
        if (output.length > 0) {
          root.applyQueue(output);
        }
        root.runNextQueueBatchStep();
        return;
      }
    }
  }

  Process {
    id: pauseProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.pauseBusy = false;

      var output = String(pauseProcess.stdout.text || "").trim();
      var stderrText = String(pauseProcess.stderr.text || "").trim();

      if (output.length > 0) {
        root.applyState(output);
      } else if (stderrText.length > 0 && exitCode !== 0) {
        root.lastError = stderrText;
      }
    }
  }

  Process {
    id: positionProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function () {
      root.positionBusy = false;
      var output = String(positionProcess.stdout.text || "").trim();
      if (output.length > 0) {
        try {
          var parsed = JSON.parse(output);
          root.currentPosition = parsed.position || 0;
        } catch (error) {}
      }
    }
  }

  Process {
    id: seekProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.seekBusy = false;

      var output = String(seekProcess.stdout.text || "").trim();
      var stderrText = String(seekProcess.stderr.text || "").trim();

      if (exitCode === 0 && output.length > 0) {
        try {
          var parsed = JSON.parse(output);
          root.currentPosition = parsed.position || 0;
          root.lastError = "";
        } catch (error) {
          root.lastError = root.pluginApi?.tr("errors.seekMalformed");
        }
      } else if (exitCode !== 0) {
        root.lastError = stderrText.length > 0 ? stderrText : (root.pluginApi?.tr("errors.seekFailed"));
      }

      var pendingSeek = Number(root.pendingSeekPosition);
      root.pendingSeekPosition = -1;

      if (isFinite(pendingSeek) && pendingSeek >= 0) {
        root.startSeek(pendingSeek);
        return;
      }

      root.refreshStatus(true);
    }
  }

  Process {
    id: speedProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.speedBusy = false;

      var output = String(speedProcess.stdout.text || "").trim();
      var stderrText = String(speedProcess.stderr.text || "").trim();

      if (exitCode === 0 && output.length > 0) {
        root.applyState(output);
        root.lastError = "";
      } else if (exitCode !== 0) {
        root.lastError = stderrText.length > 0 ? stderrText : (root.pluginApi?.tr("errors.speedFailed"));
      }
    }
  }

  Timer {
    id: positionTimer
    interval: 1000
    repeat: true
    running: root.isPlaying && !root.isPaused && !root.seekBusy

    onTriggered: {
      if (root.positionBusy) {
        return;
      }
      root.positionBusy = true;
      positionProcess.exec({
                             "command": root.buildCommand(["position"])
                           });
    }
  }

  Process {
    id: providerProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.providerBusy = false;

      var output = String(providerProcess.stdout.text || "").trim();
      if (exitCode === 0 && output.length > 0) {
        root.applySettings(output);
        root.lastError = "";
        root.lastNotice = root.providerSuccessNotice.length > 0
            ? root.providerSuccessNotice
            : ("Switched to " + root.providerLabel(root.currentProvider) + ".");
      } else {
        var stderrText = String(providerProcess.stderr.text || "").trim();
        if (stderrText.length > 0) {
          root.lastError = stderrText;
        }
      }
      root.providerSuccessNotice = "";
    }
  }

  Process {
    id: playlistsProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.playlistsBusy = false;

      var output = String(playlistsProcess.stdout.text || "").trim();
      var stderrText = String(playlistsProcess.stderr.text || "").trim();
      if (exitCode === 0 && output.length > 0) {
        root.applyPlaylists(output);
        root.lastError = "";
        if (root.pendingPlaylistCreateName.length > 0 && root.pendingPlaylistCreateEntryId.length > 0) {
          var createdPlaylist = root.findPlaylistByName(root.pendingPlaylistCreateName);
          var pendingEntryId = root.pendingPlaylistCreateEntryId;
          root.pendingPlaylistCreateName = "";
          root.pendingPlaylistCreateEntryId = "";
          if (createdPlaylist) {
            root.addToPlaylist(createdPlaylist.id, pendingEntryId);
            return;
          }
        } else {
          root.pendingPlaylistCreateName = "";
          root.pendingPlaylistCreateEntryId = "";
        }
        root.lastNotice = root.pluginApi?.tr("notices.playlistsUpdated");
      } else if (exitCode !== 0 && stderrText.length > 0) {
        root.pendingPlaylistCreateName = "";
        root.pendingPlaylistCreateEntryId = "";
        root.lastNotice = "";
        root.lastError = stderrText;
      }
    }
  }

  Process {
    id: importProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.importBusy = false;

      var output = String(importProcess.stdout.text || "").trim();
      var stderrText = String(importProcess.stderr.text || "").trim();
      if (exitCode === 0) {
        root.lastError = "";
        root.lastNotice = output.length > 0 ? output : (root.pluginApi?.tr("notices.folderImported"));
      } else {
        root.lastNotice = "";
        root.lastError = stderrText.length > 0 ? stderrText : (root.pluginApi?.tr("errors.folderImportFailed"));
      }
    }
  }

  IpcHandler {
    target: "plugin:music"

    function toggle() {
      if (root.isPlaying) {
        root.stopPlayback();
      } else {
        root.openLauncher();
      }
    }

    function launcher() {
      root.openLauncher();
    }

    function play(url: string) {
      var target = String(url || "").trim();
      if (target.length === 0) {
        return;
      }
      root.playUrl(target, "Custom URL");
    }

    function playEntry(entryId: string, title: string, url: string, uploader: string, duration: string) {
      var target = String(url || "").trim();
      if (target.length === 0) {
        return;
      }

      root.playEntry({
                       "id": String(entryId || "").trim(),
                       "title": String(title || "").trim() || "Untitled",
                       "url": target,
                       "uploader": String(uploader || "").trim(),
                       "duration": Number(duration || 0)
                     });
    }

    function stop() {
      root.stopPlayback();
    }

    function pause() {
      root.pausePlayback();
    }

    function resume() {
      root.resumePlayback();
    }

    function seek(position: real) {
      root.seekToPosition(Number(position));
    }

    function speed(value: real) {
      root.setSpeed(Number(value));
    }

    function setProvider(provider: string) {
      root.setProvider(String(provider || "").trim());
    }

    function renamePlaylist(playlistId: string, name: string) {
      root.renamePlaylist(String(playlistId || "").trim(), String(name || "").trim());
    }

    function save(url: string) {
      var target = String(url || "").trim();
      if (target.length === 0) {
        return;
      }
      root.saveUrl(target);
    }

    function status() {
      root.refreshStatus(true);
    }
  }

  function buildCommand(extraArgs) {
    var command = ["bash", root.helperPath];
    for (var i = 0; i < extraArgs.length; i++) {
      command.push(extraArgs[i]);
    }
    return command;
  }

  function buildQueueCommand(action, extraArgs) {
    var command = ["queue-" + action];
    for (var i = 0; i < extraArgs.length; i++) {
      command.push(extraArgs[i]);
    }
    return buildCommand(command);
  }

  function normalizeUrl(value) {
    var trimmed = String(value || "").trim();
    if (trimmed.startsWith("www.")) {
      return "https://" + trimmed;
    }
    return trimmed;
  }

  function inferProviderForEntry(entry) {
    var explicitProvider = String(entry?.provider || "").trim().toLowerCase();
    if (explicitProvider === "youtube" || explicitProvider === "soundcloud" || explicitProvider === "local") {
      return explicitProvider;
    }

    var entryUrl = String(entry?.url || "").trim();
    if (entryUrl.startsWith("/")) {
      return "local";
    }
    if (entryUrl.indexOf("youtube.com") >= 0 || entryUrl.indexOf("youtu.be") >= 0) {
      return "youtube";
    }
    if (entryUrl.indexOf("soundcloud.com") >= 0) {
      return "soundcloud";
    }
    return String(root.currentProvider || "youtube");
  }

  function startupMessageForEntry(entry) {
    var provider = inferProviderForEntry(entry);
    if (provider === "local") {
      return root.pluginApi?.tr("status.openingLocal");
    }
    if (provider === "soundcloud") {
      return root.pluginApi?.tr("status.connectingSoundcloud");
    }
    return root.pluginApi?.tr("status.connectingYoutube");
  }

  function currentTrackEntry() {
    return {
      "id": String(root.currentEntryId || ""),
      "title": String(root.currentTitle || "Untitled"),
      "url": String(root.currentUrl || ""),
      "uploader": String(root.currentUploader || ""),
      "duration": Number(root.currentDuration || 0),
      "provider": inferProviderForEntry({
                                          "provider": root.currentProvider,
                                          "url": root.currentUrl
                                        })
    };
  }

  function isLocalEntry(entry) {
    return inferProviderForEntry(entry) === "local";
  }

  function isPlaceholderEntryTitle(title) {
    var normalized = String(title || "").trim().toLowerCase();
    return normalized.length === 0
        || normalized === "custom url"
        || normalized === "queued url"
        || normalized === "downloaded track";
  }

  function playEntry(entry) {
    if (!entry || !entry.url) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.playbackBusy = true;
    root.playbackStarting = true;
    root.playbackStartingProvider = inferProviderForEntry(entry);
    root.playbackStartingMessage = startupMessageForEntry(entry);
    root.isPlaying = false;
    root.isPaused = false;
    root.currentEntryId = String(entry.id || "");
    root.currentTitle = String(entry.title || "Untitled");
    root.currentUrl = String(entry.url || "");
    root.currentUploader = String(entry.uploader || "");
    root.currentDuration = Number(entry.duration || 0);
    root.currentSpeed = 1;
    root.currentPid = 0;
    root.currentPosition = 0;
    root.currentEndReason = "";
    root.playbackCommandAction = "play";
    playbackProcess.exec({
                           "command": buildCommand([
                                                    "play",
                                                    entry.id || "",
                                                    entry.title || "Untitled",
                                                    entry.url || "",
                                                    entry.uploader || "",
                                                    String(entry.duration || 0)
                                                  ])
                         });
  }

  function playUrl(url, label) {
    var cleanedUrl = normalizeUrl(url);
    if (cleanedUrl.length === 0) {
      return;
    }

    var customEntry = {
      "id": "custom-" + Date.now(),
      "title": label || "Custom URL",
      "url": cleanedUrl,
      "uploader": "",
      "duration": 0
    };
    playEntry(customEntry);
  }

  function stopPlayback() {
    root.lastError = "";
    root.lastNotice = "";
    root.playbackBusy = true;
    root.playbackStarting = false;
    root.playbackStartingProvider = "";
    root.playbackStartingMessage = "";
    root.playbackCommandAction = "stop";
    playbackProcess.exec({
                           "command": buildCommand(["stop"])
                         });
  }

  function pausePlayback() {
    if (!root.isPlaying || root.pauseBusy) {
      return;
    }

    root.pauseBusy = true;
    pauseProcess.exec({
                        "command": buildCommand(["pause"])
                      });
  }

  function resumePlayback() {
    if (!root.isPlaying || root.pauseBusy) {
      return;
    }

    root.pauseBusy = true;
    pauseProcess.exec({
                        "command": buildCommand(["resume"])
                      });
  }

  function togglePause() {
    if (root.isPaused) {
      resumePlayback();
    } else {
      pausePlayback();
    }
  }

  function startSeek(position) {
    var target = Number(position);
    if (!isFinite(target) || target < 0) {
      return;
    }

    root.seekBusy = true;
    seekProcess.exec({
                       "command": buildCommand(["seek", String(target)])
                     });
  }

  function seekToPosition(position) {
    if (!root.isPlaying) {
      return;
    }

    var duration = Number(root.currentDuration || 0);
    var target = Number(position);
    if (!isFinite(duration) || duration <= 0 || !isFinite(target)) {
      return;
    }

    target = Math.max(0, Math.min(duration, target));

    if (root.seekBusy) {
      root.pendingSeekPosition = target;
      return;
    }

    root.pendingSeekPosition = -1;
    startSeek(target);
  }

  function seekToRatio(ratio) {
    var duration = Number(root.currentDuration || 0);
    var targetRatio = Number(ratio);
    if (!isFinite(duration) || duration <= 0 || !isFinite(targetRatio)) {
      return;
    }

    seekToPosition(targetRatio * duration);
  }

  function clampSpeed(speed) {
    var target = Number(speed);
    if (!isFinite(target)) {
      return 1;
    }
    return Math.max(0.25, Math.min(4, target));
  }

  function setSpeed(speed) {
    if (!root.isPlaying || root.speedBusy) {
      return;
    }

    var target = clampSpeed(speed);
    root.speedBusy = true;
    speedProcess.exec({
                        "command": buildCommand(["speed", String(target)])
                      });
  }

  function adjustSpeed(delta) {
    setSpeed(clampSpeed(Number(root.currentSpeed || 1) + Number(delta || 0)));
  }

  function setProvider(provider) {
    var target = String(provider || "").trim();
    if (target.length === 0 || root.providerBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.providerBusy = true;
    root.providerSuccessNotice = root.pluginApi?.tr("notices.switchedTo", {"provider": root.providerLabel(target)});
    providerProcess.exec({
                           "command": buildCommand(["set-provider", target])
                         });
  }

  function cycleProvider() {
    var providers = ["youtube", "soundcloud", "local"];
    var currentIndex = providers.indexOf(root.currentProvider);
    var nextIndex = (currentIndex + 1) % providers.length;
    setProvider(providers[nextIndex]);
  }

  function providerLabel(provider) {
    var p = String(provider || root.currentProvider);
    if (p === "youtube") return "YouTube";
    if (p === "soundcloud") return "SoundCloud";
    if (p === "local") return "Local";
    return p;
  }

  function tagEntry(entryId, tag) {
    var targetId = String(entryId || "").trim();
    var targetTag = String(tag || "").trim();
    if (targetId.length === 0 || targetTag.length === 0 || root.libraryBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.libraryBusy = true;
    libraryProcess.exec({
                          "command": buildCommand(["tag", targetId, targetTag])
                        });
  }

  function untagEntry(entryId, tag) {
    var targetId = String(entryId || "").trim();
    var targetTag = String(tag || "").trim();
    if (targetId.length === 0 || targetTag.length === 0 || root.libraryBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.libraryBusy = true;
    libraryProcess.exec({
                          "command": buildCommand(["untag", targetId, targetTag])
                        });
  }

  function rateEntry(entryId, rating) {
    var targetId = String(entryId || "").trim();
    if (targetId.length === 0 || root.libraryBusy) {
      return;
    }

    var r = Number(rating || 0);
    if (r < 0) r = 0;
    if (r > 5) r = 5;

    root.lastError = "";
    root.lastNotice = "";
    root.libraryBusy = true;
    libraryProcess.exec({
                          "command": buildCommand(["rate", targetId, String(r)])
                        });
  }

  function cycleRating(entryId) {
    var entry = null;
    for (var i = 0; i < libraryEntries.length; i++) {
      if (libraryEntries[i].id === entryId) {
        entry = libraryEntries[i];
        break;
      }
    }
    var current = entry ? (entry.rating || 0) : 0;
    var next = (current + 1) % 6;
    rateEntry(entryId, next);
  }

  function setSortBy(sortBy) {
    var target = String(sortBy || "").trim();
    if (target.length === 0 || root.providerBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.providerBusy = true;
    root.providerSuccessNotice = root.pluginApi?.tr("notices.sortSet", {"sort": root.sortLabel(target)});
    providerProcess.exec({
                           "command": buildCommand(["set-sort", target])
                         });
  }

  function setDownloadDirectory(directory) {
    var target = String(directory || "").trim();
    if (target.length === 0 || root.providerBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.providerBusy = true;
    root.providerSuccessNotice = root.pluginApi?.tr("notices.downloadFolderUpdated");
    providerProcess.exec({
                           "command": buildCommand(["set-download-dir", target])
                         });
  }

  function setDownloadCacheMaxMb(value) {
    var target = Math.max(0, Math.floor(Number(value || 0)));
    if (!isFinite(target) || root.providerBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.providerBusy = true;
    root.providerSuccessNotice = root.pluginApi?.tr("notices.cacheLimitUpdated");
    providerProcess.exec({
                           "command": buildCommand(["set-cache-size", String(target)])
                         });
  }

  function setYtPlayerClient(client) {
    var target = String(client || "").trim();
    if (target.length === 0 || root.providerBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.providerBusy = true;
    root.providerSuccessNotice = root.pluginApi?.tr("notices.ytClientSet", {"client": target});
    providerProcess.exec({
                           "command": buildCommand(["set-yt-player-client", target])
                         });
  }

  function cycleSortBy() {
    var modes = ["date", "title", "duration", "rating"];
    var currentIndex = modes.indexOf(root.currentSortBy);
    var nextIndex = (currentIndex + 1) % modes.length;
    setSortBy(modes[nextIndex]);
  }

  function sortLabel(sortBy) {
    var s = String(sortBy || root.currentSortBy);
    if (s === "date") return "Date";
    if (s === "title") return "Title";
    if (s === "duration") return "Duration";
    if (s === "rating") return "Rating";
    return s;
  }

  function findPlaylistByName(name) {
    var targetName = String(name || "").trim().toLowerCase();
    if (targetName.length === 0) {
      return null;
    }

    for (var i = playlistEntries.length - 1; i >= 0; i--) {
      if (String(playlistEntries[i].name || "").trim().toLowerCase() === targetName) {
        return playlistEntries[i];
      }
    }

    return null;
  }

  function findPlaylistById(playlistId) {
    var targetId = String(playlistId || "").trim();
    if (targetId.length === 0) {
      return null;
    }

    for (var i = 0; i < playlistEntries.length; i++) {
      if (String(playlistEntries[i].id || "") === targetId) {
        return playlistEntries[i];
      }
    }

    return null;
  }

  function copyEntry(entry) {
    return {
      "id": entry?.id ?? "",
      "title": String(entry?.title || entry?.name || "Untitled"),
      "url": String(entry?.url || ""),
      "uploader": String(entry?.uploader || ""),
      "duration": Number(entry?.duration || 0),
      "provider": String(entry?.provider || ""),
      "album": String(entry?.album || ""),
      "localPath": String(entry?.localPath || ""),
      "tags": entry?.tags || [],
      "rating": Number(entry?.rating || 0),
      "playCount": Number(entry?.playCount || 0),
      "lastPlayedAt": String(entry?.lastPlayedAt || "")
    };
  }

  function shuffleEntries(entries) {
    var shuffled = entries.slice();
    for (var i = shuffled.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var tmp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = tmp;
    }
    return shuffled;
  }

  function playlistTracks(playlistId, shuffle) {
    var playlist = findPlaylistById(playlistId);
    if (!playlist) {
      return [];
    }

    var tracks = [];
    var entryIds = playlist.entryIds || [];
    for (var i = 0; i < entryIds.length; i++) {
      var entryId = String(entryIds[i] || "");
      for (var j = 0; j < libraryEntries.length; j++) {
        if (String(libraryEntries[j].id || "") === entryId) {
          tracks.push(copyEntry(libraryEntries[j]));
          break;
        }
      }
    }

    return shuffle === true ? shuffleEntries(tracks) : tracks;
  }

  function createPlaylist(name, entryIdToAdd) {
    var targetName = String(name || "").trim();
    var targetEntryId = String(entryIdToAdd || "").trim();
    if (targetName.length === 0 || root.playlistsBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.pendingPlaylistCreateName = targetEntryId.length > 0 ? targetName : "";
    root.pendingPlaylistCreateEntryId = targetEntryId;
    root.playlistsBusy = true;
    playlistsProcess.exec({
                            "command": buildCommand(["create-playlist", targetName])
                          });
  }

  function renamePlaylist(playlistId, name) {
    var targetId = String(playlistId || "").trim();
    var targetName = String(name || "").trim();
    if (targetId.length === 0 || targetName.length === 0 || root.playlistsBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.playlistsBusy = true;
    playlistsProcess.exec({
                            "command": buildCommand(["rename-playlist", targetId, targetName])
                          });
  }

  function deletePlaylist(playlistId) {
    var targetId = String(playlistId || "").trim();
    if (targetId.length === 0 || root.playlistsBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.playlistsBusy = true;
    playlistsProcess.exec({
                            "command": buildCommand(["delete-playlist", targetId])
                          });
  }

  function addToPlaylist(playlistId, entryId) {
    var pId = String(playlistId || "").trim();
    var eId = String(entryId || "").trim();
    if (pId.length === 0 || eId.length === 0 || root.playlistsBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.playlistsBusy = true;
    playlistsProcess.exec({
                            "command": buildCommand(["playlist-add", pId, eId])
                          });
  }

  function removeFromPlaylist(playlistId, entryId) {
    var pId = String(playlistId || "").trim();
    var eId = String(entryId || "").trim();
    if (pId.length === 0 || eId.length === 0 || root.playlistsBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.playlistsBusy = true;
    playlistsProcess.exec({
                            "command": buildCommand(["playlist-remove", pId, eId])
                          });
  }

  function finishQueueBatch(errorText, noticeText) {
    root.queueBatchBusy = false;
    root.queueBusy = false;
    root.queueBatchEntries = [];
    root.queueBatchIndex = 0;
    root.queueBatchFinalAction = "";
    root.queueBatchDoneNotice = "";
    root.queueControlAction = "";
    root.queueCommandAction = "";

    if (errorText && String(errorText).length > 0) {
      root.lastNotice = "";
      root.lastError = String(errorText);
      return;
    }

    root.lastError = "";
    if (noticeText && String(noticeText).length > 0) {
      root.lastNotice = String(noticeText);
    }
  }

  function runNextQueueBatchStep() {
    if (!root.queueBatchBusy) {
      return;
    }

    if (root.queueBatchIndex < root.queueBatchEntries.length) {
      var entry = root.queueBatchEntries[root.queueBatchIndex];
      queueBatchProcess.exec({
                               "command": buildQueueCommand("enqueue", [
                                                               entry.id || "",
                                                               entry.title || "Untitled",
                                                               entry.url || "",
                                                               entry.uploader || "",
                                                               String(entry.duration || 0)
                                                             ])
                             });
      return;
    }

    if (root.queueBatchFinalAction.length > 0) {
      if (root.queueBatchFinalAction === "skip") {
        root.skipQueue();
      } else if (root.queueBatchFinalAction === "start") {
        root.startQueue();
      } else if (root.queueBatchFinalAction === "stop") {
        root.stopQueue();
      }
      root.finishQueueBatch("", root.queueBatchDoneNotice);
      return;
    }

    root.finishQueueBatch("", root.queueBatchDoneNotice);
  }

  function startQueueBatch(entries, options) {
    if (root.queueBusy || root.queueBatchBusy) {
      return;
    }

    var filteredEntries = [];
    for (var i = 0; i < entries.length; i++) {
      var normalized = copyEntry(entries[i]);
      if (normalized.url.length > 0) {
        filteredEntries.push(normalized);
      }
    }

    var clearFirst = options?.clearFirst === true;
    var finalAction = String(options?.finalAction || "").trim();
    var doneNotice = String(options?.doneNotice || "").trim();
    var emptyNotice = String(options?.emptyNotice || "Playlist is empty.").trim();

    if (filteredEntries.length === 0) {
      root.lastError = "";
      root.lastNotice = emptyNotice;
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.queueBusy = true;
    root.queueBatchBusy = true;
    root.queueBatchEntries = filteredEntries;
    root.queueBatchIndex = 0;
    root.queueBatchFinalAction = finalAction;
    root.queueBatchDoneNotice = doneNotice;

    if (clearFirst) {
      root.queueControlAction = "clear";
      queueControlProcess.exec({
                                 "command": buildQueueCommand("clear", [])
                               });
      return;
    }

    root.runNextQueueBatchStep();
  }

  function queuePlaylist(playlistId, shuffle) {
    var playlist = findPlaylistById(playlistId);
    var entries = playlistTracks(playlistId, shuffle);
    var playlistName = String(playlist?.name || "playlist");
    startQueueBatch(entries, {
                      "clearFirst": false,
                      "doneNotice": shuffle === true
                          ? (root.pluginApi?.tr("notices.addedShuffledPlaylistToQueue", {"name": playlistName}))
                          : (root.pluginApi?.tr("notices.addedPlaylistToQueue", {"name": playlistName})),
                      "emptyNotice": root.pluginApi?.tr("notices.playlistEmpty")
                    });
  }

  function playPlaylist(playlistId, shuffle) {
    var playlist = findPlaylistById(playlistId);
    var entries = playlistTracks(playlistId, shuffle);
    if (entries.length === 0) {
      root.lastError = "";
      root.lastNotice = root.pluginApi?.tr("notices.playlistEmpty");
      return;
    }

    var playlistName = String(playlist?.name || "playlist");
    startQueueBatch(entries, {
                      "clearFirst": true,
                      "finalAction": "skip",
                      "doneNotice": shuffle === true
                          ? (root.pluginApi?.tr("notices.playingShuffledPlaylist", {"name": playlistName}))
                          : (root.pluginApi?.tr("notices.playingPlaylist", {"name": playlistName})),
                      "emptyNotice": root.pluginApi?.tr("notices.playlistEmpty")
                    });
  }

  function applyQueue(rawText) {
    var text = String(rawText || "").trim();
    if (text.length === 0) {
      root.queueEntries = [];
      return;
    }

    try {
      var parsed = JSON.parse(text);
      if (Array.isArray(parsed)) {
        root.queueEntries = parsed.map(function (entry) {
          return {
            "id": String(entry?.id || ""),
            "title": String(entry?.title || "Untitled"),
            "url": String(entry?.url || ""),
            "uploader": String(entry?.uploader || ""),
            "duration": Number(entry?.duration || 0),
            "queuedAt": String(entry?.queuedAt || "")
          };
        });
      } else {
        root.queueEntries = [];
      }
    } catch (error) {
      Logger.w("MusicSearch", "Failed to parse queue:", error);
      root.queueEntries = [];
    }
  }

  function removeQueueEntry(entryId, showNotice) {
    var targetId = String(entryId || "").trim();
    if (targetId.length === 0 || root.queueBusy || root.queueBatchBusy) {
      return;
    }

    root.lastError = "";
    if (showNotice !== false) {
      root.lastNotice = "";
    }
    root.queueBusy = true;
    root.queueCommandAction = showNotice === false ? "remove-silent" : "remove";
    queueProcess.exec({
                        "command": buildQueueCommand("remove", [targetId])
                      });
  }

  function clearQueue() {
    if (root.queueBusy || root.queueBatchBusy) {
      return;
    }

    root.queueActive = false;
    root.pendingAutoplaySaved = false;
    root.pendingAutoplaySavedShuffle = false;
    root.pendingQueueLaunchEntry = null;
    root.pendingQueueLaunchEntryId = "";
    root.queueLaunchBusy = false;
    root.lastError = "";
    root.lastNotice = "";
    root.queueBusy = true;
    root.queueCommandAction = "clear";
    queueProcess.exec({
                        "command": buildQueueCommand("clear", [])
                      });
  }

  function launchQueueEntry(entry) {
    var normalized = copyEntry(entry);
    if (!normalized.url || root.queueLaunchBusy || root.playbackBusy) {
      return;
    }

    root.queueActive = true;
    root.pendingQueueLaunchEntry = normalized;
    root.pendingQueueLaunchEntryId = normalized.id;
    root.queueLaunchBusy = true;
    playEntry(normalized);
  }

  function playQueueEntryNow(entry) {
    if (!entry || !entry.url) {
      return;
    }

    launchQueueEntry(entry);
  }

  function startQueue() {
    if (root.queueEntries.length === 0) {
      root.queueActive = false;
      root.lastError = "";
      root.lastNotice = "Queue is empty.";
      return;
    }

    root.queueActive = true;
    if (!root.isPlaying && !root.playbackBusy) {
      root.launchQueueEntry(root.queueEntries[0]);
    } else {
      root.lastError = "";
      root.lastNotice = "Queue armed. It will start after the current song finishes.";
    }
  }

  function stopQueue() {
    root.queueActive = false;
    root.pendingAutoplaySaved = false;
    root.pendingAutoplaySavedShuffle = false;
    root.lastError = "";
    root.lastNotice = "Queue stopped.";
  }

  function skipQueue() {
    if (root.queueEntries.length === 0) {
      root.queueActive = false;
      root.lastError = "";
      root.lastNotice = "No next queued track.";
      return;
    }

    root.launchQueueEntry(root.queueEntries[0]);
  }

  function autoplaySavedTracks(shuffle) {
    if (root.queueBusy || root.queueBatchBusy) {
      return;
    }

    root.queueActive = false;
    root.pendingAutoplaySaved = shuffle !== true;
    root.pendingAutoplaySavedShuffle = shuffle === true;
    root.lastError = "";
    root.lastNotice = shuffle === true ? "Loading saved tracks into shuffled queue..." : "Loading saved tracks into queue...";
    root.queueBusy = true;
    root.queueCommandAction = "load-library";
    queueProcess.exec({
                        "command": buildQueueCommand("load-library", [root.libraryPath, shuffle === true ? "shuffle" : "ordered"])
                      });
  }

  function saveEntry(entry) {
    if (!entry || !entry.url) {
      return;
    }

    var entryUrl = String(entry.url || "").trim();
    var effectiveTitle = String(entry.title || entry.name || "").trim();
    var effectiveUploader = String(entry.uploader || "").trim();
    var effectiveDuration = Number(entry.duration || 0);
    var usingCurrentPlayback = entryUrl.length > 0 && entryUrl === root.currentUrl;

    if (usingCurrentPlayback && !isPlaceholderEntryTitle(root.currentTitle)) {
      effectiveTitle = String(root.currentTitle || "").trim();
      if (effectiveUploader.length === 0 && String(root.currentUploader || "").trim().length > 0) {
        effectiveUploader = String(root.currentUploader || "").trim();
      }
      if ((!isFinite(effectiveDuration) || effectiveDuration <= 0) && Number(root.currentDuration || 0) > 0) {
        effectiveDuration = Number(root.currentDuration || 0);
      }
    }

    if (!entryUrl.startsWith("/") && isPlaceholderEntryTitle(effectiveTitle)) {
      root.saveUrl(entryUrl);
      return;
    }

    if (effectiveTitle.length === 0 && usingCurrentPlayback) {
      effectiveTitle = String(root.currentTitle || "").trim();
      if (effectiveUploader.length === 0) {
        effectiveUploader = String(root.currentUploader || "").trim();
      }
      if (!isFinite(effectiveDuration) || effectiveDuration <= 0) {
        effectiveDuration = Number(root.currentDuration || 0);
      }
    }

    root.lastError = "";
    root.lastNotice = "";
    root.libraryBusy = true;
    libraryProcess.exec({
                          "command": buildCommand([
                                                   "save",
                                                   entry.id || "",
                                                   effectiveTitle || "Untitled",
                                                   entryUrl,
                                                   effectiveUploader,
                                                   String(isFinite(effectiveDuration) ? effectiveDuration : 0)
                                                 ])
                        });
  }

  function saveUrl(url) {
    var cleanedUrl = normalizeUrl(url);
    if (cleanedUrl.length === 0) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.libraryBusy = true;
    libraryProcess.exec({
                          "command": buildCommand(["save-url", cleanedUrl])
                        });
  }

  function removeEntry(entryId) {
    var targetId = String(entryId || "").trim();
    if (targetId.length === 0) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.libraryBusy = true;
    libraryProcess.exec({
                          "command": buildCommand(["remove", targetId])
                        });
  }

  function editMetadata(entryId, field, value) {
    var targetId = String(entryId || "").trim();
    var targetField = String(field || "").trim();
    var targetValue = String(value || "");
    if (targetId.length === 0 || targetField.length === 0 || root.libraryBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.libraryBusy = true;
    libraryProcess.exec({
                          "command": buildCommand(["edit-metadata", targetId, targetField, targetValue])
                        });
  }

  function importFolderAsPlaylist(folderPath, playlistName) {
    var targetFolder = String(folderPath || "").trim();
    var targetName = String(playlistName || "").trim();
    if (targetFolder.length === 0 || root.importBusy || root.libraryBusy || root.playlistsBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = root.pluginApi?.tr("notices.importingFolder");
    root.importBusy = true;

    var commandArgs = ["import-folder-playlist", targetFolder];
    if (targetName.length > 0) {
      commandArgs.push(targetName);
    }

    importProcess.exec({
                         "command": buildCommand(commandArgs)
                       });
  }

  function syncFolderPlaylist(playlistId) {
    var targetId = String(playlistId || "").trim();
    if (targetId.length === 0 || root.importBusy || root.playlistsBusy) {
      return;
    }

    root.lastError = "";
    root.lastNotice = root.pluginApi?.tr("notices.syncingFolder");
    root.importBusy = true;
    importProcess.exec({
                         "command": buildCommand(["sync-folder-playlist", targetId])
                       });
  }

  function downloadEntry(entry) {
    if (!entry || !entry.url) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.downloadBusy = true;
    downloadProcess.exec({
                           "command": buildCommand([
                                                    "download-mp3",
                                                    entry.title || "Downloaded Track",
                                                    entry.url || ""
                                                  ])
                         });
  }

  function downloadCurrentTrack() {
    var entry = currentTrackEntry();
    if (!entry.url || isLocalEntry(entry)) {
      return;
    }

    downloadEntry(entry);
  }

  function maybeAutoDownloadCurrentTrack() {
    var entry = currentTrackEntry();
    if (!entry.url || root.downloadBusy || isLocalEntry(entry)) {
      return;
    }

    root.lastNotice = root.pluginApi?.tr("notices.savingMp3");
    downloadEntry(entry);
  }

  function downloadUrl(url, label) {
    var cleanedUrl = normalizeUrl(url);
    if (cleanedUrl.length === 0) {
      return;
    }

    downloadEntry({
                    "title": label || "Downloaded Track",
                    "url": cleanedUrl
                  });
  }

  function enqueueEntry(entry) {
    if (!entry || !entry.url) {
      return;
    }

    root.lastError = "";
    root.lastNotice = "";
    root.queueBusy = true;
    root.queueCommandAction = "enqueue";
    queueProcess.exec({
                        "command": buildQueueCommand("enqueue", [
                                                       entry.id || "",
                                                       entry.title || entry.name || "Untitled",
                                                       entry.url || "",
                                                       entry.uploader || "",
                                                       String(entry.duration || 0)
                                                     ])
                      });
  }

  function enqueueUrl(url, label) {
    var cleanedUrl = normalizeUrl(url);
    if (cleanedUrl.length === 0) {
      return;
    }

    enqueueEntry({
                   "id": "queued-" + Date.now(),
                   "title": label || "Queued URL",
                   "url": cleanedUrl,
                   "uploader": "",
                   "duration": 0
                 });
  }

  function isSaved(entry) {
    if (!entry) {
      return false;
    }

    for (var i = 0; i < libraryEntries.length; i++) {
      var candidate = libraryEntries[i];
      if (candidate.isSaved === false) {
        continue;
      }
      if (entry.id && candidate.id === entry.id) {
        return true;
      }
      if (entry.url && candidate.url === entry.url) {
        return true;
      }
    }

    return false;
  }

  function findSavedEntry(entry) {
    if (!entry) {
      return null;
    }

    for (var i = 0; i < libraryEntries.length; i++) {
      var candidate = libraryEntries[i];
      if (candidate.isSaved === false) {
        continue;
      }
      if (entry.id && candidate.id === entry.id) {
        return candidate;
      }
      if (entry.url && candidate.url === entry.url) {
        return candidate;
      }
    }

    return null;
  }

  function findLibraryEntry(entry) {
    if (!entry) {
      return null;
    }

    for (var i = 0; i < libraryEntries.length; i++) {
      var candidate = libraryEntries[i];
      if (entry.id && candidate.id === entry.id) {
        return candidate;
      }
      if (entry.url && candidate.url === entry.url) {
        return candidate;
      }
    }

    return null;
  }

  function refreshStatus(forceRefresh) {
    if ((root.statusBusy || root.playbackBusy) && forceRefresh !== true) {
      return;
    }

    root.statusBusy = true;
    statusProcess.exec({
                         "command": buildCommand(["status"])
                       });
  }

  function openLauncher() {
    if (!pluginApi) {
      return;
    }

    pluginApi.withCurrentScreen(function (screen) {
      pluginApi.openLauncher(screen);
    });
  }

  function applyState(rawText) {
    var text = String(rawText || "").trim();
    if (text.length === 0) {
      return;
    }

    try {
      var state = JSON.parse(text);
      var previousEntryId = root.currentEntryId;
      var previousUrl = root.currentUrl;
      root.isPlaying = state.isPlaying === true;
      root.isPaused = state.isPaused === true;
      root.currentEntryId = state.id || "";
      root.currentTitle = state.title || "";
      root.currentUrl = state.url || "";
      root.currentUploader = state.uploader || "";
      root.currentDuration = state.duration || 0;
      root.currentSpeed = Number(state.speed || 1) || 1;
      root.currentPid = state.pid || 0;
      root.lastError = state.error || "";
      root.currentEndReason = state.endReason || "";
      root.currentUpdatedAt = state.updatedAt || "0";
      if ((root.currentEntryId && root.currentEntryId === previousEntryId) || (root.currentUrl && root.currentUrl === previousUrl) || state.isPlaying !== true) {
        root.playbackStarting = false;
        root.playbackStartingProvider = "";
        root.playbackStartingMessage = "";
      }
      if (!state.isPlaying) {
        root.currentPosition = 0;
        root.currentSpeed = Number(state.speed || 1) || 1;
      } else if (root.currentEntryId !== previousEntryId || root.currentUrl !== previousUrl) {
        root.currentPosition = 0;
      }

      if (root.pendingQueueLaunchEntry
          && root.isPlaying
          && ((root.pendingQueueLaunchEntry.id && root.currentEntryId === root.pendingQueueLaunchEntry.id)
              || (root.pendingQueueLaunchEntry.url && root.currentUrl === root.pendingQueueLaunchEntry.url))) {
        root.queueLaunchBusy = false;
        root.removeQueueEntry(root.pendingQueueLaunchEntry.id, false);
        root.lastError = "";
        root.lastNotice = "Queued playback: " + (root.pendingQueueLaunchEntry.title || "Untitled");
        root.pendingQueueLaunchEntry = null;
        root.pendingQueueLaunchEntryId = "";
      }

      if (root.queueActive
          && !root.isPlaying
          && root.currentUpdatedAt.length > 0
          && root.currentUpdatedAt !== root.lastHandledQueueUpdate
          && (root.currentEndReason === "finished" || root.currentEndReason === "error")) {
        root.lastHandledQueueUpdate = root.currentUpdatedAt;
        root.queueLaunchBusy = false;
        if (root.queueEntries.length > 0) {
          root.launchQueueEntry(root.queueEntries[0]);
        } else {
          root.queueActive = false;
          if (root.currentEndReason === "error") {
            root.lastNotice = "";
            root.lastError = "Queue ran out after a playback error.";
          } else {
            root.lastError = "";
            root.lastNotice = "Queue finished.";
          }
        }
      }
    } catch (error) {
      Logger.w("MusicSearch", "Failed to parse music state:", error);
    }
  }

  function applyLibrary(rawText) {
    var text = String(rawText || "").trim();
    if (text.length === 0) {
      root.libraryEntries = [];
      return;
    }

    try {
      var parsed = JSON.parse(text);
      if (Array.isArray(parsed)) {
        root.libraryEntries = parsed.map(function (entry) {
          return {
            "id": String(entry?.id || ""),
            "title": String(entry?.title || "Untitled"),
            "url": String(entry?.url || ""),
            "uploader": String(entry?.uploader || ""),
            "duration": Number(entry?.duration || 0),
            "savedAt": String(entry?.savedAt || ""),
            "provider": String(entry?.provider || ""),
            "album": String(entry?.album || ""),
            "localPath": String(entry?.localPath || ""),
            "isSaved": entry?.isSaved !== false,
            "tags": Array.isArray(entry?.tags) ? entry.tags : [],
            "rating": Number(entry?.rating || 0),
            "playCount": Number(entry?.playCount || 0),
            "lastPlayedAt": String(entry?.lastPlayedAt || "")
          };
        });
      } else {
        root.libraryEntries = [];
      }
    } catch (error) {
      Logger.w("MusicSearch", "Failed to parse music library:", error);
      root.libraryEntries = [];
    }
  }

  function visibleLibraryEntries() {
    return libraryEntries.filter(function (entry) {
      return entry?.isSaved !== false;
    });
  }

  function applySettings(rawText) {
    var text = String(rawText || "").trim();
    if (text.length === 0) {
      return;
    }

    try {
      var settings = JSON.parse(text);
      root.currentProvider = settings.activeProvider || "youtube";
      root.currentSortBy = settings.sortBy || "date";
      root.downloadDirectory = settings.downloadDirectory || (Quickshell.env("HOME") + "/Music/Noctalia");
      root.downloadCacheMaxMb = Number(settings.downloadCacheMaxMb || 0);
      root.ytPlayerClient = settings.ytPlayerClient || "android";
    } catch (error) {
      Logger.w("MusicSearch", "Failed to parse music settings:", error);
    }
  }

  function applyPlaylists(rawText) {
    var text = String(rawText || "").trim();
    if (text.length === 0) {
      root.playlistEntries = [];
      return;
    }

    try {
      var parsed = JSON.parse(text);
      if (Array.isArray(parsed)) {
        root.playlistEntries = parsed;
      } else {
        root.playlistEntries = [];
      }
    } catch (error) {
      Logger.w("MusicSearch", "Failed to parse playlists:", error);
      root.playlistEntries = [];
    }
  }
}
