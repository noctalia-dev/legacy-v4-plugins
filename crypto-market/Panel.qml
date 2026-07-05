import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property int tick: mainInstance?.refreshNonce ?? 0

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  property real contentPreferredWidth: 680 * Style.uiScaleRatio
  property real contentPreferredHeight: 480 * Style.uiScaleRatio

  anchors.fill: parent

  function tr(key) {
    const t = root.tick;
    return mainInstance ? mainInstance.tr(key) : key;
  }

  function buildCoinRows() {
    const t = root.tick;  // 强制依赖刷新
    const watchList = mainInstance?.watchList ?? [];
    const rows = [];

    for (let i = 0; i < watchList.length; i++) {
      const coin = watchList[i];
      const key = mainInstance?.normalizeAssetKey(coin) ?? coin;
      const data = mainInstance?.marketData[key];
      rows.push({
        coin: key,
        price: mainInstance?.formatPrice(data?.close) ?? "--",
        change: mainInstance?.formatChange(data?.change) ?? "--",
        high: mainInstance?.formatPrice(data?.high) ?? "--",
        low: mainInstance?.formatPrice(data?.low) ?? "--",
        color: mainInstance?.getPriceColor(coin) ?? Color.mOnSurface
      });
    }

    return rows;
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: mainLayout
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // 标题栏
      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.margin2M

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            pointSize: Style.fontSizeXXL
            color: Color.mPrimary
            icon: "chart-line"
          }

          ColumnLayout {
            spacing: Style.marginXXS
            Layout.fillWidth: true

            NText {
              text: root.tr("panel.title")
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: `${root.tr("panel.refresh")}: ${mainInstance?.refreshInterval ?? 5} ${root.tr("settings.seconds")}`
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              Layout.fillWidth: true
            }
          }

          NIconButton {
            icon: "refresh"
            tooltipText: root.tr("panel.refreshNow")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              if (mainInstance && mainInstance.watchList) {
                for (let i = 0; i < mainInstance.watchList.length; i++) {
                  mainInstance.fetchMarketData(mainInstance.watchList[i]);
                }
              }
            }
          }

          NIconButton {
            icon: "settings"
            tooltipText: root.tr("panel.settings")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              if (pluginApi) {
                BarService.openPluginSettings(pluginApi.panelOpenScreen, pluginApi.manifest);
              }
            }
          }

          NIconButton {
            icon: "close"
            tooltipText: root.tr("panel.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              if (pluginApi) {
                pluginApi.closePanel(pluginApi.panelOpenScreen);
              }
            }
          }
        }
      }

      // 加载/错误状态
      NBox {
        Layout.fillWidth: true
        visible: (mainInstance?.isLoading ?? true) || (mainInstance?.errorMessage ?? false)
        implicitHeight: statusText.implicitHeight + Style.margin2L

        NText {
          id: statusText
          anchors.centerIn: parent
          text: {
            if (mainInstance?.isLoading) return "⏳ " + root.tr("panel.loading");
            if (mainInstance?.errorMessage) return `⚠️ ${mainInstance.errorMessage}`;
            return "";
          }
          pointSize: Style.fontSizeM
          color: mainInstance?.errorMessage ? Color.mError : Color.mOnSurfaceVariant
        }
      }

      // 行情表格
      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !(mainInstance?.isLoading) && !mainInstance?.errorMessage

        Flickable {
          anchors.fill: parent
          anchors.margins: Style.marginL
          contentHeight: tableColumn.height
          clip: true

          ColumnLayout {
            id: tableColumn
            width: parent.width
            spacing: Style.marginS

            // 表头
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM

              Item {
                Layout.preferredWidth: 32 * Style.uiScaleRatio
                Layout.preferredHeight: 1
              }

              NText {
                Layout.preferredWidth: 80 * Style.uiScaleRatio
                text: root.tr("panel.coin")
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightBold
                color: Color.mOnSurfaceVariant
              }

              NText {
                Layout.preferredWidth: 140 * Style.uiScaleRatio
                text: root.tr("panel.price")
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightBold
                color: Color.mOnSurfaceVariant
              }

              NText {
                Layout.preferredWidth: 110 * Style.uiScaleRatio
                text: root.tr("panel.change")
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightBold
                color: Color.mOnSurfaceVariant
              }

              NText {
                Layout.preferredWidth: 120 * Style.uiScaleRatio
                text: root.tr("panel.high")
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightBold
                color: Color.mOnSurfaceVariant
              }

              NText {
                Layout.preferredWidth: 120 * Style.uiScaleRatio
                text: root.tr("panel.low")
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightBold
                color: Color.mOnSurfaceVariant
              }
            }

            NDivider {
              Layout.fillWidth: true
            }

            Repeater {
              model: buildCoinRows()

              delegate: RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                Component.onCompleted: {
                  mainInstance?.requestLogo(modelData.coin);
                }

                Item {
                  Layout.preferredWidth: 32 * Style.uiScaleRatio
                  Layout.preferredHeight: 28 * Style.uiScaleRatio

                  Image {
                    id: coinLogoImage
                    anchors.centerIn: parent
                    width: 24 * Style.uiScaleRatio
                    height: 24 * Style.uiScaleRatio
                    source: mainInstance?.getLogoPath(modelData.coin) ?? ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    smooth: true
                    visible: source !== "" && status === Image.Ready

                    layer.enabled: true
                    layer.effect: OpacityMask {
                      maskSource: Rectangle {
                        width: coinLogoImage.width
                        height: coinLogoImage.height
                        radius: coinLogoImage.width / 2
                        visible: false
                      }
                    }
                  }

                  NText {
                    anchors.centerIn: parent
                    visible: coinLogoImage.source === "" || coinLogoImage.status === Image.Error
                    text: mainInstance?.getCoinIcon(modelData.coin) ?? "🔸"
                    pointSize: Style.fontSizeL
                  }
                }

                NText {
                  Layout.preferredWidth: 80 * Style.uiScaleRatio
                  text: modelData.coin.toUpperCase()
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightMedium
                  color: Color.mOnSurface
                }

                NText {
                  Layout.preferredWidth: 140 * Style.uiScaleRatio
                  text: modelData.price
                  pointSize: Style.fontSizeM
                  color: modelData.color
                }

                NText {
                  Layout.preferredWidth: 110 * Style.uiScaleRatio
                  text: modelData.change
                  pointSize: Style.fontSizeM
                  color: modelData.color
                }

                NText {
                  Layout.preferredWidth: 120 * Style.uiScaleRatio
                  text: modelData.high
                  pointSize: Style.fontSizeS
                  color: Color.mOnSurfaceVariant
                }

                NText {
                  Layout.preferredWidth: 120 * Style.uiScaleRatio
                  text: modelData.low
                  pointSize: Style.fontSizeS
                  color: Color.mOnSurfaceVariant
                }
              }
            }
          }
        }
      }

      // 底部信息
      NText {
        Layout.fillWidth: true
        visible: !(mainInstance?.isLoading) && !mainInstance?.errorMessage
        text: {
          const source = mainInstance?.dataSource || "huobi";
          const sourceName = root.tr("dataSource." + source);
          return root.tr("panel.dataFrom") + ": " + sourceName;
        }
        pointSize: Style.fontSizeXS
        color: Color.mOnSurfaceVariant
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }
}
