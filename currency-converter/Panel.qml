import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null
  
  // SmartPanel properties
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 400 * Style.uiScaleRatio
  property real contentPreferredHeight: 320 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  
  anchors.fill: parent

  // Configuration
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Local state
  property string fromCurrency: cfg.fromCurrency || defaults.fromCurrency || "USD"
  property string toCurrency: cfg.toCurrency || defaults.toCurrency || "BRL"
  property real fromAmount: 1.0
  property real toAmount: 0.0
  property var availableRates: ({})
  property var currencies: []
  property real exchangeRate: 0.0
  property bool loading: false

  Component.onCompleted: {
    // Build currency list from common currencies
    currencies = [
      "USD", "EUR", "BRL", "GBP", "JPY", "CNY", "CAD", "AUD", 
      "CHF", "INR", "MXN", "ARS", "CLP", "COP", "PEN", "UYU"
    ];
    fetchExchangeRates();
  }

  // API call process
  Process {
    id: apiProcess
    running: false

    command: [
      "curl",
      "-s",
      `https://api.exchangerate-api.com/v4/latest/USD`
    ]

    stdout: StdioCollector {}

    onExited: exitCode => {
      loading = false;
      if (exitCode === 0) {
        try {
          var response = JSON.parse(stdout.text);
          if (response.rates) {
            availableRates = response.rates;
            calculateConversion();
          }
        } catch (e) {
          Logger.d("Error parsing exchange rates:", e);
        }
      } else {
        Logger.d("Failed to fetch exchange rates");
      }
    }
  }

  function fetchExchangeRates() {
    if (loading) return;
    loading = true;
    apiProcess.running = true;
  }

  onFromAmountChanged: calculateConversion()
  onFromCurrencyChanged: calculateConversion()
  onToCurrencyChanged: calculateConversion()
  onAvailableRatesChanged: calculateConversion()

  function calculateConversion() {
    if (!availableRates || Object.keys(availableRates).length === 0) {
      toAmount = 0;
      return;
    }

    // Get rates relative to the base currency (USD from API)
    var baseRate = availableRates[fromCurrency] || 1;
    var targetRate = availableRates[toCurrency] || 1;
    
    // Calculate conversion
    var rate = targetRate / baseRate;
    toAmount = fromAmount * rate;
  }

  function swapCurrencies() {
    var temp = fromCurrency;
    fromCurrency = toCurrency;
    toCurrency = temp;
    calculateConversion();
    saveSelectedCurrencies();
  }

  function saveSelectedCurrencies() {
    if (pluginApi && pluginApi.pluginSettings) {
      pluginApi.pluginSettings.fromCurrency = fromCurrency;
      pluginApi.pluginSettings.toCurrency = toCurrency;
      pluginApi.saveSettings();
      Logger.d("Currency Converter: Saved currencies -", fromCurrency, "to", toCurrency);
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginL

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM

          // Header
          NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: headerContent.implicitHeight + Style.marginL * 2
        color: Color.mSurfaceVariant

        ColumnLayout {
          id: headerContent
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
              icon: "currency-dollar"
              pointSize: Style.fontSizeXXL
              color: Color.mPrimary
            }

            NText {
              text: pluginApi?.tr("currency-converter.title") || "Currency Converter"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NIconButton {
              icon: "refresh"
              tooltipText: pluginApi?.tr("currency-converter.refresh") || "Refresh rates"
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                fetchExchangeRates();
              }
            }

            NIconButton {
              icon: "settings"
              tooltipText: pluginApi?.tr("currency-converter.settings.open-settings") || "Open settings"
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                // Close this panel first, then open the plugin settings on the same screen
                var screen = pluginApi?.panelOpenScreen;
                if (screen) {
                  pluginApi.closePanel(screen);
                  Qt.callLater(function() {
                    BarService.openPluginSettings(screen, pluginApi.manifest);
                  });
                } else if (pluginApi && pluginApi.withCurrentScreen) {
                  // Fallback for contexts where panelOpenScreen isn't available
                  pluginApi.withCurrentScreen(function(s) {
                    pluginApi.closePanel(s);
                    Qt.callLater(function() {
                      BarService.openPluginSettings(s, pluginApi.manifest);
                    });
                  });
                } else {
                  // Last-resort fallback to older API
                  try {
                    pluginApi.openSettings(root.screen, root);
                  } catch (e) {
                    try {
                      pluginApi.openSettings();
                    } catch (err) {
                      Logger.w("Currency", "openSettings failed:", err);
                    }
                  }
                }
              }
            }
          }
        }
      }

      // From section
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          text: pluginApi?.tr("currency-converter.from") || "From"
          color: Color.mOnSurface
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
        }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM

              NTextInput {
                id: fromAmountInput
                Layout.fillWidth: true
                Layout.preferredHeight: Style.baseWidgetSize
                text: fromAmount.toString()
                
                property var numberValidator: DoubleValidator {
                  bottom: 0
                  decimals: 2
                  notation: DoubleValidator.StandardNotation
                }
                
                Component.onCompleted: {
                  if (inputItem) {
                    inputItem.validator = numberValidator;
                  }
                }
                
                onTextChanged: {
                  var val = parseFloat(text);
                  if (!isNaN(val) && val >= 0) {
                    fromAmount = val;
                  }
                }
              }

              ComboBox {
                id: fromCurrencyCombo
                Layout.preferredWidth: 120 * Style.uiScaleRatio
                Layout.preferredHeight: Style.baseWidgetSize
                model: currencies
                currentIndex: currencies.indexOf(fromCurrency)
                
                onActivated: index => {
                  fromCurrency = currencies[index];
                  saveSelectedCurrencies();
                }

                background: Rectangle {
                  color: Color.mSurface
                  border.color: Color.mOutline
                  border.width: Style.borderS
                  radius: Style.iRadiusM
                }

                contentItem: NText {
                  leftPadding: Style.marginM
                  rightPadding: Style.marginM
                  pointSize: Style.fontSizeM
                  verticalAlignment: Text.AlignVCenter
                  color: Color.mOnSurface
                  text: fromCurrencyCombo.displayText
                }

                indicator: NIcon {
                  x: fromCurrencyCombo.width - width - Style.marginS
                  y: fromCurrencyCombo.topPadding + (fromCurrencyCombo.availableHeight - height) / 2
                  icon: "caret-down"
                  pointSize: Style.fontSizeM
                }

                popup: Popup {
                  y: fromCurrencyCombo.height
                  implicitWidth: fromCurrencyCombo.width
                  implicitHeight: Math.min(300, fromCurrencyListView.contentHeight + Style.marginM * 2)
                  padding: Style.marginM

                  contentItem: ListView {
                    id: fromCurrencyListView
                    clip: true
                    model: fromCurrencyCombo.model
                    currentIndex: fromCurrencyCombo.highlightedIndex

                    delegate: Rectangle {
                      required property int index
                      required property string modelData
                      property bool isHighlighted: fromCurrencyListView.currentIndex === index

                      width: fromCurrencyListView.width
                      height: delegateText.implicitHeight + Style.marginS * 2
                      radius: Style.iRadiusS
                      color: isHighlighted ? Color.mHover : Color.transparent

                      NText {
                        id: delegateText
                        anchors.fill: parent
                        anchors.leftMargin: Style.marginM
                        anchors.rightMargin: Style.marginM
                        verticalAlignment: Text.AlignVCenter
                        pointSize: Style.fontSizeM
                        color: parent.isHighlighted ? Color.mOnHover : Color.mOnSurface
                        text: modelData
                      }

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: {
                          if (containsMouse)
                            fromCurrencyListView.currentIndex = index;
                        }
                        onClicked: {
                          fromCurrencyCombo.currentIndex = index;
                          fromCurrencyCombo.activated(index);
                          fromCurrencyCombo.popup.close();
                        }
                      }
                    }
                  }

                  background: Rectangle {
                    color: Color.mSurfaceVariant
                    border.color: Color.mOutline
                    border.width: Style.borderS
                    radius: Style.iRadiusM
                  }
                }
              }
            }
          }

          // Swap button (centered between the From and To inputs)
          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.baseWidgetSize * 1.0
            Layout.topMargin: Style.marginS
            Layout.bottomMargin: Style.marginS
            Layout.alignment: Qt.AlignHCenter

            NIconButton {
              icon: "arrows-exchange"
              tooltipText: pluginApi?.tr("currency-converter.swap") || "Swap currencies"
              baseSize: Style.baseWidgetSize * 1.2
              colorBg: Color.mPrimary
              colorFg: Color.mOnPrimary
              onClicked: swapCurrencies()
            }
          }

          // To section
          ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: -Style.marginL
            spacing: Style.marginS

            NText {
              text: pluginApi?.tr("currency-converter.to") || "To"
              color: Color.mOnSurface
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightBold
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.baseWidgetSize
                color: Color.mSurfaceVariant
                border.color: Color.mOutline
                border.width: Style.borderS
                radius: Style.iRadiusM

                NText {
                  anchors.fill: parent
                  anchors.leftMargin: Style.marginM
                  anchors.rightMargin: Style.marginM
                  verticalAlignment: Text.AlignVCenter
                  text: toAmount.toFixed(2)
                  color: Color.mPrimary
                  pointSize: Style.fontSizeL
                  font.weight: Style.fontWeightBold
                }
              }

              ComboBox {
                id: toCurrencyCombo
                Layout.preferredWidth: 120 * Style.uiScaleRatio
                Layout.preferredHeight: Style.baseWidgetSize
                model: currencies
                currentIndex: currencies.indexOf(toCurrency)
                
                onActivated: index => {
                  toCurrency = currencies[index];
                  saveSelectedCurrencies();
                }

                background: Rectangle {
                  color: Color.mSurface
                  border.color: Color.mOutline
                  border.width: Style.borderS
                  radius: Style.iRadiusM
                }

                contentItem: NText {
                  leftPadding: Style.marginM
                  rightPadding: Style.marginM
                  pointSize: Style.fontSizeM
                  verticalAlignment: Text.AlignVCenter
                  color: Color.mOnSurface
                  text: toCurrencyCombo.displayText
                }

                indicator: NIcon {
                  x: toCurrencyCombo.width - width - Style.marginS
                  y: toCurrencyCombo.topPadding + (toCurrencyCombo.availableHeight - height) / 2
                  icon: "caret-down"
                  pointSize: Style.fontSizeM
                }

                popup: Popup {
                  y: toCurrencyCombo.height
                  implicitWidth: toCurrencyCombo.width
                  implicitHeight: Math.min(300, toCurrencyListView.contentHeight + Style.marginM * 2)
                  padding: Style.marginM

                  contentItem: ListView {
                    id: toCurrencyListView
                    clip: true
                    model: toCurrencyCombo.model
                    currentIndex: toCurrencyCombo.highlightedIndex

                    delegate: Rectangle {
                      required property int index
                      required property string modelData
                      property bool isHighlighted: toCurrencyListView.currentIndex === index

                      width: toCurrencyListView.width
                      height: toDelegateText.implicitHeight + Style.marginS * 2
                      radius: Style.iRadiusS
                      color: isHighlighted ? Color.mHover : Color.transparent

                      NText {
                        id: toDelegateText
                        anchors.fill: parent
                        anchors.leftMargin: Style.marginM
                        anchors.rightMargin: Style.marginM
                        verticalAlignment: Text.AlignVCenter
                        pointSize: Style.fontSizeM
                        color: parent.isHighlighted ? Color.mOnHover : Color.mOnSurface
                        text: modelData
                      }

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: {
                          if (containsMouse)
                            toCurrencyListView.currentIndex = index;
                        }
                        onClicked: {
                          toCurrencyCombo.currentIndex = index;
                          toCurrencyCombo.activated(index);
                          toCurrencyCombo.popup.close();
                        }
                      }
                    }
                  }

                  background: Rectangle {
                    color: Color.mSurfaceVariant
                    border.color: Color.mOutline
                    border.width: Style.borderS
                    radius: Style.iRadiusM
                  }
                }
              }
            }
          }
        }
      }

      // Exchange rate info
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: rateInfoText.implicitHeight + Style.marginM * 2
        Layout.topMargin: Style.marginS
        color: Color.mSurfaceVariant
        radius: Style.iRadiusM

        NText {
          id: rateInfoText
          anchors.fill: parent
          anchors.margins: Style.marginM
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
          text: {
            if (!availableRates || Object.keys(availableRates).length === 0) {
              return pluginApi?.tr("currency-converter.no-data") || "No data available";
            }
            var baseRate = availableRates[fromCurrency] || 1;
            var targetRate = availableRates[toCurrency] || 1;
            var rate = (targetRate / baseRate).toFixed(4);
            return `1 ${fromCurrency} = ${rate} ${toCurrency}`;
          }
        }
      }
    }
  }
}
