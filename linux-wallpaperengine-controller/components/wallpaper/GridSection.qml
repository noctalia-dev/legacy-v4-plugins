import QtQuick
import QtQuick.Layouts
import QtMultimedia

import "../shared"

import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var mainInstance: null
  property var wallpapers: []
  property string pendingPath: ""
  property string selectedPath: ""
  property bool scanningWallpapers: false
  property int wallpaperItemsCount: 0
  property int visibleWallpaperCount: 0
  property int currentPage: 0
  property int pageCount: 1
  property int currentPageDisplay: 0
  property int currentPageStartIndex: 0
  property int currentPageEndIndex: 0
  property bool paginationVisible: false
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

  function showBadge(key, modelData) {
    const order = root.badgeOrder || [];
    if (order.indexOf(key) < 0) {
      return false;
    }

    if (key === "type") {
      return root.typeLabel && root.typeLabel(modelData.type).length > 0;
    }
    if (key === "dynamic") {
      return true;
    }
    if (key === "music") {
      return !!modelData.hasEmbeddedAudio;
    }
    if (key === "reactive") {
      return !!modelData.hasAudioReactive;
    }
    if (key === "approved") {
      return !!modelData.approved;
    }
    if (key === "resolution") {
      return root.resolutionBadgeIcon && root.resolutionBadgeIcon(modelData.resolution).length > 0;
    }
    if (key === "compatibility") {
      return root.propertyCompatibilityBadgeTextForPath
        && root.propertyCompatibilityBadgeTextForPath(String(modelData.path || "")).length > 0;
    }

    return false;
  }

  signal wallpaperActivated(string path)
  signal previousPageRequested()
  signal nextPageRequested()

  Layout.fillWidth: true
  Layout.fillHeight: true
  spacing: Style.marginS

  Component {
    id: wallpaperCardDelegate

Rectangle {
        id: tileCard
        required property var modelData
        readonly property var wallpaperData: modelData
       readonly property bool isPending: root.pendingPath === modelData.path
       readonly property bool isSelected: root.selectedPath === modelData.path
       readonly property bool isMotion: modelData.motionPreview && modelData.motionPreview.length > 0
       readonly property bool isVideoMotion: root.isVideoMotion && root.isVideoMotion(modelData.motionPreview)
       readonly property bool isInView: {
         const gv = GridView.view;
         const cellY = y - gv.contentY;
         return cellY + height > -50 && cellY < gv.height + 50;
       }
       width: GridView.view.cellWidth
       height: GridView.view.cellHeight
       radius: Style.radiusL
       color: Qt.alpha(Color.mSurface, 0.82)
       border.width: isPending ? 2 : (isSelected ? 1 : 0)
       border.color: isPending ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.45)
       clip: true

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginXS

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 136 * Style.uiScaleRatio
          radius: Style.radiusM
          color: Color.mSurfaceVariant
          clip: true

          Image {
            anchors.fill: parent
            visible: modelData.thumb && modelData.thumb.length > 0
            source: visible ? ("file://" + modelData.thumb) : ""
            fillMode: Image.PreserveAspectCrop
            cache: false
          }

          Loader {
            anchors.fill: parent
            active: tileCard.isMotion
            sourceComponent: tileCard.isVideoMotion ? motionVideoComponent : motionAnimatedComponent
          }

          Component {
            id: motionAnimatedComponent

            AnimatedImage {
              anchors.fill: parent
              source: "file://" + modelData.motionPreview
              fillMode: Image.PreserveAspectCrop
              cache: false
              playing: tileCard.isInView
            }
          }

          Component {
            id: motionVideoComponent

            Video {
              anchors.fill: parent
              autoPlay: tileCard.isInView
              loops: MediaPlayer.Infinite
              muted: true
              fillMode: VideoOutput.PreserveAspectCrop
              source: "file://" + modelData.motionPreview
              visible: tileCard.isInView
            }
          }

          NIcon {
            anchors.centerIn: parent
            visible: (!modelData.thumb || modelData.thumb.length === 0) && (!modelData.motionPreview || modelData.motionPreview.length === 0)
            icon: "photo"
            pointSize: Style.fontSizeXL
            color: Color.mOnSurfaceVariant
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            Layout.fillWidth: true
            text: modelData.name
            color: Color.mOnSurface
            elide: Text.ElideRight
            font.weight: Font.Medium
          }

          NIcon {
            visible: root.selectedPath === modelData.path
            icon: "check"
            pointSize: Style.fontSizeL
            color: Color.mPrimary
          }
        }

        Item {
          id: badgeContainer
          Layout.fillWidth: true
          Layout.preferredHeight: badgeFlow.implicitHeight
          readonly property var visibleBadgeKeys: {
            const ordered = root.badgeOrder || [];
            const result = [];
            for (const key of ordered) {
              if (root.showBadge(String(key || ""), modelData)) {
                result.push(String(key || ""));
              }
            }
            return result;
          }

          Flow {
            id: badgeFlow
            width: parent.width
            spacing: Style.marginXS

            Repeater {
              model: badgeContainer.visibleBadgeKeys

              WallpaperBadge {
                required property var modelData
                compact: true
                badgeIcon: {
                  const key = String(modelData || "");
                  if (key === "type") return root.typeBadgeIcon ? root.typeBadgeIcon(tileCard.wallpaperData.type) : "category";
                  if (key === "dynamic") return root.dynamicBadgeIcon ? root.dynamicBadgeIcon(!!tileCard.wallpaperData.dynamic) : (tileCard.wallpaperData.dynamic ? "player-play" : "player-stop");
                  if (key === "music") return "volume";
                  if (key === "reactive") return "wave-sine";
                  if (key === "approved") return "rosette-discount-check";
                  if (key === "resolution") return "aspect-ratio";
                  if (key === "compatibility") return "settings-cog";
                  return "";
                }
                badgeColor: {
                  const key = String(modelData || "");
                  if (key === "type") return Color.mSecondary;
                  if (key === "dynamic") return tileCard.wallpaperData.dynamic ? Color.mTertiary : Color.mOnSurfaceVariant;
                  if (key === "music") return Color.mPrimary;
                  if (key === "reactive") return Color.mSecondary;
                  if (key === "approved") return Color.mPrimary;
                  if (key === "resolution") return Color.mOnSurfaceVariant;
                  if (key === "compatibility") {
                    const cPath = String(tileCard.wallpaperData.path || "");
                    return root.propertyCompatibilityBadgeColorForPath ? root.propertyCompatibilityBadgeColorForPath(cPath) : Color.mError;
                  }
                  return Color.mOnSurfaceVariant;
                }
                badgeBgColor: {
                  const key = String(modelData || "");
                  if (key === "type") return Qt.alpha(Color.mSecondary, 0.18);
                  if (key === "dynamic") return Qt.alpha(Color.mTertiary, 0.18);
                  if (key === "music") return Qt.alpha(Color.mPrimary, 0.16);
                  if (key === "reactive") return Qt.alpha(Color.mSecondary, 0.16);
                  if (key === "approved") return Qt.alpha(Color.mPrimary, 0.16);
                  if (key === "resolution") return Qt.alpha(Color.mSurfaceVariant, 0.24);
                  if (key === "compatibility") {
                    const cPath = String(tileCard.wallpaperData.path || "");
                    const cColor = root.propertyCompatibilityBadgeColorForPath ? root.propertyCompatibilityBadgeColorForPath(cPath) : Color.mError;
                    return root.propertyCompatibilityBadgeBackgroundForPath ? root.propertyCompatibilityBadgeBackgroundForPath(cPath) : Qt.alpha(cColor, 0.16);
                  }
                  return Qt.alpha(Color.mSurfaceVariant, 0.24);
                }
              }
            }
          }
        }
      }

       MouseArea {
         anchors.fill: parent
         enabled: root.mainInstance?.engineAvailable ?? false
         hoverEnabled: true
         onClicked: root.wallpaperActivated(modelData.path)
       }
    }
  }

  CardGridSection {
    Layout.fillWidth: true
    Layout.fillHeight: true
    pluginApi: root.pluginApi
    items: root.wallpapers
    cardDelegate: wallpaperCardDelegate
    cellHeight: 208 * Style.uiScaleRatio
    showEmptyState: root.wallpapers.length === 0 && !root.scanningWallpapers
    emptyIcon: "photo"
    emptyText: root.wallpaperItemsCount === 0
      ? pluginApi?.tr("panel.emptyAll")
      : pluginApi?.tr("panel.emptyFiltered")
    paginationVisible: root.paginationVisible
    currentPage: root.currentPage
    pageCount: root.pageCount
    currentPageDisplay: root.currentPageDisplay
    currentPageStartIndex: root.currentPageStartIndex
    currentPageEndIndex: root.currentPageEndIndex
    totalVisibleCount: root.visibleWallpaperCount
    onPreviousPageRequested: root.previousPageRequested()
    onNextPageRequested: root.nextPageRequested()
  }
}
