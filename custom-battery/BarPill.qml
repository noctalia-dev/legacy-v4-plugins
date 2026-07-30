import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root

  required property ShellScreen screen

  property string icon: ""
  property string iconSource: ""
  property string iconBackgroundSource: ""
  property string text: ""
  property string suffix: ""
  property var tooltipText: null
  property bool autoHide: false
  property bool forceOpen: false
  property bool forceClose: false
  property bool oppositeDirection: false
  property bool hovered: false
  property bool rotateText: false
  property color customBackgroundColor: "transparent"
  property color customTextIconColor: "transparent"
  property color customIconColor: "transparent"
  property bool textInsideIcon: false
  property bool transparentBackground: false
  property bool charging: false
  property bool isPowerSaver: false

  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool isVerticalBar: barPosition === "left" || barPosition === "right"

  signal shown
  signal hidden
  signal entered
  signal exited
  signal clicked
  signal rightClicked
  signal middleClicked
  signal wheel(int delta)

  width: isVerticalBar ? parent.width : (pillLoader.item ? pillLoader.item.implicitWidth : 0)
  height: isVerticalBar ? (pillLoader.item ? pillLoader.item.implicitHeight : 0) : parent.height
  implicitWidth: pillLoader.item ? pillLoader.item.implicitWidth : 0
  implicitHeight: pillLoader.item ? pillLoader.item.implicitHeight : 0

  Loader {
    id: pillLoader
    anchors.fill: parent
    sourceComponent: isVerticalBar ? verticalPillComponent : horizontalPillComponent

    Component {
      id: verticalPillComponent
      BarPillHorizontal {
        screen: root.screen
        icon: root.icon
        iconSource: root.iconSource
        text: root.text
        suffix: root.suffix
        tooltipText: root.tooltipText
        autoHide: root.autoHide
        forceOpen: false
        forceClose: true
        oppositeDirection: root.oppositeDirection
        hovered: root.hovered
        customBackgroundColor: root.customBackgroundColor
        customTextIconColor: root.customTextIconColor
        customIconColor: root.customIconColor
        textInsideIcon: root.textInsideIcon
        transparentBackground: root.transparentBackground
        charging: root.charging
        isPowerSaver: root.isPowerSaver
        isVertical: root.isVerticalBar

        onShown: root.shown()
        onHidden: root.hidden()
        onEntered: root.entered()
        onExited: root.exited()
        onClicked: root.clicked()
        onRightClicked: root.rightClicked()
        onMiddleClicked: root.middleClicked()
        onWheel: delta => root.wheel(delta)
      }
    }

    Component {
      id: horizontalPillComponent
      BarPillHorizontal {
        screen: root.screen
        icon: root.icon
        iconSource: root.iconSource
        text: root.text
        suffix: root.suffix
        tooltipText: root.tooltipText
        autoHide: root.autoHide
        forceOpen: root.forceOpen
        forceClose: root.forceClose
        oppositeDirection: root.oppositeDirection
        hovered: root.hovered
        customBackgroundColor: root.customBackgroundColor
        customTextIconColor: root.customTextIconColor
        customIconColor: root.customIconColor
        textInsideIcon: root.textInsideIcon
        transparentBackground: root.transparentBackground
        charging: root.charging
        isPowerSaver: root.isPowerSaver
        isVertical: root.isVerticalBar

        onShown: root.shown()
        onHidden: root.hidden()
        onEntered: root.entered()
        onExited: root.exited()
        onClicked: root.clicked()
        onRightClicked: root.rightClicked()
        onMiddleClicked: root.middleClicked()
        onWheel: delta => root.wheel(delta)
      }
    }
  }

  function show() {
    if (pillLoader.item && pillLoader.item.show) {
      pillLoader.item.show();
    }
  }

  function hide() {
    if (pillLoader.item && pillLoader.item.hide) {
      pillLoader.item.hide();
    }
  }

  function showDelayed() {
    if (pillLoader.item && pillLoader.item.showDelayed) {
      pillLoader.item.showDelayed();
    }
  }
}
