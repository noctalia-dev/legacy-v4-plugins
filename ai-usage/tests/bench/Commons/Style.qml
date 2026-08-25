pragma Singleton
import QtQuick

// Style stub — tokens used by the plugin's panes (Settings + BarWidget).
QtObject {
  readonly property real fontSizeXXS: 8
  readonly property real fontSizeXS: 9
  readonly property real fontSizeS: 10
  readonly property real fontSizeM: 11
  readonly property real fontSizeL: 13
  readonly property real fontSizeXL: 16
  readonly property real fontSizeXXL: 18
  readonly property real fontSizeXXXL: 24
  readonly property int radiusS: 8
  readonly property int radiusM: 12
  readonly property int fontWeightRegular: 400
  readonly property int fontWeightSemiBold: 600
  readonly property int iRadiusS: 12
  readonly property int iRadiusM: 16
  readonly property int radiusL: 20
  readonly property int marginXXS: 2
  readonly property int marginXS: 4
  readonly property int marginS: 6
  readonly property int marginM: 9
  readonly property int marginL: 13
  readonly property real baseWidgetSize: 33
  readonly property real uiScaleRatio: 1.0

  readonly property color capsuleColor: "#20202a"
  readonly property color capsuleBorderColor: "#31313f"
  readonly property int capsuleBorderWidth: 1

  function pixelAlignCenter(outer, inner) {
    return Math.round((outer - inner) / 2);
  }
  function getBarHeightForScreen(name) { return 30 }
  function getCapsuleHeightForScreen(name) { return 24 }
  function getBarFontSizeForScreen(name) { return 11 }
}
