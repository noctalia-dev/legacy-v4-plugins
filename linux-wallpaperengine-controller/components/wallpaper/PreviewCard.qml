import QtQuick
import QtQuick.Layouts
import QtMultimedia

import "../../helpers/panel/DescriptionHelpers.js" as DescriptionHelpers

import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var selectedWallpaperData: null
  property var propertyCompatibilityBadgeIconForPath: null
  property var propertyCompatibilityBadgeTextForPath: null
  property var propertyCompatibilityBadgeColorForPath: null
  property var propertyCompatibilityBadgeBackgroundForPath: null
  property var resolutionBadgeIcon: null
  property var resolutionBadgeLabel: null
  property var typeLabel: null
  property var typeBadgeIcon: null
  property var dynamicBadgeIcon: null
  property var badgeOrder: []
  property var isVideoMotion: null
  property var formatBytes: null
  property bool showDescription: true
  readonly property var visibleBadgeKeys: {
    const ordered = root.badgeOrder || [];
    const result = [];
    for (const key of ordered) {
      if (root.badgeVisible(String(key || ""))) {
        result.push(String(key || ""));
      }
    }
    return result;
  }
  property bool descriptionExpanded: false
  property bool descriptionShouldCollapse: false
  readonly property int collapsedDescriptionLineCount: 6
  readonly property real collapsedDescriptionHeight: descriptionFontMetrics.height * root.collapsedDescriptionLineCount
  readonly property string selectedDescriptionMarkup: {
    return DescriptionHelpers.toRichDescription(root.selectedWallpaperData?.description || "");
  }

  function evaluateDescriptionCollapse() {
    if (root.selectedDescriptionMarkup.length === 0) {
      root.descriptionShouldCollapse = false;
      return;
    }

    const measuredLinesRaw = Number(descriptionMeasureText.lineCount || 0);
    const measuredHeight = Number(descriptionMeasureText.contentHeight || 0);
    const lineHeight = Math.max(1, Number(descriptionFontMetrics.height || 1));
    const measuredLines = measuredLinesRaw > 0 ? measuredLinesRaw : Math.ceil(measuredHeight / lineHeight);
    const rawDescription = String(root.selectedWallpaperData?.description || "");
    const normalizedRaw = rawDescription
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .replace(/\\n/g, "\n");
    const hardBreakCount = normalizedRaw.split(/\n+/).length;
    const longTextHint = normalizedRaw.length > 900;

    if (measuredLinesRaw > 0 || measuredHeight > 0) {
      root.descriptionShouldCollapse = measuredLines > root.collapsedDescriptionLineCount;
      return;
    }

    root.descriptionShouldCollapse = hardBreakCount > root.collapsedDescriptionLineCount + 1 || longTextHint;
  }

  function badgeVisible(key) {
    if (!root.selectedWallpaperData) {
      return false;
    }
    if (key === "resolution") {
      return root.resolutionBadgeLabel && root.resolutionBadgeLabel(root.selectedWallpaperData.resolution).length > 0;
    }
    if (key === "type") {
      return root.typeLabel && root.typeLabel(root.selectedWallpaperData.type).length > 0;
    }
    if (key === "dynamic") {
      return true;
    }
    if (key === "music") {
      return !!root.selectedWallpaperData.hasEmbeddedAudio;
    }
    if (key === "reactive") {
      return !!root.selectedWallpaperData.hasAudioReactive;
    }
    if (key === "approved") {
      return !!root.selectedWallpaperData.approved;
    }
    if (key === "compatibility") {
      const path = String(root.selectedWallpaperData.path || "");
      return root.propertyCompatibilityBadgeTextForPath && root.propertyCompatibilityBadgeTextForPath(path).length > 0;
    }
    return false;
  }

  Layout.fillWidth: true
  spacing: Style.marginS

  onSelectedWallpaperDataChanged: {
    descriptionExpanded = false;
    descriptionCollapseEvalTimer.restart();
  }
  onSelectedDescriptionMarkupChanged: descriptionCollapseEvalTimer.restart()
  onWidthChanged: descriptionCollapseEvalTimer.restart()

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 180 * Style.uiScaleRatio
    radius: Style.radiusM
    color: Color.mSurfaceVariant
    clip: true

    Image {
      anchors.fill: parent
      visible: root.selectedWallpaperData && (!root.selectedWallpaperData.motionPreview || root.selectedWallpaperData.motionPreview.length === 0) && root.selectedWallpaperData.thumb && root.selectedWallpaperData.thumb.length > 0
      source: visible ? ("file://" + root.selectedWallpaperData.thumb) : ""
      fillMode: Image.PreserveAspectCrop
      cache: false
    }

    AnimatedImage {
      anchors.fill: parent
      visible: root.selectedWallpaperData && root.selectedWallpaperData.motionPreview && root.selectedWallpaperData.motionPreview.length > 0 && !(root.isVideoMotion && root.isVideoMotion(root.selectedWallpaperData.motionPreview))
      source: visible ? ("file://" + root.selectedWallpaperData.motionPreview) : ""
      fillMode: Image.PreserveAspectCrop
      cache: false
      playing: visible
    }

    Video {
      anchors.fill: parent
      visible: root.selectedWallpaperData && root.selectedWallpaperData.motionPreview && root.selectedWallpaperData.motionPreview.length > 0 && root.isVideoMotion && root.isVideoMotion(root.selectedWallpaperData.motionPreview)
      autoPlay: true
      loops: MediaPlayer.Infinite
      muted: true
      fillMode: VideoOutput.PreserveAspectCrop
      source: visible ? ("file://" + root.selectedWallpaperData.motionPreview) : ""
    }
  }

  NText {
    Layout.fillWidth: true
    text: root.selectedWallpaperData ? root.selectedWallpaperData.name : ""
    color: Color.mOnSurface
    font.weight: Font.Bold
    elide: Text.ElideRight
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: badgeFlow.implicitHeight

    Flow {
      id: badgeFlow
      width: parent.width
      spacing: Style.marginS

      Repeater {
        model: root.visibleBadgeKeys

        WallpaperBadge {
          required property var modelData
          compact: false
          badgeIcon: {
            const key = String(modelData || "");
            if (key === "type") return root.typeBadgeIcon ? root.typeBadgeIcon(root.selectedWallpaperData.type) : "category";
            if (key === "dynamic") return root.dynamicBadgeIcon ? root.dynamicBadgeIcon(!!root.selectedWallpaperData.dynamic) : (root.selectedWallpaperData.dynamic ? "player-play" : "player-stop");
            if (key === "music") return "volume";
            if (key === "reactive") return "wave-sine";
            if (key === "approved") return "rosette-discount-check";
            if (key === "resolution") return "aspect-ratio";
            if (key === "compatibility") return "settings-cog";
            return "";
          }
          badgeText: {
            const key = String(modelData || "");
            if (key === "type") return root.typeLabel ? root.typeLabel(root.selectedWallpaperData.type) : "";
            if (key === "dynamic") return root.selectedWallpaperData.dynamic ? pluginApi?.tr("panel.dynamicBadge") : pluginApi?.tr("panel.staticBadge");
            if (key === "music") return pluginApi?.tr("panel.musicBadge");
            if (key === "reactive") return pluginApi?.tr("panel.reactiveBadge");
            if (key === "approved") return pluginApi?.tr("panel.approvedBadge");
            if (key === "resolution") return root.resolutionBadgeLabel ? root.resolutionBadgeLabel(root.selectedWallpaperData.resolution) : "";
            if (key === "compatibility") {
              const cPath = String(root.selectedWallpaperData?.path || "");
              return root.propertyCompatibilityBadgeTextForPath ? root.propertyCompatibilityBadgeTextForPath(cPath) : "";
            }
            return "";
          }
          badgeColor: {
            const key = String(modelData || "");
            if (key === "type") return Color.mSecondary;
            if (key === "dynamic") return root.selectedWallpaperData.dynamic ? Color.mTertiary : Color.mOnSurfaceVariant;
            if (key === "music") return Color.mPrimary;
            if (key === "reactive") return Color.mSecondary;
            if (key === "approved") return Color.mPrimary;
            if (key === "resolution") return Color.mOnSurfaceVariant;
            if (key === "compatibility") {
              const cPath = String(root.selectedWallpaperData?.path || "");
              return root.propertyCompatibilityBadgeColorForPath ? root.propertyCompatibilityBadgeColorForPath(cPath) : Color.mError;
            }
            return Color.mOnSurfaceVariant;
          }
          badgeBgColor: {
            const key = String(modelData || "");
            if (key === "type") return Qt.alpha(Color.mSecondary, 0.1);
            if (key === "dynamic") return root.selectedWallpaperData.dynamic ? Qt.alpha(Color.mTertiary, 0.1) : Qt.alpha(Color.mOutline, 0.1);
            if (key === "music") return Qt.alpha(Color.mPrimary, 0.1);
            if (key === "reactive") return Qt.alpha(Color.mSecondary, 0.1);
            if (key === "approved") return Qt.alpha(Color.mPrimary, 0.1);
            if (key === "resolution") return Qt.alpha(Color.mSurfaceVariant, 0.24);
            if (key === "compatibility") {
              const cPath = String(root.selectedWallpaperData?.path || "");
              const cColor = root.propertyCompatibilityBadgeColorForPath ? root.propertyCompatibilityBadgeColorForPath(cPath) : Color.mError;
              return root.propertyCompatibilityBadgeBackgroundForPath ? root.propertyCompatibilityBadgeBackgroundForPath(cPath) : Qt.alpha(cColor, 0.1);
            }
            return Qt.alpha(Color.mSurfaceVariant, 0.24);
          }
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM

    NText {
      text: pluginApi?.tr("panel.infoType")
      color: Color.mOnSurfaceVariant
    }

    Item { Layout.fillWidth: true }

    NText {
      text: root.selectedWallpaperData && root.typeLabel ? root.typeLabel(root.selectedWallpaperData.type) : ""
      color: Color.mOnSurface
    }
  }

  RowLayout {
    Layout.fillWidth: true

    NText {
      text: pluginApi?.tr("panel.infoId")
      color: Color.mOnSurfaceVariant
    }

    Item { Layout.fillWidth: true }

    NText {
      text: root.selectedWallpaperData ? root.selectedWallpaperData.id : ""
      color: Color.mOnSurface
      elide: Text.ElideMiddle
    }
  }

  RowLayout {
    Layout.fillWidth: true

    NText {
      text: pluginApi?.tr("panel.infoResolution")
      color: Color.mOnSurfaceVariant
    }

    Item { Layout.fillWidth: true }

    NText {
      text: root.selectedWallpaperData
        ? (String(root.selectedWallpaperData.resolution || "unknown") === "unknown"
          ? pluginApi?.tr("panel.resolutionUnknown")
          : root.selectedWallpaperData.resolution)
        : ""
      color: Color.mOnSurface
    }
  }

  RowLayout {
    Layout.fillWidth: true

    NText {
      text: pluginApi?.tr("panel.infoSize")
      color: Color.mOnSurfaceVariant
    }

    Item { Layout.fillWidth: true }

    NText {
      text: root.selectedWallpaperData && root.formatBytes ? root.formatBytes(root.selectedWallpaperData.bytes) : ""
      color: Color.mOnSurface
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.showDescription && root.selectedDescriptionMarkup.length > 0
    spacing: Style.marginXS

    FontMetrics {
      id: descriptionFontMetrics
      font: descriptionText.font
    }

    NText {
      Layout.fillWidth: true
      text: pluginApi?.tr("panel.infoDescription")
      color: Color.mOnSurfaceVariant
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: {
        if (!root.descriptionShouldCollapse || root.descriptionExpanded) {
          return descriptionText.implicitHeight + Style.marginS * 2;
        }
        return root.collapsedDescriptionHeight + Style.marginS * 2;
      }
      radius: Style.radiusM
      color: Qt.alpha(Color.mSurfaceVariant, 0.2)
      border.width: Style.borderS
      border.color: Qt.alpha(Color.mOutline, 0.22)
      clip: true

      NText {
        id: descriptionMeasureText
        visible: false
        width: descriptionText.width
        text: root.selectedDescriptionMarkup
        textFormat: Text.RichText
        wrapMode: Text.Wrap
        font: descriptionText.font
        onContentHeightChanged: descriptionCollapseEvalTimer.restart()
      }

      NText {
        id: descriptionText
        anchors.fill: parent
        anchors.margins: Style.marginS
        text: root.selectedDescriptionMarkup
        textFormat: Text.RichText
        color: Color.mOnSurfaceVariant
        wrapMode: Text.Wrap
        linkColor: Color.mPrimary
        onLinkActivated: url => Qt.openUrlExternally(url)
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 36 * Style.uiScaleRatio
        visible: root.descriptionShouldCollapse && !root.descriptionExpanded
        color: Qt.rgba(
          Color.mSurfaceVariant.r,
          Color.mSurfaceVariant.g,
          Color.mSurfaceVariant.b,
          0.28
        )
      }
    }

    NButton {
      Layout.fillWidth: true
      visible: root.descriptionShouldCollapse || root.descriptionExpanded
      text: root.descriptionExpanded ? pluginApi?.tr("panel.showLess") : pluginApi?.tr("panel.showMore")
      icon: root.descriptionExpanded ? "chevron-up" : "chevron-down"
      onClicked: root.descriptionExpanded = !root.descriptionExpanded
    }
  }

  Timer {
    id: descriptionCollapseEvalTimer
    interval: 40
    repeat: false
    onTriggered: root.evaluateDescriptionCollapse()
  }
}
