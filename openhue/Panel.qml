import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Widgets

Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null

  // SmartPanel properties (required for panel behavior)
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  readonly property bool panelAnchorRight: true

  // Preferred dimensions
  property real contentPreferredWidth: 420 * Style.uiScaleRatio
  property real contentPreferredHeight: panelContainer.implicitHeight + Style.marginL * 2

  property int activeTabIdx: 0

  anchors.fill: parent

  Component.onCompleted: {
    if (pluginApi) {
      pluginApi.mainInstance.refresh()
    }
  }

  onPluginApiChanged: {
    if (pluginApi) {
      pluginApi.mainInstance.refresh()
    }
  }

  ColumnLayout {
    id: panelContainer
    anchors {
      fill: parent
      margins: Style.marginL
    }
    spacing: Style.marginL

    // header
    NBox {
      Layout.fillWidth: true
      implicitHeight: headerRow.implicitHeight + (Style.marginM * 2)

      RowLayout {
        id: headerRow
        anchors {
          fill: parent
          margins: Style.marginM
        }
        spacing: Style.marginM

        NIcon {
          icon: "lamp"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        NText {
          text: "Hue lights"
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
          Layout.fillWidth: true
        }

        NIconButton {
          icon: "close"
          tooltipText: "Close"
          baseSize: Style.baseWidgetSize * 0.8
          onClicked: {
            pluginApi.closePanel(screen)
          }
        }
      }
    }

    // Rooms/Lights tab switcher
    NTabBar {
      id: tabs
      Layout.fillWidth: true
      currentIndex: activeTabIdx
      onCurrentIndexChanged: root.activeTabIdx = currentIndex

      NTabButton {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        text: "Lights"
        tabIndex: 0
        checked: tabs.currentIndex === tabIndex
      }

      NTabButton {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        text: "Rooms"
        enabled: false // TODO: Re-enable once implemented
        tabIndex: 1
        checked: tabs.currentIndex === tabIndex
      }
    }

    // Brightness controls
    // Stacklayout used to switch between "lights" and "rooms" views
    StackLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      currentIndex: root.activeTabIdx

      // Lights
      NScrollView {
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
          spacing: Style.marginM
          width: parent.width

          Repeater {
            model: pluginApi.mainInstance.lights

            NBox {
              id: lightBox
              Layout.fillWidth: true
              Layout.preferredHeight: lightCol.implicitHeight + (Style.marginM * 2)

              required property var modelData
              readonly property string id: modelData.id || "0"
              readonly property string name: modelData.name || "Unknown light"
              readonly property real brightness: modelData.brightness || 0.0
              readonly property bool isOn: modelData.on || false

              RowLayout {
                anchors.fill: parent
                anchors.margins: Style.marginL
                spacing: Style.marginM

                ColumnLayout {
                  id: lightCol
                  Layout.fillWidth: true
                  spacing: Style.marginXS

                  NLabel {
                    label: lightBox.name
                    labelColor: Color.mPrimary
                    Layout.fillWidth: true
                  }

                  NValueSlider {
                    Layout.fillWidth: true
                    from: 1
                    to: 100
                    value: lightBox.brightness
                    stepSize: 1
                    heightRatio: 0.5
                    text: Math.round(value) + "%"
                    enabled: true
                    onMoved: value => {
                      root.pluginApi.mainInstance.setLightBrightness(lightBox.id, value)
                    }
                  }
                }

                NToggle {
                  checked: lightBox.isOn
                  onToggled: {
                    root.pluginApi.mainInstance.setLightOnState(lightBox.id, !lightBox.isOn)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
