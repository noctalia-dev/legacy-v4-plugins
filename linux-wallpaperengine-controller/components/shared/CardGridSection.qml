import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var items: []
  property Component cardDelegate: null
  property real minCardWidth: 244 * Style.uiScaleRatio
  property real cardGap: Style.marginS
  property real cellHeight: 208 * Style.uiScaleRatio
  property bool showEmptyState: items.length === 0
  property string emptyIcon: "photo"
  property string emptyText: ""
  property bool paginationVisible: false
  property int currentPage: 0
  property int pageCount: 1
  property int currentPageDisplay: 0
  property int currentPageStartIndex: 0
  property int currentPageEndIndex: 0
  property int totalVisibleCount: 0

  signal previousPageRequested()
  signal nextPageRequested()

  Layout.fillWidth: true
  Layout.fillHeight: true
  spacing: Style.marginS

  NGridView {
    id: gridView
    Layout.fillWidth: true
    Layout.fillHeight: true
    property int columnCount: Math.max(1, Math.floor((availableWidth + root.cardGap) / (root.minCardWidth + root.cardGap)))
    cellWidth: (availableWidth - ((columnCount - 1) * root.cardGap)) / columnCount
    cellHeight: root.cellHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    model: root.items
    delegate: root.cardDelegate

    Rectangle {
      visible: root.showEmptyState
      anchors.centerIn: parent
      color: "transparent"
      width: 320 * Style.uiScaleRatio
      height: 140 * Style.uiScaleRatio

      ColumnLayout {
        anchors.centerIn: parent
        spacing: Style.marginS

        NIcon {
          Layout.alignment: Qt.AlignHCenter
          icon: root.emptyIcon
          pointSize: Style.fontSizeXL
          color: Color.mOnSurfaceVariant
        }

        NText {
          text: root.emptyText
          color: Color.mOnSurfaceVariant
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
        }
      }
    }
  }

  Rectangle {
    Layout.fillWidth: true
    visible: root.paginationVisible
    implicitHeight: paginationRow.implicitHeight + Style.marginS * 2
    radius: Style.radiusM
    color: Qt.alpha(Color.mSurface, 0.78)
    border.width: Style.borderS
    border.color: Qt.alpha(Color.mOutline, 0.3)

    RowLayout {
      id: paginationRow
      anchors.fill: parent
      anchors.margins: Style.marginS
      spacing: Style.marginS

      NButton {
        text: pluginApi?.tr("panel.prevPage")
        icon: "chevron-left"
        enabled: root.currentPage > 0
        onClicked: root.previousPageRequested()
      }

      NText {
        text: pluginApi?.tr("panel.pageSummary", {
          current: root.currentPageDisplay,
          total: root.pageCount
        })
        color: Color.mOnSurface
        font.weight: Font.Medium
      }

      NText {
        text: pluginApi?.tr("panel.pageRange", {
          start: root.currentPageStartIndex,
          end: root.currentPageEndIndex,
          total: root.totalVisibleCount
        })
        color: Color.mOnSurfaceVariant
      }

      Item { Layout.fillWidth: true }

      NButton {
        text: pluginApi?.tr("panel.nextPage")
        icon: "chevron-right"
        enabled: root.currentPage < root.pageCount - 1
        onClicked: root.nextPageRequested()
      }
    }
  }
}
