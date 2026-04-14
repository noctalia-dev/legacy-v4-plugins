import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: Math.round(420 * Style.uiScaleRatio)
  property real contentPreferredHeight: 500 * Style.uiScaleRatio
  readonly property bool allowAttach: true

  readonly property var mainInstance: pluginApi?.mainInstance
  property string searchQuery: ""
  property int selectedIndex: -1

  readonly property var items: mainInstance?.items ?? []
  readonly property var filteredItems: {
    if (!searchQuery || searchQuery.length === 0) return root.items;
    const q = searchQuery.toLowerCase();
    return root.items.filter(item => {
      const preview = (item.preview || "").toLowerCase();
      return preview.includes(q);
    });
  }

  onSearchQueryChanged: root.selectedIndex = root.filteredItems.length > 0 ? 0 : -1

  function activateSelected() {
    if (root.selectedIndex >= 0 && root.selectedIndex < root.filteredItems.length) {
      const item = root.filteredItems[root.selectedIndex];
      if (item && root.mainInstance) {
        root.mainInstance.copyToClipboard(item.id);
        if (pluginApi) pluginApi.closePanel(pluginApi.panelOpenScreen);
      }
    }
  }

  anchors.fill: parent

  Component.onCompleted: {
    if (mainInstance) mainInstance.refreshOnPanelOpen();
    root.selectedIndex = -1;
    Qt.callLater(function() {
      if (panelSearchInput && panelSearchInput.inputItem) {
        panelSearchInput.inputItem.forceActiveFocus();
      } else {
        panelSearchInput.forceActiveFocus();
      }
    });
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // ── HEADER ──
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(headerRow.implicitHeight + Style.marginM * 2 + 1)

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RowLayout {
            id: headerRow

            NIcon {
              icon: "clipboard"
              pointSize: Style.fontSizeXXL
              color: Color.mPrimary
            }

            NLabel {
              label: pluginApi?.tr("panel.title")
            }

            Item {
              Layout.fillWidth: true
            }

            NIconButton {
              icon: "settings"
              tooltipText: pluginApi?.tr("menu.settings")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                BarService.openPluginSettings(pluginApi.panelOpenScreen, pluginApi.manifest);
              }
            }

            NIconButton {
              icon: "trash"
              tooltipText: pluginApi?.tr("panel.clear-all")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                if (mainInstance) mainInstance.wipeAll();
              }
            }

            NIconButton {
              icon: "x"
              tooltipText: pluginApi?.tr("panel.close")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                if (pluginApi) pluginApi.closePanel(pluginApi.panelOpenScreen);
              }
            }
          }
        }
      }

      // ── SEARCH ──
      NTextInput {
        id: panelSearchInput
        Layout.fillWidth: true
        placeholderText: pluginApi?.tr("panel.search-placeholder")
        text: root.searchQuery
        onTextChanged: root.searchQuery = text

        Keys.onDownPressed: {
          if (root.filteredItems.length > 0) {
            root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredItems.length - 1);
            panelListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
          }
        }
        Keys.onUpPressed: {
          if (root.selectedIndex > 0) {
            root.selectedIndex = root.selectedIndex - 1;
            panelListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
          }
        }
        Keys.onReturnPressed: root.activateSelected()
        Keys.onEscapePressed: {
          if (root.searchQuery !== "") {
            root.searchQuery = "";
            panelSearchInput.text = "";
            root.selectedIndex = -1;
          } else {
            if (pluginApi) pluginApi.closePanel(pluginApi.panelOpenScreen);
          }
        }
      }

      // ── LIST ──
      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        reserveScrollbarSpace: false

        ColumnLayout {
          anchors.fill: parent
          spacing: Style.marginM

          // Items box
          NBox {
            Layout.fillWidth: true
            Layout.preferredHeight: root.filteredItems.length > 0
              ? Math.round(panelListView.contentHeight + Style.marginM * 2)
              : Math.round(Style.marginXL * 4)
            Layout.minimumHeight: Style.marginXL * 2

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: 0

              ListView {
                id: panelListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                currentIndex: root.selectedIndex
                spacing: 0
                interactive: false

                model: root.filteredItems

                delegate: ClipboardItem {
                  required property var modelData
                  required property int index
                  width: panelListView.width
                  pluginApi: root.pluginApi
                  mainInstance: root.mainInstance
                  itemData: modelData
                  selected: index === root.selectedIndex

                  onCopyRequested: itemId => {
                    if (root.mainInstance) {
                      root.mainInstance.copyToClipboard(itemId);
                      if (root.pluginApi) root.pluginApi.closePanel(root.pluginApi.panelOpenScreen);
                    }
                  }

                  onDeleteRequested: itemId => {
                    if (root.mainInstance) root.mainInstance.deleteById(itemId);
                  }
                }
              }

              // Empty / no results (inside the NBox when list is empty)
              ColumnLayout {
                visible: root.filteredItems.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: Style.marginM

                Item { Layout.fillHeight: true }

                NIcon {
                  visible: root.items.length === 0
                  icon: "clipboard"
                  pointSize: Style.fontSizeXXL * 2
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  visible: root.items.length === 0
                  text: pluginApi?.tr("panel.empty")
                  font.pointSize: Style.fontSizeM * Style.uiScaleRatio
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  visible: root.items.length > 0 && root.filteredItems.length === 0
                  text: pluginApi?.tr("panel.no-results")
                  font.pointSize: Style.fontSizeM * Style.uiScaleRatio
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                Item { Layout.fillHeight: true }
              }
            }
          }
        }
      }
    }
  }
}
