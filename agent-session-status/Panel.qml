import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true
  readonly property var mainInstance: pluginApi?.mainInstance

  property real contentPreferredWidth: 420 * Style.uiScaleRatio
  property real contentPreferredHeight: 520 * Style.uiScaleRatio

  anchors.fill: parent

  function statusIcon(status) {
    if (status === "running") return "loader"
    if (status === "blocked") return "alert-triangle"
    return "circle-check"
  }

  function statusColor(status) {
    if (status === "running") return Color.mPrimary
    if (status === "blocked") return Color.mError
    return Color.mSecondary
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginL
      }
      spacing: Style.marginM

      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: headerRow.implicitHeight + Style.marginM * 2

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "bot"
            color: Color.mPrimary
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            NText {
              text: pluginApi?.tr("panel.title")
              pointSize: Style.fontSizeM
              font.weight: Font.DemiBold
              color: Color.mOnSurface
            }

            NText {
              Layout.fillWidth: true
              text: pluginApi?.tr("panel.subtitle", {
                count: root.mainInstance?.runningCount ?? 0,
                url: root.mainInstance?.serverUrl ?? ""
              })
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              elide: Text.ElideRight
            }
          }

          NIconButton {
            icon: "reload"
            tooltipText: pluginApi?.tr("panel.restart")
            onClicked: root.mainInstance?.restartService()
          }
        }
      }

      NBox {
        visible: !!(root.mainInstance?.serviceError)
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? errorText.implicitHeight + Style.marginM * 2 : 0

        NText {
          id: errorText
          anchors.fill: parent
          anchors.margins: Style.marginM
          text: root.mainInstance?.serviceError ?? ""
          pointSize: Style.fontSizeS
          color: Color.mError
          wrapMode: Text.WordWrap
        }
      }

      NScrollView {
        id: sessionScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth

        ColumnLayout {
          width: sessionScroll.availableWidth
          spacing: Style.marginM

          Repeater {
            model: root.mainInstance?.agents ?? []

            delegate: NBox {
              required property var modelData
              Layout.fillWidth: true
              Layout.preferredHeight: agentColumn.implicitHeight + Style.marginM * 2

              ColumnLayout {
                id: agentColumn
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginS

                  NIcon {
                    icon: "terminal"
                    color: Color.mPrimary
                  }

                  NText {
                    Layout.fillWidth: true
                    text: modelData.agent
                    pointSize: Style.fontSizeM
                    font.weight: Font.DemiBold
                    color: Color.mOnSurface
                    elide: Text.ElideRight
                  }

                  NText {
                    text: pluginApi?.tr("panel.agentRunning", { count: modelData.runningCount ?? 0 })
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                  }
                }

                Repeater {
                  model: modelData.sessions ?? []

                  delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NIcon {
                      icon: root.statusIcon(modelData.status)
                      color: root.statusColor(modelData.status)
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: Style.marginXXS

                      NText {
                        Layout.fillWidth: true
                        text: modelData.title
                        pointSize: Style.fontSizeS
                        color: Color.mOnSurface
                        elide: Text.ElideRight
                      }

                      NText {
                        Layout.fillWidth: true
                        text: pluginApi?.tr("panel.sessionMeta", {
                          id: modelData.id,
                          status: pluginApi?.tr("status." + modelData.status)
                        })
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        elide: Text.ElideMiddle
                      }
                    }
                  }
                }
              }
            }
          }

          Item {
            visible: (root.mainInstance?.agents ?? []).length === 0
            width: sessionScroll.availableWidth
            Layout.fillWidth: true
            Layout.preferredHeight: emptyColumn.implicitHeight + Style.marginXL * 2

            ColumnLayout {
              id: emptyColumn
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.marginS

              NIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: "bot-off"
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXXL
              }

              NText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                text: pluginApi?.tr("panel.empty")
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NButton {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.refresh")
          icon: "refresh"
          onClicked: root.mainInstance?.refreshAndPrune()
        }

        NIconButton {
          icon: "settings"
          tooltipText: pluginApi?.tr("menu.settings")
          onClicked: {
            if (pluginApi) BarService.openPluginSettings(pluginApi.panelOpenScreen, pluginApi.manifest)
          }
        }
      }
    }
  }
}
