import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  readonly property var mainInstance: pluginApi?.mainInstance ?? null
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})
  readonly property string defaultDownloadDirectory: Quickshell.env("HOME") + "/Music/Noctalia"
  readonly property string currentProvider: root.mainInstance?.currentProvider ?? "youtube"
  readonly property string currentSortBy: root.mainInstance?.currentSortBy ?? "date"
  readonly property string currentYtPlayerClient: root.mainInstance?.ytPlayerClient ?? "android"
  readonly property string currentDownloadDirectory: root.mainInstance?.downloadDirectory ?? root.defaultDownloadDirectory
  readonly property int currentDownloadCacheMaxMb: Number(root.mainInstance?.downloadCacheMaxMb ?? 0)
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
  property string editDownloadDirectory: root.currentDownloadDirectory
  property int editDownloadCacheMaxMb: root.currentDownloadCacheMaxMb

  spacing: Style.marginL

  function saveSetting(key, value) {
    if (!pluginApi) {
      Logger.e("MusicSearch", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings[key] = value;
    pluginApi.saveSettings();
  }

  function applyDownloadDirectory() {
    var target = (editDownloadDirectory || "").trim();
    if (target.length === 0) {
      return;
    }
    pluginApi?.mainInstance?.setDownloadDirectory(target);
  }

  function applyCacheLimit() {
    var target = Math.max(0, Math.floor(editDownloadCacheMaxMb || 0));
    editDownloadCacheMaxMb = target;
    pluginApi?.mainInstance?.setDownloadCacheMaxMb(target);
  }

  onCurrentDownloadDirectoryChanged: root.editDownloadDirectory = root.currentDownloadDirectory
  onCurrentDownloadCacheMaxMbChanged: root.editDownloadCacheMaxMb = root.currentDownloadCacheMaxMb

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.provider.label")
    description: pluginApi?.tr("settings.provider.desc")
    model: [
      {"key": "youtube", "name": pluginApi?.tr("providers.youtube")},
      {"key": "soundcloud", "name": pluginApi?.tr("providers.soundcloud")},
      {"key": "local", "name": pluginApi?.tr("providers.local")}
    ]
    currentKey: root.currentProvider
    defaultValue: "youtube"
    onSelected: key => pluginApi?.mainInstance?.setProvider(key)
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.sort.label")
    description: pluginApi?.tr("settings.sort.desc")
    model: [
      {"key": "date", "name": pluginApi?.tr("sort.savedDate")},
      {"key": "title", "name": pluginApi?.tr("sort.title")},
      {"key": "duration", "name": pluginApi?.tr("sort.duration")},
      {"key": "rating", "name": pluginApi?.tr("sort.rating")}
    ]
    currentKey: root.currentSortBy
    defaultValue: "date"
    onSelected: key => pluginApi?.mainInstance?.setSortBy(key)
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.ytClient.label")
    description: pluginApi?.tr("settings.ytClient.desc")
    model: [
      {"key": "android", "name": pluginApi?.tr("settings.ytClient.android")},
      {"key": "web", "name": pluginApi?.tr("settings.ytClient.web")},
      {"key": "default", "name": pluginApi?.tr("settings.ytClient.default")}
    ]
    currentKey: root.currentYtPlayerClient
    defaultValue: "android"
    onSelected: key => pluginApi?.mainInstance?.setYtPlayerClient(key)
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    Layout.fillWidth: true
    text: pluginApi?.tr("settings.downloads.title")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NText {
    Layout.fillWidth: true
    text: pluginApi?.tr("settings.downloads.currentFolder", {"path": root.editDownloadDirectory})
    wrapMode: Text.Wrap
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NButton {
      text: pluginApi?.tr("settings.downloads.chooseFolder")
      onClicked: downloadFolderPicker.open()
    }

    NButton {
      text: pluginApi?.tr("settings.downloads.applyFolder")
      enabled: String(root.editDownloadDirectory || "").trim().length > 0
      onClicked: root.applyDownloadDirectory()
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.cache.label")
      description: pluginApi?.tr("settings.cache.desc")
    }

    NSpinBox {
      from: 0
      to: 500000
      stepSize: 128
      value: root.editDownloadCacheMaxMb
      onValueChanged: if (value !== root.editDownloadCacheMaxMb) root.editDownloadCacheMaxMb = value
    }

    NButton {
      text: pluginApi?.tr("settings.cache.apply")
      onClicked: root.applyCacheLimit()
    }
  }

  NToggle {
    label: pluginApi?.tr("settings.autoSave.label")
    description: pluginApi?.tr("settings.autoSave.desc")
    checked: root.autoSaveMp3AfterPlayback
    onToggled: root.saveSetting("autoSaveMp3AfterPlayback", checked)
    defaultValue: root.defaults.autoSaveMp3AfterPlayback ?? false
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    Layout.fillWidth: true
    text: pluginApi?.tr("settings.home.title")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NToggle {
    label: pluginApi?.tr("settings.home.recent.label")
    description: pluginApi?.tr("settings.home.recent.desc")
    checked: root.showHomeRecent
    onToggled: root.saveSetting("showHomeRecent", checked)
    defaultValue: root.defaults.showHomeRecent ?? true
  }

  NToggle {
    label: pluginApi?.tr("settings.home.top.label")
    description: pluginApi?.tr("settings.home.top.desc")
    checked: root.showHomeTop
    onToggled: root.saveSetting("showHomeTop", checked)
    defaultValue: root.defaults.showHomeTop ?? true
  }

  NToggle {
    label: pluginApi?.tr("settings.home.tags.label")
    description: pluginApi?.tr("settings.home.tags.desc")
    checked: root.showHomeTags
    onToggled: root.saveSetting("showHomeTags", checked)
    defaultValue: root.defaults.showHomeTags ?? true
  }

  NToggle {
    label: pluginApi?.tr("settings.home.artists.label")
    description: pluginApi?.tr("settings.home.artists.desc")
    checked: root.showHomeArtists
    onToggled: root.saveSetting("showHomeArtists", checked)
    defaultValue: root.defaults.showHomeArtists ?? true
  }

  NToggle {
    label: pluginApi?.tr("settings.home.playlists.label")
    description: pluginApi?.tr("settings.home.playlists.desc")
    checked: root.showHomePlaylists
    onToggled: root.saveSetting("showHomePlaylists", checked)
    defaultValue: root.defaults.showHomePlaylists ?? true
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    Layout.fillWidth: true
    text: pluginApi?.tr("settings.preview.title")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.preview.metadata.label")
    description: pluginApi?.tr("settings.preview.metadata.desc")
    model: [
      {"key": "always", "name": pluginApi?.tr("settings.preview.metadata.all")},
      {"key": "playing", "name": pluginApi?.tr("settings.preview.metadata.playing")},
      {"key": "never", "name": pluginApi?.tr("settings.preview.metadata.disabled")}
    ]
    currentKey: root.previewMetadataMode
    defaultValue: root.defaults.previewMetadataMode ?? "always"
    onSelected: key => root.saveSetting("previewMetadataMode", key)
  }

  NText {
    Layout.fillWidth: true
    text: {
      if (root.previewMetadataMode === "never") {
        return pluginApi?.tr("settings.preview.metadata.neverHint");
      }
      if (root.previewMetadataMode === "playing") {
        return pluginApi?.tr("settings.preview.metadata.playingHint");
      }
      return pluginApi?.tr("settings.preview.metadata.alwaysHint");
    }
    wrapMode: Text.Wrap
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.preview.thumbnail.label")
    description: pluginApi?.tr("settings.preview.thumbnail.desc")
    model: [
      {"key": "small", "name": pluginApi?.tr("settings.preview.thumbnail.small")},
      {"key": "comfortable", "name": pluginApi?.tr("settings.preview.thumbnail.comfortable")},
      {"key": "large", "name": pluginApi?.tr("settings.preview.thumbnail.large")}
    ]
    currentKey: root.previewThumbnailSize
    defaultValue: root.defaults.previewThumbnailSize ?? "comfortable"
    onSelected: key => root.saveSetting("previewThumbnailSize", key)
  }

  NToggle {
    label: pluginApi?.tr("settings.preview.chips.label")
    description: pluginApi?.tr("settings.preview.chips.desc")
    checked: root.showPreviewChips
    onToggled: root.saveSetting("showPreviewChips", checked)
    defaultValue: root.defaults.showPreviewChips ?? true
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    Layout.fillWidth: true
    text: pluginApi?.tr("settings.metadata.title")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NToggle {
    label: pluginApi?.tr("settings.metadata.uploader.label")
    description: pluginApi?.tr("settings.metadata.uploader.desc")
    checked: root.showUploaderMetadata
    onToggled: root.saveSetting("showUploaderMetadata", checked)
    defaultValue: root.defaults.showUploaderMetadata ?? true
  }

  NToggle {
    label: pluginApi?.tr("settings.metadata.album.label")
    description: pluginApi?.tr("settings.metadata.album.desc")
    checked: root.showAlbumMetadata
    onToggled: root.saveSetting("showAlbumMetadata", checked)
    defaultValue: root.defaults.showAlbumMetadata ?? true
  }

  NToggle {
    label: pluginApi?.tr("settings.metadata.duration.label")
    description: pluginApi?.tr("settings.metadata.duration.desc")
    checked: root.showDurationMetadata
    onToggled: root.saveSetting("showDurationMetadata", checked)
    defaultValue: root.defaults.showDurationMetadata ?? true
  }

  NToggle {
    label: pluginApi?.tr("settings.metadata.rating.label")
    description: pluginApi?.tr("settings.metadata.rating.desc")
    checked: root.showRatingMetadata
    onToggled: root.saveSetting("showRatingMetadata", checked)
    defaultValue: root.defaults.showRatingMetadata ?? true
  }

  NToggle {
    label: pluginApi?.tr("settings.metadata.tags.label")
    description: pluginApi?.tr("settings.metadata.tags.desc")
    checked: root.showTagMetadata
    onToggled: root.saveSetting("showTagMetadata", checked)
    defaultValue: root.defaults.showTagMetadata ?? true
  }

  NToggle {
    label: pluginApi?.tr("settings.metadata.playStats.label")
    description: pluginApi?.tr("settings.metadata.playStats.desc")
    checked: root.showPlayStatsMetadata
    onToggled: root.saveSetting("showPlayStatsMetadata", checked)
    defaultValue: root.defaults.showPlayStatsMetadata ?? true
  }

  NToggle {
    label: pluginApi?.tr("settings.metadata.status.label")
    description: pluginApi?.tr("settings.metadata.status.desc")
    checked: root.showStatusMetadata
    onToggled: root.saveSetting("showStatusMetadata", checked)
    defaultValue: root.defaults.showStatusMetadata ?? true
  }

  NFilePicker {
    id: downloadFolderPicker
    selectionMode: "folders"
    title: pluginApi?.tr("settings.downloads.folderPickerTitle")
    initialPath: root.editDownloadDirectory || (Quickshell.env("HOME") + "/Music")
    onAccepted: paths => {
      if (paths.length > 0) {
        root.editDownloadDirectory = paths[0];
        root.applyDownloadDirectory();
      }
    }
  }
}
