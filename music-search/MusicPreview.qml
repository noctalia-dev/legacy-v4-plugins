import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import "MusicUtils.js" as MusicUtils

Item {
  id: previewPanel

  property var currentItem: null
  property var detailData: null
  property bool loadingDetails: false
  property string lastLoadedUrl: ""
  property string requestedUrl: ""
  property string previewError: ""
  property bool descriptionExpanded: false
  property real livePosition: 0
  property bool seekDragging: false
  readonly property var detailCacheOwner: currentItem?.provider || null
  readonly property string previewMetadataMode: detailCacheOwner?.mainInstance?.previewMetadataMode ?? detailCacheOwner?.pluginApi?.pluginSettings?.previewMetadataMode ?? currentItem?.previewMetadataMode ?? detailCacheOwner?.pluginApi?.manifest?.metadata?.defaultSettings?.previewMetadataMode ?? "always"
  readonly property string previewThumbnailSize: detailCacheOwner?.mainInstance?.previewThumbnailSize ?? detailCacheOwner?.pluginApi?.pluginSettings?.previewThumbnailSize ?? currentItem?.previewThumbnailSize ?? detailCacheOwner?.pluginApi?.manifest?.metadata?.defaultSettings?.previewThumbnailSize ?? "comfortable"
  readonly property real compactArtworkHeight: Math.round((previewThumbnailSize === "small" ? 120 : (previewThumbnailSize === "large" ? 190 : 150)) * Style.uiScaleRatio)
  readonly property real fullArtworkHeight: Math.round((previewThumbnailSize === "small" ? 180 : (previewThumbnailSize === "large" ? 280 : 220)) * Style.uiScaleRatio)
  readonly property real effectiveArtworkHeight: {
    if (contentArea.height <= 0) {
      return fullArtworkHeight;
    }
    var responsiveHeight = Math.round(contentArea.height * 0.4);
    return Math.max(compactArtworkHeight, Math.min(fullArtworkHeight, responsiveHeight));
  }
  readonly property bool compactLayout: contentArea.height > 0 && effectiveArtworkHeight < (fullArtworkHeight - Math.round(8 * Style.uiScaleRatio))
  readonly property bool showUploaderMetadata: detailCacheOwner?.mainInstance?.showUploaderMetadata !== false
  readonly property bool showAlbumMetadata: detailCacheOwner?.mainInstance?.showAlbumMetadata !== false
  readonly property bool showDurationMetadata: detailCacheOwner?.mainInstance?.showDurationMetadata !== false
  readonly property bool showPlayStatsMetadata: detailCacheOwner?.mainInstance?.showPlayStatsMetadata !== false
  readonly property bool showStatusMetadata: detailCacheOwner?.mainInstance?.showStatusMetadata !== false
  readonly property real currentSpeed: detailCacheOwner?.mainInstance?.currentSpeed || 1
  readonly property real maxPreviewHeight: Math.round(560 * Style.uiScaleRatio)

  implicitHeight: Math.min(previewContent.implicitHeight + (Style.marginS * 2), maxPreviewHeight)

  function detailCache() {
    return detailCacheOwner?.previewDetailCache || ({});
  }

  function cacheDetailsForUrl(url, details) {
    if (!detailCacheOwner || !url) {
      return;
    }

    var updatedCache = {};
    var existingCache = detailCache();
    for (var key in existingCache) {
      updatedCache[key] = existingCache[key];
    }
    updatedCache[url] = details;

    var cacheKeys = Object.keys(updatedCache);
    if (cacheKeys.length > 50) {
      delete updatedCache[cacheKeys[0]];
    }

    detailCacheOwner.previewDetailCache = updatedCache;
  }

  function resetPreviewState(clearCache) {
    detailDelay.stop();
    detailData = null;
    previewError = "";
    loadingDetails = false;
    requestedUrl = "";
    lastLoadedUrl = "";
    descriptionExpanded = false;
    livePosition = 0;
    seekDragging = false;
    positionSyncTimer.stop();
  }

  function isItemPlayingNow(item) {
    var targetItem = item || currentItem;
    if (!targetItem) {
      return false;
    }

    var mainInstance = detailCacheOwner?.mainInstance || null;
    if (!mainInstance || mainInstance.isPlaying !== true) {
      return targetItem?.isPlaying === true;
    }

    var itemId = (targetItem.id || "").trim();
    if (itemId.length > 0 && mainInstance.currentEntryId === itemId) {
      return true;
    }

    var itemUrl = (targetItem.url || "").trim();
    return itemUrl.length > 0 && mainInstance.currentUrl === itemUrl;
  }

  function isItemStartingNow(item) {
    var targetItem = item || currentItem;
    if (!targetItem) {
      return false;
    }

    var mainInstance = detailCacheOwner?.mainInstance || null;
    if (!mainInstance || mainInstance.playbackStarting !== true) {
      return targetItem?.isStarting === true;
    }

    var itemId = (targetItem.id || "").trim();
    if (itemId.length > 0 && mainInstance.currentEntryId === itemId) {
      return true;
    }

    var itemUrl = (targetItem.url || "").trim();
    return itemUrl.length > 0 && mainInstance.currentUrl === itemUrl;
  }

  function startupMessage() {
    var mainInstance = detailCacheOwner?.mainInstance || null;
    if (!isItemStartingNow(currentItem)) {
      return "";
    }
    return mainInstance?.playbackStartingMessage || detailCacheOwner?.pluginApi?.tr("status.startingPlayback");
  }

  function richMetadataAllowedForItem(item) {
    var targetItem = item || currentItem;
    if (!targetItem || !targetItem.url || !targetItem.helperPath) {
      return false;
    }

    if (previewMetadataMode === "never") {
      return false;
    }

    if (previewMetadataMode === "playing") {
      return isItemPlayingNow(targetItem);
    }

    return true;
  }

  function syncRichMetadataState() {
    detailDelay.stop();
    loadingDetails = false;
    requestedUrl = "";
    previewError = "";

    var nextUrl = currentItem?.url || "";
    if (!nextUrl || !richMetadataAllowedForItem(currentItem)) {
      detailData = null;
      lastLoadedUrl = "";
      return;
    }

    var cached = detailCache()[nextUrl];
    detailData = cached || null;
    lastLoadedUrl = cached ? nextUrl : "";
    if (!cached) {
      detailDelay.restart();
    }
  }

  function formatViews(count) {
    var total = Number(count || 0);
    if (!isFinite(total) || total <= 0) {
      return "";
    }
    if (total >= 1000000000) {
      return (total / 1000000000).toFixed(1).replace(/\.0$/, "") + "B views";
    }
    if (total >= 1000000) {
      return (total / 1000000).toFixed(1).replace(/\.0$/, "") + "M views";
    }
    if (total >= 1000) {
      return (total / 1000).toFixed(1).replace(/\.0$/, "") + "K views";
    }
    return total + " views";
  }

  function formatUploadDate(rawDate) {
    var text = String(rawDate || "").trim();
    if (text.length !== 8) {
      return "";
    }
    return text.slice(0, 4) + "-" + text.slice(4, 6) + "-" + text.slice(6, 8);
  }

  function formatSpeed(value) {
    var speed = Number(value || 1);
    if (!isFinite(speed) || speed <= 0) {
      speed = 1;
    }
    return speed.toFixed(2) + "x";
  }

  function effectiveTitle() {
    var visibleDetailData = richMetadataAllowedForItem(currentItem) ? detailData : null;
    return visibleDetailData?.title || currentItem?.name || currentItem?.title || detailCacheOwner?.pluginApi?.tr("common.untitled");
  }

  function effectiveUploader() {
    var visibleDetailData = richMetadataAllowedForItem(currentItem) ? detailData : null;
    return visibleDetailData?.uploader || visibleDetailData?.channel || currentItem?.uploader || "";
  }

  function effectiveAlbum() {
    var visibleDetailData = richMetadataAllowedForItem(currentItem) ? detailData : null;
    return visibleDetailData?.album || currentItem?.album || "";
  }

  function effectiveDuration() {
    var visibleDetailData = richMetadataAllowedForItem(currentItem) ? detailData : null;
    return visibleDetailData?.duration || currentItem?.duration || 0;
  }

  function fullDescription() {
    var visibleDetailData = richMetadataAllowedForItem(currentItem) ? detailData : null;
    return (visibleDetailData?.description || "").trim();
  }

  function descriptionNeedsExpansion() {
    return fullDescription().length > 500;
  }

  function effectiveDescription() {
    var description = fullDescription();
    if (!descriptionExpanded && description.length > 500) {
      return description.slice(0, 500) + "...";
    }
    return description;
  }

  function effectiveThumbnail() {
    var visibleDetailData = richMetadataAllowedForItem(currentItem) ? detailData : null;
    return visibleDetailData?.thumbnail || "";
  }

  function syncLivePosition() {
    if (seekDragging) {
      return;
    }

    var mainInstance = detailCacheOwner?.mainInstance || null;
    if (isItemPlayingNow(currentItem) && mainInstance) {
      var nextPosition = Number(mainInstance.currentPosition || 0);
      livePosition = isFinite(nextPosition) && nextPosition >= 0 ? nextPosition : 0;
      return;
    }

    if (!currentItem?.isPlaying) {
      livePosition = 0;
    }
  }

  function requestSeekForRatio(ratio) {
    var duration = Number(effectiveDuration() || 0);
    var nextRatio = Number(ratio);
    if (!isFinite(duration) || duration <= 0 || !isFinite(nextRatio)) {
      return;
    }

    nextRatio = Math.max(0, Math.min(1, nextRatio));
    livePosition = nextRatio * duration;
    detailCacheOwner?.mainInstance?.seekToRatio(nextRatio);
  }

  function loadDetails() {
    if (!richMetadataAllowedForItem(currentItem)) {
      detailData = null;
      previewError = "";
      loadingDetails = false;
      requestedUrl = "";
      lastLoadedUrl = "";
      return;
    }

    if (!currentItem || !currentItem.url || !currentItem.helperPath) {
      return;
    }

    var cached = detailCache()[currentItem.url];
    if (cached) {
      detailData = cached;
      lastLoadedUrl = currentItem.url;
      previewError = "";
      return;
    }

    if (lastLoadedUrl === currentItem.url && detailData) {
      return;
    }

    loadingDetails = true;
    previewError = "";
    requestedUrl = currentItem.url;
    detailsProcess.exec({
                          "command": ["bash", currentItem.helperPath, "details", currentItem.url]
                        });
  }

  Connections {
    target: previewPanel
    function onCurrentItemChanged() {
      previewPanel.descriptionExpanded = false;
      var nextUrl = previewPanel.currentItem?.url || "";
      if (!nextUrl) {
        previewPanel.resetPreviewState(true);
        return;
      }
      previewPanel.syncRichMetadataState();
      previewPanel.syncLivePosition();
    }
  }

  onPreviewMetadataModeChanged: syncRichMetadataState()

  Connections {
    target: detailCacheOwner?.mainInstance || null

    function onIsPlayingChanged() {
      previewPanel.syncRichMetadataState();
      previewPanel.syncLivePosition();
    }

    function onPreviewMetadataModeChanged() {
      previewPanel.syncRichMetadataState();
    }

    function onCurrentEntryIdChanged() {
      previewPanel.syncRichMetadataState();
      previewPanel.syncLivePosition();
    }

    function onCurrentUrlChanged() {
      previewPanel.syncRichMetadataState();
      previewPanel.syncLivePosition();
    }

    function onCurrentPositionChanged() {
      previewPanel.syncLivePosition();
    }
  }

  Component.onDestruction: resetPreviewState(true)

  Timer {
    id: detailDelay
    interval: currentItem?.previewDelayMs || 500
    repeat: false
    onTriggered: previewPanel.loadDetails()
  }

  Timer {
    id: positionSyncTimer
    interval: 250
    repeat: true
    running: isItemPlayingNow(currentItem) && !previewPanel.seekDragging

    onTriggered: previewPanel.syncLivePosition()
  }

  Process {
    id: detailsProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      loadingDetails = false;

      if (!previewPanel.currentItem || requestedUrl !== previewPanel.currentItem.url || !previewPanel.richMetadataAllowedForItem(previewPanel.currentItem)) {
        return;
      }

      if (exitCode === 0) {
        try {
          detailData = JSON.parse(String(detailsProcess.stdout.text || "{}"));
          if (previewPanel.currentItem?.url) {
            previewPanel.cacheDetailsForUrl(previewPanel.currentItem.url, detailData);
          }
          lastLoadedUrl = previewPanel.currentItem.url || "";
          previewError = "";
        } catch (error) {
          detailData = null;
          previewError = detailCacheOwner?.pluginApi?.tr("preview.metadataParseError");
        }
      } else {
        var fallback = previewPanel.currentItem?.url ? previewPanel.detailCache()[previewPanel.currentItem.url] : null;
        detailData = fallback || null;
        previewError = fallback ? "" : (String(detailsProcess.stderr.text || "").trim() || detailCacheOwner?.pluginApi?.tr("preview.metadataUnavailable"));
      }
    }
  }

  ScrollView {
    id: contentArea
    anchors.fill: parent
    anchors.margins: Style.marginS
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    Item {
      id: previewContent
      width: contentArea.availableWidth
      implicitHeight: previewLayout.implicitHeight + (Style.marginS * 2)

      ColumnLayout {
      id: previewLayout
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginS
      spacing: Style.marginS

      NImageRounded {
        Layout.fillWidth: true
        Layout.preferredHeight: effectiveArtworkHeight
        radius: Style.radiusM
        visible: imagePath !== ""
        imagePath: effectiveThumbnail()
        imageFillMode: Image.PreserveAspectCrop
      }

      RowLayout {
        Layout.fillWidth: true
        visible: detailCacheOwner?.mainInstance?.showPreviewChips !== false
        spacing: Style.marginXS

        Repeater {
          model: {
            var chips = [];
            if (currentItem?.sourceLabel) {
              chips.push({
                           "label": currentItem.sourceLabel,
                           "clickable": false,
                           "query": ""
                         });
            }
            if (currentItem?.isSaved) {
              chips.push({
                           "label": detailCacheOwner?.pluginApi?.tr("preview.chipSaved"),
                           "clickable": true,
                           "query": (detailCacheOwner?.commandName || ">music-search") + " saved:"
                         });
            }
            if (isItemStartingNow(currentItem)) {
              chips.push({
                           "label": detailCacheOwner?.pluginApi?.tr("preview.chipStarting"),
                           "clickable": false,
                           "query": ""
                         });
            }
            var tags = currentItem?.tags || [];
            for (var i = 0; i < tags.length; i++) {
              var tag = String(tags[i] || "").trim();
              if (tag.length > 0) {
                chips.push({
                             "label": "#" + tag,
                             "clickable": true,
                             "query": (detailCacheOwner?.commandName || ">music-search") + " #" + tag
                           });
              }
            }
            return chips;
          }

          Rectangle {
            radius: Style.radiusM
            color: Color.mSecondary
            implicitHeight: chipLabel.implicitHeight + Style.marginXS
            implicitWidth: chipLabel.implicitWidth + Style.marginM

            NText {
              id: chipLabel
              anchors.centerIn: parent
              text: modelData?.label || ""
              pointSize: Style.fontSizeXS
              color: Color.mOnSecondary
            }

            MouseArea {
              anchors.fill: parent
              enabled: modelData?.clickable === true
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: {
                if (!enabled) {
                  return;
                }
                if (detailCacheOwner?.launcher && modelData?.query) {
                  detailCacheOwner.launcher.setSearchText(modelData.query);
                }
              }
            }
          }
        }

        Item {
          Layout.fillWidth: true
        }
      }

      NText {
        Layout.fillWidth: true
        text: effectiveTitle()
        wrapMode: Text.Wrap
        maximumLineCount: compactLayout ? 2 : 3
        elide: Text.ElideRight
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL
        color: Color.mOnSurface
      }

      RowLayout {
        Layout.fillWidth: true
        visible: (showUploaderMetadata && effectiveUploader() !== "") || currentItem?.isPlaying === true
        spacing: Style.marginXS

        NText {
          Layout.fillWidth: true
          visible: showUploaderMetadata && text !== ""
          text: effectiveUploader()
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
          wrapMode: compactLayout ? Text.NoWrap : Text.Wrap
          elide: Text.ElideRight
        }

        RowLayout {
          visible: currentItem?.isPlaying === true
          spacing: Math.max(2, Math.round(Style.marginXS * 0.5))

          NButton {
            text: "-"
            backgroundColor: "transparent"
            textColor: Color.mOnSurfaceVariant
            outlined: false
            enabled: currentItem?.isPlaying === true
            implicitWidth: Math.round(24 * Style.uiScaleRatio)
            implicitHeight: Math.round(24 * Style.uiScaleRatio)
            onClicked: detailCacheOwner?.mainInstance?.adjustSpeed(-0.05)
          }

          Rectangle {
            radius: Style.radiusM
            color: Color.mPrimary
            implicitHeight: Math.round(24 * Style.uiScaleRatio)
            implicitWidth: speedChipLabel.implicitWidth + Math.round(18 * Style.uiScaleRatio)

            NText {
              id: speedChipLabel
              anchors.centerIn: parent
              text: formatSpeed(currentSpeed)
              pointSize: Style.fontSizeS
              color: Color.mOnPrimary
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: detailCacheOwner?.mainInstance?.setSpeed(1.0)
            }
          }

          NButton {
            text: "+"
            backgroundColor: "transparent"
            textColor: Color.mOnSurfaceVariant
            outlined: false
            enabled: currentItem?.isPlaying === true
            implicitWidth: Math.round(24 * Style.uiScaleRatio)
            implicitHeight: Math.round(24 * Style.uiScaleRatio)
            onClicked: detailCacheOwner?.mainInstance?.adjustSpeed(0.05)
          }
        }
      }

      Item {
        id: progressWrapper
        Layout.fillWidth: true
        Layout.preferredHeight: progressSlider.implicitHeight + progressTimes.implicitHeight + Style.marginXS
        visible: currentItem?.isPlaying === true && effectiveDuration() > 0
        property real localSeekRatio: -1
        property real lastSentSeekRatio: -1
        property real seekEpsilon: 0.01
        property real progressRatio: {
          var duration = Number(effectiveDuration() || 0);
          if (!isFinite(duration) || duration <= 0) {
            return 0;
          }
          var activePosition = previewPanel.seekDragging && localSeekRatio >= 0
              ? (localSeekRatio * duration)
              : Number(previewPanel.livePosition || 0);
          var ratio = activePosition / duration;
          if (!isFinite(ratio)) {
            return 0;
          }
          return Math.max(0, Math.min(1, ratio));
        }

        Timer {
          id: seekDebounce
          interval: 75
          repeat: false

          onTriggered: {
            if (previewPanel.seekDragging && progressWrapper.localSeekRatio >= 0) {
              var next = Math.max(0, Math.min(1, progressWrapper.localSeekRatio));
              if (progressWrapper.lastSentSeekRatio < 0 || Math.abs(next - progressWrapper.lastSentSeekRatio) >= progressWrapper.seekEpsilon) {
                previewPanel.requestSeekForRatio(next);
                progressWrapper.lastSentSeekRatio = next;
              }
            }
          }
        }

        NSlider {
          id: progressSlider
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          from: 0
          to: 1
          stepSize: 0
          snapAlways: false
          heightRatio: 0.4
          enabled: currentItem?.isPlaying === true && effectiveDuration() > 0
          value: progressWrapper.progressRatio

          onMoved: {
            progressWrapper.localSeekRatio = value;
            previewPanel.livePosition = value * Number(previewPanel.effectiveDuration() || 0);
            seekDebounce.restart();
          }
          onPressedChanged: {
            if (pressed) {
              previewPanel.seekDragging = true;
              progressWrapper.localSeekRatio = value;
              previewPanel.requestSeekForRatio(value);
              progressWrapper.lastSentSeekRatio = value;
            } else {
              seekDebounce.stop();
              previewPanel.requestSeekForRatio(value);
              previewPanel.seekDragging = false;
              progressWrapper.localSeekRatio = -1;
              progressWrapper.lastSentSeekRatio = -1;
              previewPanel.syncLivePosition();
            }
          }
        }

        RowLayout {
          id: progressTimes
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: progressSlider.bottom
          anchors.topMargin: 2

          NText {
            text: MusicUtils.formatDuration(previewPanel.livePosition)
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
          }

          Item {
            Layout.fillWidth: true
          }

          NText {
            text: MusicUtils.formatDuration(effectiveDuration())
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
          }
        }
      }

      NDivider {
        Layout.fillWidth: true
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: Style.marginXS
        columnSpacing: Style.marginS

        NText {
          visible: showDurationMetadata
          text: visible ? (detailCacheOwner?.pluginApi?.tr("preview.length")) : ""
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
        NText {
          visible: showDurationMetadata
          text: MusicUtils.formatDuration(effectiveDuration()) || "-"
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          Layout.fillWidth: true
        }

        NText {
          visible: showAlbumMetadata && effectiveAlbum() !== ""
          text: visible ? (detailCacheOwner?.pluginApi?.tr("preview.album")) : ""
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
        NText {
          visible: showAlbumMetadata && effectiveAlbum() !== ""
          text: effectiveAlbum()
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          Layout.fillWidth: true
        }

        NText {
          visible: showPlayStatsMetadata && Number(currentItem?.playCount || 0) > 0
          text: visible ? (detailCacheOwner?.pluginApi?.tr("preview.plays")) : ""
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
        NText {
          visible: showPlayStatsMetadata && Number(currentItem?.playCount || 0) > 0
          text: Number(currentItem?.playCount || 0)
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          Layout.fillWidth: true
        }

        NText {
          visible: showPlayStatsMetadata && MusicUtils.formatRelativeTime(currentItem?.lastPlayedAt) !== ""
          text: visible ? (detailCacheOwner?.pluginApi?.tr("preview.lastPlayed")) : ""
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
        NText {
          visible: showPlayStatsMetadata && MusicUtils.formatRelativeTime(currentItem?.lastPlayedAt) !== ""
          text: MusicUtils.formatRelativeTime(currentItem?.lastPlayedAt)
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          Layout.fillWidth: true
        }

        NText {
          visible: previewPanel.richMetadataAllowedForItem(previewPanel.currentItem) && formatUploadDate(detailData?.uploadDate) !== ""
          text: visible ? (detailCacheOwner?.pluginApi?.tr("preview.uploaded")) : ""
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
        NText {
          visible: previewPanel.richMetadataAllowedForItem(previewPanel.currentItem) && formatUploadDate(detailData?.uploadDate) !== ""
          text: formatUploadDate(detailData?.uploadDate)
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          Layout.fillWidth: true
        }

        NText {
          visible: previewPanel.richMetadataAllowedForItem(previewPanel.currentItem) && formatViews(detailData?.viewCount) !== ""
          text: visible ? (detailCacheOwner?.pluginApi?.tr("preview.reach")) : ""
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
        NText {
          visible: previewPanel.richMetadataAllowedForItem(previewPanel.currentItem) && formatViews(detailData?.viewCount) !== ""
          text: formatViews(detailData?.viewCount)
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          Layout.fillWidth: true
        }

        NText {
          visible: showStatusMetadata && previewPanel.richMetadataAllowedForItem(previewPanel.currentItem) && !!detailData?.availability
          text: visible ? (detailCacheOwner?.pluginApi?.tr("preview.status")) : ""
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
        NText {
          visible: showStatusMetadata && previewPanel.richMetadataAllowedForItem(previewPanel.currentItem) && !!detailData?.availability
          text: detailData?.availability || ""
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignRight
          Layout.fillWidth: true
        }
      }

      Item {
        Layout.fillWidth: true
        visible: effectiveDescription() !== "" || previewError !== "" || currentItem?.lastError
        implicitHeight: descriptionColumn.implicitHeight

        ColumnLayout {
          id: descriptionColumn
          anchors.fill: parent
          spacing: Math.max(4, Math.round(Style.marginXS * 0.75))

          NText {
            id: descriptionText
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: {
              if (previewError)
                return previewError;
              if (currentItem?.lastError)
                return detailCacheOwner?.pluginApi?.tr("preview.lastPlaybackError", {"error": currentItem.lastError});
              return effectiveDescription();
            }
            pointSize: Style.fontSizeS
            color: (previewError || currentItem?.lastError) ? Color.mError : Color.mOnSurfaceVariant
          }

          NButton {
            visible: !previewError && !currentItem?.lastError && descriptionNeedsExpansion()
            text: previewPanel.descriptionExpanded ? (detailCacheOwner?.pluginApi?.tr("preview.readLess")) : (detailCacheOwner?.pluginApi?.tr("preview.readMore"))
            backgroundColor: "transparent"
            outlined: false
            textColor: Color.mPrimary
            implicitHeight: Math.round(24 * Style.uiScaleRatio)
            implicitWidth: readMoreMeasure.implicitWidth + Math.round(16 * Style.uiScaleRatio)
            onClicked: previewPanel.descriptionExpanded = !previewPanel.descriptionExpanded

            NText {
              id: readMoreMeasure
              visible: false
              text: parent.text
              pointSize: Style.fontSizeS
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        visible: isItemStartingNow(currentItem)
        spacing: Style.marginXS

        BusyIndicator {
          running: true
          width: Style.baseWidgetSize * 0.75
          height: width
        }

        NText {
          Layout.fillWidth: true
          text: startupMessage()
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          wrapMode: Text.Wrap
        }
      }

      RowLayout {
        Layout.fillWidth: true
        visible: loadingDetails

        BusyIndicator {
          running: true
          width: Style.baseWidgetSize * 0.75
          height: width
        }

        NText {
          text: detailCacheOwner?.pluginApi?.tr("preview.loadingMetadata")
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
      }
    }
  }
}
}
