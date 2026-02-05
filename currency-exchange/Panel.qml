import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "CurrencyData.js" as CurrencyData

Item {
  id: root

  readonly property bool allowAttach: true
  property var cfg: pluginApi?.pluginSettings || ({})
  property real contentPreferredHeight: 280 * Style.uiScaleRatio
  property real contentPreferredWidth: 420 * Style.uiScaleRatio
  property var currencyModel: CurrencyData.buildCompactModel()
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property real fromAmount: 1.0
  property string fromCurrency: cfg.sourceCurrency || defaults.sourceCurrency
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool loaded: main?.loaded || false
  readonly property bool loading: main?.loading || false
  readonly property var main: pluginApi?.mainInstance
  property var pluginApi: null
  readonly property real rate: main ? main.getRate(fromCurrency, toCurrency) : 0
  readonly property real toAmount: main ? main.convert(fromAmount, fromCurrency, toCurrency) : 0
  property string toCurrency: cfg.targetCurrency || defaults.targetCurrency

  function swapCurrencies() {
    var temp = fromCurrency;
    fromCurrency = toCurrency;
    toCurrency = temp;
  }

  anchors.fill: parent

  Component.onCompleted: {
    if (main) {
      main.fetchRates();
    }
  }

  ListModel {
    id: currencyListModel

    Component.onCompleted: {
      for (var i = 0; i < CurrencyData.currencies.length; i++) {
        var code = CurrencyData.currencies[i];
        append({
          "key": code,
          "name": code
        });
      }
    }
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

      // Header
      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + (Style.marginXL)

        RowLayout {
          id: headerRow

          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            color: Color.mPrimary
            icon: "currency-dollar"
            pointSize: Style.fontSizeXXL
          }
          NText {
            Layout.fillWidth: true
            color: Color.mOnSurface
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            text: pluginApi?.tr("panel.title") || "Currency Converter"
          }
          NIconButton {
            baseSize: Style.baseWidgetSize * 0.8
            icon: "settings"
            tooltipText: pluginApi?.tr("panel.settings") || "Settings"

            onClicked: {
              var screen = pluginApi?.panelOpenScreen;
              if (screen && pluginApi?.manifest) {
                BarService.openPluginSettings(screen, pluginApi.manifest);
              }
            }
          }
          NIconButton {
            baseSize: Style.baseWidgetSize * 0.8
            icon: "refresh"
            tooltipText: pluginApi?.tr("panel.refresh") || "Refresh rates"

            onClicked: {
              if (main)
                main.fetchRates(true);
            }
          }
          NIconButton {
            baseSize: Style.baseWidgetSize * 0.8
            icon: "close"
            tooltipText: pluginApi?.tr("panel.close") || "Close"

            onClicked: {
              if (pluginApi)
                pluginApi.withCurrentScreen(s => pluginApi.closePanel(s));
            }
          }
        }
      }

      // Converter Form
      NBox {
        Layout.fillHeight: true
        Layout.fillWidth: true
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          // Row 1: From input + From combo
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Rectangle {
              id: fromInputRect

              Layout.fillWidth: true
              Layout.preferredHeight: Style.baseWidgetSize
              Layout.preferredWidth: 100
              border.color: fromInput.activeFocus ? Color.mPrimary : Color.mOutline
              border.width: fromInput.activeFocus ? 2 : Style.borderS
              color: Color.mSurfaceVariant
              radius: Style.iRadiusM

              TextInput {
                id: fromInput

                anchors.fill: parent
                anchors.leftMargin: Style.marginL
                anchors.rightMargin: Style.marginL
                color: Color.mOnSurface
                font.pointSize: Style.fontSizeM
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                selectByMouse: true
                text: fromAmount.toString()
                verticalAlignment: Text.AlignVCenter

                validator: RegularExpressionValidator {
                  regularExpression: /^\d*[.,]?\d{0,2}$/
                }

                onTextChanged: {
                  var normalized = text.replace(",", ".");
                  var val = parseFloat(normalized);
                  if (!isNaN(val) && val >= 0) {
                    fromAmount = val;
                  }
                }
              }
            }
            CurrencyComboBox {
              id: fromCombo

              Layout.fillWidth: true
              Layout.preferredWidth: 100
              currentKey: fromCurrency
              minimumWidth: 100
              model: currencyListModel

              onSelected: key => {
                fromCurrency = key;
              }
            }
          }

          // Swap row
          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.baseWidgetSize * 0.8
            spacing: Style.marginS

            Item {
              Layout.fillWidth: true
            }
            NIconButton {
              baseSize: Style.baseWidgetSize * 0.7
              icon: "arrows-exchange"
              tooltipText: pluginApi?.tr("panel.swap") || "Swap currencies"

              onClicked: swapCurrencies()
            }
            Item {
              Layout.fillWidth: true
            }
          }

          // Row 2: To input (result) + To combo
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Rectangle {
              id: toInputRect

              Layout.fillWidth: true
              Layout.preferredHeight: Style.baseWidgetSize
              Layout.preferredWidth: 100
              color: Color.mPrimary
              radius: Style.iRadiusM

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginL
                anchors.rightMargin: Style.marginS
                spacing: Style.marginXS

                NText {
                  Layout.fillHeight: true
                  Layout.fillWidth: true
                  color: Color.mOnPrimary
                  font.weight: Style.fontWeightBold
                  horizontalAlignment: Text.AlignRight
                  pointSize: Style.fontSizeM
                  text: loaded ? toAmount.toFixed(2) : (loading ? "..." : "--")
                  verticalAlignment: Text.AlignVCenter
                }
                NIconButton {
                  id: copyBtn

                  Layout.alignment: Qt.AlignVCenter
                  baseSize: Style.baseWidgetSize * 0.7
                  icon: "copy"
                  tooltipText: pluginApi?.tr("panel.copy_result") || "Copy result"
                  visible: loaded && toAmount > 0

                  onClicked: main.copyToClipboard(toAmount.toFixed(2))
                }
              }
            }
            CurrencyComboBox {
              id: toCombo

              Layout.fillWidth: true
              Layout.preferredWidth: 100
              currentKey: toCurrency
              minimumWidth: 100
              model: currencyListModel

              onSelected: key => {
                toCurrency = key;
              }
            }
          }
          Item {
            Layout.fillHeight: true
          }

          // Rate info
          NText {
            Layout.fillWidth: true
            color: Color.mOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            pointSize: Style.fontSizeS
            text: {
              if (loading)
                return pluginApi?.tr("panel.loading") || "Loading rates...";
              if (!loaded)
                return pluginApi?.tr("panel.error") || "Could not load rates";
              return pluginApi?.tr("panel.rate_format", {
                from: fromCurrency,
                rate: main?.formatNumber(rate),
                to: toCurrency
              }) || ("1 " + fromCurrency + " = " + main?.formatNumber(rate) + " " + toCurrency);
            }
          }

          // Last update time
          NText {
            Layout.fillWidth: true
            color: Color.mOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.6
            pointSize: Style.fontSizeXS
            text: {
              if (!main?.lastFetch)
                return "";
              var date = new Date(main.lastFetch);
              var timeStr = date.toLocaleTimeString(Qt.locale(), "HH:mm");
              return pluginApi?.tr("panel.updated", {
                time: timeStr
              }) || ("Updated " + timeStr);
            }
            visible: loaded && main?.lastFetch > 0
          }
        }
      }
    }
  }
}
