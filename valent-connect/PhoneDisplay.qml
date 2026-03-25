import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Commons
import qs.Widgets

Rectangle {
  id: phoneRoot

  // Public properties
  property string backgroundImage: "" // Path to background image

  // Scale to parent while maintaining iPhone-like proportions
  height: parent ? parent.height : 235
  width: (height / 235) * 115

  // Dynamically scaled corner radius based on size
  readonly property real scaleFactor: Math.min(width / 115, height / 235)
  radius: 20 * scaleFactor

  color: "#1c1c1e"

  RectangularShadow {
    anchors.fill: phoneRect
    radius: phoneRoot.radius
    blur: 15
    spread: 1
  }

  // Bezel/frame
  Rectangle {
    id: phoneRect

    anchors {
      fill: parent
      margins: 2 * phoneRoot.scaleFactor
    }
    radius: 18 * phoneRoot.scaleFactor
    color: "black"

    // Screen
    Rectangle {
      id: screen
      anchors {
        fill: parent
        margins: 1 * phoneRoot.scaleFactor
      }
      radius: 17 * phoneRoot.scaleFactor
      color: "black"
      clip: true

      // Background wallpaper
      Image {
        anchors.fill: parent
        source: phoneRoot.backgroundImage
        fillMode: Image.PreserveAspectCrop
        visible: phoneRoot.backgroundImage !== ""

        // Fallback gradient if no image
        Rectangle {
          anchors.fill: parent
          visible: phoneRoot.backgroundImage === ""
          gradient: Gradient {
            GradientStop { position: 0.0; color: "#2c3e50" }
            GradientStop { position: 1.0; color: "#34495e" }
          }
        }
      }

      // Dynamic Island
      Rectangle {
        id: dynamicIsland
        anchors {
          top: parent.top
          horizontalCenter: parent.horizontalCenter
          topMargin: 6 * phoneRoot.scaleFactor
        }
        width: 48 * phoneRoot.scaleFactor
        height: 10 * phoneRoot.scaleFactor
        radius: 5 * phoneRoot.scaleFactor
        color: "black"
      }

      // Home indicator (bottom gesture bar)
      Rectangle {
        anchors {
          bottom: parent.bottom
          horizontalCenter: parent.horizontalCenter
          bottomMargin: 6 * phoneRoot.scaleFactor
        }
        width: 40 * phoneRoot.scaleFactor
        height: 4 * phoneRoot.scaleFactor
        radius: 2 * phoneRoot.scaleFactor
        color: "white"
        opacity: 0.4
      }
    }
  }
}
