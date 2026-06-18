import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root
  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  property real contentPreferredWidth: 500 * Style.uiScaleRatio
  property real contentPreferredHeight: 640 * Style.uiScaleRatio

  anchors.fill: parent

  readonly property var mainInst: pluginApi?.mainInstance
  readonly property var liveOutputs: mainInst?.liveOutputs || []
  readonly property var niriOutputs: mainInst?.niriOutputs || []
  readonly property bool isNiri: mainInst?.isNiri || false
  readonly property bool loading: mainInst?.loading || false
  readonly property bool modifying: mainInst?.modifying || false

  readonly property var transforms: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]

  readonly property string subtitleText: {
    if (loading) return pluginApi?.tr("panel.loading")
    var count = liveOutputs.length
    if (count === 1) return pluginApi?.tr("panel.singleOutput")
    return pluginApi?.tr("panel.outputCount", { count: count })
  }

  onVisibleChanged: {
    if (!mainInst) return
    if (visible) {
      mainInst.refresh()
      mainInst.startMonitor()
    } else {
      mainInst.stopMonitor()
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors { fill: parent; margins: Style.marginL }
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXXS

          NText {
            text: pluginApi?.tr("panel.title")
            pointSize: Style.fontSizeL; font.weight: Font.Bold; color: Color.mOnSurface
            Layout.fillWidth: true
          }
          NText {
            text: root.subtitleText
            pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant
          }
        }

        NIconButton {
          icon: "reload"; baseSize: 28
          enabled: !root.loading && !root.modifying
          onClicked: { if (root.mainInst) root.mainInst.refresh() }
        }

        NIconButton {
          icon: "x"; baseSize: 28
          onClicked: pluginApi?.closePanel(pluginApi.panelOpenScreen)
        }
      }

      Flickable {
        id: flickable
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: contentCol.implicitHeight
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: contentCol
          width: flickable.width
          spacing: Style.marginM

          ColumnLayout {
            visible: root.loading && root.liveOutputs.length === 0
            Layout.fillWidth: true
            Layout.topMargin: Style.marginXL
            spacing: Style.marginM

            NIcon {
              icon: "loader"; color: Color.mPrimary; pointSize: Style.fontSizeXXL
              Layout.alignment: Qt.AlignHCenter
            }
            NText {
              text: pluginApi?.tr("panel.loading")
              color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeM
              Layout.alignment: Qt.AlignHCenter
            }
          }

          ColumnLayout {
            visible: !root.loading && root.liveOutputs.length === 0
            Layout.fillWidth: true
            Layout.topMargin: Style.marginXL
            spacing: Style.marginM

            NIcon {
              icon: "device-desktop-off"; color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXXL
              Layout.alignment: Qt.AlignHCenter
            }
            NText {
              text: pluginApi?.tr("panel.noOutputs")
              color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeM
              Layout.alignment: Qt.AlignHCenter
            }
          }

          ColumnLayout {
            visible: root.isNiri && !root.loading && root.liveOutputs.length > 0
            Layout.fillWidth: true
            spacing: Style.marginM

            RowLayout {
              spacing: Style.marginS
              NIcon { icon: "activity"; color: Color.mPrimary; pointSize: Style.fontSizeS }
              NText {
                text: pluginApi?.tr("panel.liveSection")
                pointSize: Style.fontSizeM; font.weight: Font.DemiBold; color: Color.mOnSurface
              }
            }

            Repeater {
              model: root.liveOutputs
              delegate: NiriLiveCard {
                output: modelData
                pluginApi: root.pluginApi
                modifying: root.modifying
                transforms: root.transforms
                onModeRequested: label => root.mainInst?.setMode(output.name, label)
                onScaleRequested: scale => root.mainInst?.setScale(output.name, scale)
                onAutoScaleRequested: root.mainInst?.setScale(output.name, "auto")
                onTransformRequested: t => root.mainInst?.setTransform(output.name, t)
                onVrrToggleRequested: root.mainInst?.setVrr(output.name, !output.vrrEnabled)
                onPowerToggleRequested: root.mainInst?.setPower(output.name, !output.enabled)
              }
            }
          }

          ColumnLayout {
            visible: !root.isNiri && !root.loading && root.liveOutputs.length > 0
            Layout.fillWidth: true
            spacing: Style.marginM

            RowLayout {
              spacing: Style.marginS
              NIcon { icon: "activity"; color: Color.mPrimary; pointSize: Style.fontSizeS }
              NText {
                text: pluginApi?.tr("panel.liveSection")
                pointSize: Style.fontSizeM; font.weight: Font.DemiBold; color: Color.mOnSurface
              }
            }

            NText {
              text: pluginApi?.tr("panel.liveDescriptionWlr")
              pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant
              Layout.fillWidth: true
            }

            Repeater {
              model: root.liveOutputs
              delegate: WlrCard {
                output: modelData
                pluginApi: root.pluginApi
              }
            }
          }

          ColumnLayout {
            visible: root.isNiri && !root.loading && root.niriOutputs.length > 0
            Layout.fillWidth: true
            spacing: Style.marginM

            NDivider { Layout.fillWidth: true }

            NText {
              text: pluginApi?.tr("panel.niriSection")
              pointSize: Style.fontSizeM; font.weight: Font.DemiBold; color: Color.mOnSurface
            }

            NText {
              text: pluginApi?.tr("panel.niriDescription")
              pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant
              Layout.fillWidth: true
            }

            Repeater {
              model: root.niriOutputs
              delegate: NiriConfigCard {
                output: modelData
                pluginApi: root.pluginApi
              }
            }
          }

          ColumnLayout {
            visible: root.isNiri && !root.loading && root.niriOutputs.length === 0 && root.liveOutputs.length > 0
            Layout.fillWidth: true
            spacing: Style.marginS

            NDivider { Layout.fillWidth: true }

            NText {
              text: pluginApi?.tr("panel.niriSection")
              pointSize: Style.fontSizeM; font.weight: Font.DemiBold; color: Color.mOnSurfaceVariant
            }
            NText {
              text: pluginApi?.tr("panel.noNiriOutputs")
              pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant
              Layout.fillWidth: true
            }
          }
        }
      }
    }
  }
}
