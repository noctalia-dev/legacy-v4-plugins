import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Flat clipboard row — Klipper-style.
// Transparent by default, highlight on hover or keyboard selection,
// action icons appear on the right on hover.
Item {
  id: root

  property var pluginApi: null
  property var mainInstance: null
  property var itemData: null
  property bool selected: false

  signal copyRequested(string itemId)
  signal deleteRequested(string itemId)

  readonly property string itemId: itemData?.id ?? ""
  readonly property string preview: itemData?.preview ?? ""
  readonly property bool isImage: itemData?.isImage ?? false
  readonly property string mime: itemData?.mime ?? "text/plain"
  readonly property bool enableImages: mainInstance?.enableImages ?? true

  readonly property bool highlighted: root.selected || itemMouse.containsMouse

  implicitHeight: Style.marginXL * 2

  // ── Row background ──
  Rectangle {
    anchors.fill: parent
    radius: Style.radiusS
    color: {
      if (root.selected) return Qt.alpha(Color.mPrimary, 0.15);
      if (itemMouse.containsMouse) return Color.mSurfaceVariant;
      return "transparent";
    }
    Behavior on color { ColorAnimation { duration: 100 } }
  }

  MouseArea {
    id: itemMouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: root.copyRequested(root.itemId)
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.marginM
    anchors.rightMargin: Style.marginS
    spacing: Style.marginS

    // ── Text preview ──
    NText {
      visible: !root.isImage
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: root.preview
      font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      color: Color.mOnSurface
      elide: Text.ElideRight
      maximumLineCount: 1
      wrapMode: Text.NoWrap
    }

    // ── Image thumbnail ──
    Image {
      id: imagePreview
      visible: root.isImage && root.enableImages
      Layout.alignment: Qt.AlignVCenter
      Layout.preferredWidth: 32 * Style.uiScaleRatio
      Layout.preferredHeight: 32 * Style.uiScaleRatio
      fillMode: Image.PreserveAspectFit
      sourceSize.height: 32
      source: {
        if (!root.isImage || !root.enableImages || !root.mainInstance) return "";
        const cached = root.mainInstance.getImageData(root.itemId);
        if (cached) return cached;
        root.mainInstance.decodeToDataUrl(root.itemId, root.mime, null);
        return "";
      }

      readonly property int cacheRev: root.mainInstance?.imageCacheRevision ?? 0
      onCacheRevChanged: {
        if (root.isImage && root.enableImages && root.mainInstance) {
          const cached = root.mainInstance.getImageData(root.itemId);
          if (cached) source = cached;
        }
      }
    }

    // ── Image fallback label ──
    NText {
      visible: root.isImage && (!root.enableImages || imagePreview.source === "")
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: pluginApi?.tr("item.image-label")
      font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      color: Color.mOnSurfaceVariant
      font.italic: true
      elide: Text.ElideRight
      maximumLineCount: 1
      wrapMode: Text.NoWrap
    }

    // ── Action icons (visible on hover or selected) ──
    RowLayout {
      visible: root.highlighted
      spacing: Style.marginXS
      Layout.alignment: Qt.AlignVCenter

      NIconButton {
        icon: "copy"
        baseSize: Style.baseWidgetSize * 0.7
        tooltipText: pluginApi?.tr("item.copy")
        colorFg: Color.mPrimary
        onClicked: root.copyRequested(root.itemId)
      }

      NIconButton {
        icon: "trash"
        baseSize: Style.baseWidgetSize * 0.7
        tooltipText: pluginApi?.tr("item.delete")
        colorFg: Color.mError
        onClicked: root.deleteRequested(root.itemId)
      }
    }
  }
}
